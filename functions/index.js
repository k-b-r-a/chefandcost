const { onCall, onRequest, HttpsError } = require('firebase-functions/v2/https');
const admin = require('firebase-admin');
const { GoogleAuth } = require('google-auth-library');
const {
  validateIntegrityPayload,
  decodeIntegrityTokenWithGoogle,
} = require('./playIntegrityVerifier');
const {
  computeBillingRequestHash,
  verifySubscriptionPurchaseWithGoogle,
} = require('./playBillingVerifier');

if (!admin.apps.length) {
  admin.initializeApp();
}

const PACKAGE_NAME = process.env.PLAY_INTEGRITY_PACKAGE_NAME || 'com.chefandcost.app';

async function getGoogleAccessToken(
  scopes = ['https://www.googleapis.com/auth/playintegrity']
) {
  const auth = new GoogleAuth({ scopes });
  const client = await auth.getClient();
  const tokenResponse = await client.getAccessToken();
  return tokenResponse.token;
}

/**
 * Callable Function: verifyPlayIntegrityToken
 */
exports.verifyPlayIntegrityToken = onCall(async (request) => {
  const { token, requestHash, nonce } = request.data || {};

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
    });

    if (!result.isValid) {
      return {
        verified: false,
        violations: result.violations,
        warnings: result.warnings,
        summary: result.summary,
      };
    }

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
 */
exports.verifyPlayBillingPurchase = onCall(async (request) => {
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError('unauthenticated', 'Authentication is required to verify purchases.');
  }

  const uid = request.auth.uid;
  const {
    purchaseToken,
    productId,
    obfuscatedAccountId,
    obfuscatedProfileId,
    integrityToken,
  } = request.data || {};

  if (!purchaseToken || !productId || !integrityToken) {
    throw new HttpsError(
      'invalid-argument',
      'purchaseToken, productId, and integrityToken are required.'
    );
  }

  const expectedRequestHash = computeBillingRequestHash({ uid, productId, purchaseToken });

  const accessToken = await getGoogleAccessToken([
    'https://www.googleapis.com/auth/playintegrity',
    'https://www.googleapis.com/auth/androidpublisher',
  ]);

  const payload = await decodeIntegrityTokenWithGoogle(PACKAGE_NAME, integrityToken, accessToken);
  const integrityResult = validateIntegrityPayload(payload, {
    expectedPackageName: PACKAGE_NAME,
    expectedRequestHash,
  });

  if (!integrityResult.isValid) {
    throw new HttpsError(
      'permission-denied',
      `Play Integrity check failed: ${integrityResult.violations.join('; ')}`
    );
  }

  const purchaseRef = admin.firestore().collection('purchases').doc(purchaseToken);
  const existingPurchaseSnap = await purchaseRef.get();
  if (existingPurchaseSnap.exists && existingPurchaseSnap.data()?.uid && existingPurchaseSnap.data().uid !== uid) {
    throw new HttpsError('permission-denied', 'Purchase token is already bound to another account.');
  }

  const billingResult = await verifySubscriptionPurchaseWithGoogle({
    packageName: PACKAGE_NAME,
    purchaseToken,
    requestedProductId: productId,
    uid,
    accessToken,
  });

  if (!billingResult.isValid) {
    throw new HttpsError(
      'permission-denied',
      `Play Billing verification failed: ${billingResult.violations.join('; ')}`
    );
  }

  const expiryTimestamp = admin.firestore.Timestamp.fromDate(billingResult.expiryDate);
  const batch = admin.firestore().batch();

  batch.set(
    admin.firestore().collection('entitlements').doc(uid),
    {
      isSubscribed: true,
      hasLifetimeSubscription: false,
      plan: billingResult.productId,
      subscriptionState: billingResult.subscriptionState,
      subscriptionExpiresAt: expiryTimestamp,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      source: 'google_play_billing',
    },
    { merge: true }
  );

  batch.set(
    purchaseRef,
    {
      uid,
      productId: billingResult.productId,
      expiryTime: expiryTimestamp,
      obfuscatedAccountId: obfuscatedAccountId || null,
      obfuscatedProfileId: obfuscatedProfileId || null,
      fraudProtectionActive: Boolean(obfuscatedAccountId && obfuscatedProfileId),
      integrityVerified: true,
      integritySummary: integrityResult.summary,
      verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  await batch.commit();

  return {
    success: true,
    verified: true,
    planId: billingResult.productId,
    expiresAtMs: billingResult.expiryDate.getTime(),
    subscriptionState: billingResult.subscriptionState,
  };
});

/**
 * HTTPS endpoint: verifyIntegrityHttp
 */
exports.verifyIntegrityHttp = onRequest(async (req, res) => {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method Not Allowed' });
  }

  const { token, requestHash, nonce } = req.body || {};
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
    });

    const status = result.isValid ? 200 : 403;
    return res.status(status).json(result);
  } catch (error) {
    console.error('HTTP Integrity check failed:', error);
    return res.status(500).json({ error: error.message });
  }
});
