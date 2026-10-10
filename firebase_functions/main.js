'use strict';

// V2-only Firebase entry point.
// The retired 222-card / rarity / Weekly Pass backend is no longer exported.
// No real question content is bundled here; content lives in cardsV2 only.

const v2 = require('./v2_functions');
const matchmakingV2 = require('./matchmaking_functions_v2');
const duelV2 = require('./duel_functions_v2');
const botV2 = require('./bot_functions_v2');
const customAnswersV2 = require('./custom_answers_functions_v2');
const profileFeaturesV2 = require('./profile_features_functions_v2');
const weeklyRankingV2 = require('./weekly_ranking_functions_v2');
const weeklyPrestigeV2 = require('./weekly_prestige_functions_v2');
const purchaseVerificationV2 = require('./purchase_verification_functions_v2');
const cardLifecycleV2 = require('./card_lifecycle_functions_v2');
const adminV2 = require('./admin_functions_v2');

module.exports = {
  ...v2,
  ...matchmakingV2,
  ...duelV2,
  ...botV2,
  ...customAnswersV2,
  ...profileFeaturesV2,
  ...weeklyRankingV2,
  ...weeklyPrestigeV2,
  ...purchaseVerificationV2,
  ...cardLifecycleV2,
  ...adminV2,
};
