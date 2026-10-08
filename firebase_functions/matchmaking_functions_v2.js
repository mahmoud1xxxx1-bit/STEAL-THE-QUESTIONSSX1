'use strict';

const admin = require('firebase-admin');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { normalizeProfileV2 } = require('./player_profile_v2');
const { validateDeck } = require('./core_engine_v2');
const { markPvpDeckActivity } = require('./card_lifecycle_engine_v2');
const {
  MATCH_STATUS_SEARCHING,
  MATCH_STATUS_MATCHED,
  canPairQueueEntries,
  activeDeckForProfile,
} = require('./matchmaking_engine_v2');

const db = admin.firestore();
const { Timestamp } = admin.firestore;
const DUEL_DURATION_MS = 3 * 60 * 1000;

function authUid(request) {
  const uid = request.auth && request.auth.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Authentication required.');
  return uid;
}

function profileFromUserData(data) {
  return normalizeProfileV2(data && data.profileV2 && typeof data.profileV2 === 'object' ? data.profileV2 : {});
}

async function ensureSearchingEntry(uid) {
  const userRef = db.collection('users').doc(uid);
  const queueRef = db.collection('matchQueueV2').doc(uid);
  return db.runTransaction(async (tx) => {
    const userSnap = await tx.get(userRef);
    const queueSnap = await tx.get(queueRef);
    if (!userSnap.exists) throw new HttpsError('not-found', 'Profile not found.');
    const userData = userSnap.data();
    if (userData.activeDuelV2) {
      return { status: MATCH_STATUS_MATCHED, duelId: String(userData.activeDuelV2) };
    }
    if (queueSnap.exists) {
      const q = queueSnap.data();
      if (q.status === MATCH_STATUS_MATCHED && q.duelId) {
        return { status: MATCH_STATUS_MATCHED, duelId: String(q.duelId) };
      }
    }
    const profile = profileFromUserData(userData);
    let deckPackIds;
    try {
      deckPackIds = activeDeckForProfile(profile);
    } catch (_) {
      throw new HttpsError('failed-precondition', 'A valid active 10-card deck is required for PvP.');
    }
    tx.set(queueRef, {
      uid,
      status: MATCH_STATUS_SEARCHING,
      duelId: null,
      deckPackIds,
      createdAt: queueSnap.exists && queueSnap.data().createdAt ? queueSnap.data().createdAt : Timestamp.now(),
      updatedAt: Timestamp.now(),
    }, { merge: true });
    return { status: MATCH_STATUS_SEARCHING, duelId: null };
  });
}

const findOrCreateDuelV2 = onCall(async (request) => {
  const uid = authUid(request);
  const entry = await ensureSearchingEntry(uid);
  if (entry.status === MATCH_STATUS_MATCHED) return entry;

  const candidates = await db.collection('matchQueueV2')
    .where('status', '==', MATCH_STATUS_SEARCHING)
    .orderBy('createdAt', 'asc')
    .limit(10)
    .get();

  for (const candidateDoc of candidates.docs) {
    if (candidateDoc.id === uid) continue;
    const candidateUid = candidateDoc.id;
    const ownQueueRef = db.collection('matchQueueV2').doc(uid);
    const candidateQueueRef = db.collection('matchQueueV2').doc(candidateUid);
    const ownUserRef = db.collection('users').doc(uid);
    const candidateUserRef = db.collection('users').doc(candidateUid);
    const duelRef = db.collection('duelsV2').doc();
    const secretRef = db.collection('duelSecretsV2').doc(duelRef.id);

    const matched = await db.runTransaction(async (tx) => {
      const ownQueueSnap = await tx.get(ownQueueRef);
      const candidateQueueSnap = await tx.get(candidateQueueRef);
      const ownUserSnap = await tx.get(ownUserRef);
      const candidateUserSnap = await tx.get(candidateUserRef);
      if (!ownQueueSnap.exists || !candidateQueueSnap.exists || !ownUserSnap.exists || !candidateUserSnap.exists) return null;

      const ownQueue = ownQueueSnap.data();
      const candidateQueue = candidateQueueSnap.data();
      if (ownQueue.status === MATCH_STATUS_MATCHED && ownQueue.duelId) {
        return { status: MATCH_STATUS_MATCHED, duelId: String(ownQueue.duelId) };
      }
      if (!canPairQueueEntries(ownQueue, candidateQueue)) return null;
      const ownUser = ownUserSnap.data();
      const candidateUser = candidateUserSnap.data();
      if (ownUser.activeDuelV2 || candidateUser.activeDuelV2) return null;
      const ownProfile = profileFromUserData(ownUser);
      const candidateProfile = profileFromUserData(candidateUser);
      if (!validateDeck(ownQueue.deckPackIds, ownProfile.ownedPackIds) || !validateDeck(candidateQueue.deckPackIds, candidateProfile.ownedPackIds)) return null;

      const now = Timestamp.now();
      const nowMs = now.toMillis();
      let ownProfileWithActivity;
      let candidateProfileWithActivity;
      try {
        ownProfileWithActivity = markPvpDeckActivity(
          ownProfile,
          ownQueue.deckPackIds,
          nowMs,
        );
        candidateProfileWithActivity = markPvpDeckActivity(
          candidateProfile,
          candidateQueue.deckPackIds,
          nowMs,
        );
      } catch (_) {
        return null;
      }
      const deadlineAt = Timestamp.fromMillis(nowMs + DUEL_DURATION_MS);
      tx.create(duelRef, {
        duelId: duelRef.id,
        status: 'matched',
        p1Uid: uid,
        p2Uid: candidateUid,
        winnerUid: null,
        loserUid: null,
        result: null,
        stealConfirmed: false,
        stolenPackId: null,
        questionPlanReady: false,
        createdAt: now,
        deadlineAt,
      });
      tx.create(secretRef, {
        duelId: duelRef.id,
        p1DeckPackIds: ownQueue.deckPackIds.map(String),
        p2DeckPackIds: candidateQueue.deckPackIds.map(String),
        p1Prepared: false,
        p2Prepared: false,
        p1ChallengeSelections: [],
        p2ChallengeSelections: [],
        createdAt: now,
      });
      tx.update(ownQueueRef, { status: MATCH_STATUS_MATCHED, duelId: duelRef.id, updatedAt: now });
      tx.update(candidateQueueRef, { status: MATCH_STATUS_MATCHED, duelId: duelRef.id, updatedAt: now });
      tx.update(ownUserRef, {
        profileV2: ownProfileWithActivity,
        activeDuelV2: duelRef.id,
        updatedAt: now,
      });
      tx.update(candidateUserRef, {
        profileV2: candidateProfileWithActivity,
        activeDuelV2: duelRef.id,
        updatedAt: now,
      });
      return { status: MATCH_STATUS_MATCHED, duelId: duelRef.id };
    });

    if (matched) return matched;
  }

  return { status: MATCH_STATUS_SEARCHING, duelId: null };
});

const getMatchStatusV2 = onCall(async (request) => {
  const uid = authUid(request);
  const userSnap = await db.collection('users').doc(uid).get();
  const queueSnap = await db.collection('matchQueueV2').doc(uid).get();
  if (!userSnap.exists) throw new HttpsError('not-found', 'Profile not found.');
  const activeDuel = userSnap.data().activeDuelV2;
  if (activeDuel) return { status: MATCH_STATUS_MATCHED, duelId: String(activeDuel) };
  if (!queueSnap.exists) return { status: 'idle', duelId: null };
  const q = queueSnap.data();
  return { status: String(q.status || 'idle'), duelId: q.duelId ? String(q.duelId) : null };
});

const cancelMatchmakingV2 = onCall(async (request) => {
  const uid = authUid(request);
  const queueRef = db.collection('matchQueueV2').doc(uid);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(queueRef);
    if (!snap.exists) return;
    const q = snap.data();
    if (q.status === MATCH_STATUS_MATCHED) {
      throw new HttpsError('failed-precondition', 'A matched duel cannot be cancelled from the queue.');
    }
    tx.delete(queueRef);
  });
  return { ok: true };
});

module.exports = {
  findOrCreateDuelV2,
  getMatchStatusV2,
  cancelMatchmakingV2,
};
