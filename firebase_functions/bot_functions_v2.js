'use strict';

const crypto = require('crypto');
const admin = require('firebase-admin');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { normalizeProfileV2 } = require('./player_profile_v2');
const {
  normalizeRecent,
  recordRecent,
  entitlement,
  sampleUnique,
} = require('./core_engine_v2');
const {
  validateQuestionDocument,
  localizedQuestion,
} = require('./content_contract_v2');
const {
  botUnlocked,
  chooseRewardPack,
  resolveBotAnswer,
  awardPack,
} = require('./bot_engine_v2');

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
  return snap.docs
    .filter((doc) => Number(doc.data().questionCount || 0) > 0)
    .map((doc) => doc.id);
}

function chooseQuestionDoc(usableDocs, recentIds) {
  const recent = normalizeRecent(recentIds);
  const recentSet = new Set(recent);
  const fresh = usableDocs.filter((doc) => !recentSet.has(doc.id));
  if (fresh.length) return fresh[crypto.randomInt(fresh.length)];
  for (const id of recent) {
    const found = usableDocs.find((doc) => doc.id === id);
    if (found) return found;
  }
  return usableDocs[crypto.randomInt(usableDocs.length)];
}

function shuffle(values) {
  const copy = [...values];
  for (let i = copy.length - 1; i > 0; i -= 1) {
    const j = crypto.randomInt(i + 1);
    [copy[i], copy[j]] = [copy[j], copy[i]];
  }
  return copy;
}

async function loadQuestionForCard(cardId, recentIds, language, answerChoiceCount) {
  const snap = await db.collection('cardsV2').doc(cardId).collection('questions')
    .where('enabled', '==', true)
    .limit(100)
    .get();
  if (snap.empty) return null;

  const usable = snap.docs.filter((doc) => {
    try {
      return validateQuestionDocument(doc.id, cardId, doc.data());
    } catch (_) {
      return false;
    }
  });
  if (!usable.length) return null;

  const chosen = chooseQuestionDoc(usable, recentIds);
  const localized = localizedQuestion(chosen.data(), language);
  const wrongs = sampleUnique(localized.wrongAnswers, answerChoiceCount - 1);
  if (!wrongs) return null;
  const choices = shuffle([localized.correct, ...wrongs]);

  return {
    questionId: chosen.id,
    prompt: localized.prompt,
    choices,
    correctIndex: choices.indexOf(localized.correct),
  };
}

function publicRound(round) {
  return {
    roundId: String(round.roundId),
    cardId: String(round.cardId),
    questionId: String(round.questionId),
    prompt: round.prompt || null,
    choices: Array.isArray(round.choices) ? round.choices.map(String) : [],
    timeoutMs: 20000,
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
  const language = request.data && request.data.language === 'en' ? 'en' : 'ar';
  const userRef = db.collection('users').doc(uid);
  const firstUserSnap = await userRef.get();
  if (!firstUserSnap.exists) throw new HttpsError('not-found', 'Profile not found.');
  const firstData = firstUserSnap.data();

  if (firstData.activeBotRoundV2) {
    const existingSnap = await db.collection('botRoundsV2').doc(String(firstData.activeBotRoundV2)).get();
    if (existingSnap.exists && existingSnap.data().status === 'active') {
      return publicRound(existingSnap.data());
    }
  }

  const profile = profileFromData(firstData);
  if (!botUnlocked(profile.ownedPackIds)) {
    throw new HttpsError('failed-precondition', 'Bot onboarding is complete after 10 owned cards.');
  }

  const enabledCardIds = await loadEnabledCardIds();
  const remaining = enabledCardIds.filter((id) => !profile.ownedPackIds.includes(id));
  if (!remaining.length) throw new HttpsError('failed-precondition', 'CONTENT_NOT_AVAILABLE');

  const answerChoiceCount = entitlement(profile.subscriptionActive).answerChoices;
  const attempted = new Set();
  let cardId = null;
  let question = null;
  while (attempted.size < remaining.length) {
    const candidates = remaining.filter((id) => !attempted.has(id));
    const chosen = chooseRewardPack(candidates, profile.ownedPackIds);
    if (!chosen) break;
    attempted.add(chosen);
    const q = await loadQuestionForCard(
      chosen,
      profile.recentQuestionIds,
      language,
      answerChoiceCount,
    );
    if (q) {
      cardId = chosen;
      question = q;
      break;
    }
  }
  if (!cardId || !question) throw new HttpsError('failed-precondition', 'CONTENT_NOT_AVAILABLE');

  const roundRef = db.collection('botRoundsV2').doc();
  const now = Timestamp.now();
  const roundData = {
    roundId: roundRef.id,
    uid,
    status: 'active',
    cardId,
    questionId: question.questionId,
    language,
    prompt: question.prompt,
    choices: question.choices,
    correctIndex: question.correctIndex,
    startedAt: now,
    resolvedAt: null,
    awarded: false,
  };

  return db.runTransaction(async (tx) => {
    const currentSnap = await tx.get(userRef);
    if (!currentSnap.exists) throw new HttpsError('not-found', 'Profile not found.');
    const currentData = currentSnap.data();
    if (currentData.activeBotRoundV2) {
      const existingRef = db.collection('botRoundsV2').doc(String(currentData.activeBotRoundV2));
      const existingSnap = await tx.get(existingRef);
      if (existingSnap.exists && existingSnap.data().status === 'active') {
        return publicRound(existingSnap.data());
      }
    }
    const currentProfile = profileFromData(currentData);
    if (!botUnlocked(currentProfile.ownedPackIds) || currentProfile.ownedPackIds.includes(cardId)) {
      throw new HttpsError('aborted', 'Bot eligibility changed. Start again.');
    }
    const nextProfile = {
      ...currentProfile,
      recentQuestionIds: recordRecent(currentProfile.recentQuestionIds, question.questionId),
    };
    tx.create(roundRef, roundData);
    tx.update(userRef, {
      profileV2: nextProfile,
      activeBotRoundV2: roundRef.id,
      updatedAt: now,
    });
    return publicRound(roundData);
  });
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
    let profile = profileFromData(userSnap.data());

    if (round.status === 'resolved') {
      if (userSnap.data().activeBotRoundV2 === roundId) {
        tx.update(userRef, { activeBotRoundV2: null, updatedAt: Timestamp.now() });
      }
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

    if (userSnap.data().activeBotRoundV2 !== roundId) {
      throw new HttpsError('failed-precondition', 'This is not the active bot round.');
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

    let awarded = false;
    if (result.correct) {
      const reward = awardPack(profile.ownedPackIds, round.cardId);
      awarded = reward.awarded;
      profile = { ...profile, ownedPackIds: reward.ownedPackIds };
    }

    tx.update(userRef, {
      profileV2: profile,
      schemaVersion: 2,
      activeBotRoundV2: null,
      updatedAt: now,
    });
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
