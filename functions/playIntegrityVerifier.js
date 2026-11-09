/**
 * Google Play Integrity Token Verification Engine
 * 
 * Verifies and validates Google Play Integrity API tokens according to Google's
 * security specifications, checking all 7 Play Integrity signals:
 * 1. Play licensing checks (accountDetails.appLicensingVerdict)
 * 2. App integrity checks (appIntegrity.appRecognitionVerdict)
 * 3. Device integrity checks (deviceIntegrity.deviceRecognitionVerdict)
 * 4. Virtual integrity checks (MEETS_VIRTUAL_INTEGRITY)
 * 5. Recent device activity (deviceIntegrity.recentDeviceActivity.deviceActivityLevel)
 * 6. Play Protect status (environmentDetails.playProtectVerdict)
 * 7. App access risk (environmentDetails.appAccessRiskVerdict)
 */

const https = require('https');

/**
 * Standard security policy configuration for integrity evaluation.
 */
const DEFAULT_SECURITY_POLICY = {
  // 1. Account Licensing
  requireLicensed: true, // Must be 'LICENSED'

  // 2. App Recognition
  requireAppRecognition: true, // Must be 'PLAY_RECOGNIZED'
  allowedPackageNames: ['com.chefandcost.app'],
  minVersionCode: 1,
  allowedCertificateSha256Digests: [], // Empty array = allow any valid Play-recognized cert

  // 3 & 4. Device & Virtual Integrity
  requireDeviceIntegrity: true, // Must contain 'MEETS_DEVICE_INTEGRITY' or 'MEETS_STRONG_INTEGRITY'
  requireStrongIntegrity: false, // Hardware-backed key attestation (optional for ultra-sensitive flows)
  allowVirtualIntegrity: true, // Allow Google Play Games for PC

  // 5. Recent Device Activity (detect token farms / hyperactive botnets)
  maxDeviceActivityLevel: 'LEVEL_2', // Reject 'LEVEL_3' and 'LEVEL_4'

  // 6. Google Play Protect Status
  requireCleanPlayProtect: true, // Must be 'NO_ISSUES' (reject 'WARNING', 'DANGEROUS')

  // 7. App Access Risk (Tapjacking & screen overlay defense)
  requireCleanAppAccessRisk: true, // otherAppsWithDisplayOverOtherAppsVerdict must be 'NO_ISSUES'

  // Replay Attack Protection
  maxTokenAgeSeconds: 300, // Tokens must be <= 5 minutes old
};

/**
 * Verifies a Google Play Integrity token payload against the security policy.
 * 
 * @param {Object} payload The decrypted `tokenPayloadExternal` from Google Play Integrity API
 * @param {Object} options Validation options (expectedPackageName, expectedRequestHash, expectedNonce, policy)
 * @returns {Object} Comprehensive verification result
 */
function validateIntegrityPayload(payload, options = {}) {
  const policy = { ...DEFAULT_SECURITY_POLICY, ...options.policy };
  const violations = [];
  const warnings = [];

  if (!payload || typeof payload !== 'object') {
    return {
      isValid: false,
      violations: ['Integrity token payload is null or invalid.'],
      warnings: [],
      summary: null,
      rawPayload: null,
    };
  }

  const requestDetails = payload.requestDetails || {};
  const appIntegrity = payload.appIntegrity || {};
  const deviceIntegrity = payload.deviceIntegrity || {};
  const accountDetails = payload.accountDetails || {};
  const environmentDetails = payload.environmentDetails || {};

  // -------------------------------------------------------------
  // 1. Request Details & Replay Attack Defense
  // -------------------------------------------------------------
  const expectedPackage = options.expectedPackageName || 'com.chefandcost.app';
  if (requestDetails.requestPackageName && requestDetails.requestPackageName !== expectedPackage) {
    violations.push(`Package name mismatch: expected "${expectedPackage}", got "${requestDetails.requestPackageName}".`);
  }

  if (options.expectedRequestHash) {
    if (!requestDetails.requestHash) {
      violations.push('Token lacks requestHash, but an expected requestHash was specified.');
    } else if (requestDetails.requestHash !== options.expectedRequestHash) {
      violations.push(`requestHash mismatch: expected "${options.expectedRequestHash}", got "${requestDetails.requestHash}".`);
    }
  }

  if (options.expectedNonce) {
    if (!requestDetails.nonce) {
      violations.push('Token lacks nonce, but an expected nonce was specified.');
    } else if (requestDetails.nonce !== options.expectedNonce) {
      violations.push(`nonce mismatch: expected "${options.expectedNonce}", got "${requestDetails.nonce}".`);
    }
  }

  // Token freshness check
  if (requestDetails.timestampMillis) {
    const tokenTimestamp = parseInt(requestDetails.timestampMillis, 10);
    const now = Date.now();
    const tokenAgeSeconds = Math.max(0, (now - tokenTimestamp) / 1000);

    if (tokenAgeSeconds > policy.maxTokenAgeSeconds) {
      violations.push(`Token expired: token age is ${Math.round(tokenAgeSeconds)}s (max allowed: ${policy.maxTokenAgeSeconds}s).`);
    }
  } else {
    warnings.push('Token payload does not contain timestampMillis.');
  }

  // -------------------------------------------------------------
  // 2. App Integrity Checks (Detect Tampering / Sideloading)
  // -------------------------------------------------------------
  const appRecognition = appIntegrity.appRecognitionVerdict || 'UNEVALUATED';
  const isPlayRecognized = appRecognition === 'PLAY_RECOGNIZED';

  if (policy.requireAppRecognition && !isPlayRecognized) {
    violations.push(`App integrity check failed: verdict is "${appRecognition}" (expected "PLAY_RECOGNIZED"). App binary may be tampered or modified.`);
  }

  if (appIntegrity.packageName && policy.allowedPackageNames.length > 0) {
    if (!policy.allowedPackageNames.includes(appIntegrity.packageName)) {
      violations.push(`App package "${appIntegrity.packageName}" is not in the allowed package list.`);
    }
  }

  if (appIntegrity.versionCode && policy.minVersionCode) {
    const versionCode = parseInt(appIntegrity.versionCode, 10);
    if (versionCode < policy.minVersionCode) {
      violations.push(`App versionCode ${versionCode} is below minimum required version ${policy.minVersionCode}.`);
    }
  }

  if (policy.allowedCertificateSha256Digests && policy.allowedCertificateSha256Digests.length > 0) {
    const certDigests = appIntegrity.certificateSha256Digest || [];
    const hasMatchingCert = certDigests.some((d) => policy.allowedCertificateSha256Digests.includes(d));
    if (!hasMatchingCert) {
      violations.push('Certificate SHA-256 digest does not match any authorized Play release certificate.');
    }
  }

  // -------------------------------------------------------------
  // 3 & 4. Device Integrity & Virtual Integrity Checks
  // -------------------------------------------------------------
  const deviceVerdicts = deviceIntegrity.deviceRecognitionVerdict || [];
  const meetsDeviceIntegrity = deviceVerdicts.includes('MEETS_DEVICE_INTEGRITY');
  const meetsStrongIntegrity = deviceVerdicts.includes('MEETS_STRONG_INTEGRITY');
  const meetsVirtualIntegrity = deviceVerdicts.includes('MEETS_VIRTUAL_INTEGRITY');
  const meetsBasicIntegrity = deviceVerdicts.includes('MEETS_BASIC_INTEGRITY');

  if (policy.requireStrongIntegrity && !meetsStrongIntegrity) {
    violations.push('Strong integrity requirement failed: device lacks hardware-backed key attestation (MEETS_STRONG_INTEGRITY).');
  }

  if (policy.requireDeviceIntegrity) {
    const isDeviceCertified = meetsDeviceIntegrity || meetsStrongIntegrity;
    const isAllowedVirtual = policy.allowVirtualIntegrity && meetsVirtualIntegrity;

    if (!isDeviceCertified && !isAllowedVirtual) {
      if (meetsBasicIntegrity) {
        violations.push('Device integrity failed: device only MEETS_BASIC_INTEGRITY (device is likely rooted, unlocked, or custom ROM).');
      } else {
        violations.push(`Device integrity failed: verdicts are [${deviceVerdicts.join(', ')}]. Certified hardware or approved virtual environment required.`);
      }
    }
  }

  // -------------------------------------------------------------
  // 5. Recent Device Activity (Hyperactive / Botnet Detection)
  // -------------------------------------------------------------
  const recentActivity = deviceIntegrity.recentDeviceActivity || {};
  const activityLevel = recentActivity.deviceActivityLevel || 'LEVEL_1';

  const activityLevelOrder = {
    LEVEL_1: 1, // Normal / few requests
    LEVEL_2: 2, // Moderate activity
    LEVEL_3: 3, // High activity (suspicious)
    LEVEL_4: 4, // Hyperactive (automated abuse / token farm)
    UNSPECIFIED: 0,
  };

  const currentLevelVal = activityLevelOrder[activityLevel] || 0;
  const maxAllowedVal = activityLevelOrder[policy.maxDeviceActivityLevel] || 2;

  if (currentLevelVal > maxAllowedVal) {
    violations.push(`Recent device activity alert: level is "${activityLevel}" (max permitted: "${policy.maxDeviceActivityLevel}"). Potential token generation farm or automated abuse.`);
  }

  // -------------------------------------------------------------
  // 6. Account Licensing Checks (Google Play Licensing)
  // -------------------------------------------------------------
  const licensingVerdict = accountDetails.appLicensingVerdict || 'UNEVALUATED';
  const isLicensed = licensingVerdict === 'LICENSED';

  if (policy.requireLicensed && !isLicensed) {
    violations.push(`Play licensing check failed: user account verdict is "${licensingVerdict}" (expected "LICENSED"). User did not acquire app from Google Play.`);
  }

  // -------------------------------------------------------------
  // 7. Environment Details: Play Protect & App Access Risk
  // -------------------------------------------------------------
  const playProtect = environmentDetails.playProtectVerdict || 'NO_ISSUES';
  const isPlayProtectClean = playProtect === 'NO_ISSUES';

  if (policy.requireCleanPlayProtect && !isPlayProtectClean) {
    if (playProtect === 'DANGEROUS' || playProtect === 'WARNING') {
      violations.push(`Google Play Protect alert: verdict is "${playProtect}". Known malicious application detected on device.`);
    } else {
      warnings.push(`Google Play Protect non-standard status: "${playProtect}".`);
    }
  }

  const appAccessRisk = environmentDetails.appAccessRiskVerdict || {};
  const overlayVerdict = appAccessRisk.otherAppsWithDisplayOverOtherAppsVerdict || 'NO_ISSUES';
  const isOverlayClean = overlayVerdict === 'NO_ISSUES';

  if (policy.requireCleanAppAccessRisk && !isOverlayClean) {
    violations.push(`App access risk alert (overlay/tapjacking): displayOverOtherApps verdict is "${overlayVerdict}". Another app is drawing overlays over the screen, creating tapjacking or credential theft risk.`);
  }

  const appsDetected = appAccessRisk.appsDetected || [];
  if (appsDetected.includes('UNKNOWN_INSTALLED')) {
    warnings.push('Potentially risky accessibility or remote control apps detected on device.');
  }

  // -------------------------------------------------------------
  // Summary Verdict
  // -------------------------------------------------------------
  const isValid = violations.length === 0;

  return {
    isValid,
    violations,
    warnings,
    summary: {
      isLicensed,
      isPlayRecognized,
      meetsDeviceIntegrity,
      meetsStrongIntegrity,
      meetsVirtualIntegrity,
      meetsBasicIntegrity,
      deviceActivityLevel: activityLevel,
      playProtectSafe: isPlayProtectClean,
      appAccessRiskSafe: isOverlayClean,
    },
    rawPayload: payload,
  };
}

/**
 * Calls Google's decodeIntegrityToken API to decrypt and decode a Play Integrity token.
 * 
 * @param {string} packageName Android package name (e.g. 'com.chefandcost.app')
 * @param {string} integrityToken Encrypted token from Android client
 * @param {string} accessToken Google OAuth2 access token with `https://www.googleapis.com/auth/playintegrity` scope
 * @returns {Promise<Object>} The decrypted TokenPayloadExternal JSON object
 */
async function decodeIntegrityTokenWithGoogle(packageName, integrityToken, accessToken) {
  if (!packageName || !integrityToken || !accessToken) {
    throw new Error('packageName, integrityToken, and accessToken are all required.');
  }

  const endpointPath = `/v1/${encodeURIComponent(packageName)}:decodeIntegrityToken`;
  const postData = JSON.stringify({ integrityToken });

  return new Promise((resolve, reject) => {
    const req = https.request(
      {
        hostname: 'playintegrity.googleapis.com',
        port: 443,
        path: endpointPath,
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${accessToken}`,
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(postData),
        },
      },
      (res) => {
        let responseBody = '';
        res.on('data', (chunk) => {
          responseBody += chunk;
        });

        res.on('end', () => {
          try {
            const parsed = JSON.parse(responseBody);
            if (res.statusCode >= 200 && res.statusCode < 300) {
              if (parsed.tokenPayloadExternal) {
                resolve(parsed.tokenPayloadExternal);
              } else {
                reject(new Error(`Missing tokenPayloadExternal in response: ${responseBody}`));
              }
            } else {
              const errorMessage = parsed.error ? parsed.error.message : responseBody;
              reject(new Error(`Google Play Integrity API error (${res.statusCode}): ${errorMessage}`));
            }
          } catch (e) {
            reject(new Error(`Failed to parse Google API response: ${e.message}`));
          }
        });
      }
    );

    req.on('error', (err) => {
      reject(new Error(`Network error contacting Google Play Integrity API: ${err.message}`));
    });

    req.write(postData);
    req.end();
  });
}

/**
 * End-to-end verification helper: decodes token with Google API and validates payload against security policy.
 */
async function verifyIntegrityToken({
  packageName = 'com.chefandcost.app',
  integrityToken,
  accessToken,
  expectedRequestHash,
  expectedNonce,
  policy,
}) {
  const payload = await decodeIntegrityTokenWithGoogle(packageName, integrityToken, accessToken);
  return validateIntegrityPayload(payload, {
    expectedPackageName: packageName,
    expectedRequestHash,
    expectedNonce,
    policy,
  });
}

module.exports = {
  DEFAULT_SECURITY_POLICY,
  validateIntegrityPayload,
  decodeIntegrityTokenWithGoogle,
  verifyIntegrityToken,
};
