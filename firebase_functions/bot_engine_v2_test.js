'use strict';

const assert = require('assert');
const {
  BOT_QUESTION_TIMEOUT_MS,
  botUnlocked,
  rewardCandidates,
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

assert.deepStrictEqual(
  resolveBotAnswer({ correctIndex: 2, selectedIndex: 2, elapsedMs: 1500 }),
  { correct: true, timedOut: false, elapsedMs: 1500 }
);

assert.deepStrictEqual(
  resolveBotAnswer({ correctIndex: 2, selectedIndex: 2, elapsedMs: BOT_QUESTION_TIMEOUT_MS + 1 }),
  { correct: false, timedOut: true, elapsedMs: BOT_QUESTION_TIMEOUT_MS }
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
