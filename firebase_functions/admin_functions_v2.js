'use strict';

const admin = require('firebase-admin');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { normalizeProfileV2 } = require('./player_profile_v2');
const { weekKey } = require('./core_engine_v2');

const db = admin.firestore();
const { Timestamp } = admin.firestore;
const PRIMARY_ADMIN_EMAIL = 'love.dotk@gmail.com';

function cleanEmail(value) {
  return String(value || '').trim().toLowerCase();
}

async function requireAdmin(request) {
  const uid = request.auth && request.auth.uid;
  const email = cleanEmail(request.auth && request.auth.token && request.auth.token.email);
  if (!uid || !email) throw new HttpsError('unauthenticated', 'Authentication required.');
  if (email === PRIMARY_ADMIN_EMAIL) return { uid, email };

  const snap = await db.collection('adminEmailsV2').doc(email).get();
  if (!snap.exists || snap.data().enabled !== true) {
    throw new HttpsError('permission-denied', 'Admin access required.');
  }
  return { uid, email };
}

async function audit(actor, action, target, details = {}) {
  await db.collection('adminAuditV2').add({
    actorUid: actor.uid,
    actorEmail: actor.email,
    action,
    target,
    details,
    createdAt: Timestamp.now(),
  });
}

function publicPlayerRow(doc) {
  const data = doc.data();
  const profile = normalizeProfileV2(data.profileV2 || {});
  return {
    uid: doc.id,
    displayName: data.displayName || 'PLAYER',
    email: data.email || null,
    ownedCount: profile.ownedPackIds.length,
    weeklyPoints: profile.weeklyPoints,
    weeklySteals: profile.weeklySteals,
    totalSteals: profile.totalSteals,
    totalWins: profile.totalWins,
    totalLosses: profile.totalLosses,
    totalDraws: profile.totalDraws,
    subscriptionActive: profile.subscriptionActive === true,
    activeDuelV2: data.activeDuelV2 || null,
    suspended: data.suspendedV2 === true,
    suspensionReason: data.suspensionReasonV2 || null,
    currentTitleKey: profile.currentTitleKey,
    currentFrameKey: profile.currentFrameKey,
  };
}

const getAdminOverviewV2 = onCall(async (request) => {
  await requireAdmin(request);

  const [usersSnap, cardsSnap, duelsSnap, entitlementsSnap] = await Promise.all([
    db.collection('users').get(),
    db.collection('cardsV2').get(),
    db.collection('duelsV2').orderBy('createdAt', 'desc').limit(100).get(),
    db.collection('purchaseEntitlementsV2').get(),
  ]);

  let legendaryCards = 0;
  let availableLegendaryCopies = 0;
  for (const doc of cardsSnap.docs) {
    const data = doc.data();
    if (String(data.rarity || '').toLowerCase() === 'legendary') {
      legendaryCards += 1;
      availableLegendaryCopies += Math.max(0, Number(data.availableCopies || 0) | 0);
    }
  }

  let activeDuels = 0;
  for (const doc of duelsSnap.docs) {
    const status = String(doc.data().status || '');
    if (status !== 'finished' && status !== 'cancelled_by_admin') activeDuels += 1;
  }

  let activeSubscriptions = 0;
  const nowMs = Date.now();
  for (const doc of entitlementsSnap.docs) {
    const data = doc.data();
    const expiresAt = data.expiresAt;
    const expiresAtMs = expiresAt && typeof expiresAt.toMillis === 'function'
      ? expiresAt.toMillis()
      : Number(data.expiresAtMs || 0);
    if (data.active === true && expiresAtMs > nowMs) activeSubscriptions += 1;
  }

  return {
    users: usersSnap.size,
    cards: cardsSnap.size,
    legendaryCards,
    availableLegendaryCopies,
    activeDuels,
    activeSubscriptions,
  };
});

const listAdminPlayersV2 = onCall(async (request) => {
  await requireAdmin(request);
  const limit = Math.min(200, Math.max(1, Number(request.data && request.data.limit || 100) | 0));
  const snap = await db.collection('users').orderBy('updatedAt', 'desc').limit(limit).get();
  return { players: snap.docs.map(publicPlayerRow) };
});

const updateAdminPlayerStatsV2 = onCall(async (request) => {
  const actor = await requireAdmin(request);
  const uid = String(request.data && request.data.uid || '').trim();
  if (!uid || uid.includes('/')) throw new HttpsError('invalid-argument', 'Invalid player uid.');

  const allowed = ['weeklyPoints', 'weeklySteals', 'totalSteals'];
  const patch = {};
  for (const key of allowed) {
    if (request.data && request.data[key] != null) {
      const value = Number(request.data[key]);
      if (!Number.isInteger(value) || value < 0) {
        throw new HttpsError('invalid-argument', key + ' must be a non-negative integer.');
      }
      patch[key] = value;
    }
  }
  if (!Object.keys(patch).length) {
    throw new HttpsError('invalid-argument', 'No supported stat changes supplied.');
  }

  const ref = db.collection('users').doc(uid);
  const next = await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) throw new HttpsError('not-found', 'Player not found.');
    const data = snap.data();
    const profile = normalizeProfileV2(data.profileV2 || {});
    const updated = { ...profile, ...patch };
    tx.update(ref, {
      profileV2: updated,
      schemaVersion: 2,
      updatedAt: Timestamp.now(),
    });
    return updated;
  });

  await audit(actor, 'update_player_stats', uid, patch);
  return { ok: true, profile: next };
});


const setAdminPlayerSuspensionV2 = onCall(async (request) => {
  const actor = await requireAdmin(request);
  const uid = String(request.data && request.data.uid || '').trim();
  const suspended = request.data && request.data.suspended === true;
  const reason = String(request.data && request.data.reason || '').trim().slice(0, 200);
  if (!uid || uid.includes('/')) throw new HttpsError('invalid-argument', 'Invalid player uid.');
  if (uid === actor.uid && suspended) {
    throw new HttpsError('failed-precondition', 'Admin cannot suspend the current admin account.');
  }

  const userRef = db.collection('users').doc(uid);
  const result = await db.runTransaction(async (tx) => {
    const userSnap = await tx.get(userRef);
    if (!userSnap.exists) throw new HttpsError('not-found', 'Player not found.');
    const userData = userSnap.data();
    const activeDuelId = userData.activeDuelV2 ? String(userData.activeDuelV2) : null;

    let duel = null;
    let duelRef = null;
    if (suspended && activeDuelId) {
      duelRef = db.collection('duelsV2').doc(activeDuelId);
      const duelSnap = await tx.get(duelRef);
      if (duelSnap.exists) duel = duelSnap.data();
    }

    const now = Timestamp.now();
    tx.set(userRef, {
      suspendedV2: suspended,
      suspensionReasonV2: suspended ? (reason || 'ADMIN_SUSPENSION') : null,
      suspendedAtV2: suspended ? now : null,
      suspendedByV2: suspended ? actor.email : null,
      activeBotRoundV2: suspended ? null : (userData.activeBotRoundV2 || null),
      activeDuelV2: suspended ? null : (userData.activeDuelV2 || null),
      updatedAt: now,
    }, { merge: true });

    if (suspended) {
      tx.delete(db.collection('matchQueueV2').doc(uid));
    }

    const released = [];
    if (suspended && duel && duelRef &&
        duel.status !== 'finished' && duel.status !== 'cancelled_by_admin') {
      const participants = [duel.p1Uid, duel.p2Uid].filter(Boolean).map(String);
      for (const participantUid of participants) {
        tx.set(db.collection('users').doc(participantUid), {
          activeDuelV2: null,
          updatedAt: now,
        }, { merge: true });
        tx.delete(db.collection('matchQueueV2').doc(participantUid));
        released.push(participantUid);
      }
      tx.set(duelRef, {
        status: 'cancelled_by_admin',
        cancelledByAdmin: true,
        cancellationReason: 'player_suspended',
        cancelledAt: now,
        updatedAt: now,
      }, { merge: true });
      tx.delete(db.collection('duelSecretsV2').doc(activeDuelId));
    }

    return { activeDuelId, released };
  });

  await audit(
    actor,
    suspended ? 'suspend_player' : 'unsuspend_player',
    uid,
    { reason: suspended ? (reason || 'ADMIN_SUSPENSION') : null, ...result },
  );
  return { ok: true, suspended };
});

const listAdminDuelsV2 = onCall(async (request) => {
  await requireAdmin(request);
  const limit = Math.min(200, Math.max(1, Number(request.data && request.data.limit || 100) | 0));
  const snap = await db.collection('duelsV2').orderBy('createdAt', 'desc').limit(limit).get();
  return {
    duels: snap.docs.map((doc) => {
      const data = doc.data();
      return {
        duelId: doc.id,
        status: String(data.status || ''),
        p1Uid: data.p1Uid || null,
        p2Uid: data.p2Uid || null,
        winnerUid: data.winnerUid || null,
        loserUid: data.loserUid || null,
        stealConfirmed: data.stealConfirmed === true,
        stolenPackId: data.stolenPackId || null,
      };
    }),
  };
});

const cancelAdminDuelV2 = onCall(async (request) => {
  const actor = await requireAdmin(request);
  const duelId = String(request.data && request.data.duelId || '').trim();
  if (!duelId || duelId.includes('/')) throw new HttpsError('invalid-argument', 'Invalid duel id.');

  const duelRef = db.collection('duelsV2').doc(duelId);
  const result = await db.runTransaction(async (tx) => {
    const duelSnap = await tx.get(duelRef);
    if (!duelSnap.exists) throw new HttpsError('not-found', 'Duel not found.');
    const duel = duelSnap.data();
    if (duel.status === 'finished') {
      throw new HttpsError('failed-precondition', 'Finished duels cannot be cancelled.');
    }

    const now = Timestamp.now();
    const uids = [duel.p1Uid, duel.p2Uid].filter(Boolean).map(String);
    for (const uid of uids) {
      tx.set(db.collection('users').doc(uid), {
        activeDuelV2: null,
        updatedAt: now,
      }, { merge: true });
      tx.delete(db.collection('matchQueueV2').doc(uid));
    }
    tx.set(duelRef, {
      status: 'cancelled_by_admin',
      cancelledByAdmin: true,
      cancelledAt: now,
      updatedAt: now,
    }, { merge: true });
    tx.delete(db.collection('duelSecretsV2').doc(duelId));
    return { uids };
  });

  await audit(actor, 'cancel_duel', duelId, result);
  return { ok: true };
});


const listAdminRankingV2 = onCall(async (request) => {
  await requireAdmin(request);
  const currentWeek = weekKey(Date.now());
  const snap = await db.collection('weeklyRankingV2')
    .doc(currentWeek)
    .collection('players')
    .orderBy('weeklyPoints', 'desc')
    .limit(100)
    .get();
  return {
    weekKey: currentWeek,
    players: snap.docs.map((doc, index) => {
      const data = doc.data();
      return {
        rank: index + 1,
        uid: doc.id,
        displayName: data.displayName || 'PLAYER',
        weeklyPoints: Number(data.weeklyPoints || 0) | 0,
        weeklySteals: Math.max(0, Number(data.weeklySteals || 0) | 0),
        weeklyWins: Math.max(0, Number(data.weeklyWins || 0) | 0),
        weeklyLosses: Math.max(0, Number(data.weeklyLosses || 0) | 0),
        weeklyDraws: Math.max(0, Number(data.weeklyDraws || 0) | 0),
      };
    }),
  };
});

const listAdminSubscriptionsV2 = onCall(async (request) => {
  await requireAdmin(request);
  const snap = await db.collection('purchaseEntitlementsV2').limit(200).get();
  return {
    subscriptions: snap.docs.map((doc) => {
      const data = doc.data();
      const expiresAt = data.expiresAt;
      return {
        uid: doc.id,
        active: data.active === true,
        productId: data.productId || null,
        source: data.source || null,
        expiresAtMs: expiresAt && typeof expiresAt.toMillis === 'function'
          ? expiresAt.toMillis()
          : Number(data.expiresAtMs || 0),
      };
    }),
  };
});

const listAdminAuditV2 = onCall(async (request) => {
  await requireAdmin(request);
  const snap = await db.collection('adminAuditV2')
    .orderBy('createdAt', 'desc')
    .limit(100)
    .get();
  return {
    entries: snap.docs.map((doc) => {
      const data = doc.data();
      return {
        id: doc.id,
        actorEmail: data.actorEmail || null,
        action: data.action || null,
        target: data.target || null,
        details: data.details || {},
        createdAtMs: data.createdAt && typeof data.createdAt.toMillis === 'function'
          ? data.createdAt.toMillis()
          : 0,
      };
    }),
  };
});

module.exports = {
  getAdminOverviewV2,
  listAdminPlayersV2,
  updateAdminPlayerStatsV2,
  setAdminPlayerSuspensionV2,
  listAdminDuelsV2,
  cancelAdminDuelV2,
  listAdminRankingV2,
  listAdminSubscriptionsV2,
  listAdminAuditV2,
};
