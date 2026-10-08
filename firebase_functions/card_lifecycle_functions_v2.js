'use strict';

const admin = require('firebase-admin');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { normalizeProfileV2 } = require('./player_profile_v2');
const { validateDeck } = require('./core_engine_v2');
const { planLifecycleReclaim } = require('./card_lifecycle_engine_v2');

const db = admin.firestore();
const { FieldPath, FieldValue, Timestamp } = admin.firestore;

const PAGE_SIZE = 200;

function sanitizeDecks(profile) {
  const next = normalizeProfileV2(profile);
  next.decks = next.decks.map((deck) =>
    validateDeck(deck, next.ownedPackIds) ? deck : []
  );
  const slots = next.subscriptionActive ? 5 : 2;
  if (next.activeDeckIndex < 0 || next.activeDeckIndex >= slots) {
    next.activeDeckIndex = 0;
  }
  return next;
}

async function loadRareRarityMap() {
  const snap = await db.collection('cardsV2')
    .where('rarity', 'in', ['gold', 'legendary'])
    .get();
  return Object.fromEntries(
    snap.docs.map((doc) => [
      doc.id,
      String(doc.data().rarity || '').toLowerCase(),
    ]),
  );
}

async function reclaimForUser(userRef, rarityByPackId, nowMs) {
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(userRef);
    if (!snap.exists) return { changed: false, reclaimedCopies: 0 };
    const data = snap.data();

    // Never mutate live duel ownership. The next sweep/profile sync will retry
    // after activeDuelV2 is cleared.
    if (data.activeDuelV2) {
      return { changed: false, skippedActiveDuel: true, reclaimedCopies: 0 };
    }

    const current = normalizeProfileV2(data.profileV2 || {}, nowMs);
    const plan = planLifecycleReclaim({
      profile: current,
      rarityByPackId,
      nowMs,
    });
    if (!plan.baselineChanged && plan.expiredPackIds.length === 0) {
      return { changed: false, reclaimedCopies: 0 };
    }

    const owned = new Set(plan.profile.ownedPackIds);
    const counts = { ...plan.profile.ownedPackCounts };
    const activity = { ...plan.profile.packLastPvpUsedAtMs };
    let reclaimedCopies = 0;
    const now = Timestamp.fromMillis(nowMs);

    for (const packId of plan.expiredPackIds) {
      const copies = Number(plan.reclaimedCopies[packId] || 1);
      reclaimedCopies += copies;
      owned.delete(packId);
      delete counts[packId];
      delete activity[packId];
      tx.update(db.collection('cardsV2').doc(packId), {
        availableCopies: FieldValue.increment(copies),
        updatedAt: now,
      });
    }

    const next = sanitizeDecks({
      ...plan.profile,
      ownedPackIds: [...owned],
      ownedPackCounts: counts,
      packLastPvpUsedAtMs: activity,
    });

    tx.update(userRef, {
      profileV2: next,
      schemaVersion: 2,
      updatedAt: now,
    });

    return {
      changed: true,
      reclaimedPackIds: plan.expiredPackIds,
      reclaimedCopies,
    };
  });
}

async function sweepInactiveRareCards(nowMs = Date.now()) {
  const rarityByPackId = await loadRareRarityMap();
  if (Object.keys(rarityByPackId).length === 0) {
    return { usersScanned: 0, usersChanged: 0, copiesReclaimed: 0 };
  }

  let lastDoc = null;
  let usersScanned = 0;
  let usersChanged = 0;
  let copiesReclaimed = 0;

  while (true) {
    let query = db.collection('users')
      .orderBy(FieldPath.documentId())
      .limit(PAGE_SIZE);
    if (lastDoc) query = query.startAfter(lastDoc);

    const page = await query.get();
    if (page.empty) break;

    for (const doc of page.docs) {
      usersScanned += 1;
      const data = doc.data();
      const profile = normalizeProfileV2(data.profileV2 || {}, nowMs);
      const hasRare = profile.ownedPackIds.some((id) =>
        Object.prototype.hasOwnProperty.call(rarityByPackId, id)
      );
      if (!hasRare) continue;

      const result = await reclaimForUser(doc.ref, rarityByPackId, nowMs);
      if (result.changed) usersChanged += 1;
      copiesReclaimed += Number(result.reclaimedCopies || 0);
    }

    lastDoc = page.docs[page.docs.length - 1];
    if (page.size < PAGE_SIZE) break;
  }

  return { usersScanned, usersChanged, copiesReclaimed };
}

const reclaimInactiveRareCardsV2 = onSchedule({
  schedule: '15 */6 * * *',
  timeZone: 'Etc/UTC',
  retryCount: 3,
}, async () => {
  await sweepInactiveRareCards();
});

module.exports = {
  PAGE_SIZE,
  reclaimForUser,
  sweepInactiveRareCards,
  reclaimInactiveRareCardsV2,
};
