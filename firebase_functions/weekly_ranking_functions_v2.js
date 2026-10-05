'use strict';

const admin = require('firebase-admin');
const { onDocumentWritten } = require('firebase-functions/v2/firestore');
const { normalizeProfileV2 } = require('./player_profile_v2');

const db = admin.firestore();
const { Timestamp } = admin.firestore;

const syncWeeklyRankingV2 = onDocumentWritten('users/{uid}', async (event) => {
  const after = event.data && event.data.after;
  if (!after || !after.exists) return;
  const data = after.data();
  if (!data || !data.profileV2) return;
  const profile = normalizeProfileV2(data.profileV2);
  const uid = String(event.params.uid);
  const ref = db.collection('weeklyRankingV2').doc(profile.weekKey).collection('players').doc(uid);
  await ref.set({
    schemaVersion: 2,
    uid,
    displayName: data.displayName || 'PLAYER',
    weeklyPoints: profile.weeklyPoints,
    weeklyWins: profile.weeklyWins,
    weeklyLosses: profile.weeklyLosses,
    weeklyDraws: profile.weeklyDraws,
    currentTitleKey: profile.currentTitleKey,
    currentFrameKey: profile.currentFrameKey,
    updatedAt: Timestamp.now(),
  }, { merge: true });
});

module.exports = {
  syncWeeklyRankingV2,
};
