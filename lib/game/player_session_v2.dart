import '../data/player_profile_store_v2.dart';
import 'core_engine_v2.dart';
import 'player_profile_v2.dart';

class PlayerSessionV2 {
  PlayerSessionV2({required this.store});

  final PlayerProfileStoreV2 store;
  PlayerProfileV2? _profile;

  bool get initialized => _profile != null;
  PlayerProfileV2 get profile {
    final value = _profile;
    if (value == null) throw StateError('PlayerSessionV2 is not initialized.');
    return value;
  }

  Future<PlayerProfileV2> initialize({DateTime? now}) async {
    final loaded = await store.load();
    loaded.ensureCurrentWeek(now ?? DateTime.now());
    _profile = loaded;
    await store.save(loaded);
    return loaded;
  }

  Future<bool> saveDeck(int index, Iterable<String> packIds) async {
    final ok = profile.setDeck(index, packIds);
    if (!ok) return false;
    await store.save(profile);
    return true;
  }

  Future<void> setActiveDeck(int index) async {
    if (!profile.canUseDeckIndex(index)) {
      throw StateError('Deck slot is locked or invalid.');
    }
    profile.activeDeckIndex = index;
    await store.save(profile);
  }

  Future<void> replaceOwnedPacks(Iterable<String> packIds) async {
    profile.ownedPackIds
      ..clear()
      ..addAll(packIds.map(String));

    for (var i = 0; i < profile.decks.length; i++) {
      final deck = profile.decks[i];
      if (!PlayerDeckV2(deck).isValid(profile.ownedPackIds)) {
        profile.decks[i] = <String>[];
      }
    }
    if (!profile.canUseDeckIndex(profile.activeDeckIndex)) {
      profile.activeDeckIndex = 0;
    }
    await store.save(profile);
  }

  Future<void> applyResult(DuelResultV2 result, {DateTime? now}) async {
    profile.applyDuelResult(result, now: now);
    await store.save(profile);
  }

  Future<void> replaceRecentQuestions(Iterable<String> ids) async {
    profile.replaceRecentQuestions(ids);
    await store.save(profile);
  }

  Future<void> setSubscription({
    required bool active,
    required DateTime? expiresAt,
  }) async {
    profile.subscriptionActive = active;
    profile.subscriptionExpiresAt = expiresAt;
    if (!profile.canUseDeckIndex(profile.activeDeckIndex)) {
      profile.activeDeckIndex = 0;
    }
    await store.save(profile);
  }
}
