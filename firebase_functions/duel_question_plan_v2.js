'use strict';

const crypto = require('crypto');
const { normalizeRecent, recordRecent, sampleUnique } = require('./core_engine_v2');
const { mergeWrongChoices } = require('./custom_answers_engine_v2');

function shuffle(values) {
  const copy = [...values];
  for (let i = copy.length - 1; i > 0; i -= 1) {
    const j = crypto.randomInt(i + 1);
    [copy[i], copy[j]] = [copy[j], copy[i]];
  }
  return copy;
}

function selectOpponentPacks(deckPackIds) {
  const selected = sampleUnique(Array.isArray(deckPackIds) ? deckPackIds.map(String) : [], 7);
  if (!selected) throw new Error('Opponent deck must contain at least 7 packs.');
  return selected;
}

function chooseQuestionEntry(entries, recentQuestionIds, usedQuestionIds) {
  const used = usedQuestionIds instanceof Set ? usedQuestionIds : new Set(usedQuestionIds || []);
  const usable = (Array.isArray(entries) ? entries : []).filter((entry) => entry && entry.id && !used.has(String(entry.id)));
  if (!usable.length) throw new Error('No usable question is available for this pack.');

  const recent = normalizeRecent(recentQuestionIds);
  const recentSet = new Set(recent);
  const fresh = usable.filter((entry) => !recentSet.has(String(entry.id)));
  if (fresh.length) return fresh[crypto.randomInt(fresh.length)];

  for (const id of recent) {
    const found = usable.find((entry) => String(entry.id) === id);
    if (found) return found;
  }
  return usable[crypto.randomInt(usable.length)];
}

function buildPlanItem({ packId, question, customWrongChoices, answerChoiceCount }) {
  if (!question || !question.id || !question.prompt || !question.correct) {
    throw new Error('Question entry is incomplete.');
  }
  const totalChoices = Number(answerChoiceCount);
  if (!Number.isInteger(totalChoices) || totalChoices < 2 || totalChoices > 4) {
    throw new Error('Invalid answer choice count.');
  }
  const wrongs = mergeWrongChoices({
    customChoices: Array.isArray(customWrongChoices) ? customWrongChoices : [],
    defaultWrongChoices: question.wrongAnswers,
    requiredCount: totalChoices - 1,
    correctAnswer: question.correct,
  });
  const choices = shuffle([question.correct, ...wrongs]);
  return {
    packId: String(packId),
    questionId: String(question.id),
    correctIndex: choices.indexOf(question.correct),
    publicQuestion: {
      prompt: String(question.prompt),
      choices,
    },
  };
}

function nextRecent(recentQuestionIds, questionId) {
  return recordRecent(recentQuestionIds, questionId);
}

module.exports = {
  selectOpponentPacks,
  chooseQuestionEntry,
  buildPlanItem,
  nextRecent,
};
