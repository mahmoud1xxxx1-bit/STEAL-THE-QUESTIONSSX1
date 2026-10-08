'use strict';

const assert = require('assert');
const {
  BOT_QUESTION_TIMEOUT_MS,
  botUnlocked,
  rewardCandidates,
  BOT_RARITY_WEIGHTS,
  chooseWeightedRarity,
  chooseRewardCard,
  resolveBotAnswer,
  awardPack,
} = require('./bot_engine_v2');

assert.strictEqual(botUnlocked([]), true);
assert.strictEqual(botUnlocked(Array.from({ length: 10 }, (_, i) => `p${i}`)), false);

assert.deepStrictEqual(
  rewardCandidates(['a', 'b', 'c'], ['b']),
  ['a', 'c']
);

assert.deepStrictEqual(
  rewardCandidates(['a', 'b'], Array.from({ length: 10 }, (_, i) => `p${i}`)),
  []
);

assert.deepStrictEqual(BOT_RARITY_WEIGHTS, { epic: 85, gold: 12, legendary: 3 });

const rarityCards = [
  { id: 'e1', rarity: 'epic', availableCopies: 10 },
  { id: 'g1', rarity: 'gold', availableCopies: 10 },
  { id: 'l1', rarity: 'legendary', availableCopies: 10 },
];
assert.strictEqual(chooseWeightedRarity(rarityCards, () => 0), 'epic');
assert.strictEqual(chooseWeightedRarity(rarityCards, () => 84), 'epic');
assert.strictEqual(chooseWeightedRarity(rarityCards, () => 85), 'gold');
assert.strictEqual(chooseWeightedRarity(rarityCards, () => 96), 'gold');
assert.strictEqual(chooseWeightedRarity(rarityCards, () => 97), 'legendary');
assert.strictEqual(chooseWeightedRarity(rarityCards, () => 99), 'legendary');

const legendaryOnly = chooseRewardCard(
  [
    { id: 'l1', rarity: 'legendary', availableCopies: 1 },
    { id: 'e0', rarity: 'epic', availableCopies: 0 },
  ],
  [],
  () => 0
);
assert.strictEqual(legendaryOnly.id, 'l1');
assert.strictEqual(chooseRewardCard(rarityCards, ['e1', 'g1', 'l1'], () => 0), null);

assert.deepStrictEqual(
  resolveBotAnswer({ correctIndex: 2, selectedIndex: 2, elapsedMs: 1500 }),
  { correct: true, timedOut: false, elapsedMs: 1500 }
);

assert.deepStrictEqual(
  resolveBotAnswer({ correctIndex: 2, selectedIndex: 2, elapsedMs: BOT_QUESTION_TIMEOUT_MS }),
  { correct: false, timedOut: true, elapsedMs: BOT_QUESTION_TIMEOUT_MS }
);

assert.deepStrictEqual(
  resolveBotAnswer({ correctIndex: 2, selectedIndex: 2, elapsedMs: BOT_QUESTION_TIMEOUT_MS - 1 }),
  { correct: true, timedOut: false, elapsedMs: BOT_QUESTION_TIMEOUT_MS - 1 }
);

const firstAward = awardPack(['a'], 'b');
assert.strictEqual(firstAward.awarded, true);
assert.deepStrictEqual(firstAward.ownedPackIds, ['a', 'b']);

const duplicateAward = awardPack(['a', 'b'], 'b');
assert.strictEqual(duplicateAward.awarded, false);
assert.deepStrictEqual(duplicateAward.ownedPackIds, ['a', 'b']);

const full = awardPack(Array.from({ length: 10 }, (_, i) => `p${i}`), 'extra');
assert.strictEqual(full.awarded, false);
assert.strictEqual(full.botUnlocked, false);

console.log('bot_engine_v2 tests passed');
