'use strict';

const assert = require('assert');
const {
  validateCardDocument,
  validateQuestionDocument,
  localizedQuestion,
} = require('./content_contract_v2');

assert.strictEqual(validateCardDocument('football_01', {
  category: 'football',
  titleAr: 'موضوع',
  titleEn: 'Topic',
  enabled: true,
  questionCount: 0,
}), true);

assert.strictEqual(validateQuestionDocument('q1', 'football_01', {
  enabled: true,
  questionAr: 'سؤال',
  questionEn: 'Question',
  correctAr: 'صحيح',
  correctEn: 'Correct',
  wrongAnswersAr: ['أ', 'ب', 'ج'],
  wrongAnswersEn: ['A', 'B', 'C'],
}), true);

const localized = localizedQuestion({
  questionAr: 'سؤال',
  questionEn: 'Question',
  correctAr: 'صحيح',
  correctEn: 'Correct',
  wrongAnswersAr: ['أ', 'ب', 'ج'],
  wrongAnswersEn: ['A', 'B', 'C'],
}, 'en');
assert.strictEqual(localized.prompt, 'Question');
assert.strictEqual(localized.correct, 'Correct');
assert.deepStrictEqual(localized.wrongAnswers, ['A', 'B', 'C']);

assert.throws(() => validateQuestionDocument('q2', 'football_01', {
  enabled: true,
  questionAr: 'سؤال',
  questionEn: 'Question',
  correctAr: 'صحيح',
  correctEn: 'Correct',
  wrongAnswersAr: ['أ', 'ب'],
  wrongAnswersEn: ['A', 'B'],
}));

console.log('content_contract_v2 tests passed');
