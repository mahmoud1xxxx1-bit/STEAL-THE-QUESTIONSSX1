'use strict';

const admin = require('firebase-admin');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { normalizeProfileV2 } = require('./player_profile_v2');
const { entitlement } = require('./core_engine_v2');
const {
  unlockedPrestige,
  equipPrestige,
  normalizeVerifiedEntitlement,
} = require('./profile_features_engine_v2');

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

function cleanUid(value, fallback) {
  const uid = String(value || fallback || '').trim();
  if (!uid || uid.includes('/')) throw new HttpsError('invalid-argument', 'uid is invalid.');
  return uid;
}

function publicProfile(uid, data, rarityCounts = {}) {
  const profile = profileFromData(data);
  const unlocked = unlockedPrestige(profile);
  return {
    uid,
    displayName: data.displayName || 'PLAYER',
    ownedCount: profile.ownedPackIds.length,
    totalWins: profile.totalWins,
    totalLosses: profile.totalLosses,
    totalDraws: profile.totalDraws,
    weeklySteals: profile.weeklySteals,
    totalSteals: profile.totalSteals,
    epicCount: Number(rarityCounts.epic || 0),
    goldCount: Number(rarityCounts.gold || 0),
    legendaryCount: Number(rarityCounts.legendary || 0),
    prestige: profile.prestige,
    currentTitleKey: profile.currentTitleKey,
    currentFrameKey: profile.currentFrameKey,
    unlockedTitleKeys: unlocked.titles,
    unlockedFrameKeys: unlocked.frames,
  };
}

const getPublicProfileV2 = onCall(async (request) => {
  const requesterUid = authUid(request);
  const targetUid = cleanUid(request.data && request.data.uid, requesterUid);
  const snap = await db.collection('users').doc(targetUid).get();
  if (!snap.exists) throw new HttpsError('not-found', 'Profile not found.');
  const profile = profileFromData(snap.data());
  const refs = profile.ownedPackIds.map((id) => db.collection('cardsV2').doc(id));
  const rarityCounts = { epic: 0, gold: 0, legendary: 0 };
  if (refs.length) {
    const cards = await db.getAll(...refs);
    for (const card of cards) {
      if (!card.exists) continue;
      const rarity = String(card.data().rarity || 'epic').toLowerCase();
      const copies = Math.max(1, Number(profile.ownedPackCounts[card.id] || 1) | 0);
      if (Object.prototype.hasOwnProperty.call(rarityCounts, rarity)) {
        rarityCounts[rarity] += copies;
      }
    }
  }
  return { profile: publicProfile(targetUid, snap.data(), rarityCounts) };
});


const getHallOfLegendsV2 = onCall(async (request) => {
  authUid(request);
  const cardSnaps = await db.collection('cardsV2')
    .where('rarity', '==', 'legendary')
    .get();

  const cards = [];
  for (const cardSnap of cardSnaps.docs) {
    const cardData = cardSnap.data();
    if (cardData.enabled === false) continue;

    const holderSnaps = await db.collection('users')
      .where('profileV2.ownedPackIds', 'array-contains', cardSnap.id)
      .get();

    const holders = [];
    let ownedCopies = 0;
    for (const holderSnap of holderSnaps.docs) {
      const holderData = holderSnap.data();
      const profile = profileFromData(holderData);
      const copies = Math.max(1, Number(profile.ownedPackCounts[cardSnap.id] || 1) | 0);
      ownedCopies += copies;
      holders.push({
        displayName: holderData.displayName || 'PLAYER',
        copies,
      });
    }
    holders.sort((a, b) =>
      b.copies - a.copies || String(a.displayName).localeCompare(String(b.displayName)));

    const availableCopies = Math.max(0, Number(cardData.availableCopies || 0) | 0);
    cards.push({
      cardId: cardSnap.id,
      titleAr: String(cardData.titleAr || cardSnap.id),
      titleEn: String(cardData.titleEn || cardSnap.id),
      availableCopies,
      ownedCopies,
      totalCopies: availableCopies + ownedCopies,
      holders,
    });
  }

  cards.sort((a, b) =>
    b.ownedCopies - a.ownedCopies || String(a.cardId).localeCompare(String(b.cardId)));
  return { cards };
});

const equipPrestigeV2 = onCall(async (request) => {
  const uid = authUid(request);
  const titleKey = request.data && request.data.titleKey != null
    ? String(request.data.titleKey)
    : null;
  const frameKey = request.data && request.data.frameKey != null
    ? String(request.data.frameKey)
    : null;
  const ref = db.collection('users').doc(uid);
  const next = await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) throw new HttpsError('not-found', 'Profile not found.');
    const current = profileFromData(snap.data());
    let updated;
    try {
      updated = equipPrestige(current, { titleKey, frameKey });
    } catch (error) {
      throw new HttpsError('failed-precondition', error.message || 'Prestige reward is not unlocked.');
    }
    tx.update(ref, {
      profileV2: updated,
      schemaVersion: 2,
      updatedAt: Timestamp.now(),
    });
    return updated;
  });
  return { profile: next, unlocked: unlockedPrestige(next) };
});

const refreshSubscriptionV2 = onCall(async (request) => {
  const uid = authUid(request);
  const userRef = db.collection('users').doc(uid);
  const entitlementRef = db.collection('purchaseEntitlementsV2').doc(uid);
  return db.runTransaction(async (tx) => {
    const [userSnap, entitlementSnap] = await Promise.all([
      tx.get(userRef),
      tx.get(entitlementRef),
    ]);
    if (!userSnap.exists) throw new HttpsError('not-found', 'Profile not found.');

    const current = profileFromData(userSnap.data());
    const verified = normalizeVerifiedEntitlement(
      entitlementSnap.exists ? entitlementSnap.data() : null,
    );
    const next = {
      ...current,
      subscriptionActive: verified.active,
      subscriptionExpiresAt: verified.active
        ? Timestamp.fromMillis(verified.expiresAtMs)
        : null,
    };
    if (!verified.active && next.activeDeckIndex >= 2) next.activeDeckIndex = 0;

    tx.update(userRef, {
      profileV2: next,
      schemaVersion: 2,
      updatedAt: Timestamp.now(),
    });

    const limits = entitlement(verified.active);
    return {
      active: verified.active,
      expiresAtMs: verified.expiresAtMs,
      source: verified.source,
      productId: verified.productId,
      deckSlots: limits.deckSlots,
      answerChoices: limits.answerChoices,
      editableWrongChoices: limits.editableWrongChoices,
      profile: next,
    };
  });
});

const getSubscriptionStatusV2 = onCall(async (request) => {
  const uid = authUid(request);
  const [userSnap, entitlementSnap] = await Promise.all([
    db.collection('users').doc(uid).get(),
    db.collection('purchaseEntitlementsV2').doc(uid).get(),
  ]);
  if (!userSnap.exists) throw new HttpsError('not-found', 'Profile not found.');
  const verified = normalizeVerifiedEntitlement(
    entitlementSnap.exists ? entitlementSnap.data() : null,
  );
  const limits = entitlement(verified.active);
  return {
    active: verified.active,
    expiresAtMs: verified.expiresAtMs,
    source: verified.source,
    productId: verified.productId,
    deckSlots: limits.deckSlots,
    answerChoices: limits.answerChoices,
    editableWrongChoices: limits.editableWrongChoices,
  };
});

module.exports = {
  getPublicProfileV2,
  getHallOfLegendsV2,
  equipPrestigeV2,
  refreshSubscriptionV2,
  getSubscriptionStatusV2,
};
