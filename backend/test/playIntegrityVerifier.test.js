const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const {
  validateIntegrityPayload,
  DEFAULT_SECURITY_POLICY,
} = require('../playIntegrityVerifier');

function createGoldenPayload(overrides = {}) {
  const now = Date.now();
  return {
    requestDetails: {
      requestPackageName: 'com.chefandcost.app',
      requestHash: 'valid_request_hash_sha256',
      timestampMillis: String(now - 1000), // 1 second ago
      ...(overrides.requestDetails || {}),
    },
    appIntegrity: {
      appRecognitionVerdict: 'PLAY_RECOGNIZED',
      packageName: 'com.chefandcost.app',
      certificateSha256Digest: ['44942522dd783beee359e86e1976731b72290d50'],
      versionCode: '3',
      ...(overrides.appIntegrity || {}),
    },
    deviceIntegrity: {
      deviceRecognitionVerdict: [
        'MEETS_BASIC_INTEGRITY',
        'MEETS_DEVICE_INTEGRITY',
        'MEETS_STRONG_INTEGRITY',
      ],
      recentDeviceActivity: {
        deviceActivityLevel: 'LEVEL_1',
      },
      deviceAttributes: {
        sdkVersion: 36,
      },
      ...(overrides.deviceIntegrity || {}),
    },
    accountDetails: {
      appLicensingVerdict: 'LICENSED',
      ...(overrides.accountDetails || {}),
    },
    environmentDetails: {
      playProtectVerdict: 'NO_ISSUES',
      appAccessRiskVerdict: {
        appsDetected: ['KNOWN_INSTALLED'],
        otherAppsWithDisplayOverOtherAppsVerdict: 'NO_ISSUES',
      },
      ...(overrides.environmentDetails || {}),
    },
  };
}

describe('Play Integrity Verifier - Signal 1: Play Licensing Checks', () => {
  it('passes when appLicensingVerdict is LICENSED', () => {
    const payload = createGoldenPayload();
    const result = validateIntegrityPayload(payload);
    assert.equal(result.isValid, true);
    assert.equal(result.summary.isLicensed, true);
    assert.equal(result.violations.length, 0);
  });

  it('fails when appLicensingVerdict is UNLICENSED', () => {
    const payload = createGoldenPayload({
      accountDetails: { appLicensingVerdict: 'UNLICENSED' },
    });
    const result = validateIntegrityPayload(payload);
    assert.equal(result.isValid, false);
    assert.equal(result.summary.isLicensed, false);
    assert.ok(result.violations.some((v) => v.includes('licensing')));
  });
});

describe('Play Integrity Verifier - Signal 2: App Integrity Checks', () => {
  it('fails when appRecognitionVerdict is UNRECOGNIZED_VERSION (tampered/modified binary)', () => {
    const payload = createGoldenPayload({
      appIntegrity: { appRecognitionVerdict: 'UNRECOGNIZED_VERSION' },
    });
    const result = validateIntegrityPayload(payload);
    assert.equal(result.isValid, false);
    assert.equal(result.summary.isPlayRecognized, false);
    assert.ok(result.violations.some((v) => v.includes('App integrity check failed')));
  });

  it('fails when package name does not match expected package', () => {
    const payload = createGoldenPayload({
      appIntegrity: { packageName: 'com.malicious.repackaged' },
    });
    const result = validateIntegrityPayload(payload);
    assert.equal(result.isValid, false);
    assert.ok(result.violations.some((v) => v.includes('not in the allowed package list')));
  });
});

describe('Play Integrity Verifier - Signal 3: Device Integrity Checks', () => {
  it('fails when device only MEETS_BASIC_INTEGRITY (rooted / unlocked bootloader)', () => {
    const payload = createGoldenPayload({
      deviceIntegrity: {
        deviceRecognitionVerdict: ['MEETS_BASIC_INTEGRITY'],
      },
    });
    const result = validateIntegrityPayload(payload);
    assert.equal(result.isValid, false);
    assert.equal(result.summary.meetsDeviceIntegrity, false);
    assert.ok(result.violations.some((v) => v.includes('MEETS_BASIC_INTEGRITY')));
  });

  it('fails when strong integrity is required but missing', () => {
    const payload = createGoldenPayload({
      deviceIntegrity: {
        deviceRecognitionVerdict: ['MEETS_BASIC_INTEGRITY', 'MEETS_DEVICE_INTEGRITY'],
      },
    });
    const result = validateIntegrityPayload(payload, {
      policy: { requireStrongIntegrity: true },
    });
    assert.equal(result.isValid, false);
    assert.ok(result.violations.some((v) => v.includes('MEETS_STRONG_INTEGRITY')));
  });
});

describe('Play Integrity Verifier - Signal 4: Virtual Integrity Checks (Play Games for PC / Emulators)', () => {
  it('permits virtual environment when allowVirtualIntegrity is true (Google Play Games PC)', () => {
    const payload = createGoldenPayload({
      deviceIntegrity: {
        deviceRecognitionVerdict: ['MEETS_VIRTUAL_INTEGRITY', 'MEETS_BASIC_INTEGRITY'],
      },
    });
    const result = validateIntegrityPayload(payload, {
      policy: { allowVirtualIntegrity: true },
    });
    assert.equal(result.isValid, true);
    assert.equal(result.summary.meetsVirtualIntegrity, true);
  });

  it('rejects virtual environment when allowVirtualIntegrity is disabled', () => {
    const payload = createGoldenPayload({
      deviceIntegrity: {
        deviceRecognitionVerdict: ['MEETS_VIRTUAL_INTEGRITY', 'MEETS_BASIC_INTEGRITY'],
      },
    });
    const result = validateIntegrityPayload(payload, {
      policy: { allowVirtualIntegrity: false },
    });
    assert.equal(result.isValid, false);
    assert.ok(result.violations.some((v) => v.includes('Device integrity failed')));
  });
});

describe('Play Integrity Verifier - Signal 5: Recent Device Activity (Token Farm / Botnet Detection)', () => {
  it('accepts normal activity levels LEVEL_1 and LEVEL_2', () => {
    const payload = createGoldenPayload({
      deviceIntegrity: {
        deviceRecognitionVerdict: ['MEETS_DEVICE_INTEGRITY'],
        recentDeviceActivity: { deviceActivityLevel: 'LEVEL_2' },
      },
    });
    const result = validateIntegrityPayload(payload);
    assert.equal(result.isValid, true);
  });

  it('rejects hyperactive activity level LEVEL_4 (automated attack farm)', () => {
    const payload = createGoldenPayload({
      deviceIntegrity: {
        deviceRecognitionVerdict: ['MEETS_DEVICE_INTEGRITY'],
        recentDeviceActivity: { deviceActivityLevel: 'LEVEL_4' },
      },
    });
    const result = validateIntegrityPayload(payload);
    assert.equal(result.isValid, false);
    assert.ok(result.violations.some((v) => v.includes('Recent device activity alert')));
  });
});

describe('Play Integrity Verifier - Signal 6: Google Play Protect Status (Malware Detection)', () => {
  it('fails when Play Protect detects DANGEROUS malware', () => {
    const payload = createGoldenPayload({
      environmentDetails: {
        playProtectVerdict: 'DANGEROUS',
      },
    });
    const result = validateIntegrityPayload(payload);
    assert.equal(result.isValid, false);
    assert.equal(result.summary.playProtectSafe, false);
    assert.ok(result.violations.some((v) => v.includes('Google Play Protect alert')));
  });
});

describe('Play Integrity Verifier - Signal 7: App Access Risk (Tapjacking & Overlay Defense)', () => {
  it('fails when another app is displaying overlays over screen (tapjacking risk)', () => {
    const payload = createGoldenPayload({
      environmentDetails: {
        playProtectVerdict: 'NO_ISSUES',
        appAccessRiskVerdict: {
          otherAppsWithDisplayOverOtherAppsVerdict: 'UNKNOWN',
        },
      },
    });
    const result = validateIntegrityPayload(payload);
    assert.equal(result.isValid, false);
    assert.equal(result.summary.appAccessRiskSafe, false);
    assert.ok(result.violations.some((v) => v.includes('overlay/tapjacking')));
  });
});

describe('Play Integrity Verifier - Replay Attack Defense & Request Binding', () => {
  it('rejects expired tokens older than maxTokenAgeSeconds', () => {
    const oldTimestamp = Date.now() - 600 * 1000; // 10 minutes ago
    const payload = createGoldenPayload({
      requestDetails: { timestampMillis: String(oldTimestamp) },
    });
    const result = validateIntegrityPayload(payload, {
      policy: { maxTokenAgeSeconds: 300 },
    });
    assert.equal(result.isValid, false);
    assert.ok(result.violations.some((v) => v.includes('Token expired')));
  });

  it('enforces expected requestHash match for Standard Integrity tokens', () => {
    const payload = createGoldenPayload({
      requestDetails: { requestHash: 'actual_token_hash_xyz' },
    });
    const result = validateIntegrityPayload(payload, {
      expectedRequestHash: 'expected_different_hash',
    });
    assert.equal(result.isValid, false);
    assert.ok(result.violations.some((v) => v.includes('requestHash mismatch')));
  });
});
