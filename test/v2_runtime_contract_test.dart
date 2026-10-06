import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:steal_the_questions/game/core_engine_v2.dart';
import 'package:steal_the_questions/game/player_profile_v2.dart';

void main() {
  test('active V2 runtime uses the agreed product constants', () {
    expect(kDeckSizeV2, 10);
    expect(kDuelCardsV2, 7);
    expect(kSecondsPerQuestionV2, 20);
    expect(kRecentQuestionLimitV2, 50);
    expect(kFreeDeckSlotsV2, 2);
    expect(kSubscriberDeckSlotsV2, 5);
    expect(kFreeAnswerChoicesV2, 3);
    expect(kSubscriberAnswerChoicesV2, 4);
    expect(kCategoriesV2.length, 7);
  });

  test('new V2 profile starts without legacy cards or rarity state', () {
    final profile = PlayerProfileV2.empty(now: DateTime.utc(2026, 10, 5));
    expect(profile.ownedPackIds, isEmpty);
    expect(profile.decks.length, 5);
    expect(profile.prestige.first, 0);
    expect(profile.prestige.second, 0);
    expect(profile.prestige.third, 0);
    expect(profile.subscriptionActive, isFalse);
  });
  test('release entry point and active UI contain no retired product model', () {
    final mainSource = File('lib/main.dart').readAsStringSync();
    final activeSource = File('lib/v2_active_app.dart').readAsStringSync();

    expect(mainSource, contains('StealQuestionsV2App'));
    expect(mainSource, isNot(contains('SevenCategoriesApp')));
    expect(activeSource, isNot(contains('222')));
    expect(activeSource.toLowerCase(), isNot(contains('weekly pass')));
    expect(activeSource.toLowerCase(), isNot(contains('rarity system')));
  });

  test('Android auth requires Google sign-in and has no anonymous fallback', () {
    final runtimeSource =
        File('lib/backend/online_runtime_v2.dart').readAsStringSync();
    final authSource = File('lib/backend/google_auth_v2.dart').readAsStringSync();
    final activeSource = File('lib/v2_active_app.dart').readAsStringSync();

    expect(runtimeSource, isNot(contains('signInAnonymously')));
    expect(authSource, contains('GoogleSignIn'));
    expect(authSource, contains('GoogleAuthProvider.credential'));
    expect(activeSource, contains('Continue with Google'));
  });
}
