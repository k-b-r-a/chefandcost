const crypto = require('crypto');
const https = require('https');

const ACTIVE_SUBSCRIPTION_STATES = new Set([
  'SUBSCRIPTION_STATE_ACTIVE',
  'SUBSCRIPTION_STATE_IN_GRACE_PERIOD',
]);

function computeBillingRequestHash({ uid, productId, purchaseToken }) {
  const digest = crypto
    .createHash('sha256')
    .update(`${uid}:${productId}:${purchaseToken}`, 'utf8')
    .digest('base64');
  return digest.replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function computeExpectedObfuscatedAccountId(uid) {
  return crypto
    .createHash('sha256')
    .update(`${uid}::chefy_billing_account`, 'utf8')
    .digest('hex');
}

function defaultHttpsRequest({ hostname, path, method, headers, body }) {
  return new Promise((resolve, reject) => {
    const req = https.request(
      {
        hostname,
        port: 443,
        path,
        method,
        headers,
      },
      (res) => {
        let responseBody = '';
        res.on('data', (chunk) => {
          responseBody += chunk;
        });
        res.on('end', () => {
          resolve({ statusCode: res.statusCode || 500, body: responseBody });
        });
      }
    );
    req.on('error', reject);
    if (body) req.write(body);
    req.end();
  });
}

async function fetchSubscriptionPurchaseV2({
  packageName,
  purchaseToken,
  accessToken,
  requestImpl = defaultHttpsRequest,
}) {
  if (!packageName || !purchaseToken || !accessToken) {
    throw new Error('packageName, purchaseToken, and accessToken are required.');
  }
  const path = `/androidpublisher/v3/applications/${encodeURIComponent(packageName)}/purchases/subscriptionsv2/tokens/${encodeURIComponent(purchaseToken)}`;
  const res = await requestImpl({
    hostname: 'androidpublisher.googleapis.com',
    path,
    method: 'GET',
    headers: {
      Authorization: `Bearer ${accessToken}`,
      Accept: 'application/json',
    },
  });

  const parsed = res.body ? JSON.parse(res.body) : {};
  if (res.statusCode < 200 || res.statusCode >= 300) {
    const message = parsed.error ? parsed.error.message : res.body;
    throw new Error(`Google Play Developer API error (${res.statusCode}): ${message}`);
  }
  return parsed;
}

async function acknowledgeSubscriptionPurchase({
  packageName,
  productId,
  purchaseToken,
  accessToken,
  requestImpl = defaultHttpsRequest,
}) {
  const path = `/androidpublisher/v3/applications/${encodeURIComponent(packageName)}/purchases/subscriptions/${encodeURIComponent(productId)}/tokens/${encodeURIComponent(purchaseToken)}:acknowledge`;
  const body = JSON.stringify({ developerPayload: 'verified_by_chefy_cloud_functions' });
  const res = await requestImpl({
    hostname: 'androidpublisher.googleapis.com',
    path,
    method: 'POST',
    headers: {
      Authorization: `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
      'Content-Length': Buffer.byteLength(body),
    },
    body,
  });

  if (res.statusCode < 200 || res.statusCode >= 300) {
    const parsed = res.body ? JSON.parse(res.body) : {};
    const message = parsed.error ? parsed.error.message : res.body;
    throw new Error(`Google Play acknowledge error (${res.statusCode}): ${message}`);
  }
  return true;
}

function evaluateSubscriptionPurchaseV2(
  subscriptionData,
  { uid, requestedProductId, now = new Date() } = {}
) {
  const violations = [];
  if (!subscriptionData || typeof subscriptionData !== 'object') {
    return { isValid: false, violations: ['Empty subscription payload.'] };
  }

  const subscriptionState = subscriptionData.subscriptionState || 'SUBSCRIPTION_STATE_UNSPECIFIED';
  if (!ACTIVE_SUBSCRIPTION_STATES.has(subscriptionState)) {
    violations.push(`Subscription is not active (state: ${subscriptionState}).`);
  }

  const lineItems = Array.isArray(subscriptionData.lineItems) ? subscriptionData.lineItems : [];
  if (lineItems.length === 0) {
    violations.push('Subscription has no lineItems.');
  }

  const matchedItem =
    lineItems.find((item) => item && item.productId === requestedProductId) || lineItems[0];

  let expiryDate = null;
  if (!matchedItem || !matchedItem.expiryTime) {
    violations.push('Subscription lineItem is missing expiryTime.');
  } else {
    expiryDate = new Date(matchedItem.expiryTime);
    if (Number.isNaN(expiryDate.getTime()) || expiryDate <= now) {
      violations.push(`Subscription has expired (expiryTime: ${matchedItem.expiryTime}).`);
    }
  }

  const obfuscatedExternalAccountId =
    subscriptionData.externalAccountIdentifiers?.obfuscatedExternalAccountId || null;
  if (uid && obfuscatedExternalAccountId) {
    const expectedAccountId = computeExpectedObfuscatedAccountId(uid);
    if (obfuscatedExternalAccountId !== expectedAccountId) {
      violations.push('obfuscatedExternalAccountId does not match authenticated user.');
    }
  }

  return {
    isValid: violations.length === 0,
    violations,
    productId: matchedItem?.productId || requestedProductId,
    expiryDate,
    subscriptionState,
    needsAcknowledgement: subscriptionData.acknowledgementState === 'ACKNOWLEDGEMENT_STATE_PENDING',
    obfuscatedExternalAccountId,
  };
}

async function verifySubscriptionPurchaseWithGoogle({
  packageName,
  purchaseToken,
  requestedProductId,
  uid,
  accessToken,
  requestImpl = defaultHttpsRequest,
  now = new Date(),
}) {
  const subscriptionData = await fetchSubscriptionPurchaseV2({
    packageName,
    purchaseToken,
    accessToken,
    requestImpl,
  });

  const evaluation = evaluateSubscriptionPurchaseV2(subscriptionData, {
    uid,
    requestedProductId,
    now,
  });

  if (evaluation.isValid && evaluation.needsAcknowledgement) {
    await acknowledgeSubscriptionPurchase({
      packageName,
      productId: evaluation.productId,
      purchaseToken,
      accessToken,
      requestImpl,
    });
  }

  return evaluation;
}

module.exports = {
  computeBillingRequestHash,
  computeExpectedObfuscatedAccountId,
  fetchSubscriptionPurchaseV2,
  acknowledgeSubscriptionPurchase,
  evaluateSubscriptionPurchaseV2,
  verifySubscriptionPurchaseWithGoogle,
};
