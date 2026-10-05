'use strict';

const { DECK_SIZE, validateDeck } = require('./core_engine_v2');

const MATCH_STATUS_SEARCHING = 'searching';
const MATCH_STATUS_MATCHED = 'matched';
const DUEL_STATUS_MATCHED = 'matched';
const DUEL_DURATION_MS = 3 * 60 * 1000;

function normalizePackIds(values) {
  return [...new Set((Array.isArray(values) ? values : []).map(String).map((v) => v.trim()).filter(Boolean))];
}

function activeDeckForProfile(profile) {
  const data = profile && typeof profile === 'object' ? profile : {};
  const owned = normalizePackIds(data.ownedPackIds);
  const decks = Array.isArray(data.decks) ? data.decks : [];
  const index = Number.isInteger(data.activeDeckIndex) ? data.activeDeckIndex : 0;
  const deck = Array.isArray(decks[index]) ? decks[index].map(String) : [];
  if (owned.length < DECK_SIZE) throw new Error('Player needs at least 10 owned cards for PvP.');
  if (!validateDeck(deck, owned)) throw new Error('Active deck must contain exactly 10 distinct owned cards.');
  return deck;
}

function canPairQueueEntries(a, b) {
  if (!a || !b) return false;
  if (a.status !== MATCH_STATUS_SEARCHING || b.status !== MATCH_STATUS_SEARCHING) return false;
  if (!a.uid || !b.uid || String(a.uid) === String(b.uid)) return false;
  const deckA = normalizePackIds(a.deckPackIds);
  const deckB = normalizePackIds(b.deckPackIds);
  return deckA.length === DECK_SIZE && deckB.length === DECK_SIZE;
}

function duelShell({ duelId, p1Uid, p2Uid, nowMs = Date.now() }) {
  if (!duelId || !p1Uid || !p2Uid || p1Uid === p2Uid) throw new Error('Invalid duel participants.');
  return {
    duelId: String(duelId),
    status: DUEL_STATUS_MATCHED,
    p1Uid: String(p1Uid),
    p2Uid: String(p2Uid),
    winnerUid: null,
    loserUid: null,
    result: null,
    stealConfirmed: false,
    stolenPackId: null,
    questionPlanReady: false,
    createdAtMs: Number(nowMs),
    deadlineAtMs: Number(nowMs) + DUEL_DURATION_MS,
  };
}

module.exports = {
  MATCH_STATUS_SEARCHING,
  MATCH_STATUS_MATCHED,
  DUEL_STATUS_MATCHED,
  DUEL_DURATION_MS,
  normalizePackIds,
  activeDeckForProfile,
  canPairQueueEntries,
  duelShell,
};
