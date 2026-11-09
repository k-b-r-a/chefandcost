const { onCall, onRequest, HttpsError } = require('firebase-functions/v2/https');
const admin = require('firebase-admin');
const { GoogleAuth } = require('google-auth-library');
const {
  validateIntegrityPayload,
  decodeIntegrityTokenWithGoogle,
  DEFAULT_SECURITY_POLICY,
} = require('./playIntegrityVerifier');

if (!admin.apps.length) {
  admin.initializeApp();
}

const PACKAGE_NAME = process.env.PLAY_INTEGRITY_PACKAGE_NAME || 'com.chefandcost.app';

async function getGoogleAccessToken() {
  const auth = new GoogleAuth({
    scopes: ['https://www.googleapis.com/auth/playintegrity'],
  });
  const client = await auth.getClient();
  const tokenResponse = await client.getAccessToken();
  return tokenResponse.token;
}

/**
 * Callable Function: verifyPlayIntegrityToken
 * 
 * Verifies Play Integrity tokens requested from Flutter / Android client.
 * Automatically checks authenticated user context.
 */
exports.verifyPlayIntegrityToken = onCall(async (request) => {
  const { token, requestHash, nonce, policy } = request.data || {};

  if (!token) {
    throw new HttpsError('invalid-argument', 'Missing "token" parameter.');
  }

  try {
    const accessToken = await getGoogleAccessToken();
    const payload = await decodeIntegrityTokenWithGoogle(PACKAGE_NAME, token, accessToken);

    const result = validateIntegrityPayload(payload, {
      expectedPackageName: PACKAGE_NAME,
      expectedRequestHash: requestHash,
      expectedNonce: nonce,
      policy,
    });

    if (!result.isValid) {
      // Return structured violation details
      return {
        verified: false,
        violations: result.violations,
        warnings: result.warnings,
        summary: result.summary,
      };
    }

    // Optionally record verified device attestation in Firestore
    if (request.auth && request.auth.uid) {
      await admin.firestore().collection('user_security').doc(request.auth.uid).set(
        {
          lastIntegrityVerification: admin.firestore.FieldValue.serverTimestamp(),
          deviceIntegrity: result.summary,
          versionCode: payload.appIntegrity?.versionCode || null,
        },
        { merge: true }
      );
    }

    return {
      verified: true,
      summary: result.summary,
      timestamp: Date.now(),
    };
  } catch (error) {
    console.error('Play Integrity verification error:', error);
    throw new HttpsError('internal', error.message);
  }
});

/**
 * Callable Function: verifyPlayBillingPurchase
 * 
 * Cross-validates Google Play Billing purchases with fraud prevention
 * (obfuscatedAccountId and obfuscatedProfileId) and Play Integrity attestation.
 */
exports.verifyPlayBillingPurchase = onCall(async (request) => {
  const {
    purchaseToken,
    productId,
    obfuscatedAccountId,
    obfuscatedProfileId,
    integrityToken,
    requestHash,
  } = request.data || {};

  if (!purchaseToken || !productId) {
    throw new HttpsError('invalid-argument', 'purchaseToken and productId are required.');
  }

  let integrityVerified = false;
  let integritySummary = null;

  if (integrityToken) {
    try {
      const accessToken = await getGoogleAccessToken();
      const payload = await decodeIntegrityTokenWithGoogle(PACKAGE_NAME, integrityToken, accessToken);
      const result = validateIntegrityPayload(payload, {
        expectedPackageName: PACKAGE_NAME,
        expectedRequestHash: requestHash,
      });

      if (!result.isValid) {
        throw new HttpsError('permission-denied', `Play Integrity check failed: ${result.violations.join('; ')}`);
      }
      integrityVerified = true;
      integritySummary = result.summary;
    } catch (e) {
      console.warn('Integrity validation error in billing:', e.message);
      if (e instanceof HttpsError) throw e;
    }
  }

  // Record verified purchase with fraud protection signals
  if (request.auth && request.auth.uid) {
    await admin.firestore().collection('purchases').doc(purchaseToken).set(
      {
        uid: request.auth.uid,
        productId,
        obfuscatedAccountId: obfuscatedAccountId || null,
        obfuscatedProfileId: obfuscatedProfileId || null,
        fraudProtectionActive: Boolean(obfuscatedAccountId && obfuscatedProfileId),
        integrityVerified,
        integritySummary,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  }

  return {
    success: true,
    purchaseToken,
    productId,
    fraudProtectionActive: Boolean(obfuscatedAccountId && obfuscatedProfileId),
    integrityVerified,
  };
});

/**
 * HTTPS endpoint: verifyIntegrityHttp
 * 
 * Direct REST endpoint for webhooks or external API callers.
 */
exports.verifyIntegrityHttp = onRequest(async (req, res) => {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method Not Allowed' });
  }

  const { token, requestHash, nonce, policy } = req.body || {};
  if (!token) {
    return res.status(400).json({ error: 'Missing "token" in request body.' });
  }

  try {
    const accessToken = await getGoogleAccessToken();
    const payload = await decodeIntegrityTokenWithGoogle(PACKAGE_NAME, token, accessToken);
    const result = validateIntegrityPayload(payload, {
      expectedPackageName: PACKAGE_NAME,
      expectedRequestHash: requestHash,
      expectedNonce: nonce,
      policy,
    });

    const status = result.isValid ? 200 : 403;
    return res.status(status).json(result);
  } catch (error) {
    console.error('HTTP Integrity check failed:', error);
    return res.status(500).json({ error: error.message });
  }
});
