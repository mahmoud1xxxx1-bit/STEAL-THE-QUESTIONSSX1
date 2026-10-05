import 'player_profile_v2.dart';

/// Controlled bridge from the legacy player shape into V2.
///
/// Legacy card IDs are not assumed to be V2 pack IDs. A caller must supply an
/// explicit mapping when content migration is intentionally performed later.
class LegacyProfileBridgeV2 {
  const LegacyProfileBridgeV2();

  PlayerProfileV2 migrate({
    required Map<String, dynamic> legacy,
    Map<String, String> legacyCardToPack = const <String, String>{},
    DateTime? now,
  }) {
    final profile = PlayerProfileV2.empty(now: now);

    final legacyOwned = List<String>.from(
      legacy['ownedCards'] as List? ?? const <dynamic>[],
    );
    profile.ownedPackIds.addAll(
      legacyOwned
          .map((id) => legacyCardToPack[id])
          .whereType<String>(),
    );

    profile.totalWins = (legacy['wins'] as num?)?.toInt() ?? 0;
    profile.totalLosses = (legacy['losses'] as num?)?.toInt() ?? 0;

    final expiry = _readDate(legacy['weeklyPassExpiresAt']);
    if (expiry != null && expiry.isAfter(now ?? DateTime.now())) {
      profile.subscriptionActive = true;
      profile.subscriptionExpiresAt = expiry;
    }

    // Legacy decks are migrated only when every card has an explicit V2 pack
    // mapping. This prevents treating old question-card IDs as new topic packs.
    final rawDecks = legacy['decks'] as List? ?? const <dynamic>[];
    for (var i = 0; i < rawDecks.length && i < profile.decks.length; i++) {
      final rawDeck = rawDecks[i];
      if (rawDeck is! List) continue;
      final legacyIds = rawDeck.map((id) => id.toString()).toList(growable: false);
      final mapped = legacyIds.map((id) => legacyCardToPack[id]).toList(growable: false);
      if (mapped.any((id) => id == null)) continue;
      final packIds = mapped.whereType<String>().toList(growable: false);
      if (packIds.length == 10 && packIds.toSet().length == 10 && packIds.every(profile.ownedPackIds.contains)) {
        profile.decks[i] = packIds;
      }
    }

    final legacyActive = (legacy['activeDeck'] as num?)?.toInt() ?? 0;
    if (profile.canUseDeckIndex(legacyActive) && profile.decks[legacyActive].isNotEmpty) {
      profile.activeDeckIndex = legacyActive;
    }

    return profile;
  }

  DateTime? _readDate(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
