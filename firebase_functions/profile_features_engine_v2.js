'use strict';

const TITLE_BY_PLACE = Object.freeze({
  1: 'champion_of_the_week',
  2: 'weekly_runner_up',
  3: 'weekly_third_place',
});

const FRAME_BY_PLACE = Object.freeze({
  1: 'weekly_gold_frame',
  2: 'weekly_silver_frame',
  3: 'weekly_bronze_frame',
});

function unlockedPrestige(profile) {
  const prestige = profile && profile.prestige && typeof profile.prestige === 'object'
    ? profile.prestige
    : {};
  const titles = [];
  const frames = [];
  if (Number(prestige.first || 0) > 0) {
    titles.push(TITLE_BY_PLACE[1]);
    frames.push(FRAME_BY_PLACE[1]);
  }
  if (Number(prestige.second || 0) > 0) {
    titles.push(TITLE_BY_PLACE[2]);
    frames.push(FRAME_BY_PLACE[2]);
  }
  if (Number(prestige.third || 0) > 0) {
    titles.push(TITLE_BY_PLACE[3]);
    frames.push(FRAME_BY_PLACE[3]);
  }
  return { titles, frames };
}

function equipPrestige(profile, { titleKey = null, frameKey = null } = {}) {
  const unlocked = unlockedPrestige(profile);
  if (titleKey !== null && !unlocked.titles.includes(String(titleKey))) {
    throw new Error('Title is not unlocked.');
  }
  if (frameKey !== null && !unlocked.frames.includes(String(frameKey))) {
    throw new Error('Frame is not unlocked.');
  }
  return {
    ...profile,
    currentTitleKey: titleKey === null ? null : String(titleKey),
    currentFrameKey: frameKey === null ? null : String(frameKey),
  };
}

function millis(value) {
  if (!value) return null;
  if (typeof value.toMillis === 'function') return value.toMillis();
  if (value instanceof Date) return value.getTime();
  if (typeof value === 'number') return Number.isFinite(value) ? value : null;
  const parsed = Date.parse(String(value));
  return Number.isFinite(parsed) ? parsed : null;
}

function normalizeVerifiedEntitlement(data, nowMs = Date.now()) {
  const raw = data && typeof data === 'object' ? data : {};
  const expiresAtMs = millis(raw.expiresAt);
  const verifiedAtMs = millis(raw.verifiedAt);
  const active = raw.verified === true && expiresAtMs !== null && expiresAtMs > nowMs;
  return {
    active,
    expiresAtMs: active ? expiresAtMs : null,
    verifiedAtMs,
    source: typeof raw.source === 'string' ? raw.source : null,
    productId: typeof raw.productId === 'string' ? raw.productId : null,
  };
}

function previousWeekKey(nowMs = Date.now()) {
  const date = new Date(nowMs);
  const day = date.getUTCDay();
  const daysSinceMonday = (day + 6) % 7;
  date.setUTCDate(date.getUTCDate() - daysSinceMonday - 7);
  return date.toISOString().slice(0, 10);
}

function podiumPlace(index) {
  const place = Number(index) + 1;
  return place >= 1 && place <= 3 ? place : null;
}

module.exports = {
  TITLE_BY_PLACE,
  FRAME_BY_PLACE,
  unlockedPrestige,
  equipPrestige,
  normalizeVerifiedEntitlement,
  previousWeekKey,
  podiumPlace,
};
