'use strict';

const admin = require('firebase-admin');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { normalizeProfileV2 } = require('./player_profile_v2');
const { entitlement } = require('./core_engine_v2');
const { validateQuestionDocument, localizedQuestion } = require('./content_contract_v2');
const { validateCustomWrongChoices } = require('./custom_answers_engine_v2');

const db = admin.firestore();
const { Timestamp } = admin.firestore;

function authUid(request) {
  const uid = request.auth && request.auth.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Authentication required.');
  return uid;
}

function cleanId(value, name) {
  const id = String(value || '').trim();
  if (!id || id.includes('/')) throw new HttpsError('invalid-argument', `${name} is invalid.`);
  return id;
}

function choiceDocId(cardId, questionId, language) {
  return `${cardId}--${questionId}--${language}`;
}

async function loadOwnedQuestion(uid, cardId, questionId, language) {
  const [userSnap, questionSnap] = await Promise.all([
    db.collection('users').doc(uid).get(),
    db.collection('cardsV2').doc(cardId).collection('questions').doc(questionId).get(),
  ]);
  if (!userSnap.exists) throw new HttpsError('not-found', 'Profile not found.');
  const profile = normalizeProfileV2(userSnap.data().profileV2 || {});
  if (!profile.ownedPackIds.includes(cardId)) {
    throw new HttpsError('permission-denied', 'You can customize only questions from owned cards.');
  }
  if (!questionSnap.exists) throw new HttpsError('not-found', 'Question not found.');
  try {
    validateQuestionDocument(questionId, cardId, questionSnap.data());
  } catch (_) {
    throw new HttpsError('failed-precondition', 'Question content is not valid for customization.');
  }
  if (questionSnap.data().enabled !== true) {
    throw new HttpsError('failed-precondition', 'Question is disabled.');
  }
  const localized = localizedQuestion(questionSnap.data(), language);
  return { profile, localized };
}

const getCustomWrongChoicesV2 = onCall(async (request) => {
  const uid = authUid(request);
  const cardId = cleanId(request.data && request.data.cardId, 'cardId');
  const questionId = cleanId(request.data && request.data.questionId, 'questionId');
  const language = request.data && request.data.language === 'en' ? 'en' : 'ar';
  const { profile } = await loadOwnedQuestion(uid, cardId, questionId, language);
  const limit = entitlement(profile.subscriptionActive).editableWrongChoices;
  const ref = db.collection('users').doc(uid).collection('customChoicesV2')
    .doc(choiceDocId(cardId, questionId, language));
  const snap = await ref.get();
  const choices = snap.exists && Array.isArray(snap.data().choices)
    ? snap.data().choices.map(String).slice(0, limit)
    : [];
  return { cardId, questionId, language, choices, maxChoices: limit };
});

const saveCustomWrongChoicesV2 = onCall(async (request) => {
  const uid = authUid(request);
  const cardId = cleanId(request.data && request.data.cardId, 'cardId');
  const questionId = cleanId(request.data && request.data.questionId, 'questionId');
  const language = request.data && request.data.language === 'en' ? 'en' : 'ar';
  const rawChoices = request.data && request.data.choices;
  const { profile, localized } = await loadOwnedQuestion(uid, cardId, questionId, language);
  const limit = entitlement(profile.subscriptionActive).editableWrongChoices;
  let choices;
  try {
    choices = validateCustomWrongChoices(rawChoices, localized.correct, limit);
  } catch (error) {
    throw new HttpsError('invalid-argument', error.message || 'Invalid custom choices.');
  }

  const ref = db.collection('users').doc(uid).collection('customChoicesV2')
    .doc(choiceDocId(cardId, questionId, language));
  if (choices.length === 0) {
    await ref.delete();
  } else {
    await ref.set({
      schemaVersion: 2,
      cardId,
      questionId,
      language,
      choices,
      updatedAt: Timestamp.now(),
    }, { merge: false });
  }
  return { cardId, questionId, language, choices, maxChoices: limit };
});

module.exports = {
  getCustomWrongChoicesV2,
  saveCustomWrongChoicesV2,
};
