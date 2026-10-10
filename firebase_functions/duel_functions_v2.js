'use strict';

const admin = require('firebase-admin');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { Timestamp } = admin.firestore;
const { normalizeProfileV2, applyDuelResultV2 } = require('./player_profile_v2');
const { entitlement } = require('./core_engine_v2');
const { validateQuestionDocument, localizedQuestion } = require('./content_contract_v2');
const { publicDuelState, submitAnswer, finalizeDuel, validateQuestionPlan } = require('./duel_lifecycle_v2');
const {
  buildPlanItem,
  nextRecent,
} = require('./duel_question_plan_v2');
const {
  buildPrepOptions,
  validatePrepSelections,
  enoughSelectableCards,
} = require('./duel_preparation_engine_v2');

const db = admin.firestore();

function authUid(request) {
  const uid = request.auth && request.auth.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Authentication required.');
  return uid;
}

async function ensureNotSuspended(uid) {
  const snap = await db.collection('users').doc(uid).get();
  if (!snap.exists) throw new HttpsError('not-found', 'Profile not found.');
  if (snap.data().suspendedV2 === true) {
    throw new HttpsError('permission-denied', 'ACCOUNT_SUSPENDED');
  }
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

function languageFromRequest(request) {
  return request.data && request.data.language === 'en' ? 'en' : 'ar';
}

function choiceDocId(cardId, questionId, language) {
  return `${cardId}--${questionId}--${language}`;
}

async function loadQuestionEntries(cardId, language) {
  const snap = await db.collection('cardsV2').doc(cardId).collection('questions')
    .where('enabled', '==', true)
    .limit(100)
    .get();
  const result = [];
  for (const doc of snap.docs) {
    try {
      validateQuestionDocument(doc.id, cardId, doc.data());
      const localized = localizedQuestion(doc.data(), language);
      result.push({
        id: doc.id,
        prompt: localized.prompt,
        correct: localized.correct,
        wrongAnswers: localized.wrongAnswers,
      });
    } catch (_) {
      // Invalid/disabled content is deliberately excluded from live duel plans.
    }
  }
  return result;
}

async function loadCustomChoices(ownerUid, cardId, questionId, language, limit) {
  const snap = await db.collection('users').doc(ownerUid).collection('customChoicesV2')
    .doc(choiceDocId(cardId, questionId, language))
    .get();
  if (!snap.exists || !Array.isArray(snap.data().choices)) return [];
  return snap.data().choices.map(String).slice(0, Math.max(0, limit));
}


async function loadPrepOptions({ deckPackIds, playerProfile, opponentProfile, language }) {
  const entriesByPack = {};
  for (const packId of deckPackIds) {
    entriesByPack[String(packId)] = await loadQuestionEntries(String(packId), language);
  }
  return {
    entriesByPack,
    options: buildPrepOptions({
      deckPackIds,
      entriesByPack,
      playerRecent: playerProfile.recentQuestionIds,
      opponentRecent: opponentProfile.recentQuestionIds,
    }),
  };
}

async function buildPlanFromSelections({
  selections,
  answeringProfile,
  attackerUid,
  language,
}) {
  const answerChoiceCount = entitlement(answeringProfile.subscriptionActive).answerChoices;
  const wrongChoiceCount = answerChoiceCount - 1;
  const plan = [];
  let recentQuestionIds = Array.isArray(answeringProfile.recentQuestionIds)
    ? [...answeringProfile.recentQuestionIds]
    : [];

  for (const selection of selections) {
    const packId = String(selection.packId);
    const questionId = String(selection.questionId);
    const entries = await loadQuestionEntries(packId, language);
    const question = entries.find((entry) => String(entry.id) === questionId);
    if (!question) throw new HttpsError('failed-precondition', 'SELECTED_QUESTION_NOT_AVAILABLE');
    const customWrongChoices = await loadCustomChoices(
      attackerUid,
      packId,
      questionId,
      language,
      wrongChoiceCount,
    );
    const item = buildPlanItem({
      packId,
      question,
      customWrongChoices,
      answerChoiceCount,
    });
    plan.push(item);
    recentQuestionIds = nextRecent(recentQuestionIds, questionId);
  }

  if (!validateQuestionPlan(plan)) {
    throw new HttpsError('failed-precondition', 'Invalid selected duel question plan.');
  }
  return { plan, recentQuestionIds };
}


const getDuelPreparationV2 = onCall(async (request) => {
  const uid = authUid(request);
  await ensureNotSuspended(uid);
  const duelId = duelIdFromRequest(request);
  const language = languageFromRequest(request);
  const duelRef = db.collection('duelsV2').doc(duelId);
  const secretRef = db.collection('duelSecretsV2').doc(duelId);
  const [duelSnap, secretSnap] = await Promise.all([duelRef.get(), secretRef.get()]);
  if (!duelSnap.exists || !secretSnap.exists) throw new HttpsError('not-found', 'Duel not found.');

  const duel = duelSnap.data();
  const secret = secretSnap.data();
  ensureParticipant(duel, uid);
  const isP1 = uid === duel.p1Uid;
  const ownUid = uid;
  const opponentUid = isP1 ? duel.p2Uid : duel.p1Uid;
  const ownDeck = isP1 ? secret.p1DeckPackIds : secret.p2DeckPackIds;
  const [ownSnap, opponentSnap] = await Promise.all([
    db.collection('users').doc(ownUid).get(),
    db.collection('users').doc(opponentUid).get(),
  ]);
  if (!ownSnap.exists || !opponentSnap.exists) throw new HttpsError('not-found', 'Player data not found.');

  const ownProfile = profileFromUserData(ownSnap.data());
  const opponentProfile = profileFromUserData(opponentSnap.data());
  const prep = await loadPrepOptions({
    deckPackIds: ownDeck,
    playerProfile: ownProfile,
    opponentProfile,
    language,
  });

  return {
    duelId,
    requiredSelections: 7,
    cards: prep.options,
    canSubmit: enoughSelectableCards(prep.options),
    prepared: isP1 ? secret.p1Prepared === true : secret.p2Prepared === true,
    opponentPrepared: isP1 ? secret.p2Prepared === true : secret.p1Prepared === true,
    questionPlanReady: duel.questionPlanReady === true,
  };
});

const submitDuelPreparationV2 = onCall(async (request) => {
  const uid = authUid(request);
  await ensureNotSuspended(uid);
  const duelId = duelIdFromRequest(request);
  const language = languageFromRequest(request);
  const rawSelections = Array.isArray(request.data && request.data.selections)
    ? request.data.selections
    : [];
  const selections = rawSelections.map((item) => ({
    packId: String(item && item.packId || '').trim(),
    questionId: String(item && item.questionId || '').trim(),
  }));

  const duelRef = db.collection('duelsV2').doc(duelId);
  const secretRef = db.collection('duelSecretsV2').doc(duelId);
  const [duelSnap, secretSnap] = await Promise.all([duelRef.get(), secretRef.get()]);
  if (!duelSnap.exists || !secretSnap.exists) throw new HttpsError('not-found', 'Duel not found.');
  const duel = duelSnap.data();
  const secret = secretSnap.data();
  ensureParticipant(duel, uid);
  if (duel.status === 'finished') throw new HttpsError('failed-precondition', 'Duel already finished.');

  const isP1 = uid === duel.p1Uid;
  const opponentUid = isP1 ? duel.p2Uid : duel.p1Uid;
  const ownDeck = isP1 ? secret.p1DeckPackIds : secret.p2DeckPackIds;
  const [ownSnap, opponentSnap] = await Promise.all([
    db.collection('users').doc(uid).get(),
    db.collection('users').doc(opponentUid).get(),
  ]);
  if (!ownSnap.exists || !opponentSnap.exists) throw new HttpsError('not-found', 'Player data not found.');

  const ownProfile = profileFromUserData(ownSnap.data());
  const opponentProfile = profileFromUserData(opponentSnap.data());
  const prep = await loadPrepOptions({
    deckPackIds: ownDeck,
    playerProfile: ownProfile,
    opponentProfile,
    language,
  });
  if (!enoughSelectableCards(prep.options)) {
    throw new HttpsError('failed-precondition', 'NOT_ENOUGH_FRESH_QUESTIONS');
  }
  try {
    validatePrepSelections({
      selections,
      deckPackIds: ownDeck,
      options: prep.options,
    });
  } catch (error) {
    throw new HttpsError('failed-precondition', error.message || 'Invalid preparation selection.');
  }

  return db.runTransaction(async (tx) => {
    const currentDuelSnap = await tx.get(duelRef);
    const currentSecretSnap = await tx.get(secretRef);
    if (!currentDuelSnap.exists || !currentSecretSnap.exists) {
      throw new HttpsError('not-found', 'Duel not found.');
    }
    const currentDuel = currentDuelSnap.data();
    const currentSecret = currentSecretSnap.data();
    ensureParticipant(currentDuel, uid);

    const preparedKey = isP1 ? 'p1Prepared' : 'p2Prepared';
    const selectionsKey = isP1 ? 'p1ChallengeSelections' : 'p2ChallengeSelections';
    const languageKey = isP1 ? 'p1PrepLanguage' : 'p2PrepLanguage';
    const otherSelections = isP1
      ? currentSecret.p2ChallengeSelections
      : currentSecret.p1ChallengeSelections;

    if (currentSecret[preparedKey] === true) {
      return publicDuelState(currentDuel, uid);
    }

    const otherQuestionIds = new Set(
      (Array.isArray(otherSelections) ? otherSelections : [])
        .map((item) => String(item && item.questionId || '')),
    );
    if (selections.some((item) => otherQuestionIds.has(item.questionId))) {
      throw new HttpsError('aborted', 'QUESTION_SELECTION_CHANGED');
    }

    const now = Timestamp.now();
    tx.update(secretRef, {
      [preparedKey]: true,
      [selectionsKey]: selections,
      [languageKey]: language,
      updatedAt: now,
    });
    tx.update(duelRef, { updatedAt: now });
    return publicDuelState(currentDuel, uid);
  });
});

const getDuelStateV2 = onCall(async (request) => {
  const uid = authUid(request);
  await ensureNotSuspended(uid);
  const duelId = duelIdFromRequest(request);
  const snap = await db.collection('duelsV2').doc(duelId).get();
  if (!snap.exists) throw new HttpsError('not-found', 'Duel not found.');
  const duel = snap.data();
  ensureParticipant(duel, uid);
  return publicDuelState(duel, uid);
});

const prepareDuelQuestionsV2 = onCall(async (request) => {
  const uid = authUid(request);
  await ensureNotSuspended(uid);
  const duelId = duelIdFromRequest(request);
  const language = languageFromRequest(request);
  const duelRef = db.collection('duelsV2').doc(duelId);
  const secretRef = db.collection('duelSecretsV2').doc(duelId);
  const userRef = db.collection('users').doc(uid);

  const [duelSnap, secretSnap, userSnap] = await Promise.all([
    duelRef.get(),
    secretRef.get(),
    userRef.get(),
  ]);
  if (!duelSnap.exists || !secretSnap.exists || !userSnap.exists) {
    throw new HttpsError('not-found', 'Duel or player data not found.');
  }
  const duel = duelSnap.data();
  const secret = secretSnap.data();
  ensureParticipant(duel, uid);
  if (duel.status === 'finished') throw new HttpsError('failed-precondition', 'Duel already finished.');

  const isP1 = uid === duel.p1Uid;
  const planKey = isP1 ? 'p1QuestionPlan' : 'p2QuestionPlan';
  const otherPlanKey = isP1 ? 'p2QuestionPlan' : 'p1QuestionPlan';
  const attackerUid = isP1 ? duel.p2Uid : duel.p1Uid;
  const attackerSelections = isP1
    ? secret.p2ChallengeSelections
    : secret.p1ChallengeSelections;

  if (validateQuestionPlan(secret[planKey])) {
    return publicDuelState(duel, uid);
  }
  if (!Array.isArray(attackerSelections) || attackerSelections.length !== 7) {
    return publicDuelState(duel, uid);
  }

  const playerProfile = profileFromUserData(userSnap.data());
  const generated = await buildPlanFromSelections({
    selections: attackerSelections,
    answeringProfile: playerProfile,
    attackerUid,
    language,
  });

  return db.runTransaction(async (tx) => {
    const [currentDuelSnap, currentSecretSnap, currentUserSnap] = await Promise.all([
      tx.get(duelRef),
      tx.get(secretRef),
      tx.get(userRef),
    ]);
    if (!currentDuelSnap.exists || !currentSecretSnap.exists || !currentUserSnap.exists) {
      throw new HttpsError('not-found', 'Duel or player data not found.');
    }
    const currentDuel = currentDuelSnap.data();
    const currentSecret = currentSecretSnap.data();
    ensureParticipant(currentDuel, uid);
    if (validateQuestionPlan(currentSecret[planKey])) {
      return publicDuelState(currentDuel, uid);
    }

    const currentProfile = profileFromUserData(currentUserSnap.data());
    currentProfile.recentQuestionIds = generated.recentQuestionIds;
    const otherReady = validateQuestionPlan(currentSecret[otherPlanKey]);
    const now = Timestamp.now();
    tx.update(secretRef, {
      [planKey]: generated.plan,
      updatedAt: now,
    });
    tx.update(userRef, {
      profileV2: currentProfile,
      schemaVersion: 2,
      updatedAt: now,
    });
    tx.update(duelRef, {
      questionPlanReady: otherReady,
      updatedAt: now,
    });
    return publicDuelState({ ...currentDuel, questionPlanReady: otherReady }, uid);
  });
});
const startNextQuestionV2 = onCall(async (request) => {
  const uid = authUid(request);
  await ensureNotSuspended(uid);
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
  await ensureNotSuspended(uid);
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
  await ensureNotSuspended(uid);
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

module.exports = {
  getDuelPreparationV2,
  submitDuelPreparationV2,
  getDuelStateV2,
  prepareDuelQuestionsV2,
  startNextQuestionV2,
  submitDuelAnswerV2,
  finalizeDuelV2,
};
