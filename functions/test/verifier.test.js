const test = require('node:test');
const assert = require('node:assert/strict');
const { validateIntegrityPayload } = require('../playIntegrityVerifier');
const {
  computeBillingRequestHash,
  computeExpectedObfuscatedAccountId,
  evaluateSubscriptionPurchaseV2,
  verifySubscriptionPurchaseWithGoogle,
} = require('../playBillingVerifier');

function makeValidIntegrityPayload(overrides = {}) {
  return {
    requestDetails: {
      requestPackageName: 'com.chefandcost.app',
      requestHash: 'hash123',
      timestampMillis: String(Date.now()),
      ...overrides.requestDetails,
    },
    appIntegrity: {
      appRecognitionVerdict: 'PLAY_RECOGNIZED',
      packageName: 'com.chefandcost.app',
      versionCode: '8',
      ...overrides.appIntegrity,
    },
    deviceIntegrity: {
      deviceRecognitionVerdict: ['MEETS_DEVICE_INTEGRITY'],
      recentDeviceActivity: { deviceActivityLevel: 'LEVEL_1' },
      ...overrides.deviceIntegrity,
    },
    accountDetails: {
      appLicensingVerdict: 'LICENSED',
      ...overrides.accountDetails,
    },
    environmentDetails: {
      playProtectVerdict: 'NO_ISSUES',
      appAccessRiskVerdict: { otherAppsWithDisplayOverOtherAppsVerdict: 'NO_ISSUES' },
      ...overrides.environmentDetails,
    },
  };
}

test('validateIntegrityPayload omits rawPayload by default', () => {
  const result = validateIntegrityPayload(makeValidIntegrityPayload(), {
    expectedPackageName: 'com.chefandcost.app',
    expectedRequestHash: 'hash123',
  });
  assert.equal(result.isValid, true);
  assert.equal(Object.hasOwn(result, 'rawPayload'), false);
});

test('validateIntegrityPayload rejects requestHash mismatch', () => {
  const result = validateIntegrityPayload(makeValidIntegrityPayload(), {
    expectedPackageName: 'com.chefandcost.app',
    expectedRequestHash: 'different_hash',
  });
  assert.equal(result.isValid, false);
  assert.match(result.violations.join(' '), /requestHash mismatch/);
});

test('evaluateSubscriptionPurchaseV2 rejects expired subscription', () => {
  const pastIso = new Date(Date.now() - 60_000).toISOString();
  const res = evaluateSubscriptionPurchaseV2(
    {
      subscriptionState: 'SUBSCRIPTION_STATE_EXPIRED',
      acknowledgementState: 'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED',
      lineItems: [{ productId: 'cloud_sync_monthly_199', expiryTime: pastIso }],
    },
    { uid: 'user-1', requestedProductId: 'cloud_sync_monthly_199' }
  );
  assert.equal(res.isValid, false);
  assert.equal(res.violations.length >= 2, true);
});

test('evaluateSubscriptionPurchaseV2 rejects cross-UID obfuscatedExternalAccountId', () => {
  const futureIso = new Date(Date.now() + 86_400_000).toISOString();
  const res = evaluateSubscriptionPurchaseV2(
    {
      subscriptionState: 'SUBSCRIPTION_STATE_ACTIVE',
      acknowledgementState: 'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED',
      lineItems: [{ productId: 'cloud_sync_monthly_199', expiryTime: futureIso }],
      externalAccountIdentifiers: {
        obfuscatedExternalAccountId: computeExpectedObfuscatedAccountId('other-user'),
      },
    },
    { uid: 'user-1', requestedProductId: 'cloud_sync_monthly_199' }
  );
  assert.equal(res.isValid, false);
  assert.match(res.violations.join(' '), /obfuscatedExternalAccountId/);
});

test('verifySubscriptionPurchaseWithGoogle acknowledges pending active subscription', async () => {
  const futureIso = new Date(Date.now() + 86_400_000).toISOString();
  const calls = [];
  const mockRequest = async (req) => {
    calls.push(req);
    if (req.method === 'GET') {
      return {
        statusCode: 200,
        body: JSON.stringify({
          subscriptionState: 'SUBSCRIPTION_STATE_ACTIVE',
          acknowledgementState: 'ACKNOWLEDGEMENT_STATE_PENDING',
          lineItems: [{ productId: 'cloud_sync_annual_1499', expiryTime: futureIso }],
          externalAccountIdentifiers: {
            obfuscatedExternalAccountId: computeExpectedObfuscatedAccountId('user-1'),
          },
        }),
      };
    }
    return { statusCode: 204, body: '' };
  };

  const res = await verifySubscriptionPurchaseWithGoogle({
    packageName: 'com.chefandcost.app',
    purchaseToken: 'tok-abc',
    requestedProductId: 'cloud_sync_annual_1499',
    uid: 'user-1',
    accessToken: 'oauth-token',
    requestImpl: mockRequest,
  });

  assert.equal(res.isValid, true);
  assert.equal(res.productId, 'cloud_sync_annual_1499');
  assert.equal(calls.length, 2);
  assert.equal(calls[1].method, 'POST');
  assert.match(calls[1].path, /:acknowledge$/);
});

test('computeBillingRequestHash produces deterministic URL-safe base64', () => {
  const h1 = computeBillingRequestHash({
    uid: 'u1',
    productId: 'p1',
    purchaseToken: 't1',
  });
  const h2 = computeBillingRequestHash({
    uid: 'u1',
    productId: 'p1',
    purchaseToken: 't1',
  });
  assert.equal(h1, h2);
  assert.equal(/[+/=]/.test(h1), false);
});
