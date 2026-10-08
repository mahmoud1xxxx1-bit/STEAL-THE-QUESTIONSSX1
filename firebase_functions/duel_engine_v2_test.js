'use strict';

const assert = require('assert');
const {
  scoreAnswers,
  resultForPlayer,
  botRewardCandidates,
  stealablePackIds,
  applySteal,
} = require('./duel_engine_v2');

const answers = (correctCount, elapsedMs) => Array.from({ length: 7 }, (_, i) => ({
  correct: i < correctCount,
  elapsedMs,
}));

const betterAccuracy = resultForPlayer(scoreAnswers(answers(5, 10000)), scoreAnswers(answers(4, 1000)));
assert.strictEqual(betterAccuracy, 'win');

const faster = resultForPlayer(scoreAnswers(answers(4, 5000)), scoreAnswers(answers(4, 6000)));
assert.strictEqual(faster, 'win');

const draw = resultForPlayer(scoreAnswers(answers(3, 7000)), scoreAnswers(answers(3, 7000)));
assert.strictEqual(draw, 'draw');

assert.strictEqual(scoreAnswers(answers(0, 999999)).totalElapsedMs, 7 * 20000);

assert.deepStrictEqual(
  botRewardCandidates(['p1', 'p2', 'p3', 'p3'], ['p1', 'p2']).sort(),
  ['p3']
);
assert.deepStrictEqual(
  botRewardCandidates(['extra'], Array.from({ length: 10 }, (_, i) => `p${i}`)),
  []
);

const deck = Array.from({ length: 10 }, (_, i) => `p${i}`);
const stealable = stealablePackIds(deck, ['p0', 'p1', 'p2']);
assert.strictEqual(stealable.length, 10);
assert.strictEqual(stealable.includes('p0'), true);

// A winner can only steal from the exact 10-card deck snapshot used by the loser in this duel.
assert.throws(() =>
  applySteal({
    packId: 'outside_duel_deck',
    winnerOwnedPackIds: ['x1', 'x2'],
    loserOwnedPackIds: [...deck, 'outside_duel_deck'],
    opponentDeckPackIds: deck,
  })
);

// The saved duel deck itself must remain a valid set of 10 distinct cards.
assert.throws(() =>
  stealablePackIds([...deck.slice(0, 9), 'p8'], [])
);

const transfer = applySteal({
  packId: 'p9',
  winnerOwnedPackIds: ['x1', 'x2', 'p9'],
  loserOwnedPackIds: deck,
  opponentDeckPackIds: deck,
  winnerOwnedPackCounts: { x1: 1, x2: 1, p9: 1 },
  loserOwnedPackCounts: Object.fromEntries(deck.map((id) => [id, 1])),
});
assert.strictEqual(transfer.winnerOwnedPackIds.includes('p9'), true);
assert.strictEqual(transfer.winnerOwnedPackCounts.p9, 2);
assert.strictEqual(transfer.loserOwnedPackIds.includes('p9'), false);
assert.strictEqual(transfer.loserOwnedPackIds.length, 9);
assert.strictEqual(transfer.loserPvpUnlocked, false);

const duplicateSourceTransfer = applySteal({
  packId: 'p9',
  winnerOwnedPackIds: ['p9'],
  loserOwnedPackIds: deck,
  opponentDeckPackIds: deck,
  winnerOwnedPackCounts: { p9: 2 },
  loserOwnedPackCounts: { ...Object.fromEntries(deck.map((id) => [id, 1])), p9: 2 },
});
assert.strictEqual(duplicateSourceTransfer.winnerOwnedPackCounts.p9, 3);
assert.strictEqual(duplicateSourceTransfer.loserOwnedPackCounts.p9, 1);
assert.strictEqual(duplicateSourceTransfer.loserOwnedPackIds.includes('p9'), true);

console.log('duel_engine_v2_test: ok');
