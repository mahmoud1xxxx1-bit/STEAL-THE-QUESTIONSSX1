'use strict';

const { DUEL_PACKS } = require('./core_engine_v2');
const { QUESTION_TIMEOUT_MS, scoreAnswers, resultForPlayer } = require('./duel_engine_v2');

const STATUS_MATCHED = 'matched';
const STATUS_PLAYING = 'playing';
const STATUS_FINISHED = 'finished';

function questionPlanForPlayer(secret, uid, duel) {
  if (!secret || !duel) throw new Error('Missing duel data.');
  if (uid === duel.p1Uid) return Array.isArray(secret.p1QuestionPlan) ? secret.p1QuestionPlan : [];
  if (uid === duel.p2Uid) return Array.isArray(secret.p2QuestionPlan) ? secret.p2QuestionPlan : [];
  throw new Error('Player is not part of this duel.');
}

function answerKeyForPlayer(uid, duel) {
  if (uid === duel.p1Uid) return 'p1Answers';
  if (uid === duel.p2Uid) return 'p2Answers';
  throw new Error('Player is not part of this duel.');
}

function validateQuestionPlan(plan) {
  if (!Array.isArray(plan) || plan.length !== DUEL_PACKS) return false;
  const ids = new Set();
  for (let index = 0; index < plan.length; index += 1) {
    const item = plan[index];
    if (!item || typeof item !== 'object') return false;
    if (!item.questionId || !item.packId) return false;
    if (!Number.isInteger(item.correctIndex) || item.correctIndex < 0 || item.correctIndex > 3) return false;
    if (ids.has(String(item.questionId))) return false;
    ids.add(String(item.questionId));
  }
  return true;
}

function publicDuelState(duel, uid) {
  if (!duel || (uid !== duel.p1Uid && uid !== duel.p2Uid)) throw new Error('Player is not part of this duel.');
  const mine = uid === duel.p1Uid ? 'p1' : 'p2';
  const opponent = mine === 'p1' ? 'p2' : 'p1';
  const answers = Array.isArray(duel[`${mine}Answers`]) ? duel[`${mine}Answers`] : [];
  const opponentAnswers = Array.isArray(duel[`${opponent}Answers`]) ? duel[`${opponent}Answers`] : [];
  return {
    duelId: String(duel.duelId || ''),
    status: String(duel.status || STATUS_MATCHED),
    questionPlanReady: duel.questionPlanReady === true,
    answeredCount: answers.length,
    opponentAnsweredCount: opponentAnswers.length,
    totalQuestions: DUEL_PACKS,
    deadlineAt: duel.deadlineAt || null,
    winnerUid: duel.winnerUid || null,
    loserUid: duel.loserUid || null,
    result: duel.result || null,
    stealConfirmed: duel.stealConfirmed === true,
    stolenPackId: duel.stolenPackId || null,
  };
}

function submitAnswer({ duel, secret, uid, questionIndex, selectedIndex, elapsedMs }) {
  if (!duel || !secret) throw new Error('Missing duel data.');
  if (duel.status === STATUS_FINISHED) throw new Error('Duel already finished.');
  if (duel.questionPlanReady !== true) throw new Error('Question plan is not ready.');
  const plan = questionPlanForPlayer(secret, uid, duel);
  if (!validateQuestionPlan(plan)) throw new Error('Invalid question plan.');
  if (!Number.isInteger(questionIndex) || questionIndex < 0 || questionIndex >= DUEL_PACKS) throw new Error('Invalid question index.');
  if (!Number.isInteger(selectedIndex) || selectedIndex < 0 || selectedIndex > 3) throw new Error('Invalid selected answer index.');

  const answersKey = answerKeyForPlayer(uid, duel);
  const answers = Array.isArray(duel[answersKey]) ? [...duel[answersKey]] : [];
  if (questionIndex !== answers.length) throw new Error('Questions must be answered in order and exactly once.');

  const planItem = plan[questionIndex];
  const normalizedElapsed = Math.min(QUESTION_TIMEOUT_MS, Math.max(0, Number(elapsedMs) || 0));
  answers.push({
    questionIndex,
    questionId: String(planItem.questionId),
    packId: String(planItem.packId),
    selectedIndex,
    correct: selectedIndex === planItem.correctIndex,
    elapsedMs: Math.floor(normalizedElapsed),
  });

  const next = { ...duel, [answersKey]: answers };
  if (next.status === STATUS_MATCHED) next.status = STATUS_PLAYING;
  return next;
}

function canFinalize(duel, nowMs) {
  const p1Answers = Array.isArray(duel.p1Answers) ? duel.p1Answers : [];
  const p2Answers = Array.isArray(duel.p2Answers) ? duel.p2Answers : [];
  if (p1Answers.length === DUEL_PACKS && p2Answers.length === DUEL_PACKS) return true;
  const deadlineMs = duel.deadlineAt && typeof duel.deadlineAt.toMillis === 'function'
    ? duel.deadlineAt.toMillis()
    : Date.parse(String(duel.deadlineAt || ''));
  return Number.isFinite(deadlineMs) && nowMs >= deadlineMs;
}

function paddedAnswers(answers) {
  const result = Array.isArray(answers) ? [...answers] : [];
  while (result.length < DUEL_PACKS) {
    result.push({ correct: false, elapsedMs: QUESTION_TIMEOUT_MS });
  }
  return result.slice(0, DUEL_PACKS);
}

function finalizeDuel(duel, nowMs = Date.now()) {
  if (!duel) throw new Error('Missing duel.');
  if (duel.status === STATUS_FINISHED) return duel;
  if (!canFinalize(duel, nowMs)) throw new Error('Duel cannot be finalized yet.');

  const p1Score = scoreAnswers(paddedAnswers(duel.p1Answers));
  const p2Score = scoreAnswers(paddedAnswers(duel.p2Answers));
  const p1Result = resultForPlayer(p1Score, p2Score);

  if (p1Result === 'draw') {
    return {
      ...duel,
      status: STATUS_FINISHED,
      result: 'draw',
      winnerUid: null,
      loserUid: null,
      p1Score,
      p2Score,
    };
  }

  const p1Won = p1Result === 'win';
  return {
    ...duel,
    status: STATUS_FINISHED,
    result: 'win',
    winnerUid: p1Won ? duel.p1Uid : duel.p2Uid,
    loserUid: p1Won ? duel.p2Uid : duel.p1Uid,
    p1Score,
    p2Score,
  };
}

module.exports = {
  STATUS_MATCHED,
  STATUS_PLAYING,
  STATUS_FINISHED,
  validateQuestionPlan,
  publicDuelState,
  submitAnswer,
  canFinalize,
  finalizeDuel,
};
