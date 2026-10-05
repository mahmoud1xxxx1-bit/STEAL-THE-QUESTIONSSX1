'use strict';

const assert = require('assert');
const {
  validateCustomWrongChoices,
  mergeWrongChoices,
  MAX_CHOICE_LENGTH,
} = require('./custom_answers_engine_v2');

assert.deepStrictEqual(
  validateCustomWrongChoices(['  One  ', 'Two'], 'Correct', 2),
  ['One', 'Two']
);

assert.throws(() => validateCustomWrongChoices(['x', 'X'], 'correct', 2));
assert.throws(() => validateCustomWrongChoices(['correct'], 'Correct', 2));
assert.throws(() => validateCustomWrongChoices([''], 'Correct', 2));
assert.throws(() => validateCustomWrongChoices(['a', 'b', 'c'], 'Correct', 2));
assert.throws(() => validateCustomWrongChoices(['x'.repeat(MAX_CHOICE_LENGTH + 1)], 'Correct', 2));

assert.deepStrictEqual(
  mergeWrongChoices({
    customChoices: ['Mine'],
    defaultWrongChoices: ['Default A', 'Default B', 'Default C'],
    requiredCount: 2,
    correctAnswer: 'Correct',
  }),
  ['Mine', 'Default A']
);

assert.deepStrictEqual(
  mergeWrongChoices({
    customChoices: ['Mine', 'Other'],
    defaultWrongChoices: ['Default A', 'Default B', 'Default C'],
    requiredCount: 3,
    correctAnswer: 'Correct',
  }),
  ['Mine', 'Other', 'Default A']
);

console.log('custom_answers_engine_v2 tests passed');
