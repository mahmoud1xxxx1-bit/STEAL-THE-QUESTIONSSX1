'use strict';

const assert = require('assert');
const {
  DECK_SIZE,
  DUEL_PACKS,
  buildDuelQuestionPlan,
  validateDeck,
} = require('./core_engine_v2');
const {
  botUnlocked,
  awardPack,
} = require('./bot_engine_v2');
const {
  scoreAnswers,
  resultForPlayer,
  applySteal,
} = require('./duel_engine_v2');
const {
  emptyProfileV2,
  saveDeckV2,
  applyDuelResultV2,
  pvpUnlockedV2,
} = require('./player_profile_v2');
const {
  DAY_MS,
  CARD_INACTIVITY_MS,
  markPvpDeckActivity,
  planLifecycleReclaim,
} = require('./card_lifecycle_engine_v2');

const nowMs = Date.UTC(2026, 9, 9, 12, 0, 0);

// 1) New player starts with zero cards and Bot remains available until card #10.
let ownedPackIds = [];
assert.strictEqual(botUnlocked(ownedPackIds), true);
for (let index = 1; index <= DECK_SIZE; index += 1) {
  const packId = `pack_${index}`;
  const reward = awardPack(ownedPackIds, packId);
  assert.strictEqual(reward.awarded, true);
  ownedPackIds = reward.ownedPackIds;
  assert.strictEqual(reward.botUnlocked, index < DECK_SIZE);
}
assert.strictEqual(ownedPackIds.length, DECK_SIZE);
assert.strictEqual(botUnlocked(ownedPackIds), false);

// 2) Exact 10-card owned deck becomes valid and unlocks PvP.
let profile = emptyProfileV2(nowMs);
profile.ownedPackIds = [...ownedPackIds];
profile.ownedPackCounts = Object.fromEntries(ownedPackIds.map((id) => [id, 1]));
assert.strictEqual(validateDeck(ownedPackIds, profile.ownedPackIds), true);
profile = saveDeckV2(profile, 0, ownedPackIds, nowMs);
assert.strictEqual(profile.decks[0].length, DECK_SIZE);
assert.strictEqual(pvpUnlockedV2(profile, nowMs), true);

// 3) Seven distinct prepared challenge cards each resolve to one unique placeholder question.
const selectedPackIds = ownedPackIds.slice(0, DUEL_PACKS);
const packsById = Object.fromEntries(selectedPackIds.map((packId, index) => [
  packId,
  {
    id: packId,
    category: ['football', 'anime', 'movies', 'geography', 'animals', 'science', 'general'][index],
    questionIds: [`${packId}_q1`, `${packId}_q2`, `${packId}_q3`],
  },
]));
const plan = buildDuelQuestionPlan({
  selectedPackIds,
  packsById,
  recentQuestionIds: [],
});
assert.strictEqual(plan.questions.length, DUEL_PACKS);
assert.strictEqual(new Set(plan.questions.map((item) => item.packId)).size, DUEL_PACKS);
assert.strictEqual(new Set(plan.questions.map((item) => item.questionId)).size, DUEL_PACKS);

// 4) Duel scoring uses correct-answer count first, then total elapsed time.
const playerAnswers = Array.from({ length: DUEL_PACKS }, (_, index) => ({
  correct: index < 5,
  elapsedMs: 3000 + index,
}));
const opponentAnswers = Array.from({ length: DUEL_PACKS }, (_, index) => ({
  correct: index < 4,
  elapsedMs: 1000 + index,
}));
const playerScore = scoreAnswers(playerAnswers);
const opponentScore = scoreAnswers(opponentAnswers);
assert.strictEqual(playerScore.correctAnswers, 5);
assert.strictEqual(opponentScore.correctAnswers, 4);
assert.strictEqual(resultForPlayer(playerScore, opponentScore), 'win');

// 5) Win updates weekly/total stats with +30 points.
profile = applyDuelResultV2(profile, 'win', nowMs);
assert.strictEqual(profile.weeklyPoints, 30);
assert.strictEqual(profile.weeklyWins, 1);
assert.strictEqual(profile.totalWins, 1);

// 6) Steal source is exactly the opponent's immutable 10-card duel deck.
// Duplicate ownership is represented as an extra owned copy, never an out-of-deck replacement.
const opponentDeckPackIds = [
  'pack_1',
  'opp_2',
  'opp_3',
  'opp_4',
  'opp_5',
  'opp_6',
  'opp_7',
  'opp_8',
  'opp_9',
  'opp_10',
];
const loserOwnedPackIds = [...opponentDeckPackIds, 'reserve_not_in_duel'];
const steal = applySteal({
  packId: 'pack_1',
  winnerOwnedPackIds: profile.ownedPackIds,
  loserOwnedPackIds,
  opponentDeckPackIds,
  winnerOwnedPackCounts: profile.ownedPackCounts,
  loserOwnedPackCounts: Object.fromEntries(loserOwnedPackIds.map((id) => [id, 1])),
});
assert.strictEqual(steal.winnerOwnedPackCounts.pack_1, 2);
assert.strictEqual(steal.winnerOwnedPackIds.includes('pack_1'), true);
assert.strictEqual(steal.loserOwnedPackIds.includes('pack_1'), false);
assert.strictEqual(steal.loserOwnedPackIds.includes('reserve_not_in_duel'), true);

// 7) PvP activity protects the exact 10-card deck at the moment it is used.
profile = {
  ...profile,
  ownedPackCounts: steal.winnerOwnedPackCounts,
};
profile = markPvpDeckActivity(profile, profile.decks[0], nowMs);
for (const packId of profile.decks[0]) {
  assert.strictEqual(profile.packLastPvpUsedAtMs[packId], nowMs);
}

// 8) Approved rare-card lifecycle: Epic never expires, Gold after 12 days, Legendary after 7.
const lifecycleProfile = {
  ...profile,
  ownedPackIds: ['epic_one', 'gold_one', 'legendary_one'],
  ownedPackCounts: {
    epic_one: 1,
    gold_one: 2,
    legendary_one: 1,
  },
  packLastPvpUsedAtMs: {
    epic_one: nowMs,
    gold_one: nowMs,
    legendary_one: nowMs,
  },
};
const lifecyclePlan = planLifecycleReclaim({
  profile: lifecycleProfile,
  rarityByPackId: {
    epic_one: 'epic',
    gold_one: 'gold',
    legendary_one: 'legendary',
  },
  nowMs: nowMs + CARD_INACTIVITY_MS.gold,
});
assert.strictEqual(CARD_INACTIVITY_MS.gold, 12 * DAY_MS);
assert.strictEqual(CARD_INACTIVITY_MS.legendary, 7 * DAY_MS);
assert.deepStrictEqual(
  lifecyclePlan.expiredPackIds.sort(),
  ['gold_one', 'legendary_one'],
);
assert.deepStrictEqual(lifecyclePlan.reclaimedCopies, {
  gold_one: 2,
  legendary_one: 1,
});
assert.strictEqual(lifecyclePlan.expiredPackIds.includes('epic_one'), false);

console.log('core_loop_integration_v2_test: ok');
