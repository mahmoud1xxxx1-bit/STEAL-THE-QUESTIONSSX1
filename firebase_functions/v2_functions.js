'use strict';

const admin = require('firebase-admin');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const {
  emptyProfileV2,
  normalizeProfileV2,
  saveDeckV2,
} = require('./player_profile_v2');

const db = admin.firestore();
const { Timestamp } = admin.firestore;

function authUid(request) {
  const uid = request.auth && request.auth.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Authentication required.');
  return uid;
}

function userRef(uid) {
  return db.collection('users').doc(uid);
}

function profileFromUserData(data) {
  if (data && data.profileV2 && typeof data.profileV2 === 'object') {
    return normalizeProfileV2(data.profileV2);
  }
  return emptyProfileV2();
}

const ensureProfileV2 = onCall(async (request) => {
  const uid = authUid(request);
  const ref = userRef(uid);
  const result = await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const existing = snap.exists ? snap.data() : {};
    const profile = profileFromUserData(existing);
    tx.set(ref, {
      uid,
      displayName: existing.displayName || (request.auth.token.email || '').split('@')[0] || 'PLAYER',
      email: existing.email || request.auth.token.email || null,
      profileV2: profile,
      schemaVersion: 2,
      updatedAt: Timestamp.now(),
      ...(snap.exists ? {} : { createdAt: Timestamp.now() }),
    }, { merge: true });
    return profile;
  });
  return { profile: result };
});

const getProfileV2 = onCall(async (request) => {
  const uid = authUid(request);
  const snap = await userRef(uid).get();
  if (!snap.exists) throw new HttpsError('not-found', 'Profile not found.');
  return { profile: profileFromUserData(snap.data()) };
});

const saveDeckV2Callable = onCall(async (request) => {
  const uid = authUid(request);
  const deckIndex = Number(request.data && request.data.deckIndex);
  const packIds = Array.isArray(request.data && request.data.packIds)
    ? request.data.packIds.map(String)
    : [];
  const ref = userRef(uid);

  const profile = await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) throw new HttpsError('not-found', 'Profile not found.');
    const current = profileFromUserData(snap.data());
    let next;
    try {
      next = saveDeckV2(current, deckIndex, packIds);
    } catch (_) {
      throw new HttpsError('failed-precondition', 'Deck must contain exactly 10 distinct owned cards in an unlocked slot.');
    }
    tx.update(ref, {
      profileV2: next,
      schemaVersion: 2,
      updatedAt: Timestamp.now(),
    });
    return next;
  });

  return { ok: true, profile };
});

const setActiveDeckV2 = onCall(async (request) => {
  const uid = authUid(request);
  const deckIndex = Number(request.data && request.data.deckIndex);
  const ref = userRef(uid);

  const profile = await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) throw new HttpsError('not-found', 'Profile not found.');
    const current = profileFromUserData(snap.data());
    const slots = current.subscriptionActive ? 5 : 2;
    if (!Number.isInteger(deckIndex) || deckIndex < 0 || deckIndex >= slots) {
      throw new HttpsError('permission-denied', 'Deck slot is locked or invalid.');
    }
    const next = { ...current, activeDeckIndex: deckIndex };
    tx.update(ref, {
      profileV2: next,
      schemaVersion: 2,
      updatedAt: Timestamp.now(),
    });
    return next;
  });

  return { ok: true, profile };
});

module.exports = {
  ensureProfileV2,
  getProfileV2,
  saveDeckV2: saveDeckV2Callable,
  setActiveDeckV2,
};
