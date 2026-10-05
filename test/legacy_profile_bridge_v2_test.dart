import 'package:flutter_test/flutter_test.dart';
import 'package:steal_the_questions/game/legacy_profile_bridge_v2.dart';

void main() {
  test('legacy content is not silently treated as v2 packs', () {
    final profile = const LegacyProfileBridgeV2().migrate(
      legacy: <String, dynamic>{
        'ownedCards': <String>['old_q1', 'old_q2'],
        'decks': <List<String>>[
          <String>['old_q1', 'old_q2'],
        ],
        'wins': 12,
        'losses': 4,
      },
      now: DateTime.utc(2026, 10, 5),
    );

    expect(profile.ownedPackIds, isEmpty);
    expect(profile.decks.every((deck) => deck.isEmpty), isTrue);
    expect(profile.totalWins, 12);
    expect(profile.totalLosses, 4);
  });

  test('legacy cards migrate only with explicit pack mapping', () {
    final oldIds = List<String>.generate(10, (i) => 'old_$i');
    final mapping = <String, String>{
      for (var i = 0; i < 10; i++) 'old_$i': 'pack_$i',
    };

    final profile = const LegacyProfileBridgeV2().migrate(
      legacy: <String, dynamic>{
        'ownedCards': oldIds,
        'decks': <List<String>>[oldIds],
        'activeDeck': 0,
      },
      legacyCardToPack: mapping,
      now: DateTime.utc(2026, 10, 5),
    );

    expect(profile.ownedPackIds.length, 10);
    expect(profile.decks[0].length, 10);
    expect(profile.activeDeckIndex, 0);
    expect(profile.activeDeckReady, isTrue);
  });
}
