'use strict';

const admin = require('firebase-admin');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { normalizeProfileV2 } = require('./player_profile_v2');
const { botUnlocked, chooseRewardPack, resolveBotAnswer, awardPack } = require('./bot_engine_v2');

const db = admin.firestore();
const { Timestamp } = admin.firestore;

function authUid(request) {
  const uid = request.auth && request.auth.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Authentication required.');
  return uid;
}

function profileFromData(data) {
  return normalizeProfileV2(data && data.profileV2 && typeof data.profileV2 === 'object' ? data.profileV2 : {});
}

async function loadEnabledCardIds() {
  const snap = await db.collection('cardsV2').where('enabled', '==', true).limit(500).get();
  return snap.docs.map((doc) => doc.id);
}

async function loadQuestionForCard(cardId) {
  const snap = await db.collection('cardsV2').doc(cardId).collection('questions')
    .where('enabled', '==', true)
    .limit(50)
    .get();
  if (snap.empty) return null;
  const usable = snap.docs.filter((doc) => {
    const data = doc.data();
    return Array.isArray(data.choices) && data.choices.length >= 2 && Number.isInteger(data.correctIndex);
  });
  if (!usable.length) return null;
  const chosen = usable[Math.floor(Math.random() * usable.length)];
  const data = chosen.data();
  return {
    questionId: chosen.id,
    prompt: data.prompt || null,
    choices: data.choices.map(String),
    correctIndex: Number(data.correctIndex),
  };
}

const getBotStatusV2 = onCall(async (request) => {
  const uid = authUid(request);
  const userSnap = await db.collection('users').doc(uid).get();
  if (!userSnap.exists) throw new HttpsError('not-found', 'Profile not found.');
  const profile = profileFromData(userSnap.data());
  const enabledCardIds = await loadEnabledCardIds();
  const unowned = enabledCardIds.filter((id) => !profile.ownedPackIds.includes(id));
  return {
    botUnlocked: botUnlocked(profile.ownedPackIds),
    ownedCount: profile.ownedPackIds.length,
    targetCount: 10,
    contentAvailable: unowned.length > 0,
  };
});

const startBotRoundV2 = onCall(async (request) => {
  const uid = authUid(request);
  const userRef = db.collection('users').doc(uid);
  const userSnap = await userRef.get();
  if (!userSnap.exists) throw new HttpsError('not-found', 'Profile not found.');
  const profile = profileFromData(userSnap.data());
  if (!botUnlocked(profile.ownedPackIds)) {
    throw new HttpsError('failed-precondition', 'Bot onboarding is complete after 10 owned cards.');
  }

  const enabledCardIds = await loadEnabledCardIds();
  const remaining = enabledCardIds.filter((id) => !profile.ownedPackIds.includes(id));
  if (!remaining.length) {
    throw new HttpsError('failed-precondition', 'CONTENT_NOT_AVAILABLE');
  }

  const attempted = new Set();
  let cardId = null;
  let question = null;
  while (attempted.size < remaining.length) {
    const candidates = remaining.filter((id) => !attempted.has(id));
    const chosen = chooseRewardPack(candidates, profile.ownedPackIds);
    if (!chosen) break;
    attempted.add(chosen);
    const q = await loadQuestionForCard(chosen);
    if (q) {
      cardId = chosen;
      question = q;
      break;
    }
  }

  if (!cardId || !question) {
    throw new HttpsError('failed-precondition', 'CONTENT_NOT_AVAILABLE');
  }

  const roundRef = db.collection('botRoundsV2').doc();
  const now = Timestamp.now();
  await roundRef.set({
    roundId: roundRef.id,
    uid,
    status: 'active',
    cardId,
    questionId: question.questionId,
    correctIndex: question.correctIndex,
    startedAt: now,
    resolvedAt: null,
    awarded: false,
  });

  return {
    roundId: roundRef.id,
    cardId,
    questionId: question.questionId,
    prompt: question.prompt,
    choices: question.choices,
    timeoutMs: 20000,
  };
});

const submitBotAnswerV2 = onCall(async (request) => {
  const uid = authUid(request);
  const roundId = String(request.data && request.data.roundId || '').trim();
  const selectedIndex = Number(request.data && request.data.selectedIndex);
  if (!roundId) throw new HttpsError('invalid-argument', 'roundId is required.');

  const roundRef = db.collection('botRoundsV2').doc(roundId);
  const userRef = db.collection('users').doc(uid);

  return db.runTransaction(async (tx) => {
    const roundSnap = await tx.get(roundRef);
    const userSnap = await tx.get(userRef);
    if (!roundSnap.exists || !userSnap.exists) throw new HttpsError('not-found', 'Bot round or profile not found.');
    const round = roundSnap.data();
    if (round.uid !== uid) throw new HttpsError('permission-denied', 'This bot round belongs to another player.');
    if (round.status === 'resolved') {
      const profile = profileFromData(userSnap.data());
      return {
        ok: true,
        alreadyResolved: true,
        correct: round.correct === true,
        awarded: round.awarded === true,
        awardedCardId: round.awarded === true ? String(round.cardId) : null,
        botUnlocked: botUnlocked(profile.ownedPackIds),
        profile,
      };
    }

    const startedAt = round.startedAt;
    if (!startedAt || typeof startedAt.toMillis !== 'function') {
      throw new HttpsError('failed-precondition', 'Invalid bot round start time.');
    }
    const now = Timestamp.now();
    const result = resolveBotAnswer({
      correctIndex: Number(round.correctIndex),
      selectedIndex,
      elapsedMs: now.toMillis() - startedAt.toMillis(),
    });

    let profile = profileFromData(userSnap.data());
    let awarded = false;
    if (result.correct) {
      const reward = awardPack(profile.ownedPackIds, round.cardId);
      awarded = reward.awarded;
      profile = { ...profile, ownedPackIds: reward.ownedPackIds };
      tx.update(userRef, {
        profileV2: profile,
        schemaVersion: 2,
        updatedAt: now,
      });
    }

    tx.update(roundRef, {
      status: 'resolved',
      correct: result.correct,
      timedOut: result.timedOut,
      elapsedMs: result.elapsedMs,
      awarded,
      resolvedAt: now,
    });

    return {
      ok: true,
      alreadyResolved: false,
      correct: result.correct,
      awarded,
      awardedCardId: awarded ? String(round.cardId) : null,
      botUnlocked: botUnlocked(profile.ownedPackIds),
      profile,
    };
  });
});

module.exports = {
  getBotStatusV2,
  startBotRoundV2,
  submitBotAnswerV2,
};
