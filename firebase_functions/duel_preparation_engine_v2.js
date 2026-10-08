'use strict';

const { DUEL_PACKS, normalizeRecent } = require('./core_engine_v2');

function uniqueStrings(values) {
  return [...new Set((Array.isArray(values) ? values : []).map(String).map((v) => v.trim()).filter(Boolean))];
}

function combinedRecent(playerRecent, opponentRecent) {
  return new Set([...normalizeRecent(playerRecent), ...normalizeRecent(opponentRecent)]);
}

function buildPrepOptions({ deckPackIds, entriesByPack, playerRecent, opponentRecent }) {
  const deck = uniqueStrings(deckPackIds);
  if (deck.length !== 10) throw new Error('Preparation requires exactly 10 deck cards.');
  const blockedIds = combinedRecent(playerRecent, opponentRecent);

  return deck.map((packId) => {
    const entries = Array.isArray(entriesByPack && entriesByPack[packId])
      ? entriesByPack[packId]
      : [];
    const questions = entries
      .filter((entry) => entry && entry.id && entry.prompt)
      .map((entry) => ({
        questionId: String(entry.id),
        prompt: String(entry.prompt),
        blocked: blockedIds.has(String(entry.id)),
      }));
    return {
      packId,
      questions,
      selectableCount: questions.filter((q) => !q.blocked).length,
    };
  });
}

function validatePrepSelections({ selections, deckPackIds, options }) {
  const deck = new Set(uniqueStrings(deckPackIds));
  const list = Array.isArray(selections) ? selections : [];
  if (list.length !== DUEL_PACKS) throw new Error('Exactly 7 question selections are required.');

  const optionMap = new Map(
    (Array.isArray(options) ? options : []).map((card) => [
      String(card.packId),
      new Map(
        (Array.isArray(card.questions) ? card.questions : []).map((q) => [
          String(q.questionId),
          q,
        ]),
      ),
    ]),
  );

  const usedCards = new Set();
  const usedQuestions = new Set();
  for (const raw of list) {
    const packId = String(raw && raw.packId || '').trim();
    const questionId = String(raw && raw.questionId || '').trim();
    if (!deck.has(packId)) throw new Error('Selected card is not in the active deck.');
    if (usedCards.has(packId)) throw new Error('A card can only be used once in a duel.');
    if (usedQuestions.has(questionId)) throw new Error('A question can only be used once in a duel.');

    const question = optionMap.get(packId) && optionMap.get(packId).get(questionId);
    if (!question) throw new Error('Selected question does not belong to this card.');
    if (question.blocked === true) throw new Error('Repeated questions cannot be selected.');

    usedCards.add(packId);
    usedQuestions.add(questionId);
  }
  return true;
}

function enoughSelectableCards(options) {
  return (Array.isArray(options) ? options : [])
    .filter((card) => Number(card && card.selectableCount || 0) > 0)
    .length >= DUEL_PACKS;
}

module.exports = {
  combinedRecent,
  buildPrepOptions,
  validatePrepSelections,
  enoughSelectableCards,
};
