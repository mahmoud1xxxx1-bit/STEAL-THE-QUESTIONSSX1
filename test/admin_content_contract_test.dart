import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('admin panel is hidden behind email authorization', () {
    final app = File('lib/v2_active_app.dart').readAsStringSync();
    final admin = File('lib/admin/admin_content_v2.dart').readAsStringSync();
    final rules = File('firestore.rules').readAsStringSync();

    expect(app, contains('AdminAccessV2'));
    expect(app, contains('if (isAdmin)'));
    expect(app, contains('AdminDashboardV2'));
    expect(admin, contains("collection('adminEmailsV2')"));
    expect(rules, contains('function isAdmin()'));
    expect(rules, contains('request.auth.token.email'));
    expect(rules, contains('allow write: if false;'));
  });

  test('admin content supports cards rarity inventory and expandable questions', () {
    final admin = File('lib/admin/admin_content_v2.dart').readAsStringSync();
    final dashboard =
        File('lib/admin/admin_dashboard_v2.dart').readAsStringSync();

    expect(admin, contains('availableCopies'));
    expect(admin, contains('questionCount'));
    expect(admin, contains('upsertCard'));
    expect(admin, contains('upsertQuestion'));
    expect(admin, contains('setQuestionEnabled'));
    expect(dashboard, contains('CardRarityV2.legendary'));
    expect(dashboard, contains('إضافة سؤال'));
  });
  test('primary owner email retains admin access contract', () {
    final adminSource =
        File('lib/admin/admin_content_v2.dart').readAsStringSync();
    final rules = File('firestore.rules').readAsStringSync();

    expect(adminSource, contains("kPrimaryAdminEmailV2 = 'love.dotk@gmail.com'"));
    expect(rules, contains("request.auth.token.email == 'love.dotk@gmail.com'"));
  });

  test('Super Admin uses server-authoritative audited operations', () {
    final server =
        File('firebase_functions/admin_functions_v2.js').readAsStringSync();
    final main = File('firebase_functions/main.js').readAsStringSync();
    final rules = File('firestore.rules').readAsStringSync();
    final dashboard =
        File('lib/admin/admin_dashboard_v2.dart').readAsStringSync();

    expect(server, contains("PRIMARY_ADMIN_EMAIL = 'love.dotk@gmail.com'"));
    expect(server, contains("db.collection('adminAuditV2').add"));
    expect(server, contains("audit(actor, 'update_player_stats'"));
    expect(server, contains("audit(actor, 'cancel_duel'"));
    expect(server, contains('getAdminOverviewV2'));
    expect(server, contains('listAdminPlayersV2'));
    expect(server, contains('listAdminDuelsV2'));
    expect(server, contains('listAdminSubscriptionsV2'));
    expect(main, contains('...adminV2'));
    expect(rules, contains('match /adminAuditV2/{entryId}'));
    expect(rules, contains('allow read, write: if false'));
    expect(dashboard, contains('لوحة الإدارة الكاملة'));
    expect(dashboard, contains('AdminPlayersPageV2'));
    expect(dashboard, contains('AdminDuelsPageV2'));
    expect(dashboard, contains('AdminSubscriptionsPageV2'));
    expect(dashboard, contains('AdminAuditPageV2'));
  });

  test('Super Admin can suspend abusive players and server blocks play paths', () {
    final adminServer =
        File('firebase_functions/admin_functions_v2.js').readAsStringSync();
    final matchmaking =
        File('firebase_functions/matchmaking_functions_v2.js').readAsStringSync();
    final bot =
        File('firebase_functions/bot_functions_v2.js').readAsStringSync();
    final duel =
        File('firebase_functions/duel_functions_v2.js').readAsStringSync();
    final steal =
        File('firebase_functions/v2_functions.js').readAsStringSync();
    final adminApi = File('lib/admin/admin_api_v2.dart').readAsStringSync();
    final adminUi =
        File('lib/admin/admin_super_pages_v2.dart').readAsStringSync();

    expect(adminServer, contains('setAdminPlayerSuspensionV2'));
    expect(adminServer, contains("'suspend_player'"));
    expect(adminServer, contains("'unsuspend_player'"));
    expect(adminServer, contains('Primary admin account cannot be suspended.'));
    expect(adminServer, contains("collection('botRoundsV2').doc(activeBotRoundId)"));
    expect(matchmaking, contains('ACCOUNT_SUSPENDED'));
    expect(matchmaking, contains('candidateUser.suspendedV2 === true'));
    expect(bot, contains('ensureNotSuspended(firstData)'));
    expect(bot, contains('ensureNotSuspended(userSnap.data())'));
    expect(duel, contains('await ensureNotSuspended(uid)'));
    expect(steal, contains('await ensureNotSuspended(uid)'));
    expect(adminApi, contains('setPlayerSuspension'));
    expect(adminUi, contains('_toggleSuspension'));
    expect(adminUi, contains('تعليق اللاعب'));
    expect(adminUi, contains('إعادة تفعيل اللاعب'));
  });

}
