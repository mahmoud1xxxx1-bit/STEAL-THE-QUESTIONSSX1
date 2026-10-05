'use strict';

const assert = require('assert');
const {
  unlockedPrestige,
  equipPrestige,
  normalizeVerifiedEntitlement,
  previousWeekKey,
  podiumPlace,
} = require('./profile_features_engine_v2');

(function testPrestigeUnlocksFollowEarnedPodiums() {
  const unlocked = unlockedPrestige({ prestige: { first: 2, second: 0, third: 1 } });
  assert.deepStrictEqual(unlocked.titles, ['champion_of_the_week', 'weekly_third_place']);
  assert.deepStrictEqual(unlocked.frames, ['weekly_gold_frame', 'weekly_bronze_frame']);
})();

(function testCannotEquipUnearnedPrestige() {
  assert.throws(() => equipPrestige(
    { prestige: { first: 0, second: 1, third: 0 } },
    { titleKey: 'champion_of_the_week' },
  ));
})();

(function testCanEquipAndClearEarnedPrestige() {
  const profile = { prestige: { first: 1, second: 0, third: 0 } };
  const equipped = equipPrestige(profile, {
    titleKey: 'champion_of_the_week',
    frameKey: 'weekly_gold_frame',
  });
  assert.strictEqual(equipped.currentTitleKey, 'champion_of_the_week');
  assert.strictEqual(equipped.currentFrameKey, 'weekly_gold_frame');
  const cleared = equipPrestige(equipped, { titleKey: null, frameKey: null });
  assert.strictEqual(cleared.currentTitleKey, null);
  assert.strictEqual(cleared.currentFrameKey, null);
})();

(function testVerifiedSubscriptionRequiresFutureExpiry() {
  const now = Date.UTC(2026, 9, 5, 12, 0, 0);
  const valid = normalizeVerifiedEntitlement({
    verified: true,
    expiresAt: new Date(now + 30 * 24 * 60 * 60 * 1000),
    verifiedAt: new Date(now),
    source: 'google_play',
    productId: 'monthly_10_usd',
  }, now);
  assert.strictEqual(valid.active, true);
  assert.strictEqual(valid.source, 'google_play');

  const expired = normalizeVerifiedEntitlement({
    verified: true,
    expiresAt: new Date(now - 1),
  }, now);
  assert.strictEqual(expired.active, false);

  const unverified = normalizeVerifiedEntitlement({
    verified: false,
    expiresAt: new Date(now + 100000),
  }, now);
  assert.strictEqual(unverified.active, false);
})();

(function testPreviousWeekUsesMondayUtcKey() {
  assert.strictEqual(previousWeekKey(Date.UTC(2026, 9, 5, 10, 0, 0)), '2026-09-28');
  assert.strictEqual(previousWeekKey(Date.UTC(2026, 9, 11, 23, 59, 0)), '2026-09-28');
})();

(function testPodiumPlaceOnlyTopThree() {
  assert.strictEqual(podiumPlace(0), 1);
  assert.strictEqual(podiumPlace(2), 3);
  assert.strictEqual(podiumPlace(3), null);
})();

console.log('profile_features_engine_v2 tests passed');
