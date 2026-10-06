'use strict';

const assert = require('assert');
const {
  MONTHLY_PRODUCT_ID,
  normalizePlatform,
  validatePurchaseRequest,
  verifiedEntitlement,
} = require('./purchase_verification_engine_v2');

assert.strictEqual(normalizePlatform('android'), 'google_play');
assert.strictEqual(normalizePlatform('ios'), 'app_store');
assert.strictEqual(normalizePlatform('x'), null);

assert.deepStrictEqual(
  validatePurchaseRequest({
    productId: MONTHLY_PRODUCT_ID,
    platform: 'android',
    serverVerificationData: 'token',
  }),
  {
    productId: MONTHLY_PRODUCT_ID,
    platform: 'google_play',
    serverVerificationData: 'token',
    purchaseId: null,
  }
);

assert.throws(() => validatePurchaseRequest({
  productId: 'weekly_pass_v1',
  platform: 'android',
  serverVerificationData: 'token',
}));

assert.throws(() => validatePurchaseRequest({
  productId: MONTHLY_PRODUCT_ID,
  platform: 'ios',
  serverVerificationData: 'receipt',
}));

const now = Date.now();
const entitlement = verifiedEntitlement({
  source: 'google_play',
  productId: MONTHLY_PRODUCT_ID,
  transactionId: 'tx1',
  expiresAtMs: now + 60000,
  nowMs: now,
});
assert.strictEqual(entitlement.verified, true);
assert.strictEqual(entitlement.source, 'google_play');
assert.strictEqual(entitlement.productId, MONTHLY_PRODUCT_ID);

assert.throws(() => verifiedEntitlement({
  source: 'app_store',
  productId: MONTHLY_PRODUCT_ID,
  transactionId: 'tx2',
  expiresAtMs: now - 1,
  nowMs: now,
}));

console.log('purchase_verification_engine_v2 tests passed');
