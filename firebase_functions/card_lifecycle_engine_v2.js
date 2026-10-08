'use strict';

const { DECK_SIZE } = require('./core_engine_v2');

const DAY_MS = 24 * 60 * 60 * 1000;
const CARD_INACTIVITY_MS = Object.freeze({
  gold: 12 * DAY_MS,
  legendary: 7 * DAY_MS,
});

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

function baselineRareActivity(profile, rarityByPackId, nowMs = Date.now()) {
  const owned = uniqueStrings(profile && profile.ownedPackIds);
  const activity = normalizeActivityMap(
    profile && profile.packLastPvpUsedAtMs,
    owned,
  );
  let changed = false;
  for (const packId of owned) {
    const rarity = String((rarityByPackId && rarityByPackId[packId]) || '').toLowerCase();
    if (rarity !== 'gold' && rarity !== 'legendary') continue;
    const current = Number(activity[packId]);
    if (!Number.isFinite(current) || current <= 0) {
      activity[packId] = Math.max(1, Math.floor(Number(nowMs)));
      changed = true;
    }
  }
  return {
    profile: {
      ...profile,
      packLastPvpUsedAtMs: activity,
    },
    changed,
  };
}

function planLifecycleReclaim({
  profile,
  rarityByPackId,
  nowMs = Date.now(),
}) {
  const baseline = baselineRareActivity(profile, rarityByPackId, nowMs);
  const expired = expiredPackIds({
    profile: baseline.profile,
    rarityByPackId,
    nowMs,
  });
  const counts = baseline.profile && baseline.profile.ownedPackCounts &&
    typeof baseline.profile.ownedPackCounts === 'object'
    ? baseline.profile.ownedPackCounts
    : {};
  return {
    profile: baseline.profile,
    baselineChanged: baseline.changed,
    expiredPackIds: expired,
    reclaimedCopies: Object.fromEntries(
      expired.map((packId) => {
        const count = Number(counts[packId]);
        return [packId, Number.isInteger(count) && count > 0 ? count : 1];
      }),
    ),
  };
}

function expiredPackIds({
  profile,
  rarityByPackId,
  inactivityMsByRarity = CARD_INACTIVITY_MS,
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
  DAY_MS,
  CARD_INACTIVITY_MS,
  normalizeActivityMap,
  markPvpDeckActivity,
  baselineRareActivity,
  planLifecycleReclaim,
  expiredPackIds,
};
