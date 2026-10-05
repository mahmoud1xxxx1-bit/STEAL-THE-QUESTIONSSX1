'use strict';

const assert = require('assert');
const { rankWeeklyEntries, topThree, rewardDocumentId } = require('./weekly_prestige_engine_v2');

(function testRankingUsesPointsThenWinsThenUid() {
  const ranked = rankWeeklyEntries([
    { uid: 'b', weeklyPoints: 60, weeklyWins: 1 },
    { uid: 'c', weeklyPoints: 30, weeklyWins: 9 },
    { uid: 'a', weeklyPoints: 60, weeklyWins: 1 },
    { uid: 'd', weeklyPoints: 60, weeklyWins: 2 },
  ]);
  assert.deepStrictEqual(ranked.map((x) => x.uid), ['d', 'a', 'b', 'c']);
})();

(function testTopThreeAssignsPlaces() {
  const top = topThree([
    { uid: 'u1', weeklyPoints: 90, weeklyWins: 3 },
    { uid: 'u2', weeklyPoints: 60, weeklyWins: 2 },
    { uid: 'u3', weeklyPoints: 30, weeklyWins: 1 },
    { uid: 'u4', weeklyPoints: 0, weeklyWins: 0 },
  ]);
  assert.strictEqual(top.length, 3);
  assert.deepStrictEqual(top.map((x) => x.place), [1, 2, 3]);
})();

(function testRewardDocumentIdIsDeterministic() {
  assert.strictEqual(rewardDocumentId('2026-09-28', 'user_1'), '2026-09-28--user_1');
})();

console.log('weekly_prestige_engine_v2 tests passed');
