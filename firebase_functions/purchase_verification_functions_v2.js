'use strict';

const crypto = require('crypto');
const admin = require('firebase-admin');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { defineSecret, defineString } = require('firebase-functions/params');
const {
  MONTHLY_PRODUCT_ID,
  validatePurchaseRequest,
  verifiedEntitlement,
} = require('./purchase_verification_engine_v2');

const GOOGLE_PLAY_SERVICE_ACCOUNT_JSON = defineSecret('GOOGLE_PLAY_SERVICE_ACCOUNT_JSON');
const APPLE_IAP_PRIVATE_KEY = defineSecret('APPLE_IAP_PRIVATE_KEY');
const GOOGLE_PLAY_PACKAGE_NAME = defineString('GOOGLE_PLAY_PACKAGE_NAME');
const APPLE_IAP_ISSUER_ID = defineString('APPLE_IAP_ISSUER_ID');
const APPLE_IAP_KEY_ID = defineString('APPLE_IAP_KEY_ID');
const APPLE_BUNDLE_ID = defineString('APPLE_BUNDLE_ID');

const db = admin.firestore();
const { Timestamp } = admin.firestore;

function authUid(request) {
  const uid = request.auth && request.auth.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Authentication required.');
  return uid;
}

function base64url(value) {
  return Buffer.from(value).toString('base64url');
}

function jsonPart(value) {
  return base64url(JSON.stringify(value));
}

function signJwtRs256(header, payload, privateKey) {
  const input = `${jsonPart(header)}.${jsonPart(payload)}`;
  const signature = crypto.sign('RSA-SHA256', Buffer.from(input), privateKey);
  return `${input}.${signature.toString('base64url')}`;
}

function signJwtEs256(header, payload, privateKey) {
  const input = `${jsonPart(header)}.${jsonPart(payload)}`;
  const signature = crypto.sign('sha256', Buffer.from(input), {
    key: privateKey,
    dsaEncoding: 'ieee-p1363',
  });
  return `${input}.${signature.toString('base64url')}`;
}

function decodeJwtPayload(token) {
  const parts = String(token || '').split('.');
  if (parts.length < 2) throw new Error('INVALID_SIGNED_PAYLOAD');
  return JSON.parse(Buffer.from(parts[1], 'base64url').toString('utf8'));
}

async function googleAccessToken(serviceAccount) {
  const now = Math.floor(Date.now() / 1000);
  const assertion = signJwtRs256(
    { alg: 'RS256', typ: 'JWT' },
    {
      iss: serviceAccount.client_email,
      scope: 'https://www.googleapis.com/auth/androidpublisher',
      aud: 'https://oauth2.googleapis.com/token',
      iat: now,
      exp: now + 3600,
    },
    serviceAccount.private_key,
  );

  const body = new URLSearchParams({
    grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
    assertion,
  });
  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body,
  });
  if (!response.ok) throw new Error('GOOGLE_AUTH_FAILED');
  const data = await response.json();
  if (!data.access_token) throw new Error('GOOGLE_AUTH_FAILED');
  return data.access_token;
}

async function verifyGooglePlay(purchase) {
  const packageName = GOOGLE_PLAY_PACKAGE_NAME.value().trim();
  if (!packageName) throw new Error('GOOGLE_PACKAGE_NOT_CONFIGURED');

  let account;
  try {
    account = JSON.parse(GOOGLE_PLAY_SERVICE_ACCOUNT_JSON.value());
  } catch (_) {
    throw new Error('GOOGLE_SERVICE_ACCOUNT_INVALID');
  }
  if (!account.client_email || !account.private_key) {
    throw new Error('GOOGLE_SERVICE_ACCOUNT_INVALID');
  }

  const token = await googleAccessToken(account);
  const url =
    'https://androidpublisher.googleapis.com/androidpublisher/v3/applications/' +
    encodeURIComponent(packageName) +
    '/purchases/subscriptionsv2/tokens/' +
    encodeURIComponent(purchase.serverVerificationData);

  const response = await fetch(url, {
    headers: { authorization: `Bearer ${token}` },
  });
  if (!response.ok) throw new Error('GOOGLE_PURCHASE_NOT_VERIFIED');

  const data = await response.json();
  const lineItems = Array.isArray(data.lineItems) ? data.lineItems : [];
  const item = lineItems
    .filter((value) => value && value.productId === MONTHLY_PRODUCT_ID)
    .sort((a, b) => Date.parse(String(b.expiryTime || '')) - Date.parse(String(a.expiryTime || '')))[0];
  if (!item) throw new Error('PRODUCT_MISMATCH');

  const transactionId =
    data.latestOrderId ||
    (data.externalAccountIdentifiers && data.externalAccountIdentifiers.obfuscatedExternalAccountId) ||
    purchase.serverVerificationData.slice(0, 80);

  return verifiedEntitlement({
    source: 'google_play',
    productId: item.productId,
    transactionId,
    expiresAtMs: Date.parse(String(item.expiryTime || '')),
  });
}

function appleBearerToken() {
  const issuerId = APPLE_IAP_ISSUER_ID.value().trim();
  const keyId = APPLE_IAP_KEY_ID.value().trim();
  const bundleId = APPLE_BUNDLE_ID.value().trim();
  const privateKey = APPLE_IAP_PRIVATE_KEY.value();

  if (!issuerId || !keyId || !bundleId || !privateKey) {
    throw new Error('APPLE_NOT_CONFIGURED');
  }

  const now = Math.floor(Date.now() / 1000);
  return signJwtEs256(
    { alg: 'ES256', kid: keyId, typ: 'JWT' },
    {
      iss: issuerId,
      iat: now,
      exp: now + 300,
      aud: 'appstoreconnect-v1',
      bid: bundleId,
    },
    privateKey,
  );
}

async function verifyApple(purchase) {
  const bundleId = APPLE_BUNDLE_ID.value().trim();
  const bearer = appleBearerToken();
  const transactionId = purchase.purchaseId;
  const urls = [
    'https://api.storekit.itunes.apple.com/inApps/v1/transactions/' + encodeURIComponent(transactionId),
    'https://api.storekit-sandbox.itunes.apple.com/inApps/v1/transactions/' + encodeURIComponent(transactionId),
  ];

  let signedTransactionInfo = null;
  for (const url of urls) {
    const response = await fetch(url, {
      headers: { authorization: `Bearer ${bearer}` },
    });
    if (response.ok) {
      const data = await response.json();
      signedTransactionInfo = data.signedTransactionInfo || null;
      if (signedTransactionInfo) break;
    }
  }

  if (!signedTransactionInfo) throw new Error('APPLE_PURCHASE_NOT_VERIFIED');
  const data = decodeJwtPayload(signedTransactionInfo);
  if (String(data.bundleId || '') !== bundleId) throw new Error('BUNDLE_MISMATCH');
  if (String(data.productId || '') !== MONTHLY_PRODUCT_ID) throw new Error('PRODUCT_MISMATCH');

  return verifiedEntitlement({
    source: 'app_store',
    productId: data.productId,
    transactionId: String(data.transactionId || transactionId),
    originalTransactionId: data.originalTransactionId || null,
    expiresAtMs: Number(data.expiresDate),
  });
}

function mapVerificationError(error) {
  const message = error && error.message ? String(error.message) : 'PURCHASE_VERIFICATION_FAILED';
  if (message.includes('CONFIGURED') || message.includes('SERVICE_ACCOUNT')) {
    return new HttpsError('failed-precondition', message);
  }
  if (message.includes('INVALID_') || message.includes('MISSING_') ||
      message.includes('MISMATCH') || message.includes('INACTIVE')) {
    return new HttpsError('invalid-argument', message);
  }
  return new HttpsError('permission-denied', 'Purchase could not be verified.');
}

const verifySubscriptionPurchaseV2 = onCall(
  {
    secrets: [GOOGLE_PLAY_SERVICE_ACCOUNT_JSON, APPLE_IAP_PRIVATE_KEY],
  },
  async (request) => {
    const uid = authUid(request);
    let purchase;
    try {
      purchase = validatePurchaseRequest(request.data);
    } catch (error) {
      throw mapVerificationError(error);
    }

    let verified;
    try {
      verified = purchase.platform === 'google_play'
        ? await verifyGooglePlay(purchase)
        : await verifyApple(purchase);
    } catch (error) {
      throw mapVerificationError(error);
    }

    const entitlementRef = db.collection('purchaseEntitlementsV2').doc(uid);
    const claimKey = crypto.createHash('sha256')
      .update(`${verified.source}:${verified.transactionId}`)
      .digest('hex');
    const claimRef = db.collection('purchaseReceiptClaimsV2').doc(claimKey);

    await db.runTransaction(async (tx) => {
      const claimSnap = await tx.get(claimRef);
      if (claimSnap.exists && claimSnap.data().uid !== uid) {
        throw new HttpsError(
          'permission-denied',
          'This store transaction is already linked to another account.',
        );
      }

      tx.set(claimRef, {
        uid,
        source: verified.source,
        productId: verified.productId,
        transactionId: verified.transactionId,
        updatedAt: Timestamp.now(),
      }, { merge: true });

      tx.set(entitlementRef, {
        verified: true,
        source: verified.source,
        productId: verified.productId,
        transactionId: verified.transactionId,
        originalTransactionId: verified.originalTransactionId,
        expiresAt: Timestamp.fromMillis(verified.expiresAtMs),
        verifiedAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
      }, { merge: true });
    });

    return {
      verified: true,
      source: verified.source,
      productId: verified.productId,
      expiresAtMs: verified.expiresAtMs,
    };
  },
);

module.exports = {
  verifySubscriptionPurchaseV2,
};
