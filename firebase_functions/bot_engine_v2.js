'use strict';

const crypto = require('crypto');
const { DECK_SIZE } = require('./core_engine_v2');

const BOT_QUESTION_TIMEOUT_MS = 20000;

function uniqueStrings(values) {
  return [...new Set((Array.isArray(values) ? values : []).map((v) => String(v).trim()).filter(Boolean))];
}

function botUnlocked(ownedPackIds) {
  return uniqueStrings(ownedPackIds).length < DECK_SIZE;
}

function rewardCandidates(enabledPackIds, ownedPackIds) {
  if (!botUnlocked(ownedPackIds)) return [];
  const owned = new Set(uniqueStrings(ownedPackIds));
  return uniqueStrings(enabledPackIds).filter((id) => !owned.has(id));
}

function chooseRewardPack(enabledPackIds, ownedPackIds) {
  const candidates = rewardCandidates(enabledPackIds, ownedPackIds);
  if (!candidates.length) return null;
  return candidates[crypto.randomInt(candidates.length)];
}

function resolveBotAnswer({ correctIndex, selectedIndex, elapsedMs }) {
  const elapsed = Number(elapsedMs);
  const withinTime = Number.isFinite(elapsed) && elapsed >= 0 && elapsed <= BOT_QUESTION_TIMEOUT_MS;
  const selected = Number(selectedIndex);
  const correct = withinTime && Number.isInteger(selected) && selected === Number(correctIndex);
  return {
    correct,
    timedOut: !withinTime,
    elapsedMs: withinTime ? Math.floor(elapsed) : BOT_QUESTION_TIMEOUT_MS,
  };
}

function awardPack(ownedPackIds, packId) {
  const owned = uniqueStrings(ownedPackIds);
  if (!botUnlocked(owned)) return { ownedPackIds: owned, awarded: false, botUnlocked: false };
  const id = String(packId || '').trim();
  if (!id || owned.includes(id)) return { ownedPackIds: owned, awarded: false, botUnlocked: true };
  const next = [...owned, id];
  return {
    ownedPackIds: next,
    awarded: true,
    botUnlocked: next.length < DECK_SIZE,
  };
}

module.exports = {
  BOT_QUESTION_TIMEOUT_MS,
  botUnlocked,
  rewardCandidates,
  chooseRewardPack,
  resolveBotAnswer,
  awardPack,
};
