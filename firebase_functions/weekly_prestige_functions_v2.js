'use strict';

const admin = require('firebase-admin');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { Timestamp } = admin.firestore;
const { normalizeProfileV2, applyPrestigeV2 } = require('./player_profile_v2');
const { previousWeekKey } = require('./profile_features_engine_v2');
const { topThree, rewardDocumentId } = require('./weekly_prestige_engine_v2');

const db = admin.firestore();

async function applyPodiumReward(weekKey, entry) {
  const userRef = db.collection('users').doc(entry.uid);
  const rewardRef = db.collection('rankingRewardsV2').doc(rewardDocumentId(weekKey, entry.uid));
  return db.runTransaction(async (tx) => {
    const [userSnap, rewardSnap] = await Promise.all([
      tx.get(userRef),
      tx.get(rewardRef),
    ]);
    if (!userSnap.exists) return false;
    if (rewardSnap.exists && rewardSnap.data().applied === true) return false;

    const data = userSnap.data();
    const current = normalizeProfileV2(data.profileV2 || {});
    const next = applyPrestigeV2(current, entry.place);
    const now = Timestamp.now();
    tx.update(userRef, {
      profileV2: next,
      schemaVersion: 2,
      updatedAt: now,
    });
    tx.set(rewardRef, {
      schemaVersion: 2,
      weekKey,
      uid: entry.uid,
      displayName: entry.displayName,
      place: entry.place,
      weeklyPoints: entry.weeklyPoints,
      weeklyWins: entry.weeklyWins,
      applied: true,
      appliedAt: now,
    }, { merge: false });
    return true;
  });
}

const awardPreviousWeekPrestigeV2 = onSchedule({
  schedule: '10 0 * * 1',
  timeZone: 'Etc/UTC',
  retryCount: 3,
}, async () => {
  const weekKey = previousWeekKey();
  const snap = await db.collection('weeklyRankingV2').doc(weekKey).collection('players').limit(1000).get();
  if (snap.empty) return;
  const entries = snap.docs.map((doc) => ({ uid: doc.id, ...doc.data() }));
  const podium = topThree(entries);
  for (const entry of podium) {
    await applyPodiumReward(weekKey, entry);
  }
});

module.exports = {
  awardPreviousWeekPrestigeV2,
};
