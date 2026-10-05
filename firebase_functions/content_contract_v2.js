'use strict';

const { CATEGORIES } = require('./core_engine_v2');

function nonEmptyString(value) {
  return typeof value === 'string' && value.trim().length > 0;
}

function uniqueNonEmptyStrings(values) {
  if (!Array.isArray(values)) return null;
  const normalized = values.map((value) => String(value).trim()).filter(Boolean);
  if (normalized.length !== values.length) return null;
  if (new Set(normalized).size !== normalized.length) return null;
  return normalized;
}

function validateCardDocument(cardId, data) {
  if (!nonEmptyString(cardId)) throw new Error('Card id is required.');
  if (!data || typeof data !== 'object') throw new Error(`Card ${cardId} is invalid.`);
  if (!CATEGORIES.includes(data.category)) throw new Error(`Card ${cardId} has an invalid category.`);
  if (!nonEmptyString(data.titleAr) || !nonEmptyString(data.titleEn)) {
    throw new Error(`Card ${cardId} requires Arabic and English titles.`);
  }
  if (typeof data.enabled !== 'boolean') throw new Error(`Card ${cardId} enabled must be boolean.`);
  const count = Number(data.questionCount);
  if (!Number.isInteger(count) || count < 0) throw new Error(`Card ${cardId} questionCount must be a non-negative integer.`);
  return true;
}

function validateQuestionDocument(questionId, cardId, data) {
  if (!nonEmptyString(questionId) || !nonEmptyString(cardId)) throw new Error('Question and card IDs are required.');
  if (!data || typeof data !== 'object') throw new Error(`Question ${questionId} is invalid.`);
  if (typeof data.enabled !== 'boolean') throw new Error(`Question ${questionId} enabled must be boolean.`);
  for (const key of ['questionAr', 'questionEn', 'correctAr', 'correctEn']) {
    if (!nonEmptyString(data[key])) throw new Error(`Question ${questionId} requires ${key}.`);
  }
  const wrongAr = uniqueNonEmptyStrings(data.wrongAnswersAr);
  const wrongEn = uniqueNonEmptyStrings(data.wrongAnswersEn);
  if (!wrongAr || wrongAr.length < 3 || !wrongEn || wrongEn.length < 3) {
    throw new Error(`Question ${questionId} requires at least 3 unique wrong answers in each language.`);
  }
  if (wrongAr.includes(data.correctAr.trim()) || wrongEn.includes(data.correctEn.trim())) {
    throw new Error(`Question ${questionId} wrong answers cannot equal the correct answer.`);
  }
  return true;
}

function localizedQuestion(data, language) {
  const ar = language === 'ar';
  return {
    prompt: ar ? data.questionAr : data.questionEn,
    correct: ar ? data.correctAr : data.correctEn,
    wrongAnswers: [...(ar ? data.wrongAnswersAr : data.wrongAnswersEn)],
  };
}

module.exports = {
  validateCardDocument,
  validateQuestionDocument,
  localizedQuestion,
};
