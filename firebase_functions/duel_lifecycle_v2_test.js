'use strict';

const assert = require('assert');
const {
  validateQuestionPlan,
  submitAnswer,
  finalizeDuel,
  publicDuelState,
} = require('./duel_lifecycle_v2');

const p1Plan = Array.from({ length: 7 }, (_, i) => ({ packId: `b${i}`, questionId: `q1-${i}`, correctIndex: i % 3 }));
const p2Plan = Array.from({ length: 7 }, (_, i) => ({ packId: `a${i}`, questionId: `q2-${i}`, correctIndex: (i + 1) % 3 }));
const secret = { p1QuestionPlan: p1Plan, p2QuestionPlan: p2Plan };

function baseDuel() {
  return {
    duelId: 'd1',
    status: 'matched',
    p1Uid: 'p1',
    p2Uid: 'p2',
    questionPlanReady: true,
    p1Answers: [],
    p2Answers: [],
    deadlineAt: new Date(Date.now() + 60000).toISOString(),
    stealConfirmed: false,
  };
}

assert.strictEqual(validateQuestionPlan(p1Plan), true);
assert.strictEqual(validateQuestionPlan(p1Plan.slice(0, 6)), false);

let duel = baseDuel();
duel = submitAnswer({ duel, secret, uid: 'p1', questionIndex: 0, selectedIndex: 0, elapsedMs: 1000 });
assert.strictEqual(duel.p1Answers.length, 1);
assert.strictEqual(duel.p1Answers[0].correct, true);
assert.strictEqual(duel.status, 'playing');
assert.throws(() => submitAnswer({ duel, secret, uid: 'p1', questionIndex: 0, selectedIndex: 0, elapsedMs: 1 }));

for (let i = 1; i < 7; i += 1) {
  duel = submitAnswer({ duel, secret, uid: 'p1', questionIndex: i, selectedIndex: p1Plan[i].correctIndex, elapsedMs: 1000 });
}
for (let i = 0; i < 7; i += 1) {
  const selectedIndex = i === 6 ? (p2Plan[i].correctIndex + 1) % 3 : p2Plan[i].correctIndex;
  duel = submitAnswer({ duel, secret, uid: 'p2', questionIndex: i, selectedIndex, elapsedMs: 900 });
}

const finished = finalizeDuel(duel);
assert.strictEqual(finished.status, 'finished');
assert.strictEqual(finished.winnerUid, 'p1');
assert.strictEqual(finished.loserUid, 'p2');
assert.strictEqual(finished.p1Score.correctAnswers, 7);
assert.strictEqual(finished.p2Score.correctAnswers, 6);

const state = publicDuelState(finished, 'p1');
assert.strictEqual(state.answeredCount, 7);
assert.strictEqual(state.opponentAnsweredCount, 7);
assert.strictEqual(state.totalQuestions, 7);

const timedOut = baseDuel();
timedOut.deadlineAt = new Date(Date.now() - 1).toISOString();
const timeoutResult = finalizeDuel(timedOut);
assert.strictEqual(timeoutResult.result, 'draw');
assert.strictEqual(timeoutResult.p1Score.totalElapsedMs, 140000);
assert.strictEqual(timeoutResult.p2Score.totalElapsedMs, 140000);

console.log('duel_lifecycle_v2 tests passed');
