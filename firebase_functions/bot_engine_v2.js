'use strict';

const crypto = require('crypto');
const { DECK_SIZE } = require('./core_engine_v2');

const BOT_QUESTION_TIMEOUT_MS = 20000;
const BOT_RARITY_WEIGHTS = Object.freeze({
  epic: 85,
  gold: 12,
  legendary: 3,
});

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

function normalizedRewardCards(cards, ownedPackIds) {
  const owned = new Set(uniqueStrings(ownedPackIds));
  return (Array.isArray(cards) ? cards : [])
    .map((card) => ({
      id: String(card && card.id || '').trim(),
      rarity: String(card && card.rarity || 'epic').trim().toLowerCase(),
      availableCopies: Number(card && card.availableCopies || 0),
    }))
    .filter((card) =>
      card.id &&
      !owned.has(card.id) &&
      Object.prototype.hasOwnProperty.call(BOT_RARITY_WEIGHTS, card.rarity) &&
      Number.isInteger(card.availableCopies) &&
      card.availableCopies > 0
    );
}

function chooseWeightedRarity(cards, randomInt = crypto.randomInt) {
  const available = new Set(cards.map((card) => card.rarity));
  const weighted = Object.entries(BOT_RARITY_WEIGHTS)
    .filter(([rarity]) => available.has(rarity));
  const total = weighted.reduce((sum, [, weight]) => sum + weight, 0);
  if (total <= 0) return null;
  let roll = randomInt(total);
  for (const [rarity, weight] of weighted) {
    if (roll < weight) return rarity;
    roll -= weight;
  }
  return weighted[weighted.length - 1][0];
}

function chooseRewardCard(cards, ownedPackIds, randomInt = crypto.randomInt) {
  if (!botUnlocked(ownedPackIds)) return null;
  const candidates = normalizedRewardCards(cards, ownedPackIds);
  if (!candidates.length) return null;
  const rarity = chooseWeightedRarity(candidates, randomInt);
  if (!rarity) return null;
  const pool = candidates.filter((card) => card.rarity === rarity);
  return pool[randomInt(pool.length)];
}

function chooseRewardPack(enabledPackIds, ownedPackIds) {
  const candidates = rewardCandidates(enabledPackIds, ownedPackIds);
  if (!candidates.length) return null;
  return candidates[crypto.randomInt(candidates.length)];
}

function resolveBotAnswer({ correctIndex, selectedIndex, elapsedMs }) {
  const elapsed = Number(elapsedMs);
  const withinTime = Number.isFinite(elapsed) && elapsed >= 0 && elapsed < BOT_QUESTION_TIMEOUT_MS;
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
  BOT_RARITY_WEIGHTS,
  normalizedRewardCards,
  chooseWeightedRarity,
  chooseRewardCard,
  chooseRewardPack,
  resolveBotAnswer,
  awardPack,
};
