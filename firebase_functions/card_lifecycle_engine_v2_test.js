'use strict';

const assert = require('assert');
const {
  normalizeActivityMap,
  markPvpDeckActivity,
  expiredPackIds,
  CARD_INACTIVITY_MS,
  DAY_MS,
} = require('./card_lifecycle_engine_v2');

const owned = Array.from({ length: 10 }, (_, index) => `pack_${index + 1}`);
const base = {
  ownedPackIds: owned,
  packLastPvpUsedAtMs: {},
};

const marked = markPvpDeckActivity(base, owned, 100000);
assert.strictEqual(Object.keys(marked.packLastPvpUsedAtMs).length, 10);
for (const packId of owned) {
  assert.strictEqual(marked.packLastPvpUsedAtMs[packId], 100000);
}

assert.deepStrictEqual(
  expiredPackIds({
    profile: marked,
    rarityByPackId: Object.fromEntries(owned.map((id) => [id, 'epic'])),
    inactivityMsByRarity: {},
    nowMs: 999999999,
  }),
  [],
  'No card may expire until an explicit rarity policy is supplied.',
);

assert.strictEqual(CARD_INACTIVITY_MS.gold, 12 * DAY_MS);
assert.strictEqual(CARD_INACTIVITY_MS.legendary, 7 * DAY_MS);
assert.strictEqual(Object.prototype.hasOwnProperty.call(CARD_INACTIVITY_MS, 'epic'), false);

const explicitPolicy = { epic: 5000 };
assert.deepStrictEqual(
  expiredPackIds({
    profile: marked,
    rarityByPackId: Object.fromEntries(owned.map((id) => [id, 'epic'])),
    inactivityMsByRarity: explicitPolicy,
    nowMs: 104999,
  }),
  [],
);
assert.deepStrictEqual(
  expiredPackIds({
    profile: marked,
    rarityByPackId: Object.fromEntries(owned.map((id) => [id, 'epic'])),
    inactivityMsByRarity: explicitPolicy,
    nowMs: 105000,
  }),
  owned,
);

assert.deepStrictEqual(
  normalizeActivityMap(
    { pack_1: 123, pack_2: 'bad', outside: 999 },
    owned,
  ),
  { pack_1: 123 },
);

assert.throws(
  () => markPvpDeckActivity(base, owned.slice(0, 9), 100000),
  /exact 10-card duel deck/,
);

console.log('card_lifecycle_engine_v2 tests passed');

const rarityMap = {
  pack_1: 'epic',
  pack_2: 'gold',
  pack_3: 'legendary',
};
const timed = {
  ownedPackIds: ['pack_1', 'pack_2', 'pack_3'],
  packLastPvpUsedAtMs: {
    pack_1: 1000,
    pack_2: 1000,
    pack_3: 1000,
  },
};
assert.deepStrictEqual(
  expiredPackIds({
    profile: timed,
    rarityByPackId: rarityMap,
    nowMs: 1000 + (7 * DAY_MS),
  }),
  ['pack_3'],
);
assert.deepStrictEqual(
  expiredPackIds({
    profile: timed,
    rarityByPackId: rarityMap,
    nowMs: 1000 + (12 * DAY_MS),
  }).sort(),
  ['pack_2', 'pack_3'],
);
