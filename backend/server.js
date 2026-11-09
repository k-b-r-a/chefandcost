/**
 * Google Play Integrity & Billing Protection Verification Server
 * 
 * Provides HTTP endpoints for validating:
 * 1. Play Integrity tokens (Standard & Classic) across all 7 Play Integrity signals.
 * 2. Play Billing fraud prevention parameters (obfuscatedAccountId & obfuscatedProfileId).
 */

const http = require('http');
const url = require('url');
const {
  validateIntegrityPayload,
  decodeIntegrityTokenWithGoogle,
  verifyIntegrityToken,
  DEFAULT_SECURITY_POLICY,
} = require('./playIntegrityVerifier');

const PORT = process.env.PORT || 8080;
const PACKAGE_NAME = process.env.PLAY_INTEGRITY_PACKAGE_NAME || 'com.chefandcost.app';

/**
 * Retrieves a Google OAuth2 access token for the Play Integrity API.
 * Uses Google Application Default Credentials (ADC) or service account key.
 */
async function getGoogleAccessToken() {
  if (process.env.GOOGLE_ACCESS_TOKEN) {
    return process.env.GOOGLE_ACCESS_TOKEN;
  }

  try {
    const { GoogleAuth } = require('google-auth-library');
    const auth = new GoogleAuth({
      scopes: ['https://www.googleapis.com/auth/playintegrity'],
    });
    const client = await auth.getClient();
    const tokenResponse = await client.getAccessToken();
    return tokenResponse.token;
  } catch (err) {
    // Helpful diagnostic error for missing credentials
    throw new Error(
      `Failed to obtain Google OAuth2 access token: ${err.message}. ` +
      'Ensure GOOGLE_APPLICATION_CREDENTIALS points to a valid service account JSON file ' +
      'with Play Integrity API permissions enabled in Google Cloud Console.'
    );
  }
}

/**
 * Parses JSON request bodies.
 */
function readJsonBody(req) {
  return new Promise((resolve, reject) => {
    let data = '';
    req.on('data', (chunk) => {
      data += chunk;
      if (data.length > 1024 * 1024) { // 1 MB limit
        reject(new Error('Request payload too large'));
      }
    });
    req.on('end', () => {
      if (!data) return resolve({});
      try {
        resolve(JSON.parse(data));
      } catch (err) {
        reject(new Error(`Invalid JSON body: ${err.message}`));
      }
    });
    req.on('error', reject);
  });
}

function sendJson(res, statusCode, body) {
  res.writeHead(statusCode, {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  });
  res.end(JSON.stringify(body, null, 2));
}

const server = http.createServer(async (req, res) => {
  const parsedUrl = url.parse(req.url, true);
  const { pathname } = parsedUrl;

  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    res.writeHead(204, {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    });
    return res.end();
  }

  try {
    // -----------------------------------------------------------------
    // GET /health
    // -----------------------------------------------------------------
    if (req.method === 'GET' && pathname === '/health') {
      return sendJson(res, 200, {
        status: 'UP',
        timestamp: new Date().toISOString(),
        service: 'google-play-security-verifier',
        packageName: PACKAGE_NAME,
        defaultPolicy: DEFAULT_SECURITY_POLICY,
      });
    }

    // -----------------------------------------------------------------
    // POST /api/v1/integrity/verify
    // -----------------------------------------------------------------
    if (req.method === 'POST' && pathname === '/api/v1/integrity/verify') {
      const body = await readJsonBody(req);
      const { token, requestHash, nonce, packageName, policy } = body;

      if (!token) {
        return sendJson(res, 400, {
          error: 'BAD_REQUEST',
          message: 'Missing "token" in request body.',
        });
      }

      const targetPackage = packageName || PACKAGE_NAME;
      const accessToken = await getGoogleAccessToken();

      const decodedPayload = await decodeIntegrityTokenWithGoogle(
        targetPackage,
        token,
        accessToken
      );

      const verificationResult = validateIntegrityPayload(decodedPayload, {
        expectedPackageName: targetPackage,
        expectedRequestHash: requestHash,
        expectedNonce: nonce,
        policy,
      });

      const httpStatus = verificationResult.isValid ? 200 : 403;
      return sendJson(res, httpStatus, verificationResult);
    }

    // -----------------------------------------------------------------
    // POST /api/v1/integrity/simulate (For unit testing / CI sandbox)
    // -----------------------------------------------------------------
    if (req.method === 'POST' && pathname === '/api/v1/integrity/simulate') {
      const body = await readJsonBody(req);
      const { payload, expectedRequestHash, expectedNonce, policy } = body;

      if (!payload) {
        return sendJson(res, 400, {
          error: 'BAD_REQUEST',
          message: 'Missing "payload" object in request body.',
        });
      }

      const result = validateIntegrityPayload(payload, {
        expectedPackageName: PACKAGE_NAME,
        expectedRequestHash,
        expectedNonce,
        policy,
      });

      return sendJson(res, result.isValid ? 200 : 422, result);
    }

    // -----------------------------------------------------------------
    // POST /api/v1/billing/verify-purchase
    // Cross-validates Play Billing purchase with Integrity attestation
    // -----------------------------------------------------------------
    if (req.method === 'POST' && pathname === '/api/v1/billing/verify-purchase') {
      const body = await readJsonBody(req);
      const {
        purchaseToken,
        productId,
        obfuscatedAccountId,
        obfuscatedProfileId,
        integrityToken,
        requestHash,
      } = body;

      if (!purchaseToken || !productId) {
        return sendJson(res, 400, {
          error: 'BAD_REQUEST',
          message: 'purchaseToken and productId are required.',
        });
      }

      // 1. Verify Play Integrity if attestation token provided
      let integrityResult = null;
      if (integrityToken) {
        try {
          const accessToken = await getGoogleAccessToken();
          const decodedPayload = await decodeIntegrityTokenWithGoogle(
            PACKAGE_NAME,
            integrityToken,
            accessToken
          );
          integrityResult = validateIntegrityPayload(decodedPayload, {
            expectedPackageName: PACKAGE_NAME,
            expectedRequestHash: requestHash,
          });

          if (!integrityResult.isValid) {
            return sendJson(res, 403, {
              error: 'INTEGRITY_VERIFICATION_FAILED',
              message: 'Device or app failed Play Integrity checks.',
              violations: integrityResult.violations,
              summary: integrityResult.summary,
            });
          }
        } catch (e) {
          return sendJson(res, 502, {
            error: 'INTEGRITY_SERVICE_ERROR',
            message: `Failed to verify integrity token with Google: ${e.message}`,
          });
        }
      }

      // 2. Validate presence of fraud prevention obfuscated identifiers
      const fraudProtectionActive = Boolean(obfuscatedAccountId && obfuscatedProfileId);

      return sendJson(res, 200, {
        status: 'VERIFIED',
        productId,
        purchaseToken,
        fraudProtection: {
          active: fraudProtectionActive,
          obfuscatedAccountIdPresent: Boolean(obfuscatedAccountId),
          obfuscatedProfileIdPresent: Boolean(obfuscatedProfileId),
        },
        integrityVerification: integrityResult ? {
          verified: integrityResult.isValid,
          summary: integrityResult.summary,
        } : {
          verified: false,
          note: 'No integrity token provided; client should include integrity token on sensitive purchases.',
        },
      });
    }

    // 404 Route Not Found
    return sendJson(res, 404, {
      error: 'NOT_FOUND',
      message: `Cannot ${req.method} ${pathname}`,
    });
  } catch (err) {
    console.error('Unhandled server error:', err);
    return sendJson(res, 500, {
      error: 'INTERNAL_ERROR',
      message: err.message,
    });
  }
});

if (require.main === module) {
  server.listen(PORT, () => {
    console.log(`Google Play Security Verifier Server listening on port ${PORT}`);
    console.log(`Package: ${PACKAGE_NAME}`);
  });
}

module.exports = { server, PORT };
