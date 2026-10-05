'use strict';

const MAX_CHOICE_LENGTH = 80;
const MAX_CUSTOM_CHOICES = 3;

function normalizeChoice(value) {
  return typeof value === 'string' ? value.trim().replace(/\s+/g, ' ') : '';
}

function validateCustomWrongChoices(values, correctAnswer, maxChoices) {
  if (!Array.isArray(values)) throw new Error('Custom choices must be an array.');
  const limit = Number(maxChoices);
  if (!Number.isInteger(limit) || limit < 0 || limit > MAX_CUSTOM_CHOICES) {
    throw new Error('Invalid custom choice limit.');
  }
  if (values.length > limit) throw new Error(`At most ${limit} custom wrong choices are allowed.`);

  const correct = normalizeChoice(correctAnswer).toLocaleLowerCase();
  const normalized = values.map(normalizeChoice);
  if (normalized.some((value) => !value)) throw new Error('Custom choices cannot be empty.');
  if (normalized.some((value) => value.length > MAX_CHOICE_LENGTH)) {
    throw new Error(`Custom choices cannot exceed ${MAX_CHOICE_LENGTH} characters.`);
  }

  const folded = normalized.map((value) => value.toLocaleLowerCase());
  if (new Set(folded).size !== folded.length) throw new Error('Custom choices must be unique.');
  if (correct && folded.includes(correct)) throw new Error('A custom wrong choice cannot equal the correct answer.');

  return normalized;
}

function mergeWrongChoices({ customChoices, defaultWrongChoices, requiredCount, correctAnswer }) {
  const required = Number(requiredCount);
  if (!Number.isInteger(required) || required < 0 || required > MAX_CUSTOM_CHOICES) {
    throw new Error('Invalid required wrong choice count.');
  }

  const custom = validateCustomWrongChoices(customChoices || [], correctAnswer, required);
  const correct = normalizeChoice(correctAnswer).toLocaleLowerCase();
  const seen = new Set(custom.map((value) => value.toLocaleLowerCase()));
  const result = [...custom];

  for (const raw of Array.isArray(defaultWrongChoices) ? defaultWrongChoices : []) {
    if (result.length >= required) break;
    const value = normalizeChoice(raw);
    const folded = value.toLocaleLowerCase();
    if (!value || folded === correct || seen.has(folded)) continue;
    seen.add(folded);
    result.push(value);
  }

  if (result.length < required) throw new Error('Not enough valid wrong answers are available.');
  return result;
}

module.exports = {
  MAX_CHOICE_LENGTH,
  MAX_CUSTOM_CHOICES,
  normalizeChoice,
  validateCustomWrongChoices,
  mergeWrongChoices,
};
