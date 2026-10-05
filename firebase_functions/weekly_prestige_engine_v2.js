'use strict';

function normalizeEntry(entry) {
  const value = entry && typeof entry === 'object' ? entry : {};
  return {
    uid: String(value.uid || ''),
    displayName: String(value.displayName || 'PLAYER'),
    weeklyPoints: Number(value.weeklyPoints || 0) | 0,
    weeklyWins: Math.max(0, Number(value.weeklyWins || 0) | 0),
    weeklyLosses: Math.max(0, Number(value.weeklyLosses || 0) | 0),
    weeklyDraws: Math.max(0, Number(value.weeklyDraws || 0) | 0),
  };
}

function rankWeeklyEntries(entries) {
  return (Array.isArray(entries) ? entries : [])
    .map(normalizeEntry)
    .filter((entry) => entry.uid)
    .sort((a, b) => {
      if (a.weeklyPoints !== b.weeklyPoints) return b.weeklyPoints - a.weeklyPoints;
      if (a.weeklyWins !== b.weeklyWins) return b.weeklyWins - a.weeklyWins;
      return a.uid.localeCompare(b.uid);
    });
}

function topThree(entries) {
  return rankWeeklyEntries(entries).slice(0, 3).map((entry, index) => ({
    ...entry,
    place: index + 1,
  }));
}

function rewardDocumentId(weekKey, uid) {
  return `${String(weekKey)}--${String(uid)}`;
}

module.exports = {
  normalizeEntry,
  rankWeeklyEntries,
  topThree,
  rewardDocumentId,
};
