'use strict';

const { DECK_SIZE, DUEL_PACKS } = require('./core_engine_v2');

const QUESTION_TIMEOUT_MS = 20000;

function normalizeElapsedMs(value) {
  const ms = Number(value);
  if (!Number.isFinite(ms)) return QUESTION_TIMEOUT_MS;
  if (ms < 0) return 0;
  if (ms > QUESTION_TIMEOUT_MS) return QUESTION_TIMEOUT_MS;
  return Math.floor(ms);
}

function scoreAnswers(answers) {
  if (!Array.isArray(answers) || answers.length !== DUEL_PACKS) {
    throw new Error(`A duel result requires exactly ${DUEL_PACKS} answers.`);
  }
  return answers.reduce((score, answer) => ({
    correctAnswers: score.correctAnswers + (answer && answer.correct === true ? 1 : 0),
    totalElapsedMs: score.totalElapsedMs + normalizeElapsedMs(answer && answer.elapsedMs),
  }), { correctAnswers: 0, totalElapsedMs: 0 });
}

function resultForPlayer(player, opponent) {
  if (player.correctAnswers > opponent.correctAnswers) return 'win';
  if (player.correctAnswers < opponent.correctAnswers) return 'loss';
  if (player.totalElapsedMs < opponent.totalElapsedMs) return 'win';
  if (player.totalElapsedMs > opponent.totalElapsedMs) return 'loss';
  return 'draw';
}

function uniqueStrings(values) {
  return [...new Set((Array.isArray(values) ? values : []).map((v) => String(v).trim()).filter(Boolean))];
}

function botRewardCandidates(allPackIds, ownedPackIds) {
  const owned = new Set(uniqueStrings(ownedPackIds));
  if (owned.size >= DECK_SIZE) return [];
  return uniqueStrings(allPackIds).filter((id) => !owned.has(id));
}

function stealablePackIds(opponentDeckPackIds, winnerOwnedPackIds) {
  const deck = uniqueStrings(opponentDeckPackIds);
  if (deck.length !== DECK_SIZE) {
    throw new Error('Opponent deck must contain exactly 10 distinct packs.');
  }
  const winnerOwned = new Set(uniqueStrings(winnerOwnedPackIds));
  return deck.filter((id) => !winnerOwned.has(id));
}

function applySteal({ packId, winnerOwnedPackIds, loserOwnedPackIds, opponentDeckPackIds }) {
  const id = String(packId);
  const eligible = new Set(stealablePackIds(opponentDeckPackIds, winnerOwnedPackIds));
  if (!eligible.has(id)) throw new Error('Selected pack is not eligible to steal.');

  const winner = new Set(uniqueStrings(winnerOwnedPackIds));
  const loser = new Set(uniqueStrings(loserOwnedPackIds));
  if (!loser.has(id)) throw new Error('Opponent no longer owns the selected pack.');

  winner.add(id);
  loser.delete(id);
  return {
    winnerOwnedPackIds: [...winner],
    loserOwnedPackIds: [...loser],
    loserPvpUnlocked: loser.size >= DECK_SIZE,
  };
}

module.exports = {
  QUESTION_TIMEOUT_MS,
  normalizeElapsedMs,
  scoreAnswers,
  resultForPlayer,
  botRewardCandidates,
  stealablePackIds,
  applySteal,
};
