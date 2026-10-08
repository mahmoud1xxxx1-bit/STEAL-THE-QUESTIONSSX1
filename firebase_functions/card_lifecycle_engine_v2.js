'use strict';

const { DECK_SIZE } = require('./core_engine_v2');

function uniqueStrings(value) {
  return [...new Set((Array.isArray(value) ? value : []).map(String))];
}

function normalizeActivityMap(value, ownedPackIds) {
  const raw = value && typeof value === 'object' ? value : {};
  const owned = new Set(uniqueStrings(ownedPackIds));
  const next = {};
  for (const [packId, timestamp] of Object.entries(raw)) {
    if (!owned.has(String(packId))) continue;
    const ms = Number(timestamp);
    if (Number.isFinite(ms) && ms > 0) next[String(packId)] = Math.floor(ms);
  }
  return next;
}

function markPvpDeckActivity(profile, deckPackIds, nowMs = Date.now()) {
  const deck = uniqueStrings(deckPackIds);
  if (deck.length !== DECK_SIZE) throw new Error('PvP activity requires the exact 10-card duel deck.');
  const owned = uniqueStrings(profile && profile.ownedPackIds);
  const ownedSet = new Set(owned);
  if (deck.some((packId) => !ownedSet.has(packId))) {
    throw new Error('PvP activity can only be recorded for owned duel cards.');
  }
  const current = normalizeActivityMap(
    profile && profile.packLastPvpUsedAtMs,
    owned,
  );
  const stamp = Math.max(1, Math.floor(Number(nowMs)));
  for (const packId of deck) current[packId] = stamp;
  return {
    ...profile,
    packLastPvpUsedAtMs: current,
  };
}

function expiredPackIds({
  profile,
  rarityByPackId,
  inactivityMsByRarity,
  nowMs = Date.now(),
}) {
  const owned = uniqueStrings(profile && profile.ownedPackIds);
  const activity = normalizeActivityMap(
    profile && profile.packLastPvpUsedAtMs,
    owned,
  );
  const rarities = rarityByPackId && typeof rarityByPackId === 'object'
    ? rarityByPackId
    : {};
  const policy = inactivityMsByRarity && typeof inactivityMsByRarity === 'object'
    ? inactivityMsByRarity
    : {};

  return owned.filter((packId) => {
    const rarity = String(rarities[packId] || '').toLowerCase();
    const threshold = Number(policy[rarity]);
    if (!Number.isFinite(threshold) || threshold <= 0) return false;
    const lastUsedAtMs = Number(activity[packId]);
    if (!Number.isFinite(lastUsedAtMs) || lastUsedAtMs <= 0) return false;
    return nowMs - lastUsedAtMs >= threshold;
  });
}

module.exports = {
  normalizeActivityMap,
  markPvpDeckActivity,
  expiredPackIds,
};
