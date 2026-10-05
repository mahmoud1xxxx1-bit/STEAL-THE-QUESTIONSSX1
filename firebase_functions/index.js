const crypto = require('crypto');
const admin = require('firebase-admin');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { setGlobalOptions } = require('firebase-functions/v2/options');
const { defineSecret } = require('firebase-functions/params');
const { cards, questionById, publicQuestion } = require('./question_data');

admin.initializeApp();
setGlobalOptions({ region: 'us-central1', maxInstances: 20 });

const db = admin.firestore();
const { FieldValue, Timestamp } = admin.firestore;

const TOTAL_CARDS = 222;
const DECK_SIZE = 10;
const MAX_DECKS = 5;
const FREE_DECKS = 2;
const PASS_DECKS = 3;
const MIN_PVP_CARDS = 10;
const DUEL_QUESTIONS = 7;
const QUESTION_SECONDS = 20;
const QUESTION_PHASE_SECONDS = 140;
const FULL_DUEL_SECONDS = 180;
const WEEKLY_PASS_DAYS = 7;
const WEEKLY_PASS_PRODUCT = 'weekly_pass_v1';
const ANDROID_PACKAGE_NAME = 'com.STEALTHE.QUESTIONSSX1';
const APPLE_BUNDLE_ID = 'com.STEALTHE.QUESTIONSSX1';

const googlePlayServiceAccountJson = defineSecret('GOOGLE_PLAY_SERVICE_ACCOUNT_JSON');
const appleIssuerId = defineSecret('APPLE_ISSUER_ID');
const appleKeyId = defineSecret('APPLE_KEY_ID');
const applePrivateKey = defineSecret('APPLE_PRIVATE_KEY');

function authUid(request) {
  const uid = request.auth && request.auth.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Authentication required.');
  return uid;
}

function cleanIds(value) {
  if (!Array.isArray(value)) {
    throw new HttpsError('invalid-argument', 'cardIds must be an array.');
  }
  const ids = value.map((x) => String(x));
  if (ids.length !== DECK_SIZE || new Set(ids).size !== DECK_SIZE) {
    throw new HttpsError('invalid-argument', 'A deck must contain exactly 10 distinct cards.');
  }
  return ids;
}

function passActive(data, nowMs = Date.now()) {
  const expiry = data && data.weeklyPassExpiresAt;
  return !!expiry && expiry.toMillis() > nowMs;
}

function slotCountFor(data) {
  return passActive(data) ? FREE_DECKS + PASS_DECKS : FREE_DECKS;
}

function userRef(uid) {
  return db.collection('users').doc(uid);
}

function arrayFrom(value) {
  return Array.isArray(value) ? value.map(String) : [];
}

function randomUniqueFrom(list, count) {
  if (list.length < count) return null;
  const copy = [...list];
  for (let i = copy.length - 1; i > 0; i -= 1) {
    const j = crypto.randomInt(i + 1);
    [copy[i], copy[j]] = [copy[j], copy[i]];
  }
  return copy.slice(0, count);
}

function weekKey(ms = Date.now()) {
  const date = new Date(ms);
  const day = date.getUTCDay();
  const daysSinceMonday = (day + 6) % 7;
  date.setUTCDate(date.getUTCDate() - daysSinceMonday);
  return date.toISOString().slice(0, 10);
}

async function getOrCreateUser(uid, email) {
  const ref = userRef(uid);
  const snap = await ref.get();
  if (snap.exists) return snap.data();
  const data = {
    uid,
    displayName: (email && email.split('@')[0]) || 'PLAYER',
    email: email || null,
    ownedCards: [],
    ownedCount: 0,
    decks: [[], [], [], [], []],
    weeklyPassExpiresAt: null,
    wins: 0,
    losses: 0,
    activeDeck: 0,
    activeDuel: null,
    tutorialComplete: false,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp()
  };
  await ref.set(data);
  return data;
}

exports.ensureProfile = onCall(async (request) => {
  const uid = authUid(request);
  const user = await getOrCreateUser(uid, request.auth.token.email || null);
  return {
    uid,
    ownedCards: arrayFrom(user.ownedCards),
    ownedCount: Number(user.ownedCount || 0),
  };
});

exports.startBotRound = onCall(async (request) => {
  const uid = authUid(request);
  const ref = userRef(uid);
  const snap = await ref.get();
  const user = snap.data() || {};
  const owned = new Set(arrayFrom(user.ownedCards));
  if (owned.size >= MIN_PVP_CARDS) {
    throw new HttpsError('failed-precondition', 'Bot onboarding is complete.');
  }

  const available = cards
    .filter((c) => c.rarity !== 'legendary' && !owned.has(c.id))
    .map((c) => c.id);
  if (!available.length) {
    throw new HttpsError('failed-precondition', 'No unowned normal cards remain.');
  }

  const rewardCardId = available[crypto.randomInt(available.length)];
  const questionPool = cards.filter((c) => c.rarity !== 'legendary').map((c) => c.id);
  const questionCardId = questionPool[crypto.randomInt(questionPool.length)];
  const q = questionById(questionCardId);
  const roundId = db.collection('botRounds').doc().id;

  await db.collection('botRounds').doc(roundId).set({
    uid,
    cardId: questionCardId,
    rewardCardId,
    createdAt: Timestamp.now(),
    status: 'open'
  });

  const p = publicQuestion(questionCardId);
  return {
    roundId,
    questionId: p.questionId,
    questionEn: p.questionEn,
    questionAr: p.questionAr,
    answersEn: p.answersEn,
    answersAr: p.answersAr
  };
});

exports.submitBotAnswer = onCall(async (request) => {
  const uid = authUid(request);
  const roundId = String(request.data && request.data.roundId || '');
  const answerIndex = Number(request.data && request.data.answerIndex);

  if (!roundId || !Number.isInteger(answerIndex) || answerIndex < 0 || answerIndex > 3) {
    throw new HttpsError('invalid-argument', 'Invalid bot answer.');
  }

  const roundRef = db.collection('botRounds').doc(roundId);
  const uRef = userRef(uid);
  const result = await db.runTransaction(async (tx) => {
    const roundSnap = await tx.get(roundRef);
    const userSnap = await tx.get(uRef);
    if (!roundSnap.exists || roundSnap.data().uid !== uid) {
      throw new HttpsError('not-found', 'Bot round not found.');
    }
    const round = roundSnap.data();
    if (round.status !== 'open') {
      return {
        correct: !!round.correct,
        awardedCardId: round.awardedCardId || null,
        alreadyResolved: true
      };
    }

    const user = userSnap.data() || {};
    const owned = arrayFrom(user.ownedCards);
    const elapsedMs = Math.max(0, Date.now() - round.createdAt.toMillis());
    const timedOut = elapsedMs > QUESTION_SECONDS * 1000;
    const q = questionById(round.cardId);
    const correct = !timedOut && answerIndex === q.correctIndex;
    let awardedCardId = null;

    if (correct && owned.length < MIN_PVP_CARDS && !owned.includes(round.rewardCardId)) {
      awardedCardId = round.rewardCardId;
      const next = [...owned, round.rewardCardId];
      tx.update(uRef, {
        ownedCards: next,
        ownedCount: next.length,
        updatedAt: Timestamp.now()
      });
    }

    tx.update(roundRef, {
      status: 'resolved',
      answerIndex,
      timedOut,
      correct,
      awardedCardId,
      resolvedAt: Timestamp.now()
    });

    return { correct, awardedCardId, alreadyResolved: false };
  });

  return result;
});

exports.saveDeck = onCall(async (request) => {
  const uid = authUid(request);
  const deckIndex = Number(request.data && request.data.deckIndex);
  const cardIds = cleanIds(request.data && request.data.cardIds);

  if (!Number.isInteger(deckIndex) || deckIndex < 0 || deckIndex >= MAX_DECKS) {
    throw new HttpsError('invalid-argument', 'Invalid deck index.');
  }

  const ref = userRef(uid);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) throw new HttpsError('not-found', 'Profile not found.');
    const user = snap.data();
    if (deckIndex >= slotCountFor(user)) {
      throw new HttpsError('permission-denied', 'This deck slot is locked.');
    }
    const owned = new Set(arrayFrom(user.ownedCards));
    if (!cardIds.every((id) => owned.has(id))) {
      throw new HttpsError('permission-denied', 'Every deck card must be owned.');
    }

    const decks = Array.from({ length: MAX_DECKS }, (_, i) =>
      arrayFrom((user.decks || [])[i])
    );
    decks[deckIndex] = cardIds;
    tx.update(ref, { decks, updatedAt: Timestamp.now() });
  });

  return { ok: true, deckIndex, cardIds };
});

function selectSeven(deck) {
  const picked = randomUniqueFrom(deck, DUEL_QUESTIONS);
  if (!picked) throw new HttpsError('invalid-argument', 'A duel requires 10 distinct deck cards.');
  return picked;
}

function buildQuestionSet(cardIds) {
  return cardIds.map((id) => publicQuestion(id));
}

exports.findOrCreateDuel = onCall(async (request) => {
  const uid = authUid(request);
  const requestedDeck = cleanIds(request.data && request.data.deck);
  const selfRef = userRef(uid);
  const queueRef = db.collection('matchmaking').doc('searching');

  const response = await db.runTransaction(async (tx) => {
    const selfSnap = await tx.get(selfRef);
    if (!selfSnap.exists) throw new HttpsError('not-found', 'Profile not found.');
    const self = selfSnap.data();

    if (self.activeDuel) {
      const duelSnap = await tx.get(db.collection('duels').doc(self.activeDuel));
      if (duelSnap.exists) {
        return { status: duelSnap.data().status, duelId: self.activeDuel };
      }
      tx.update(selfRef, { activeDuel: null });
    }

    if (arrayFrom(self.ownedCards).length < MIN_PVP_CARDS) {
      throw new HttpsError('failed-precondition', 'At least 10 owned cards are required.');
    }
    if (!requestedDeck.every((id) => arrayFrom(self.ownedCards).includes(id))) {
      throw new HttpsError('permission-denied', 'Selected deck contains cards you do not own.');
    }

    const queueSnap = await tx.get(queueRef);
    const queue = queueSnap.exists ? queueSnap.data() : null;

    if (!queue || !queue.uid || queue.uid === uid ||
        Date.now() - queue.createdAt.toMillis() > 5 * 60 * 1000) {
      const duelRef = db.collection('duels').doc();
      const searchingDoc = {
        status: 'searching',
        p1Uid: uid,
        p1Deck: requestedDeck,
        p2Uid: null,
        p2Deck: [],
        createdAt: Timestamp.now(),
        startedAt: null,
        p1AnsweredCount: 0,
        p2AnsweredCount: 0,
        p1CorrectCount: 0,
        p2CorrectCount: 0,
        p1TotalTimeMs: 0,
        p2TotalTimeMs: 0,
        winnerUid: null,
        loserUid: null,
        result: null,
        stealRevealed: false,
        stealConfirmed: false
      };
      tx.create(duelRef, searchingDoc);
      tx.set(queueRef, {
        duelId: duelRef.id,
        uid,
        deck: requestedDeck,
        createdAt: Timestamp.now()
      });
      tx.update(selfRef, { activeDuel: duelRef.id, updatedAt: Timestamp.now() });
      return { status: 'searching', duelId: duelRef.id };
    }

    const opponentUid = String(queue.uid);
    const opponentRef = userRef(opponentUid);
    const duelRef = db.collection('duels').doc(String(queue.duelId));
    const [opponentSnap, waitingSnap] = await Promise.all([
      tx.get(opponentRef),
      tx.get(duelRef)
    ]);

    if (!opponentSnap.exists || !waitingSnap.exists || waitingSnap.data().status !== 'searching') {
      tx.delete(queueRef);
      throw new HttpsError('aborted', 'Matchmaking state changed. Try again.');
    }

    const opponent = opponentSnap.data();
    if (opponentUid === uid || opponent.activeDuel !== String(queue.duelId)) {
      tx.delete(queueRef);
      throw new HttpsError('aborted', 'Matchmaking state changed. Try again.');
    }

    const p1Deck = arrayFrom(waitingSnap.data().p1Deck);
    const p2Deck = requestedDeck;
    const p1Selected = selectSeven(p1Deck);
    const p2Selected = selectSeven(p2Deck);
    const seed = crypto.randomInt(1, 2147483647);
    const startedAt = Timestamp.now();
    const startedMs = startedAt.toMillis();
    const secretRef = db.collection('duelSecrets').doc(String(queue.duelId));

    const qP1 = buildQuestionSet(p2Selected);
    const qP2 = buildQuestionSet(p1Selected);

    tx.set(secretRef, {
      p1Deck,
      p2Deck,
      p1Selected,
      p2Selected,
      correctP1: qP1.map((q) => qCorrect(q.questionId)),
      correctP2: qP2.map((q) => qCorrect(q.questionId)),
      p1Answers: [],
      p2Answers: [],
      p1RoundStartedAt: startedAt,
      p2RoundStartedAt: startedAt,
      seed,
      startedAt,
      stealSlot: null,
      stealCardId: null,
      stealRevealed: false,
      stealConfirmed: false
    });

    tx.update(duelRef, {
      status: 'playing',
      p2Uid: uid,
      p2Deck,
      startedAt,
      questionPhaseEndsAt: Timestamp.fromMillis(startedMs + QUESTION_PHASE_SECONDS * 1000),
      closingEndsAt: Timestamp.fromMillis(startedMs + FULL_DUEL_SECONDS * 1000),
      questionsP1: qP1,
      questionsP2: qP2
    });

    tx.update(opponentRef, { updatedAt: Timestamp.now(), activeDuel: String(queue.duelId) });
    tx.update(selfRef, { updatedAt: Timestamp.now(), activeDuel: String(queue.duelId) });
    tx.delete(queueRef);

    return { status: 'playing', duelId: String(queue.duelId) };
  });

  return response;
});

function qCorrect(questionId) {
  return questionById(questionId).correctIndex;
}

function participantRole(duel, uid) {
  if (duel.p1Uid === uid) return 'p1';
  if (duel.p2Uid === uid) return 'p2';
  throw new HttpsError('permission-denied', 'You are not a participant in this duel.');
}

function answerField(role) {
  return role === 'p1' ? 'p1Answers' : 'p2Answers';
}

function roundStartField(role) {
  return role === 'p1' ? 'p1RoundStartedAt' : 'p2RoundStartedAt';
}

exports.submitDuelAnswer = onCall(async (request) => {
  const uid = authUid(request);
  const duelId = String(request.data && request.data.duelId || '');
  const questionIndex = Number(request.data && request.data.questionIndex);
  const answerIndex = Number(request.data && request.data.answerIndex);

  if (!duelId || !Number.isInteger(questionIndex) || questionIndex < 0 ||
      questionIndex >= DUEL_QUESTIONS || !Number.isInteger(answerIndex) ||
      answerIndex < 0 || answerIndex > 3) {
    throw new HttpsError('invalid-argument', 'Invalid duel answer.');
  }

  const duelRef = db.collection('duels').doc(duelId);
  const secretRef = db.collection('duelSecrets').doc(duelId);

  const response = await db.runTransaction(async (tx) => {
    const duelSnap = await tx.get(duelRef);
    const secretSnap = await tx.get(secretRef);
    if (!duelSnap.exists || !secretSnap.exists) {
      throw new HttpsError('not-found', 'Duel not found.');
    }
    const duel = duelSnap.data();
    const secret = secretSnap.data();
    if (duel.status !== 'playing') return { alreadyFinished: true };
    const role = participantRole(duel, uid);
    const answersKey = answerField(role);
    const startKey = roundStartField(role);
    const answers = Array.isArray(secret[answersKey]) ? secret[answersKey] : [];

    if (answers.length !== questionIndex) {
      throw new HttpsError('failed-precondition', 'This question is no longer current.');
    }

    const roundStarted = secret[startKey];
    if (!roundStarted) throw new HttpsError('failed-precondition', 'Question timer is unavailable.');
    const elapsedMs = Math.max(0, Date.now() - roundStarted.toMillis());
    const timedOut = elapsedMs > QUESTION_SECONDS * 1000;
    const correctList = role === 'p1' ? secret.correctP1 : secret.correctP2;
    const correct = !timedOut && answerIndex === Number(correctList[questionIndex]);
    const recordedMs = Math.min(elapsedMs, QUESTION_SECONDS * 1000);
    const answer = {
      correct,
      responseTimeMs: recordedMs,
      timedOut,
      answerIndex,
      questionIndex
    };
    const nextAnswers = [...answers, answer];

    tx.update(secretRef, {
      [answersKey]: nextAnswers,
      [startKey]: Timestamp.fromMillis(Date.now())
    });

    const countKey = role === 'p1' ? 'p1AnsweredCount' : 'p2AnsweredCount';
    const correctKey = role === 'p1' ? 'p1CorrectCount' : 'p2CorrectCount';
    const totalKey = role === 'p1' ? 'p1TotalTimeMs' : 'p2TotalTimeMs';
    const nextCorrect = nextAnswers.filter((x) => x.correct).length;
    const nextTotal = nextAnswers.reduce((sum, x) => sum + Number(x.responseTimeMs || 0), 0);

    tx.update(duelRef, {
      [countKey]: nextAnswers.length,
      [correctKey]: nextCorrect,
      [totalKey]: nextTotal
    });

    return { alreadyFinished: false, correct, timedOut, responseTimeMs: recordedMs };
  });

  return response;
});

function finalizeResult(duel, secret, nowMs) {
  const p1 = Array.isArray(secret.p1Answers) ? secret.p1Answers : [];
  const p2 = Array.isArray(secret.p2Answers) ? secret.p2Answers : [];

  const p1Filled = [...p1];
  const p2Filled = [...p2];

  while (p1Filled.length < DUEL_QUESTIONS) {
    p1Filled.push({
      correct: false,
      responseTimeMs: QUESTION_SECONDS * 1000,
      timedOut: true,
      answerIndex: -1,
      questionIndex: p1Filled.length
    });
  }
  while (p2Filled.length < DUEL_QUESTIONS) {
    p2Filled.push({
      correct: false,
      responseTimeMs: QUESTION_SECONDS * 1000,
      timedOut: true,
      answerIndex: -1,
      questionIndex: p2Filled.length
    });
  }

  const p1Correct = p1Filled.filter((x) => x.correct).length;
  const p2Correct = p2Filled.filter((x) => x.correct).length;
  const p1Time = p1Filled.reduce((sum, x) => sum + Number(x.responseTimeMs || 0), 0);
  const p2Time = p2Filled.reduce((sum, x) => sum + Number(x.responseTimeMs || 0), 0);

  let result = 'draw';
  let winnerUid = null;
  let loserUid = null;
  if (p1Correct > p2Correct) {
    result = 'playerOneWin';
    winnerUid = duel.p1Uid;
    loserUid = duel.p2Uid;
  } else if (p2Correct > p1Correct) {
    result = 'playerTwoWin';
    winnerUid = duel.p2Uid;
    loserUid = duel.p1Uid;
  } else if (p1Time < p2Time) {
    result = 'playerOneWin';
    winnerUid = duel.p1Uid;
    loserUid = duel.p2Uid;
  } else if (p2Time < p1Time) {
    result = 'playerTwoWin';
    winnerUid = duel.p2Uid;
    loserUid = duel.p1Uid;
  }

  return {
    result,
    winnerUid,
    loserUid,
    p1Filled,
    p2Filled,
    p1Correct,
    p2Correct,
    p1Time,
    p2Time,
    nowMs
  };
}

exports.resolveDuel = onCall(async (request) => {
  const uid = authUid(request);
  const duelId = String(request.data && request.data.duelId || '');
  if (!duelId) throw new HttpsError('invalid-argument', 'duelId is required.');

  const duelRef = db.collection('duels').doc(duelId);
  const secretRef = db.collection('duelSecrets').doc(duelId);

  return db.runTransaction(async (tx) => {
    const duelSnap = await tx.get(duelRef);
    const secretSnap = await tx.get(secretRef);
    if (!duelSnap.exists || !secretSnap.exists) {
      throw new HttpsError('not-found', 'Duel not found.');
    }
    const duel = duelSnap.data();
    participantRole(duel, uid);

    if (duel.status === 'finished') {
      return {
        result: duel.result,
        winnerUid: duel.winnerUid || null,
        loserUid: duel.loserUid || null
      };
    }
    if (duel.status !== 'playing') {
      throw new HttpsError('failed-precondition', 'Duel is not playing.');
    }

    const startedAt = duel.startedAt.toMillis();
    const fullyAnswered =
      Number(duel.p1AnsweredCount || 0) >= DUEL_QUESTIONS &&
      Number(duel.p2AnsweredCount || 0) >= DUEL_QUESTIONS;

    if (!fullyAnswered && Date.now() < startedAt + QUESTION_PHASE_SECONDS * 1000) {
      throw new HttpsError('failed-precondition', 'Duel question phase is still active.');
    }

    const secret = secretSnap.data();
    const resolved = finalizeResult(duel, secret, Date.now());

    const p1Ref = userRef(duel.p1Uid);
    const p2Ref = userRef(duel.p2Uid);
    const [p1Snap, p2Snap] = await Promise.all([tx.get(p1Ref), tx.get(p2Ref)]);
    if (!p1Snap.exists || !p2Snap.exists) throw new HttpsError('not-found', 'Duel players not found.');

    tx.update(secretRef, {
      p1Answers: resolved.p1Filled,
      p2Answers: resolved.p2Filled
    });

    tx.update(duelRef, {
      status: 'finished',
      p1AnsweredCount: DUEL_QUESTIONS,
      p2AnsweredCount: DUEL_QUESTIONS,
      p1CorrectCount: resolved.p1Correct,
      p2CorrectCount: resolved.p2Correct,
      p1TotalTimeMs: resolved.p1Time,
      p2TotalTimeMs: resolved.p2Time,
      result: resolved.result,
      winnerUid: resolved.winnerUid,
      loserUid: resolved.loserUid,
      resultAt: Timestamp.now()
    });

    tx.update(p1Ref, {
      wins: Number(p1Snap.data().wins || 0) + (resolved.winnerUid === duel.p1Uid ? 1 : 0),
      losses: Number(p1Snap.data().losses || 0) + (resolved.loserUid === duel.p1Uid ? 1 : 0),
      activeDuel: null,
      updatedAt: Timestamp.now()
    });
    tx.update(p2Ref, {
      wins: Number(p2Snap.data().wins || 0) + (resolved.winnerUid === duel.p2Uid ? 1 : 0),
      losses: Number(p2Snap.data().losses || 0) + (resolved.loserUid === duel.p2Uid ? 1 : 0),
      activeDuel: null,
      updatedAt: Timestamp.now()
    });

    return {
      result: resolved.result,
      winnerUid: resolved.winnerUid,
      loserUid: resolved.loserUid
    };
  });
});

exports.revealStealTarget = onCall(async (request) => {
  const uid = authUid(request);
  const duelId = String(request.data && request.data.duelId || '');
  const slotIndex = Number(request.data && request.data.slotIndex);

  if (!duelId || !Number.isInteger(slotIndex) || slotIndex < 0 || slotIndex >= DECK_SIZE) {
    throw new HttpsError('invalid-argument', 'Invalid steal slot.');
  }

  const duelRef = db.collection('duels').doc(duelId);
  const secretRef = db.collection('duelSecrets').doc(duelId);

  return db.runTransaction(async (tx) => {
    const duelSnap = await tx.get(duelRef);
    const secretSnap = await tx.get(secretRef);
    if (!duelSnap.exists || !secretSnap.exists) throw new HttpsError('not-found', 'Duel not found.');
    const duel = duelSnap.data();
    if (duel.result === 'draw' || duel.winnerUid !== uid) {
      throw new HttpsError('permission-denied', 'Only the winner can steal.');
    }
    const secret = secretSnap.data();
    const loserDeck = duel.loserUid === duel.p1Uid ? secret.p1Deck : secret.p2Deck;
    const cardId = loserDeck[slotIndex];
    if (!cardId) throw new HttpsError('failed-precondition', 'Invalid opponent card.');
    const loserSnap = await tx.get(userRef(duel.loserUid));
    const winnerSnap = await tx.get(userRef(uid));
    if (!loserSnap.exists || !winnerSnap.exists) throw new HttpsError('not-found', 'Player profile not found.');
    const loserOwned = arrayFrom(loserSnap.data().ownedCards);
    const winnerOwned = new Set(arrayFrom(winnerSnap.data().ownedCards));
    if (!loserOwned.includes(cardId)) throw new HttpsError('aborted', 'That card is no longer owned by the opponent.');
    if (winnerOwned.has(cardId)) {
      throw new HttpsError('failed-precondition', 'You already own this card. Choose another face-down card.');
    }

    tx.update(secretRef, {
      stealSlot: slotIndex,
      stealCardId: cardId,
      stealRevealed: true
    });
    return { cardId, rarity: questionById(cardId).rarity };
  });
});

exports.confirmSteal = onCall(async (request) => {
  const uid = authUid(request);
  const duelId = String(request.data && request.data.duelId || '');
  if (!duelId) throw new HttpsError('invalid-argument', 'duelId is required.');

  const duelRef = db.collection('duels').doc(duelId);
  const secretRef = db.collection('duelSecrets').doc(duelId);

  return db.runTransaction(async (tx) => {
    const duelSnap = await tx.get(duelRef);
    const secretSnap = await tx.get(secretRef);
    if (!duelSnap.exists || !secretSnap.exists) throw new HttpsError('not-found', 'Duel not found.');
    const duel = duelSnap.data();
    if (duel.result === 'draw' || duel.winnerUid !== uid) {
      throw new HttpsError('permission-denied', 'Only the winner can steal.');
    }
    const secret = secretSnap.data();
    if (secret.stealConfirmed) return { ok: true, alreadyConfirmed: true };
    const cardId = secret.stealCardId;
    if (!cardId) throw new HttpsError('failed-precondition', 'Reveal a steal target first.');

    const winnerRef = userRef(uid);
    const loserRef = userRef(duel.loserUid);
    const [winnerSnap, loserSnap] = await Promise.all([tx.get(winnerRef), tx.get(loserRef)]);
    if (!winnerSnap.exists || !loserSnap.exists) throw new HttpsError('not-found', 'Player profile not found.');

    const winnerOwned = arrayFrom(winnerSnap.data().ownedCards);
    const loserOwned = arrayFrom(loserSnap.data().ownedCards);
    if (winnerOwned.includes(cardId)) {
      throw new HttpsError('failed-precondition', 'You already own this card.');
    }
    const loserIndex = loserOwned.indexOf(cardId);
    if (loserIndex < 0) throw new HttpsError('aborted', 'The opponent no longer owns this card.');

    const nextWinner = [...winnerOwned, cardId];
    const nextLoser = loserOwned.filter((_, i) => i !== loserIndex);

    tx.update(winnerRef, {
      ownedCards: nextWinner,
      ownedCount: nextWinner.length,
      updatedAt: Timestamp.now()
    });
    tx.update(loserRef, {
      ownedCards: nextLoser,
      ownedCount: nextLoser.length,
      updatedAt: Timestamp.now()
    });
    tx.update(secretRef, { stealConfirmed: true });
    tx.update(duelRef, { stealRevealed: true, stealConfirmed: true, stolenCardId: cardId });

    return {
      ok: true,
      alreadyConfirmed: false,
      cardId,
      rarity: questionById(cardId).rarity
    };
  });
});

exports.getRanking = onCall(async (request) => {
  authUid(request);
  const snap = await db.collection('users')
    .orderBy('ownedCount', 'desc')
    .orderBy('wins', 'desc')
    .orderBy('uid', 'asc')
    .limit(100)
    .get();

  return {
    players: snap.docs.map((doc) => {
      const d = doc.data();
      return {
        uid: d.uid || doc.id,
        displayName: d.displayName || 'PLAYER',
        ownedCount: Number(d.ownedCount || 0),
        wins: Number(d.wins || 0)
      };
    })
  };
});

exports.claimRankingReward = onCall(async (request) => {
  const uid = authUid(request);
  const ranking = await db.collection('users')
    .orderBy('ownedCount', 'desc')
    .orderBy('wins', 'desc')
    .orderBy('uid', 'asc')
    .limit(3)
    .get();

  const rankIndex = ranking.docs.findIndex((doc) => doc.id === uid);
  if (rankIndex < 0 || rankIndex > 2) {
    throw new HttpsError('failed-precondition', 'Only ranks 1-3 receive a card reward.');
  }

  const rank = rankIndex + 1;
  const key = weekKey();
  const rewardRef = db.collection('rankingRewards').doc(key + '_' + uid);
  const userRefValue = userRef(uid);

  return db.runTransaction(async (tx) => {
    const rewardSnap = await tx.get(rewardRef);
    const userSnap = await tx.get(userRefValue);
    if (!userSnap.exists) throw new HttpsError('not-found', 'Profile not found.');
    if (rewardSnap.exists) {
      return { claimed: true, rank, cardIds: arrayFrom(rewardSnap.data().cardIds) };
    }

    const owned = new Set(arrayFrom(userSnap.data().ownedCards));
    const poolRarity = rank === 1 ? 'legendary' : 'gold';
    const pool = cards.filter((c) => c.rarity === poolRarity && !owned.has(c.id)).map((c) => c.id);
    const count = rank === 1 ? 1 : rank === 2 ? 3 : 2;
    const cardIds = randomUniqueFrom(pool, count);
    if (!cardIds) {
      throw new HttpsError('failed-precondition', 'No eligible unowned ranking reward cards remain.');
    }

    const nextOwned = [...owned, ...cardIds];
    tx.update(userRefValue, {
      ownedCards: nextOwned,
      ownedCount: nextOwned.length,
      updatedAt: Timestamp.now()
    });
    tx.create(rewardRef, {
      uid,
      weekKey: key,
      rank,
      cardIds,
      claimedAt: Timestamp.now()
    });

    return { claimed: true, rank, cardIds };
  });
});

function base64UrlJson(value) {
  return Buffer.from(JSON.stringify(value)).toString('base64url');
}

function decodeBase64UrlJson(value) {
  return JSON.parse(Buffer.from(value, 'base64url').toString('utf8'));
}

function signJwt(header, payload, privateKey, algorithm = 'RSA-SHA256') {
  const encodedHeader = base64UrlJson(header);
  const encodedPayload = base64UrlJson(payload);
  const unsigned = encodedHeader + '.' + encodedPayload;
  const signer = crypto.createSign(algorithm);
  signer.update(unsigned);
  signer.end();
  const signature = signer.sign(
    algorithm === 'RSA-SHA256'
      ? privateKey
      : { key: privateKey, dsaEncoding: 'ieee-p1363' }
  ).toString('base64url');
  return unsigned + '.' + signature;
}

async function googleAccessToken(serviceAccount) {
  const now = Math.floor(Date.now() / 1000);
  const assertion = signJwt(
    { alg: 'RS256', typ: 'JWT' },
    {
      iss: serviceAccount.client_email,
      scope: 'https://www.googleapis.com/auth/androidpublisher',
      aud: 'https://oauth2.googleapis.com/token',
      iat: now,
      exp: now + 3600
    },
    serviceAccount.private_key
  );

  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion
    })
  });

  if (!response.ok) {
    throw new HttpsError('failed-precondition', 'Google Play verification authentication failed.');
  }

  const data = await response.json();
  if (!data.access_token) {
    throw new HttpsError('failed-precondition', 'Google Play verification token is missing.');
  }
  return data.access_token;
}

async function verifyGooglePlaySubscription(purchaseToken) {
  let serviceAccount;
  try {
    serviceAccount = JSON.parse(googlePlayServiceAccountJson.value());
  } catch (_) {
    throw new HttpsError('failed-precondition', 'Google Play service credentials are not configured.');
  }

  if (!serviceAccount.client_email || !serviceAccount.private_key) {
    throw new HttpsError('failed-precondition', 'Google Play service credentials are incomplete.');
  }

  const accessToken = await googleAccessToken(serviceAccount);
  const url =
    'https://androidpublisher.googleapis.com/androidpublisher/v3/applications/' +
    encodeURIComponent(ANDROID_PACKAGE_NAME) +
    '/purchases/subscriptionsv2/tokens/' +
    encodeURIComponent(purchaseToken);

  const response = await fetch(url, {
    headers: { Authorization: 'Bearer ' + accessToken }
  });

  if (!response.ok) {
    throw new HttpsError('failed-precondition', 'Google Play could not verify this Weekly Pass.');
  }

  const data = await response.json();
  const item = Array.isArray(data.lineItems)
    ? data.lineItems.find((line) => line.productId === WEEKLY_PASS_PRODUCT)
    : null;
  const expiryMs = item && item.expiryTime ? Date.parse(item.expiryTime) : 0;

  if (!item ||
      !expiryMs ||
      expiryMs <= Date.now() ||
      (data.subscriptionState !== 'SUBSCRIPTION_STATE_ACTIVE' &&
       data.subscriptionState !== 'SUBSCRIPTION_STATE_IN_GRACE_PERIOD')) {
    throw new HttpsError('failed-precondition', 'The Google Play Weekly Pass is not active.');
  }

  if (data.acknowledgementState === 'ACKNOWLEDGEMENT_STATE_PENDING') {
    const acknowledgeUrl =
      'https://androidpublisher.googleapis.com/androidpublisher/v3/applications/' +
      encodeURIComponent(ANDROID_PACKAGE_NAME) +
      '/purchases/subscriptions/' +
      encodeURIComponent(WEEKLY_PASS_PRODUCT) +
      '/tokens/' +
      encodeURIComponent(purchaseToken) +
      ':acknowledge';

    const ack = await fetch(acknowledgeUrl, {
      method: 'POST',
      headers: {
        Authorization: 'Bearer ' + accessToken,
        'content-type': 'application/json'
      },
      body: '{}'
    });
    if (!ack.ok && ack.status !== 409) {
      throw new HttpsError('failed-precondition', 'Google Play purchase acknowledgement failed.');
    }
  }

  return {
    transactionKey: purchaseToken,
    expiresAtMs: expiryMs,
    environment: data.testPurchase ? 'test' : 'production'
  };
}

async function appleApiToken() {
  const issuer = appleIssuerId.value();
  const keyId = appleKeyId.value();
  const privateKey = applePrivateKey.value().replace(/\\n/g, '\n');

  if (!issuer || !keyId || !privateKey) {
    throw new HttpsError('failed-precondition', 'Apple App Store verification credentials are not configured.');
  }

  const now = Math.floor(Date.now() / 1000);
  return signJwt(
    { alg: 'ES256', kid: keyId, typ: 'JWT' },
    {
      iss: issuer,
      iat: now,
      exp: now + 300,
      aud: 'appstoreconnect-v1'
    },
    privateKey,
    'EC'
  );
}

function transactionIdFromJws(value) {
  if (!value || value.split('.').length !== 3) return null;
  try {
    const payload = decodeBase64UrlJson(value.split('.')[1]);
    return payload.transactionId ? String(payload.transactionId) : null;
  } catch (_) {
    return null;
  }
}

async function verifyAppleTransaction(transactionId, submittedVerificationData) {
  const candidate = transactionId || transactionIdFromJws(submittedVerificationData);
  if (!candidate) {
    throw new HttpsError('invalid-argument', 'Apple transaction ID is required.');
  }

  const token = await appleApiToken();
  const endpoints = [
    'https://api.storekit.itunes.apple.com/inApps/v1/transactions/' + encodeURIComponent(candidate),
    'https://api.storekit-sandbox.itunes.apple.com/inApps/v1/transactions/' + encodeURIComponent(candidate)
  ];

  let data = null;
  for (const endpoint of endpoints) {
    const response = await fetch(endpoint, {
      headers: {
        Authorization: 'Bearer ' + token,
        Accept: 'application/json'
      }
    });
    if (response.ok) {
      data = await response.json();
      break;
    }
    if (response.status !== 404) {
      throw new HttpsError('failed-precondition', 'Apple could not verify this Weekly Pass.');
    }
  }

  if (!data || !data.signedTransactionInfo) {
    throw new HttpsError('failed-precondition', 'Apple transaction could not be resolved.');
  }

  let transaction;
  try {
    transaction = decodeBase64UrlJson(data.signedTransactionInfo.split('.')[1]);
  } catch (_) {
    throw new HttpsError('failed-precondition', 'Apple returned invalid transaction data.');
  }

  const expiryMs = Number(transaction.expiresDate || 0);
  if (transaction.bundleId !== APPLE_BUNDLE_ID ||
      transaction.productId !== WEEKLY_PASS_PRODUCT ||
      !expiryMs ||
      expiryMs <= Date.now() ||
      transaction.revocationDate) {
    throw new HttpsError('failed-precondition', 'The Apple Weekly Pass is not active.');
  }

  return {
    transactionKey: String(transaction.transactionId || candidate),
    expiresAtMs: expiryMs,
    environment: String(transaction.environment || 'Production').toLowerCase()
  };
}

exports.verifyWeeklyPassPurchase = onCall(
  {
    secrets: [
      googlePlayServiceAccountJson,
      appleIssuerId,
      appleKeyId,
      applePrivateKey
    ]
  },
  async (request) => {
    const uid = authUid(request);
    const productId = String(request.data && request.data.productId || '');
    const platform = String(request.data && request.data.platform || '');
    const verificationData = String(request.data && request.data.verificationData || '');
    const transactionId = request.data && request.data.transactionId
      ? String(request.data.transactionId)
      : '';

    if (productId !== WEEKLY_PASS_PRODUCT ||
        (platform !== 'android' && platform !== 'ios') ||
        !verificationData ||
        verificationData.length > 200000) {
      throw new HttpsError('invalid-argument', 'Invalid Weekly Pass purchase payload.');
    }

    const verified = platform === 'android'
      ? await verifyGooglePlaySubscription(verificationData)
      : await verifyAppleTransaction(transactionId, verificationData);

    const entitlementId = crypto
      .createHash('sha256')
      .update(platform + ':' + verified.transactionKey)
      .digest('hex');
    const entitlementRef = db.collection('purchaseEntitlements').doc(entitlementId);
    const profileRef = userRef(uid);

    return db.runTransaction(async (tx) => {
      const [entitlementSnap, profileSnap] = await Promise.all([
        tx.get(entitlementRef),
        tx.get(profileRef)
      ]);

      if (!profileSnap.exists) {
        throw new HttpsError('not-found', 'Profile not found.');
      }

      if (entitlementSnap.exists) {
        const previous = entitlementSnap.data();
        if (previous.uid !== uid) {
          throw new HttpsError('permission-denied', 'This store transaction belongs to another account.');
        }
      }

      const currentExpiry = profileSnap.data().weeklyPassExpiresAt;
      const currentExpiryMs = currentExpiry && currentExpiry.toMillis
        ? currentExpiry.toMillis()
        : 0;
      const nextExpiryMs = Math.max(currentExpiryMs, verified.expiresAtMs);

      tx.set(entitlementRef, {
        uid,
        platform,
        productId,
        transactionKey: verified.transactionKey,
        expiresAt: Timestamp.fromMillis(verified.expiresAtMs),
        environment: verified.environment,
        verifiedAt: Timestamp.now()
      }, { merge: true });

      tx.update(profileRef, {
        weeklyPassExpiresAt: Timestamp.fromMillis(nextExpiryMs),
        updatedAt: Timestamp.now()
      });

      return {
        ok: true,
        expiresAtMs: nextExpiryMs,
        environment: verified.environment
      };
    });
  }
);

exports.expireWeeklyPass = onCall(async (request) => {
  authUid(request);
  const uid = String(request.data && request.data.uid || '');
  if (!uid) throw new HttpsError('invalid-argument', 'uid is required.');
  throw new HttpsError('permission-denied', 'Weekly Pass expiry is managed by verified store entitlement.');
});
