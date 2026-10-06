'use strict';

const MONTHLY_PRODUCT_ID = 'monthly_subscription_v2';

function cleanString(value, max = 8192) {
  const text = String(value || '').trim();
  if (!text || text.length > max) return null;
  return text;
}

function normalizePlatform(value) {
  const platform = String(value || '').trim().toLowerCase();
  if (platform === 'android' || platform === 'google_play') return 'google_play';
  if (platform === 'ios' || platform === 'app_store') return 'app_store';
  return null;
}

function validatePurchaseRequest(data) {
  const raw = data && typeof data === 'object' ? data : {};
  const productId = cleanString(raw.productId, 200);
  const platform = normalizePlatform(raw.platform || raw.source);
  const serverVerificationData = cleanString(raw.serverVerificationData, 20000);
  const purchaseId = raw.purchaseId == null ? null : cleanString(raw.purchaseId, 500);

  if (productId !== MONTHLY_PRODUCT_ID) throw new Error('INVALID_PRODUCT');
  if (!platform) throw new Error('INVALID_PLATFORM');
  if (!serverVerificationData) throw new Error('MISSING_VERIFICATION_DATA');
  if (platform === 'app_store' && !purchaseId) throw new Error('MISSING_PURCHASE_ID');

  return {
    productId,
    platform,
    serverVerificationData,
    purchaseId,
  };
}

function futureMillis(value, nowMs = Date.now()) {
  const millis = typeof value === 'number' ? value : Date.parse(String(value || ''));
  return Number.isFinite(millis) && millis > nowMs ? millis : null;
}

function verifiedEntitlement({
  source,
  productId,
  transactionId,
  expiresAtMs,
  originalTransactionId = null,
  nowMs = Date.now(),
}) {
  if (productId !== MONTHLY_PRODUCT_ID) throw new Error('PRODUCT_MISMATCH');
  const expiry = futureMillis(expiresAtMs, nowMs);
  if (!expiry) throw new Error('SUBSCRIPTION_INACTIVE');
  const tx = cleanString(transactionId, 500);
  if (!tx) throw new Error('MISSING_TRANSACTION');

  return {
    verified: true,
    source,
    productId,
    transactionId: tx,
    originalTransactionId: originalTransactionId == null
      ? null
      : cleanString(originalTransactionId, 500),
    expiresAtMs: expiry,
  };
}

module.exports = {
  MONTHLY_PRODUCT_ID,
  normalizePlatform,
  validatePurchaseRequest,
  verifiedEntitlement,
};
