'use strict';

const admin = require('firebase-admin');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { Timestamp } = admin.firestore;
const { normalizeProfileV2, applyDuelResultV2 } = require('./player_profile_v2');
const { publicDuelState, submitAnswer, finalizeDuel, validateQuestionPlan } = require('./duel_lifecycle_v2');

const db = admin.firestore();

function authUid(request) {
  const uid = request.auth && request.auth.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Authentication required.');
  return uid;
}

function profileFromUserData(data) {
  return normalizeProfileV2(data && data.profileV2 && typeof data.profileV2 === 'object' ? data.profileV2 : {});
}

function duelIdFromRequest(request) {
  const duelId = String(request.data && request.data.duelId || '').trim();
  if (!duelId) throw new HttpsError('invalid-argument', 'duelId is required.');
  return duelId;
}

function ensureParticipant(duel, uid) {
  if (!duel || (duel.p1Uid !== uid && duel.p2Uid !== uid)) {
    throw new HttpsError('permission-denied', 'Player is not part of this duel.');
  }
}

const getDuelStateV2 = onCall(async (request) => {
  const uid = authUid(request);
  const duelId = duelIdFromRequest(request);
  const snap = await db.collection('duelsV2').doc(duelId).get();
  if (!snap.exists) throw new HttpsError('not-found', 'Duel not found.');
  const duel = snap.data();
  ensureParticipant(duel, uid);
  return publicDuelState(duel, uid);
});

const startNextQuestionV2 = onCall(async (request) => {
  const uid = authUid(request);
  const duelId = duelIdFromRequest(request);
  const duelRef = db.collection('duelsV2').doc(duelId);
  const secretRef = db.collection('duelSecretsV2').doc(duelId);

  return db.runTransaction(async (tx) => {
    const duelSnap = await tx.get(duelRef);
    const secretSnap = await tx.get(secretRef);
    if (!duelSnap.exists || !secretSnap.exists) throw new HttpsError('not-found', 'Duel not found.');
    const duel = duelSnap.data();
    const secret = secretSnap.data();
    ensureParticipant(duel, uid);
    if (duel.status === 'finished') throw new HttpsError('failed-precondition', 'Duel already finished.');
    if (duel.questionPlanReady !== true) throw new HttpsError('failed-precondition', 'Question content has not been loaded yet.');

    const isP1 = uid === duel.p1Uid;
    const plan = isP1 ? secret.p1QuestionPlan : secret.p2QuestionPlan;
    if (!validateQuestionPlan(plan)) throw new HttpsError('failed-precondition', 'Invalid duel question plan.');
    const answersKey = isP1 ? 'p1Answers' : 'p2Answers';
    const startedKey = isP1 ? 'p1QuestionStartedAt' : 'p2QuestionStartedAt';
    const answers = Array.isArray(duel[answersKey]) ? duel[answersKey] : [];
    if (answers.length >= plan.length) return { complete: true, question: null, questionIndex: answers.length };

    const index = answers.length;
    const activeStart = duel[startedKey];
    const now = Timestamp.now();
    if (!activeStart) {
      tx.update(duelRef, { status: duel.status === 'matched' ? 'playing' : duel.status, [startedKey]: now, updatedAt: now });
    }

    const item = plan[index];
    return {
      complete: false,
      questionIndex: index,
      packId: String(item.packId),
      questionId: String(item.questionId),
      question: item.publicQuestion || null,
      startedAtMs: activeStart && typeof activeStart.toMillis === 'function' ? activeStart.toMillis() : now.toMillis(),
      timeoutMs: 20000,
    };
  });
});

const submitDuelAnswerV2 = onCall(async (request) => {
  const uid = authUid(request);
  const duelId = duelIdFromRequest(request);
  const questionIndex = Number(request.data && request.data.questionIndex);
  const selectedIndex = Number(request.data && request.data.selectedIndex);
  const duelRef = db.collection('duelsV2').doc(duelId);
  const secretRef = db.collection('duelSecretsV2').doc(duelId);

  return db.runTransaction(async (tx) => {
    const duelSnap = await tx.get(duelRef);
    const secretSnap = await tx.get(secretRef);
    if (!duelSnap.exists || !secretSnap.exists) throw new HttpsError('not-found', 'Duel not found.');
    const duel = duelSnap.data();
    const secret = secretSnap.data();
    ensureParticipant(duel, uid);

    const isP1 = uid === duel.p1Uid;
    const startedKey = isP1 ? 'p1QuestionStartedAt' : 'p2QuestionStartedAt';
    const startedAt = duel[startedKey];
    if (!startedAt || typeof startedAt.toMillis !== 'function') {
      throw new HttpsError('failed-precondition', 'Start the current question before answering.');
    }
    const now = Timestamp.now();
    const elapsedMs = Math.max(0, now.toMillis() - startedAt.toMillis());

    let next;
    try {
      next = submitAnswer({ duel, secret, uid, questionIndex, selectedIndex, elapsedMs });
    } catch (error) {
      throw new HttpsError('failed-precondition', error.message || 'Invalid duel answer.');
    }

    const answersKey = isP1 ? 'p1Answers' : 'p2Answers';
    const answers = next[answersKey];
    tx.update(duelRef, { status: next.status, [answersKey]: answers, [startedKey]: null, updatedAt: now });
    const last = answers[answers.length - 1];
    return { ok: true, correct: last.correct === true, elapsedMs: last.elapsedMs, answeredCount: answers.length, totalQuestions: 7 };
  });
});

const finalizeDuelV2 = onCall(async (request) => {
  const uid = authUid(request);
  const duelId = duelIdFromRequest(request);
  const duelRef = db.collection('duelsV2').doc(duelId);

  return db.runTransaction(async (tx) => {
    const duelSnap = await tx.get(duelRef);
    if (!duelSnap.exists) throw new HttpsError('not-found', 'Duel not found.');
    const duel = duelSnap.data();
    ensureParticipant(duel, uid);
    if (duel.resultApplied === true && duel.status === 'finished') return publicDuelState(duel, uid);

    let finished;
    try {
      finished = finalizeDuel(duel, Date.now());
    } catch (error) {
      throw new HttpsError('failed-precondition', error.message || 'Duel cannot be finalized yet.');
    }

    const p1Ref = db.collection('users').doc(finished.p1Uid);
    const p2Ref = db.collection('users').doc(finished.p2Uid);
    const secretRef = db.collection('duelSecretsV2').doc(duelId);
    const p1QueueRef = db.collection('matchQueueV2').doc(finished.p1Uid);
    const p2QueueRef = db.collection('matchQueueV2').doc(finished.p2Uid);
    const p1Snap = await tx.get(p1Ref);
    const p2Snap = await tx.get(p2Ref);
    const secretSnap = await tx.get(secretRef);
    if (!p1Snap.exists || !p2Snap.exists || !secretSnap.exists) throw new HttpsError('not-found', 'Duel player data is incomplete.');

    let p1Profile = profileFromUserData(p1Snap.data());
    let p2Profile = profileFromUserData(p2Snap.data());
    const now = Timestamp.now();

    if (finished.result === 'draw') {
      p1Profile = applyDuelResultV2(p1Profile, 'draw');
      p2Profile = applyDuelResultV2(p2Profile, 'draw');
      tx.update(p1Ref, { profileV2: p1Profile, activeDuelV2: null, updatedAt: now });
      tx.update(p2Ref, { profileV2: p2Profile, activeDuelV2: null, updatedAt: now });
      tx.delete(p1QueueRef);
      tx.delete(p2QueueRef);
    } else {
      const p1Won = finished.winnerUid === finished.p1Uid;
      p1Profile = applyDuelResultV2(p1Profile, p1Won ? 'win' : 'loss');
      p2Profile = applyDuelResultV2(p2Profile, p1Won ? 'loss' : 'win');
      const winnerRef = p1Won ? p1Ref : p2Ref;
      const loserRef = p1Won ? p2Ref : p1Ref;
      const loserQueueRef = p1Won ? p2QueueRef : p1QueueRef;
      tx.update(p1Ref, { profileV2: p1Profile, updatedAt: now });
      tx.update(p2Ref, { profileV2: p2Profile, updatedAt: now });
      tx.update(loserRef, { activeDuelV2: null, updatedAt: now });
      tx.update(winnerRef, { activeDuelV2: duelId, updatedAt: now });
      tx.delete(loserQueueRef);

      const secret = secretSnap.data();
      const loserDeckPackIds = p1Won ? secret.p2DeckPackIds : secret.p1DeckPackIds;
      tx.update(secretRef, { loserDeckPackIds: Array.isArray(loserDeckPackIds) ? loserDeckPackIds.map(String) : [], updatedAt: now });
    }

    const duelUpdate = {
      status: finished.status,
      result: finished.result,
      winnerUid: finished.winnerUid,
      loserUid: finished.loserUid,
      p1Score: finished.p1Score,
      p2Score: finished.p2Score,
      resultApplied: true,
      finishedAt: now,
      updatedAt: now,
    };
    tx.update(duelRef, duelUpdate);
    return publicDuelState({ ...duel, ...duelUpdate }, uid);
  });
});

module.exports = { getDuelStateV2, startNextQuestionV2, submitDuelAnswerV2, finalizeDuelV2 };
