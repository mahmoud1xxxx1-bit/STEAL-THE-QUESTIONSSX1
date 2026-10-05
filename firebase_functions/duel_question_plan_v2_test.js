'use strict';

const assert = require('assert');
const {
  selectOpponentPacks,
  chooseQuestionEntry,
  buildPlanItem,
  nextRecent,
} = require('./duel_question_plan_v2');

(function testSelectSevenUniqueOpponentPacks() {
  const deck = Array.from({ length: 10 }, (_, i) => `pack_${i}`);
  const selected = selectOpponentPacks(deck);
  assert.strictEqual(selected.length, 7);
  assert.strictEqual(new Set(selected).size, 7);
  assert(selected.every((id) => deck.includes(id)));
})();

(function testFreshQuestionPreferredOverRecent() {
  const entries = [
    { id: 'q1' },
    { id: 'q2' },
  ];
  const chosen = chooseQuestionEntry(entries, ['q1'], new Set());
  assert.strictEqual(chosen.id, 'q2');
})();

(function testOldestRecentFallback() {
  const entries = [
    { id: 'q1' },
    { id: 'q2' },
  ];
  const chosen = chooseQuestionEntry(entries, ['q2', 'q1'], new Set());
  assert.strictEqual(chosen.id, 'q2');
})();

(function testPlanItemUsesCustomWrongChoicesFirst() {
  const item = buildPlanItem({
    packId: 'pack_1',
    question: {
      id: 'q1',
      prompt: 'Prompt',
      correct: 'Correct',
      wrongAnswers: ['Default A', 'Default B', 'Default C'],
    },
    customWrongChoices: ['Custom A', 'Custom B'],
    answerChoiceCount: 4,
  });
  assert.strictEqual(item.packId, 'pack_1');
  assert.strictEqual(item.questionId, 'q1');
  assert.strictEqual(item.publicQuestion.choices.length, 4);
  assert(item.publicQuestion.choices.includes('Correct'));
  assert(item.publicQuestion.choices.includes('Custom A'));
  assert(item.publicQuestion.choices.includes('Custom B'));
  assert(Number.isInteger(item.correctIndex));
})();

(function testRecentRemainsCapped() {
  let recent = Array.from({ length: 50 }, (_, i) => `q${i}`);
  recent = nextRecent(recent, 'q50');
  assert.strictEqual(recent.length, 50);
  assert.strictEqual(recent[0], 'q1');
  assert.strictEqual(recent[49], 'q50');
})();

console.log('duel_question_plan_v2 tests passed');
