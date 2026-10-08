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
}
