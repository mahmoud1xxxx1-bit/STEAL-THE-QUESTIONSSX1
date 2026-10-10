import 'package:flutter_test/flutter_test.dart';
import 'package:steal_the_questions/game/core_engine_v2.dart';
import 'package:steal_the_questions/game/player_profile_v2.dart';

void main() {
  test('empty profile starts with v2 limits and no content', () {
    final profile = PlayerProfileV2.empty(now: DateTime.utc(2026, 10, 5));
    expect(profile.ownedPackIds, isEmpty);
    expect(profile.ownedPackCounts, isEmpty);
    expect(profile.decks.length, 5);
    expect(profile.entitlement.deckSlots, 2);
    expect(profile.entitlement.answerChoices, 3);
    expect(profile.pvpUnlocked, isFalse);
  });

  test('deck accepts exactly ten distinct owned packs', () {
    final profile = PlayerProfileV2.empty(now: DateTime.utc(2026, 10, 5));
    profile.ownedPackIds.addAll({for (var i = 0; i < 10; i++) 'pack_$i'});

    expect(profile.setDeck(0, profile.ownedPackIds), isTrue);
    expect(profile.activeDeckReady, isTrue);
    expect(profile.setDeck(1, profile.ownedPackIds.take(9)), isFalse);
  });

  test('weekly result accounting follows plus30 minus15 zero', () {
    final profile = PlayerProfileV2.empty(now: DateTime.utc(2026, 10, 5));
    profile.applyDuelResult(DuelResultV2.win, now: DateTime.utc(2026, 10, 5));
    profile.applyDuelResult(DuelResultV2.loss, now: DateTime.utc(2026, 10, 5));
    profile.applyDuelResult(DuelResultV2.draw, now: DateTime.utc(2026, 10, 5));

    expect(profile.weeklyPoints, 15);
    expect(profile.weeklyWins, 1);
    expect(profile.weeklyLosses, 1);
    expect(profile.weeklyDraws, 1);
    expect(profile.totalWins, 1);
    expect(profile.totalLosses, 1);
    expect(profile.totalDraws, 1);
  });

  test('new week resets weekly values but preserves lifetime values', () {
    final profile = PlayerProfileV2.empty(now: DateTime.utc(2026, 10, 5));
    profile.applyDuelResult(DuelResultV2.win, now: DateTime.utc(2026, 10, 5));
    profile.ensureCurrentWeek(DateTime.utc(2026, 10, 12));

    expect(profile.weeklyPoints, 0);
    expect(profile.weeklyWins, 0);
    expect(profile.weeklySteals, 0);
    expect(profile.totalWins, 1);
  });

  test('recent question history is normalized to fifty entries', () {
    final profile = PlayerProfileV2.empty(now: DateTime.utc(2026, 10, 5));
    profile.replaceRecentQuestions([for (var i = 0; i < 60; i++) 'q$i']);
    expect(profile.recentQuestionIds.length, 50);
    expect(profile.recentQuestionIds.first, 'q10');
    expect(profile.recentQuestionIds.last, 'q59');
  });

  test('serialization preserves prestige and subscription state', () {
    final profile = PlayerProfileV2(
      ownedPackIds: {'a'},
      ownedPackCounts: const {'a': 2},
      decks: List<List<String>>.generate(5, (_) => <String>[]),
      activeDeckIndex: 0,
      recentQuestionIds: const ['q1'],
      packLastPvpUsedAtMs: const {'a': 123456},
      weekKey: '2026-10-05',
      weeklyPoints: 30,
      weeklyWins: 1,
      weeklyLosses: 0,
      weeklyDraws: 0,
      weeklySteals: 3,
      totalWins: 5,
      totalLosses: 2,
      totalDraws: 1,
      totalSteals: 11,
      prestige: const PrestigeHistoryV2(first: 2, second: 1, third: 3),
      subscriptionActive: true,
      subscriptionExpiresAt: DateTime.utc(2026, 11, 5),
      currentTitleKey: 'champion_of_the_week',
      currentFrameKey: 'weekly_gold_frame',
    );

    final restored = PlayerProfileV2.fromMap(
      profile.toMap(),
      now: DateTime.utc(2026, 10, 5),
    );

    expect(restored.ownedPackCounts['a'], 2);
    expect(restored.packLastPvpUsedAtMs['a'], 123456);
    expect(restored.weeklySteals, 3);
    expect(restored.totalSteals, 11);
    expect(restored.prestige.first, 2);
    expect(restored.prestige.second, 1);
    expect(restored.prestige.third, 3);
    expect(restored.subscriptionActive, isTrue);
    expect(restored.entitlement.deckSlots, 5);
    expect(restored.currentTitleKey, 'champion_of_the_week');
  });
}
