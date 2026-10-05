import 'package:flutter_test/flutter_test.dart';
import 'package:steal_the_questions/data/player_profile_store_v2.dart';
import 'package:steal_the_questions/game/core_engine_v2.dart';
import 'package:steal_the_questions/game/player_profile_v2.dart';
import 'package:steal_the_questions/game/player_session_v2.dart';

void main() {
  test('session persists a valid owned 10-pack deck', () async {
    final profile = PlayerProfileV2.empty(now: DateTime.utc(2026, 10, 5));
    profile.ownedPackIds.addAll({for (var i = 0; i < 10; i++) 'p$i'});
    final store = MemoryPlayerProfileStoreV2(profile);
    final session = PlayerSessionV2(store: store);

    await session.initialize(now: DateTime.utc(2026, 10, 5));
    final saved = await session.saveDeck(0, [for (var i = 0; i < 10; i++) 'p$i']);

    expect(saved, isTrue);
    expect(session.profile.activeDeckReady, isTrue);
    expect((await store.load()).decks.first.length, 10);
  });

  test('session rejects unowned or duplicate deck packs', () async {
    final profile = PlayerProfileV2.empty();
    profile.ownedPackIds.addAll({for (var i = 0; i < 10; i++) 'p$i'});
    final session = PlayerSessionV2(store: MemoryPlayerProfileStoreV2(profile));
    await session.initialize();

    expect(await session.saveDeck(0, [for (var i = 0; i < 9; i++) 'p$i'] + ['missing']), isFalse);
    expect(await session.saveDeck(0, [for (var i = 0; i < 9; i++) 'p$i'] + ['p0']), isFalse);
  });

  test('free player cannot use subscriber-only deck slots', () async {
    final session = PlayerSessionV2(store: MemoryPlayerProfileStoreV2(PlayerProfileV2.empty()));
    await session.initialize();

    expect(session.profile.entitlement.deckSlots, 2);
    expect(session.profile.canUseDeckIndex(2), isFalse);
  });

  test('weekly result is persisted using v2 scoring', () async {
    final store = MemoryPlayerProfileStoreV2(PlayerProfileV2.empty(now: DateTime.utc(2026, 10, 5)));
    final session = PlayerSessionV2(store: store);
    await session.initialize(now: DateTime.utc(2026, 10, 5));

    await session.applyResult(DuelResultV2.win, now: DateTime.utc(2026, 10, 5));
    await session.applyResult(DuelResultV2.loss, now: DateTime.utc(2026, 10, 5));

    final persisted = await store.load();
    expect(persisted.weeklyPoints, 15);
    expect(persisted.totalWins, 1);
    expect(persisted.totalLosses, 1);
  });

  test('recent question history remains capped at 50 without adding content', () async {
    final session = PlayerSessionV2(store: MemoryPlayerProfileStoreV2(PlayerProfileV2.empty()));
    await session.initialize();
    await session.replaceRecentQuestions([for (var i = 0; i < 70; i++) 'q$i']);

    expect(session.profile.recentQuestionIds.length, kRecentQuestionLimitV2);
    expect(session.profile.recentQuestionIds.first, 'q20');
    expect(session.profile.recentQuestionIds.last, 'q69');
  });

  test('losing owned packs invalidates stale decks safely', () async {
    final profile = PlayerProfileV2.empty();
    profile.ownedPackIds.addAll({for (var i = 0; i < 10; i++) 'p$i'});
    profile.setDeck(0, [for (var i = 0; i < 10; i++) 'p$i']);
    final session = PlayerSessionV2(store: MemoryPlayerProfileStoreV2(profile));
    await session.initialize();

    await session.replaceOwnedPacks([for (var i = 0; i < 9; i++) 'p$i']);

    expect(session.profile.pvpUnlocked, isFalse);
    expect(session.profile.decks[0], isEmpty);
  });
}
