'use strict';

const assert = require('assert');
const {
  DUEL_DURATION_MS,
  activeDeckForProfile,
  canPairQueueEntries,
  duelShell,
} = require('./matchmaking_engine_v2');

function profile() {
  const ids = Array.from({ length: 10 }, (_, i) => `p${i}`);
  return {
    ownedPackIds: ids,
    activeDeckIndex: 0,
    decks: [ids, [], [], [], []],
  };
}

assert.deepStrictEqual(activeDeckForProfile(profile()), Array.from({ length: 10 }, (_, i) => `p${i}`));
assert.throws(() => activeDeckForProfile({ ...profile(), ownedPackIds: ['p0'] }));
assert.strictEqual(canPairQueueEntries(
  { uid: 'a', status: 'searching', deckPackIds: profile().decks[0] },
  { uid: 'b', status: 'searching', deckPackIds: profile().decks[0] },
), true);
assert.strictEqual(canPairQueueEntries(
  { uid: 'a', status: 'searching', deckPackIds: profile().decks[0] },
  { uid: 'a', status: 'searching', deckPackIds: profile().decks[0] },
), false);
const duel = duelShell({ duelId: 'd1', p1Uid: 'a', p2Uid: 'b', nowMs: 1000 });
assert.strictEqual(duel.status, 'matched');
assert.strictEqual(duel.questionPlanReady, false);
assert.strictEqual(duel.deadlineAtMs, 1000 + DUEL_DURATION_MS);

console.log('matchmaking_engine_v2 tests passed');
