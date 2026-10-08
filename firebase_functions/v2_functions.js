'use strict';

const admin = require('firebase-admin');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { emptyProfileV2, normalizeProfileV2, saveDeckV2 } = require('./player_profile_v2');
const { DECK_SIZE, validateDeck, weekKey } = require('./core_engine_v2');
const { applySteal, stealablePackIds } = require('./duel_engine_v2');
const { expiredPackIds } = require('./card_lifecycle_engine_v2');

const db = admin.firestore();
const { Timestamp, FieldValue } = admin.firestore;

function authUid(request) {
  const uid = request.auth && request.auth.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Authentication required.');
  return uid;
}

function userRef(uid) {
  return db.collection('users').doc(uid);
}

function profileFromUserData(data) {
  if (data && data.profileV2 && typeof data.profileV2 === 'object') return normalizeProfileV2(data.profileV2);
  return emptyProfileV2();
}

function sanitizeDecksAfterOwnershipChange(profile) {
  const next = normalizeProfileV2(profile);
  next.decks = next.decks.map((deck) => validateDeck(deck, next.ownedPackIds) ? deck : []);
  const slots = next.subscriptionActive ? 5 : 2;
  if (next.activeDeckIndex < 0 || next.activeDeckIndex >= slots) next.activeDeckIndex = 0;
  return next;
}

async function syncLifecycleForUser(uid) {
  const ref = userRef(uid);
  const initialSnap = await ref.get();
  if (!initialSnap.exists) throw new HttpsError('not-found', 'Profile not found.');
  const initialProfile = profileFromUserData(initialSnap.data());
  const candidateIds = [...initialProfile.ownedPackIds];
  if (!candidateIds.length) return initialProfile;

  const cardRefs = candidateIds.map((packId) => db.collection('cardsV2').doc(packId));
  const cardSnaps = await db.getAll(...cardRefs);
  const rarityByPackId = {};
  for (const cardSnap of cardSnaps) {
    if (!cardSnap.exists) continue;
    rarityByPackId[cardSnap.id] = String(cardSnap.data().rarity || 'epic').toLowerCase();
  }
  const checkNowMs = Date.now();
  const initiallyExpired = expiredPackIds({
    profile: initialProfile,
    rarityByPackId,
    nowMs: checkNowMs,
  });
  const needsBaseline = candidateIds.some((packId) => {
    const rarity = rarityByPackId[packId];
    const lastUsed = Number(initialProfile.packLastPvpUsedAtMs && initialProfile.packLastPvpUsedAtMs[packId]);
    return (rarity === 'gold' || rarity === 'legendary') &&
      (!Number.isFinite(lastUsed) || lastUsed <= 0);
  });
  if (!initiallyExpired.length && !needsBaseline) return initialProfile;

  return db.runTransaction(async (tx) => {
    const userSnap = await tx.get(ref);
    if (!userSnap.exists) throw new HttpsError('not-found', 'Profile not found.');
    const current = profileFromUserData(userSnap.data());
    const now = Timestamp.now();
    const nowMs = now.toMillis();
    const activity = { ...current.packLastPvpUsedAtMs };
    for (const packId of current.ownedPackIds) {
      const rarity = rarityByPackId[packId];
      const lastUsed = Number(activity[packId]);
      if ((rarity === 'gold' || rarity === 'legendary') &&
          (!Number.isFinite(lastUsed) || lastUsed <= 0)) {
        activity[packId] = nowMs;
      }
    }

    const currentWithBaselines = {
      ...current,
      packLastPvpUsedAtMs: activity,
    };
    const expired = expiredPackIds({
      profile: currentWithBaselines,
      rarityByPackId,
      nowMs,
    });

    const ownedSet = new Set(current.ownedPackIds);
    const counts = { ...current.ownedPackCounts };

    for (const packId of expired) {
      const copies = Math.max(1, Number(counts[packId] || 1) | 0);
      ownedSet.delete(packId);
      delete counts[packId];
      delete activity[packId];
      tx.update(db.collection('cardsV2').doc(packId), {
        availableCopies: FieldValue.increment(copies),
        updatedAt: now,
      });
    }

    const next = sanitizeDecksAfterOwnershipChange({
      ...current,
      ownedPackIds: [...ownedSet],
      ownedPackCounts: counts,
      packLastPvpUsedAtMs: activity,
    });
    tx.update(ref, {
      profileV2: next,
      schemaVersion: 2,
      updatedAt: now,
    });
    return next;
  });
}

const ensureProfileV2 = onCall(async (request) => {
  const uid = authUid(request);
  const ref = userRef(uid);
  const result = await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const existing = snap.exists ? snap.data() : {};
    const profile = profileFromUserData(existing);
    tx.set(ref, {
      uid,
      displayName: existing.displayName || (request.auth.token.email || '').split('@')[0] || 'PLAYER',
      email: existing.email || request.auth.token.email || null,
      profileV2: profile,
      schemaVersion: 2,
      updatedAt: Timestamp.now(),
      ...(snap.exists ? {} : { createdAt: Timestamp.now() }),
    }, { merge: true });
    return profile;
  });
  return { profile: result };
});

const getProfileV2 = onCall(async (request) => {
  const uid = authUid(request);
  const profile = await syncLifecycleForUser(uid);
  return { profile };
});

const saveDeckV2Callable = onCall(async (request) => {
  const uid = authUid(request);
  const deckIndex = Number(request.data && request.data.deckIndex);
  const packIds = Array.isArray(request.data && request.data.packIds) ? request.data.packIds.map(String) : [];
  const ref = userRef(uid);
  const profile = await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) throw new HttpsError('not-found', 'Profile not found.');
    const current = profileFromUserData(snap.data());
    let next;
    try {
      next = saveDeckV2(current, deckIndex, packIds);
    } catch (_) {
      throw new HttpsError('failed-precondition', 'Deck must contain exactly 10 distinct owned cards in an unlocked slot.');
    }
    tx.update(ref, { profileV2: next, schemaVersion: 2, updatedAt: Timestamp.now() });
    return next;
  });
  return { ok: true, profile };
});

const setActiveDeckV2 = onCall(async (request) => {
  const uid = authUid(request);
  const deckIndex = Number(request.data && request.data.deckIndex);
  const ref = userRef(uid);
  const profile = await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) throw new HttpsError('not-found', 'Profile not found.');
    const current = profileFromUserData(snap.data());
    const slots = current.subscriptionActive ? 5 : 2;
    if (!Number.isInteger(deckIndex) || deckIndex < 0 || deckIndex >= slots) {
      throw new HttpsError('permission-denied', 'Deck slot is locked or invalid.');
    }
    if (!validateDeck(current.decks[deckIndex], current.ownedPackIds)) {
      throw new HttpsError('failed-precondition', 'Active deck must contain exactly 10 distinct owned cards.');
    }
    const next = { ...current, activeDeckIndex: deckIndex };
    tx.update(ref, { profileV2: next, schemaVersion: 2, updatedAt: Timestamp.now() });
    return next;
  });
  return { ok: true, profile };
});

const getWeeklyRankingV2 = onCall(async (request) => {
  authUid(request);
  const key = weekKey();
  const snap = await db.collection('users')
    .where('profileV2.weekKey', '==', key)
    .orderBy('profileV2.weeklyPoints', 'desc')
    .orderBy('profileV2.weeklyWins', 'desc')
    .orderBy('uid', 'asc')
    .limit(100)
    .get();
  return {
    weekKey: key,
    players: snap.docs.map((doc, index) => {
      const data = doc.data();
      const profile = profileFromUserData(data);
      return {
        rank: index + 1,
        uid: data.uid || doc.id,
        displayName: data.displayName || 'PLAYER',
        weeklyPoints: profile.weeklyPoints,
        weeklyWins: profile.weeklyWins,
        weeklyLosses: profile.weeklyLosses,
        weeklyDraws: profile.weeklyDraws,
        currentTitleKey: profile.currentTitleKey,
        currentFrameKey: profile.currentFrameKey,
      };
    }),
  };
});

const getStealOptionsV2 = onCall(async (request) => {
  const uid = authUid(request);
  const duelId = String(request.data && request.data.duelId || '').trim();
  if (!duelId) throw new HttpsError('invalid-argument', 'duelId is required.');
  const duelRef = db.collection('duelsV2').doc(duelId);
  const secretRef = db.collection('duelSecretsV2').doc(duelId);
  const [duelSnap, secretSnap, winnerSnap] = await Promise.all([duelRef.get(), secretRef.get(), userRef(uid).get()]);
  if (!duelSnap.exists || !secretSnap.exists) throw new HttpsError('not-found', 'Duel not found.');
  if (!winnerSnap.exists) throw new HttpsError('not-found', 'Winner profile not found.');
  const duel = duelSnap.data();
  if (duel.status !== 'finished' || duel.result === 'draw' || duel.winnerUid !== uid) {
    throw new HttpsError('permission-denied', 'Only the finished duel winner can select a card.');
  }
  if (duel.stealConfirmed === true) return { packIds: [], alreadyConfirmed: true };
  const secret = secretSnap.data();
  const opponentDeckPackIds = Array.isArray(secret.loserDeckPackIds) ? secret.loserDeckPackIds.map(String) : [];
  const winnerProfile = profileFromUserData(winnerSnap.data());
  let packIds;
  try {
    packIds = stealablePackIds(opponentDeckPackIds);
  } catch (_) {
    throw new HttpsError('failed-precondition', 'Opponent duel deck is invalid.');
  }
  return { packIds, alreadyConfirmed: false };
});

const confirmStealV2 = onCall(async (request) => {
  const uid = authUid(request);
  const duelId = String(request.data && request.data.duelId || '').trim();
  const packId = String(request.data && request.data.packId || '').trim();
  if (!duelId || !packId) throw new HttpsError('invalid-argument', 'duelId and packId are required.');
  const duelRef = db.collection('duelsV2').doc(duelId);
  const secretRef = db.collection('duelSecretsV2').doc(duelId);

  return db.runTransaction(async (tx) => {
    const duelSnap = await tx.get(duelRef);
    const secretSnap = await tx.get(secretRef);
    if (!duelSnap.exists || !secretSnap.exists) throw new HttpsError('not-found', 'Duel not found.');
    const duel = duelSnap.data();
    if (duel.status !== 'finished' || duel.result === 'draw' || duel.winnerUid !== uid) {
      throw new HttpsError('permission-denied', 'Only the finished duel winner can transfer a card.');
    }
    if (duel.stealConfirmed === true) return { ok: true, alreadyConfirmed: true, packId: duel.stolenPackId || null };

    const loserUid = String(duel.loserUid || '');
    if (!loserUid || loserUid === uid) throw new HttpsError('failed-precondition', 'Invalid duel loser.');
    const winnerRef = userRef(uid);
    const loserRef = userRef(loserUid);
    const winnerSnap = await tx.get(winnerRef);
    const loserSnap = await tx.get(loserRef);
    if (!winnerSnap.exists || !loserSnap.exists) throw new HttpsError('not-found', 'Player profile not found.');

    const winner = profileFromUserData(winnerSnap.data());
    const loser = profileFromUserData(loserSnap.data());
    const secret = secretSnap.data();
    const opponentDeckPackIds = Array.isArray(secret.loserDeckPackIds) ? secret.loserDeckPackIds.map(String) : [];
    let transfer;
    try {
      transfer = applySteal({
        packId,
        winnerOwnedPackIds: winner.ownedPackIds,
        loserOwnedPackIds: loser.ownedPackIds,
        opponentDeckPackIds,
        winnerOwnedPackCounts: winner.ownedPackCounts,
        loserOwnedPackCounts: loser.ownedPackCounts,
      });
    } catch (_) {
      throw new HttpsError('failed-precondition', 'Selected card is not eligible for transfer.');
    }

    const nextWinner = sanitizeDecksAfterOwnershipChange({
      ...winner,
      ownedPackIds: transfer.winnerOwnedPackIds,
      ownedPackCounts: transfer.winnerOwnedPackCounts,
      packLastPvpUsedAtMs: {
        ...winner.packLastPvpUsedAtMs,
        [packId]: Timestamp.now().toMillis(),
      },
    });
    const nextLoser = sanitizeDecksAfterOwnershipChange({
      ...loser,
      ownedPackIds: transfer.loserOwnedPackIds,
      ownedPackCounts: transfer.loserOwnedPackCounts,
    });
    const now = Timestamp.now();
    tx.update(winnerRef, { profileV2: nextWinner, activeDuelV2: null, schemaVersion: 2, updatedAt: now });
    tx.update(loserRef, { profileV2: nextLoser, activeDuelV2: null, schemaVersion: 2, updatedAt: now });
    tx.update(duelRef, { stealConfirmed: true, stolenPackId: packId, stealConfirmedAt: now, updatedAt: now });
    tx.delete(db.collection('matchQueueV2').doc(uid));
    tx.delete(db.collection('matchQueueV2').doc(loserUid));

    return {
      ok: true,
      alreadyConfirmed: false,
      packId,
      loserPvpUnlocked: transfer.loserPvpUnlocked,
      winnerProfile: nextWinner,
      loserOwnedCount: nextLoser.ownedPackIds.length,
      pvpMinimumCollection: DECK_SIZE,
    };
  });
});

module.exports = {
  ensureProfileV2,
  getProfileV2,
  saveDeckV2: saveDeckV2Callable,
  setActiveDeckV2,
  getWeeklyRankingV2,
  getStealOptionsV2,
  confirmStealV2,
};
