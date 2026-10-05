'use strict';

// Transitional Firebase entry point.
// Keeps all current production callables available while V2 replaces them
// feature-by-feature. No real question content is added here.

const legacy = require('./index');
const v2 = require('./v2_functions');
const matchmakingV2 = require('./matchmaking_functions_v2');
const duelV2 = require('./duel_functions_v2');
const botV2 = require('./bot_functions_v2');
const customAnswersV2 = require('./custom_answers_functions_v2');

module.exports = {
  ...legacy,
  ...v2,
  ...matchmakingV2,
  ...duelV2,
  ...botV2,
  ...customAnswersV2,
};
