'use strict';

const assert = require('assert');
const {
  combinedRecent,
  buildPrepOptions,
  validatePrepSelections,
  enoughSelectableCards,
} = require('./duel_preparation_engine_v2');

const deck = Array.from({ length: 10 }, (_, i) => 'card_' + i);
const entriesByPack = Object.fromEntries(
  deck.map((cardId, i) => [
    cardId,
    [
      { id: 'q_' + i + '_1', prompt: 'Q' + i + '-1' },
      { id: 'q_' + i + '_2', prompt: 'Q' + i + '-2' },
      { id: 'q_' + i + '_3', prompt: 'Q' + i + '-3' },
    ],
  ]),
);

const recent = combinedRecent(['q_0_1'], ['q_1_1']);
assert(recent.has('q_0_1'));
assert(recent.has('q_1_1'));

const options = buildPrepOptions({
  deckPackIds: deck,
  entriesByPack,
  playerRecent: ['q_0_1'],
  opponentRecent: ['q_1_1'],
});
assert.strictEqual(options.length, 10);
assert.strictEqual(options[0].questions[0].blocked, true);
assert.strictEqual(options[1].questions[0].blocked, true);
assert.strictEqual(options[2].questions[0].blocked, false);
assert.strictEqual(enoughSelectableCards(options), true);

const selections = deck.slice(0, 7).map((packId, i) => ({
  packId,
  questionId: i <= 1 ? 'q_' + i + '_2' : 'q_' + i + '_1',
}));
assert.strictEqual(
  validatePrepSelections({
    selections,
    deckPackIds: deck,
    options,
  }),
  true,
);

assert.throws(() =>
  validatePrepSelections({
    selections: [
      { packId: 'card_0', questionId: 'q_0_1' },
      ...selections.slice(1),
    ],
    deckPackIds: deck,
    options,
  })
);

assert.throws(() =>
  validatePrepSelections({
    selections: selections.slice(0, 6),
    deckPackIds: deck,
    options,
  })
);

console.log('duel_preparation_engine_v2 tests passed');
