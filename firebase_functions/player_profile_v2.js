'use strict';

const {
  DECK_SIZE,
  RECENT_QUESTION_LIMIT,
  entitlement,
  weeklyPointsForResult,
  weekKey,
  validateDeck,
  prestigeReward,
} = require('./core_engine_v2');

function uniqueStrings(value) {
  return [...new Set((Array.isArray(value) ? value : []).map(String))];
}

function normalizePackCounts(value, ownedPackIds) {
  const raw = value && typeof value === 'object' ? value : {};
  const next = {};
  for (const packId of uniqueStrings(ownedPackIds)) {
    const count = Number(raw[packId]);
    next[packId] = Number.isInteger(count) && count > 0 ? count : 1;
  }
  return next;
}

function normalizeDecks(value) {
  const raw = Array.isArray(value) ? value : [];
  return Array.from({ length: 5 }, (_, index) => uniqueStrings(raw[index]));
}

function normalizePackPvpActivity(value, ownedPackIds) {
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

function normalizePrestige(value) {
  const p = value && typeof value === 'object' ? value : {};
  return {
    first: Math.max(0, Number(p.first || 0) | 0),
    second: Math.max(0, Number(p.second || 0) | 0),
    third: Math.max(0, Number(p.third || 0) | 0),
  };
}

function subscriptionActive(profile, nowMs = Date.now()) {
  const expiry = profile && profile.subscriptionExpiresAt;
  if (!expiry) return !!(profile && profile.subscriptionActive);
  const expiryMs = typeof expiry.toMillis === 'function' ? expiry.toMillis() : Date.parse(String(expiry));
  return Number.isFinite(expiryMs) && expiryMs > nowMs;
}

function emptyProfileV2(nowMs = Date.now()) {
  return {
    schemaVersion: 2,
    ownedPackIds: [],
    ownedPackCounts: {},
    decks: Array.from({ length: 5 }, () => []),
    activeDeckIndex: 0,
    recentQuestionIds: [],
    packLastPvpUsedAtMs: {},
    weekKey: weekKey(nowMs),
    weeklyPoints: 0,
    weeklyWins: 0,
    weeklyLosses: 0,
    weeklyDraws: 0,
    weeklySteals: 0,
    totalWins: 0,
    totalLosses: 0,
    totalDraws: 0,
    totalSteals: 0,
    prestige: { first: 0, second: 0, third: 0 },
    subscriptionActive: false,
    subscriptionExpiresAt: null,
    currentTitleKey: null,
    currentFrameKey: null,
  };
}

function normalizeProfileV2(input, nowMs = Date.now()) {
  const base = emptyProfileV2(nowMs);
  const data = input && typeof input === 'object' ? input : {};
  const active = subscriptionActive(data, nowMs);
  const ent = entitlement(active);
  const ownedPackIds = uniqueStrings(data.ownedPackIds);
  const ownedPackCounts = normalizePackCounts(data.ownedPackCounts, ownedPackIds);
  const decks = normalizeDecks(data.decks);
  let activeDeckIndex = Number.isInteger(data.activeDeckIndex) ? data.activeDeckIndex : 0;
  if (activeDeckIndex < 0 || activeDeckIndex >= ent.deckSlots) activeDeckIndex = 0;

  const normalized = {
    ...base,
    schemaVersion: 2,
    ownedPackIds,
    ownedPackCounts,
    decks,
    activeDeckIndex,
    recentQuestionIds: uniqueStrings(data.recentQuestionIds).slice(-RECENT_QUESTION_LIMIT),
    packLastPvpUsedAtMs: normalizePackPvpActivity(data.packLastPvpUsedAtMs, ownedPackIds),
    weekKey: typeof data.weekKey === 'string' ? data.weekKey : base.weekKey,
    weeklyPoints: Number(data.weeklyPoints || 0) | 0,
    weeklyWins: Math.max(0, Number(data.weeklyWins || 0) | 0),
    weeklyLosses: Math.max(0, Number(data.weeklyLosses || 0) | 0),
    weeklyDraws: Math.max(0, Number(data.weeklyDraws || 0) | 0),
    weeklySteals: Math.max(0, Number(data.weeklySteals || 0) | 0),
    totalWins: Math.max(0, Number(data.totalWins || 0) | 0),
    totalLosses: Math.max(0, Number(data.totalLosses || 0) | 0),
    totalDraws: Math.max(0, Number(data.totalDraws || 0) | 0),
    totalSteals: Math.max(0, Number(data.totalSteals || 0) | 0),
    prestige: normalizePrestige(data.prestige),
    subscriptionActive: active,
    subscriptionExpiresAt: data.subscriptionExpiresAt || null,
    currentTitleKey: typeof data.currentTitleKey === 'string' ? data.currentTitleKey : null,
    currentFrameKey: typeof data.currentFrameKey === 'string' ? data.currentFrameKey : null,
  };

  return ensureCurrentWeekV2(normalized, nowMs);
}

function ensureCurrentWeekV2(profile, nowMs = Date.now()) {
  const nextKey = weekKey(nowMs);
  if (profile.weekKey === nextKey) return profile;
  return {
    ...profile,
    weekKey: nextKey,
    weeklyPoints: 0,
    weeklyWins: 0,
    weeklyLosses: 0,
    weeklyDraws: 0,
    weeklySteals: 0,
  };
}

function applyDuelResultV2(profile, result, nowMs = Date.now()) {
  const current = ensureCurrentWeekV2(normalizeProfileV2(profile, nowMs), nowMs);
  const next = {
    ...current,
    prestige: { ...current.prestige },
    weeklyPoints: current.weeklyPoints + weeklyPointsForResult(result),
  };
  if (result === 'win') {
    next.weeklyWins += 1;
    next.totalWins += 1;
  } else if (result === 'loss') {
    next.weeklyLosses += 1;
    next.totalLosses += 1;
  } else if (result === 'draw') {
    next.weeklyDraws += 1;
    next.totalDraws += 1;
  }
  return next;
}

function canSaveDeckV2(profile, deckIndex, packIds, nowMs = Date.now()) {
  const current = normalizeProfileV2(profile, nowMs);
  const ent = entitlement(current.subscriptionActive);
  if (!Number.isInteger(deckIndex) || deckIndex < 0 || deckIndex >= ent.deckSlots) return false;
  return validateDeck(packIds, current.ownedPackIds);
}

function saveDeckV2(profile, deckIndex, packIds, nowMs = Date.now()) {
  const current = normalizeProfileV2(profile, nowMs);
  if (!canSaveDeckV2(current, deckIndex, packIds, nowMs)) {
    throw new Error('Invalid or locked V2 deck.');
  }
  const decks = current.decks.map((deck) => [...deck]);
  decks[deckIndex] = packIds.map(String);
  return { ...current, decks };
}

function applyPrestigeV2(profile, place, nowMs = Date.now()) {
  const reward = prestigeReward(place);
  if (!reward) throw new Error('Prestige place must be 1, 2, or 3.');
  const current = normalizeProfileV2(profile, nowMs);
  const prestige = { ...current.prestige };
  if (place === 1) prestige.first += 1;
  if (place === 2) prestige.second += 1;
  if (place === 3) prestige.third += 1;
  return {
    ...current,
    prestige,
    currentTitleKey: reward.title,
    currentFrameKey: reward.frame,
  };
}

function pvpUnlockedV2(profile, nowMs = Date.now()) {
  return normalizeProfileV2(profile, nowMs).ownedPackIds.length >= DECK_SIZE;
}

module.exports = {
  emptyProfileV2,
  normalizeProfileV2,
  ensureCurrentWeekV2,
  applyDuelResultV2,
  canSaveDeckV2,
  saveDeckV2,
  applyPrestigeV2,
  pvpUnlockedV2,
  subscriptionActive,
  normalizePackPvpActivity,
  normalizePackCounts,
};
