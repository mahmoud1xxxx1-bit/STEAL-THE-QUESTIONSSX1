'use strict';

// Server-side contract for the new seven-category model.
// No real questions live in this file. Content will be supplied later.

const crypto = require('crypto');

const CATEGORIES = Object.freeze([
  'football',
  'anime',
  'movies',
  'geography',
  'animals',
  'science',
  'general'
]);

const DECK_SIZE = 10;
const DUEL_PACKS = 7;
const RECENT_QUESTION_LIMIT = 50;
const FREE_DECK_SLOTS = 2;
const SUBSCRIBER_DECK_SLOTS = 5;
const FREE_ANSWER_CHOICES = 3;
const SUBSCRIBER_ANSWER_CHOICES = 4;
const WEEKLY_WIN_POINTS = 30;
const WEEKLY_LOSS_POINTS = -15;
const WEEKLY_DRAW_POINTS = 0;

function assertCategory(category) {
  if (!CATEGORIES.includes(category)) {
    throw new Error(`Unknown category: ${category}`);
  }
}

function validatePack(pack) {
  if (!pack || typeof pack !== 'object') throw new Error('Invalid pack.');
  if (!pack.id || typeof pack.id !== 'string') throw new Error('Pack id is required.');
  assertCategory(pack.category);
  if (!Array.isArray(pack.questionIds)) throw new Error(`Pack ${pack.id} questionIds must be an array.`);
  if (new Set(pack.questionIds).size !== pack.questionIds.length) {
    throw new Error(`Pack ${pack.id} contains duplicate question IDs.`);
  }
  return true;
}

function validateDeck(packIds, ownedPackIds) {
  if (!Array.isArray(packIds) || packIds.length !== DECK_SIZE || new Set(packIds).size !== DECK_SIZE) {
    return false;
  }
  const owned = new Set(Array.isArray(ownedPackIds) ? ownedPackIds.map(String) : []);
  return packIds.every((id) => owned.has(String(id)));
}

function sampleUnique(values, count) {
  if (!Array.isArray(values) || values.length < count) return null;
  const copy = [...values];
  for (let i = copy.length - 1; i > 0; i -= 1) {
    const j = crypto.randomInt(i + 1);
    [copy[i], copy[j]] = [copy[j], copy[i]];
  }
  return copy.slice(0, count);
}

function normalizeRecent(recentIds) {
  const result = [];
  for (const raw of Array.isArray(recentIds) ? recentIds : []) {
    const id = String(raw);
    const existing = result.indexOf(id);
    if (existing >= 0) result.splice(existing, 1);
    result.push(id);
  }
  return result.slice(-RECENT_QUESTION_LIMIT);
}

function recordRecent(recentIds, questionId) {
  const result = normalizeRecent(recentIds);
  const id = String(questionId);
  const existing = result.indexOf(id);
  if (existing >= 0) result.splice(existing, 1);
  result.push(id);
  return result.slice(-RECENT_QUESTION_LIMIT);
}

function oldestRecentEligible(eligibleIds, recentIds) {
  const eligible = new Set(eligibleIds);
  for (const id of normalizeRecent(recentIds)) {
    if (eligible.has(id)) return id;
  }
  return null;
}

/**
 * Selects one question from a pack.
 * Priority: no duplicate in this duel -> avoid recent -> oldest recent fallback.
 */
function chooseQuestionFromPack(pack, recentIds, usedInMatch) {
  validatePack(pack);
  const used = usedInMatch instanceof Set ? usedInMatch : new Set(usedInMatch || []);
  const eligible = pack.questionIds.map(String).filter((id) => !used.has(id));
  if (!eligible.length) throw new Error(`Pack ${pack.id} has no usable questions.`);

  const recent = new Set(normalizeRecent(recentIds));
  const fresh = eligible.filter((id) => !recent.has(id));
  const chosen = fresh.length
    ? fresh[crypto.randomInt(fresh.length)]
    : (oldestRecentEligible(eligible, recentIds) || eligible[crypto.randomInt(eligible.length)]);

  return chosen;
}

function buildDuelQuestionPlan({ selectedPackIds, packsById, recentQuestionIds }) {
  if (!Array.isArray(selectedPackIds) || selectedPackIds.length !== DUEL_PACKS) {
    throw new Error(`A duel question plan requires exactly ${DUEL_PACKS} selected packs.`);
  }

  let recent = normalizeRecent(recentQuestionIds);
  const usedInMatch = new Set();
  const questions = [];

  for (const packId of selectedPackIds) {
    const pack = packsById[String(packId)];
    if (!pack) throw new Error(`Unknown pack: ${packId}`);
    const questionId = chooseQuestionFromPack(pack, recent, usedInMatch);
    usedInMatch.add(questionId);
    recent = recordRecent(recent, questionId);
    questions.push({ packId: String(packId), questionId });
  }

  return { questions, recentQuestionIds: recent };
}

function weeklyPointsForResult(result) {
  if (result === 'win') return WEEKLY_WIN_POINTS;
  if (result === 'loss') return WEEKLY_LOSS_POINTS;
  if (result === 'draw') return WEEKLY_DRAW_POINTS;
  throw new Error(`Unknown duel result: ${result}`);
}

function weekKey(nowMs = Date.now()) {
  const date = new Date(nowMs);
  const day = date.getUTCDay();
  const daysSinceMonday = (day + 6) % 7;
  date.setUTCDate(date.getUTCDate() - daysSinceMonday);
  return date.toISOString().slice(0, 10);
}

function entitlement(active) {
  return {
    active: !!active,
    deckSlots: active ? SUBSCRIBER_DECK_SLOTS : FREE_DECK_SLOTS,
    answerChoices: active ? SUBSCRIBER_ANSWER_CHOICES : FREE_ANSWER_CHOICES,
    editableWrongChoices: (active ? SUBSCRIBER_ANSWER_CHOICES : FREE_ANSWER_CHOICES) - 1
  };
}

function prestigeReward(place) {
  if (place === 1) {
    return { trophy: 'gold_trophy', frame: 'weekly_gold_frame', title: 'champion_of_the_week', featuredChampion: true };
  }
  if (place === 2) {
    return { trophy: 'silver_trophy', frame: 'weekly_silver_frame', title: 'weekly_runner_up', featuredChampion: false };
  }
  if (place === 3) {
    return { trophy: 'bronze_trophy', frame: 'weekly_bronze_frame', title: 'weekly_third_place', featuredChampion: false };
  }
  return null;
}

module.exports = {
  CATEGORIES,
  DECK_SIZE,
  DUEL_PACKS,
  RECENT_QUESTION_LIMIT,
  FREE_DECK_SLOTS,
  SUBSCRIBER_DECK_SLOTS,
  FREE_ANSWER_CHOICES,
  SUBSCRIBER_ANSWER_CHOICES,
  WEEKLY_WIN_POINTS,
  WEEKLY_LOSS_POINTS,
  WEEKLY_DRAW_POINTS,
  validatePack,
  validateDeck,
  sampleUnique,
  normalizeRecent,
  recordRecent,
  chooseQuestionFromPack,
  buildDuelQuestionPlan,
  weeklyPointsForResult,
  weekKey,
  entitlement,
  prestigeReward
};
