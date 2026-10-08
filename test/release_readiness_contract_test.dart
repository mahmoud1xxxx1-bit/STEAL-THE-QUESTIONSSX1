import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release readiness contracts remain aligned with approved product rules', () {
    final serverCore =
        File('firebase_functions/core_engine_v2.js').readAsStringSync();
    final purchaseEngine = File(
      'firebase_functions/purchase_verification_engine_v2.js',
    ).readAsStringSync();
    final purchaseClient =
        File('lib/services/purchase_service.dart').readAsStringSync();
    final profileFeatures = File(
      'firebase_functions/profile_features_functions_v2.js',
    ).readAsStringSync();
    final weeklyRanking = File(
      'firebase_functions/weekly_ranking_functions_v2.js',
    ).readAsStringSync();
    final v2Functions =
        File('firebase_functions/v2_functions.js').readAsStringSync();
    final onlineSession =
        File('lib/game/online_player_session_v2.dart').readAsStringSync();
    final activeApp =
        File('lib/v2_active_app.dart').readAsStringSync();
    final weeklyPrestige = File(
      'firebase_functions/weekly_prestige_functions_v2.js',
    ).readAsStringSync();
    final rules = File('firestore.rules').readAsStringSync();
    final functionsMain =
        File('firebase_functions/main.js').readAsStringSync();
    final googleAuth =
        File('lib/backend/google_auth_v2.dart').readAsStringSync();
    final firebaseBootstrap =
        File('lib/backend/firebase_bootstrap.dart').readAsStringSync();
    final androidCi = File(
      '.github/workflows/flutter-web-preview.yml',
    ).readAsStringSync();
    final admin = File('lib/admin/admin_content_v2.dart').readAsStringSync();
    final catalog =
        File('lib/data/card_catalog_repository_v2.dart').readAsStringSync();

    expect(serverCore, contains('const DECK_SIZE = 10;'));
    expect(serverCore, contains('const DUEL_PACKS = 7;'));
    expect(serverCore, contains('const FREE_DECK_SLOTS = 2;'));
    expect(serverCore, contains('const SUBSCRIBER_DECK_SLOTS = 5;'));
    expect(serverCore, contains('const FREE_ANSWER_CHOICES = 3;'));
    expect(serverCore, contains('const SUBSCRIBER_ANSWER_CHOICES = 4;'));
    expect(serverCore, contains('const WEEKLY_WIN_POINTS = 30;'));
    expect(serverCore, contains('const WEEKLY_LOSS_POINTS = -15;'));
    expect(serverCore, contains('const WEEKLY_DRAW_POINTS = 0;'));

    expect(
      purchaseEngine,
      contains("const MONTHLY_PRODUCT_ID = 'monthly_subscription_v2';"),
    );
    expect(
      purchaseClient,
      contains("productId = 'monthly_subscription_v2'"),
    );
    expect(
      purchaseClient,
      contains('It never unlocks subscription features locally.'),
    );
    expect(profileFeatures, contains('purchaseEntitlementsV2'));
    expect(profileFeatures, contains('normalizeVerifiedEntitlement'));
    expect(onlineSession, contains('verifySubscriptionPurchase'));
    expect(onlineSession, contains('refreshSubscription() async'));
    expect(activeApp, contains('final verified = await session.verifySubscriptionPurchase'));
    expect(activeApp, contains('final status = await session.refreshSubscription'));
    expect(activeApp, contains('bool get _demoMode'));
    expect(activeApp, contains('if (_demoMode)'));
    expect(activeApp, contains('_DemoModeBanner'));
    expect(activeApp, contains('await _runSparkTestDuel()'));
    expect(profileFeatures, contains('if (!verified.active && next.activeDeckIndex >= 2)'));

    expect(weeklyRanking, contains("onDocumentWritten('users/{uid}'"));
    expect(weeklyRanking, contains('weeklyPoints: profile.weeklyPoints'));
    expect(v2Functions, contains('const getWeeklyRankingV2 = onCall'));
    expect(v2Functions, contains("db.collection('users')"));
    expect(v2Functions, contains("orderBy('profileV2.weeklyPoints', 'desc')"));
    expect(weeklyPrestige, contains("schedule: '10 0 * * 1'"));
    expect(weeklyPrestige, contains('rankingRewardsV2'));
    expect(weeklyPrestige, contains('applyPrestigeV2(current, entry.place)'));

    expect(rules, contains('function isAdmin()'));
    expect(rules, contains('adminEmailsV2'));
    expect(rules, contains('allow create, update, delete: if isAdmin();'));
    expect(rules, contains('allow write: if false;'));
    expect(admin, contains('AdminAccessV2'));
    expect(admin, contains("collection('adminEmailsV2')"));
    expect(catalog, contains("collection('cardsV2')"));
    expect(catalog, isNot(contains('List<CardSummaryV2> demo')));
    expect(catalog, isNot(contains('seedQuestions')));

    expect(googleAuth, contains('GoogleSignIn'));
    expect(googleAuth, contains('GoogleAuthProvider.credential'));
    expect(googleAuth, isNot(contains('signInAnonymously')));

    expect(functionsMain, contains("require('./v2_functions')"));
    expect(functionsMain, contains("require('./matchmaking_functions_v2')"));
    expect(functionsMain, contains("require('./duel_functions_v2')"));
    expect(functionsMain, contains("require('./bot_functions_v2')"));
    expect(functionsMain, contains("require('./weekly_ranking_functions_v2')"));
    expect(functionsMain, contains("require('./weekly_prestige_functions_v2')"));
    expect(
      functionsMain,
      contains("require('./purchase_verification_functions_v2')"),
    );
  });

  test('release source contains no retired project identities', () {
    const forbidden = <String>[
      '3minutes',
      'level_devil',
      'Level Devil',
      'LVL LOOL',
    ];
    final roots = <String>['lib', 'firebase_functions'];
    for (final root in roots) {
      final dir = Directory(root);
      for (final entity in dir.listSync(recursive: true)) {
        if (entity is! File) continue;
        if (!entity.path.endsWith('.dart') && !entity.path.endsWith('.js')) {
          continue;
        }
        final source = entity.readAsStringSync();
        for (final term in forbidden) {
          expect(
            source,
            isNot(contains(term)),
            reason: 'Retired project identity "$term" found in ${entity.path}',
          );
        }
      }
    }
  });

}
