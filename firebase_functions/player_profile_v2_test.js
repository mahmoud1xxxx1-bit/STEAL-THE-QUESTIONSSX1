'use strict';

const assert = require('assert');
const {
  emptyProfileV2,
  normalizeProfileV2,
  ensureCurrentWeekV2,
  applyDuelResultV2,
  canSaveDeckV2,
  saveDeckV2,
  applyPrestigeV2,
  pvpUnlockedV2,
} = require('./player_profile_v2');

const now = Date.UTC(2026, 9, 5, 12, 0, 0);

const empty = emptyProfileV2(now);
assert.strictEqual(empty.schemaVersion, 2);
assert.strictEqual(empty.ownedPackIds.length, 0);
assert.strictEqual(empty.weeklySteals, 0);
assert.strictEqual(empty.totalSteals, 0);
assert.deepStrictEqual(empty.ownedPackCounts, {});
assert.strictEqual(empty.decks.length, 5);
assert.strictEqual(empty.weeklyPoints, 0);
assert.deepStrictEqual(empty.packLastPvpUsedAtMs, {});

const owned = Array.from({ length: 10 }, (_, i) => `p${i}`);
let profile = normalizeProfileV2({
  ...empty,
  ownedPackIds: owned,
  subscriptionActive: false,
}, now);

assert.strictEqual(pvpUnlockedV2(profile, now), true);
assert.strictEqual(profile.ownedPackCounts.p0, 1);
assert.strictEqual(canSaveDeckV2(profile, 0, owned, now), true);
assert.strictEqual(canSaveDeckV2(profile, 2, owned, now), false);
profile = saveDeckV2(profile, 0, owned, now);
assert.deepStrictEqual(profile.decks[0], owned);

profile = normalizeProfileV2({
  ...profile,
  packLastPvpUsedAtMs: {
    p0: 123456,
    p1: 'bad',
    outside: 999999,
  },
}, now);
assert.deepStrictEqual(profile.packLastPvpUsedAtMs, { p0: 123456 });

profile = applyDuelResultV2(profile, 'win', now);
assert.strictEqual(profile.weeklyPoints, 30);
assert.strictEqual(profile.weeklyWins, 1);
assert.strictEqual(profile.totalWins, 1);
profile = applyDuelResultV2(profile, 'loss', now);
assert.strictEqual(profile.weeklyPoints, 15);
profile = applyDuelResultV2(profile, 'draw', now);
assert.strictEqual(profile.weeklyPoints, 15);
assert.strictEqual(profile.weeklyDraws, 1);

profile = applyPrestigeV2(profile, 1, now);
assert.strictEqual(profile.prestige.first, 1);
assert.strictEqual(profile.currentTitleKey, 'champion_of_the_week');
assert.strictEqual(profile.currentFrameKey, 'weekly_gold_frame');

const later = Date.UTC(2026, 9, 12, 12, 0, 0);
profile = normalizeProfileV2(profile, later);
assert.strictEqual(profile.weeklyPoints, 0);
assert.strictEqual(profile.weeklyWins, 0);
assert.strictEqual(profile.totalWins, 1);
assert.strictEqual(profile.prestige.first, 1);

const recent = Array.from({ length: 60 }, (_, i) => `q${i}`);
profile = normalizeProfileV2({ ...profile, recentQuestionIds: recent }, later);
assert.strictEqual(profile.recentQuestionIds.length, 50);
assert.strictEqual(profile.recentQuestionIds[0], 'q10');

console.log('player_profile_v2 tests passed');

const duplicateCounts = normalizeProfileV2({
  ...profile,
  ownedPackCounts: { p0: 3, p1: 2 },
}, later);
assert.strictEqual(duplicateCounts.ownedPackCounts.p0, 3);
assert.strictEqual(duplicateCounts.ownedPackCounts.p1, 2);
assert.strictEqual(duplicateCounts.ownedPackCounts.p2, 1);

const stealStats = normalizeProfileV2({
  ...profile,
  weeklySteals: 4,
  totalSteals: 17,
}, later);
assert.strictEqual(stealStats.weeklySteals, 4);
assert.strictEqual(stealStats.totalSteals, 17);

const nextWeekSteals = ensureCurrentWeekV2(
  stealStats,
  later + (8 * 24 * 60 * 60 * 1000),
);
assert.strictEqual(nextWeekSteals.weeklySteals, 0);
assert.strictEqual(nextWeekSteals.totalSteals, 17);
