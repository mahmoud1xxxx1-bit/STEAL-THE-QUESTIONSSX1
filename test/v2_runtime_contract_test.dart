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

  test('question timeout never auto-selects an answer', () {
    final activeSource = File('lib/v2_active_app.dart').readAsStringSync();

    expect(activeSource, isNot(contains('choices.isEmpty ? null : 0')));
    expect(
      activeSource,
      contains('Navigator.of(dialogContext).pop();'),
    );
  });

  test('mobile identity remains portrait-first and game-oriented', () {
    final mainSource = File('lib/main.dart').readAsStringSync();
    final activeSource = File('lib/v2_active_app.dart').readAsStringSync();

    expect(mainSource, contains('DeviceOrientation.portraitUp'));
    expect(mainSource, contains('DeviceOrientation.portraitDown'));
    expect(activeSource, contains('_GameBottomNav'));
    expect(activeSource, contains('_GameHeroCard'));
    expect(activeSource, contains('_CardFanMark'));
  });

  test('brand identity uses a dedicated steal-card mark and category icons', () {
    final activeSource = File('lib/v2_active_app.dart').readAsStringSync();

    expect(activeSource, contains('class _StealLogoMark'));
    expect(activeSource, contains('Icons.question_mark_rounded'));
    expect(activeSource, contains('Icons.north_west_rounded'));
    expect(activeSource, contains('IconData _categoryIcon'));
    expect(activeSource, contains('class _JourneyStrip'));
  });

  test('card collection and deck builder share one visual card language', () {
    final activeSource = File('lib/v2_active_app.dart').readAsStringSync();

    expect(activeSource, contains('class _CardCornerMark'));
    expect(activeSource, contains('class _CardOwnedRibbon'));
    expect(activeSource, contains('class _DeckMiniSlot'));
    expect(activeSource, contains('class _GameStatusBadge'));
    expect(activeSource, contains('class _StealVictoryMark'));
  });

  test('home play and ranking expose distinct game scenes', () {
    final activeSource = File('lib/v2_active_app.dart').readAsStringSync();

    expect(activeSource, contains('class _PlayerMissionCard'));
    expect(activeSource, contains('class _DuelArenaStrip'));
    expect(activeSource, contains('class _VersusMark'));
    expect(activeSource, contains('class _WeeklyPodium'));
    expect(activeSource, contains('class _PodiumPlayer'));
  });

  test('profile prestige and membership share player identity language', () {
    final activeSource = File('lib/v2_active_app.dart').readAsStringSync();

    expect(activeSource, contains('class _PlayerIdentityFrame'));
    expect(activeSource, contains('class _TitleRibbon'));
    expect(activeSource, contains('class _PrestigeMedal'));
    expect(activeSource, contains('class _IdentityEquipRow'));
    expect(activeSource, contains('Challenger club'));
  });

  test('final identity covers deck editing results loading and error states', () {
    final activeSource = File('lib/v2_active_app.dart').readAsStringSync();

    expect(activeSource, contains('class _DeckChoiceCard'));
    expect(activeSource, contains('class _DeckSelectionSlots'));
    expect(activeSource, contains('class _DuelResultCard'));
    expect(activeSource, contains('class _BrandedLoadingState'));
    expect(activeSource, contains('class _BrandedErrorState'));
  });

  test('mobile screens stay scrollable when backend is unavailable', () {
    final activeSource = File('lib/v2_active_app.dart').readAsStringSync();

    expect(activeSource, isNot(contains('ignoring: !_backendAvailable')));
    expect(
      activeSource,
      contains('AlwaysScrollableScrollPhysics'),
    );
    expect(
      activeSource,
      isNot(contains('Signed in, but game services are currently unavailable.')),
    );
  });

  test('no-Blaze demo mode stays usable and explains server-only features', () {
    final appSource = File('lib/v2_active_app.dart').readAsStringSync();
    final sessionSource =
        File('lib/game/online_player_session_v2.dart').readAsStringSync();

    expect(appSource, contains('bool get _demoMode'));
    expect(appSource, contains('class _DemoModeBanner'));
    expect(appSource, contains('وضع اختبار Spark'));
    expect(sessionSource, contains('INVALID_LOCAL_DECK'));
    expect(sessionSource, contains('_remoteConnected = false'));
    expect(sessionSource, contains('ensureSparkTestProfile'));
    expect(sessionSource, contains('applySparkTestResult'));
    expect(appSource, contains('_runSparkTestDuel'));
    expect(appSource, contains('_chooseSparkTestSteal'));
    expect(appSource, contains('setSparkTestSubscription'));
    expect(appSource, contains('equipSparkTestPrestige'));
  });

  test('rarity identity is visible across collection deck and bot rewards', () {
    final source = File('lib/v2_active_app.dart').readAsStringSync();

    expect(source, contains('_rarityAccent'));
    expect(source, contains('_rarityDark'));
    expect(source, contains('CardRarityV2.legendary'));
    expect(source, contains('_BotRewardRevealDialog'));
    expect(source, contains('awardedRarity'));
    expect(source, contains('cardMeta: _cardMeta'));
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
