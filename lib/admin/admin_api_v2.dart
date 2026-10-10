import 'package:cloud_functions/cloud_functions.dart';

class AdminOverviewV2 {
  const AdminOverviewV2({
    required this.users,
    required this.cards,
    required this.legendaryCards,
    required this.availableLegendaryCopies,
    required this.activeDuels,
    required this.activeSubscriptions,
  });

  final int users;
  final int cards;
  final int legendaryCards;
  final int availableLegendaryCopies;
  final int activeDuels;
  final int activeSubscriptions;

  factory AdminOverviewV2.fromMap(Map<String, dynamic> data) => AdminOverviewV2(
        users: (data['users'] as num?)?.toInt() ?? 0,
        cards: (data['cards'] as num?)?.toInt() ?? 0,
        legendaryCards: (data['legendaryCards'] as num?)?.toInt() ?? 0,
        availableLegendaryCopies:
            (data['availableLegendaryCopies'] as num?)?.toInt() ?? 0,
        activeDuels: (data['activeDuels'] as num?)?.toInt() ?? 0,
        activeSubscriptions:
            (data['activeSubscriptions'] as num?)?.toInt() ?? 0,
      );
}

class AdminPlayerRowV2 {
  const AdminPlayerRowV2({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.ownedCount,
    required this.weeklyPoints,
    required this.weeklySteals,
    required this.totalSteals,
    required this.totalWins,
    required this.totalLosses,
    required this.totalDraws,
    required this.subscriptionActive,
    required this.activeDuelV2,
  });

  final String uid;
  final String displayName;
  final String? email;
  final int ownedCount;
  final int weeklyPoints;
  final int weeklySteals;
  final int totalSteals;
  final int totalWins;
  final int totalLosses;
  final int totalDraws;
  final bool subscriptionActive;
  final String? activeDuelV2;

  factory AdminPlayerRowV2.fromMap(Map<String, dynamic> data) => AdminPlayerRowV2(
        uid: data['uid'] as String? ?? '',
        displayName: data['displayName'] as String? ?? 'PLAYER',
        email: data['email'] as String?,
        ownedCount: (data['ownedCount'] as num?)?.toInt() ?? 0,
        weeklyPoints: (data['weeklyPoints'] as num?)?.toInt() ?? 0,
        weeklySteals: (data['weeklySteals'] as num?)?.toInt() ?? 0,
        totalSteals: (data['totalSteals'] as num?)?.toInt() ?? 0,
        totalWins: (data['totalWins'] as num?)?.toInt() ?? 0,
        totalLosses: (data['totalLosses'] as num?)?.toInt() ?? 0,
        totalDraws: (data['totalDraws'] as num?)?.toInt() ?? 0,
        subscriptionActive: data['subscriptionActive'] == true,
        activeDuelV2: data['activeDuelV2'] as String?,
      );
}

class AdminDuelRowV2 {
  const AdminDuelRowV2({
    required this.duelId,
    required this.status,
    required this.p1Uid,
    required this.p2Uid,
    required this.winnerUid,
    required this.loserUid,
    required this.stealConfirmed,
    required this.stolenPackId,
  });

  final String duelId;
  final String status;
  final String? p1Uid;
  final String? p2Uid;
  final String? winnerUid;
  final String? loserUid;
  final bool stealConfirmed;
  final String? stolenPackId;

  factory AdminDuelRowV2.fromMap(Map<String, dynamic> data) => AdminDuelRowV2(
        duelId: data['duelId'] as String? ?? '',
        status: data['status'] as String? ?? '',
        p1Uid: data['p1Uid'] as String?,
        p2Uid: data['p2Uid'] as String?,
        winnerUid: data['winnerUid'] as String?,
        loserUid: data['loserUid'] as String?,
        stealConfirmed: data['stealConfirmed'] == true,
        stolenPackId: data['stolenPackId'] as String?,
      );
}

class AdminRankingRowV2 {
  const AdminRankingRowV2({
    required this.rank,
    required this.uid,
    required this.displayName,
    required this.weeklyPoints,
    required this.weeklySteals,
    required this.weeklyWins,
    required this.weeklyLosses,
    required this.weeklyDraws,
  });

  final int rank;
  final String uid;
  final String displayName;
  final int weeklyPoints;
  final int weeklySteals;
  final int weeklyWins;
  final int weeklyLosses;
  final int weeklyDraws;

  factory AdminRankingRowV2.fromMap(Map<String, dynamic> data) =>
      AdminRankingRowV2(
        rank: (data['rank'] as num?)?.toInt() ?? 0,
        uid: data['uid'] as String? ?? '',
        displayName: data['displayName'] as String? ?? 'PLAYER',
        weeklyPoints: (data['weeklyPoints'] as num?)?.toInt() ?? 0,
        weeklySteals: (data['weeklySteals'] as num?)?.toInt() ?? 0,
        weeklyWins: (data['weeklyWins'] as num?)?.toInt() ?? 0,
        weeklyLosses: (data['weeklyLosses'] as num?)?.toInt() ?? 0,
        weeklyDraws: (data['weeklyDraws'] as num?)?.toInt() ?? 0,
      );
}

class AdminSubscriptionRowV2 {
  const AdminSubscriptionRowV2({
    required this.uid,
    required this.active,
    required this.productId,
    required this.source,
    required this.expiresAt,
  });

  final String uid;
  final bool active;
  final String? productId;
  final String? source;
  final DateTime? expiresAt;

  factory AdminSubscriptionRowV2.fromMap(Map<String, dynamic> data) {
    final expiresAtMs = (data['expiresAtMs'] as num?)?.toInt() ?? 0;
    return AdminSubscriptionRowV2(
      uid: data['uid'] as String? ?? '',
      active: data['active'] == true,
      productId: data['productId'] as String?,
      source: data['source'] as String?,
      expiresAt: expiresAtMs <= 0
          ? null
          : DateTime.fromMillisecondsSinceEpoch(expiresAtMs, isUtc: true),
    );
  }
}

class AdminAuditRowV2 {
  const AdminAuditRowV2({
    required this.id,
    required this.actorEmail,
    required this.action,
    required this.target,
    required this.createdAt,
  });

  final String id;
  final String? actorEmail;
  final String? action;
  final String? target;
  final DateTime? createdAt;

  factory AdminAuditRowV2.fromMap(Map<String, dynamic> data) {
    final createdAtMs = (data['createdAtMs'] as num?)?.toInt() ?? 0;
    return AdminAuditRowV2(
      id: data['id'] as String? ?? '',
      actorEmail: data['actorEmail'] as String?,
      action: data['action'] as String?,
      target: data['target'] as String?,
      createdAt: createdAtMs <= 0
          ? null
          : DateTime.fromMillisecondsSinceEpoch(createdAtMs, isUtc: true),
    );
  }
}

class AdminApiV2 {
  AdminApiV2({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  Future<AdminOverviewV2> loadOverview() async {
    final raw = _map(
      (await _functions.httpsCallable('getAdminOverviewV2').call()).data,
      'Invalid admin overview response.',
    );
    return AdminOverviewV2.fromMap(raw);
  }

  Future<List<AdminPlayerRowV2>> loadPlayers() async {
    final raw = _map(
      (await _functions.httpsCallable('listAdminPlayersV2').call({
        'limit': 100,
      }))
          .data,
      'Invalid admin players response.',
    );
    return (raw['players'] as List? ?? const <dynamic>[])
        .whereType<Map>()
        .map((item) => AdminPlayerRowV2.fromMap(
              Map<String, dynamic>.from(item),
            ))
        .toList(growable: false);
  }

  Future<void> updatePlayerStats({
    required String uid,
    int? weeklyPoints,
    int? weeklySteals,
    int? totalSteals,
  }) async {
    await _functions.httpsCallable('updateAdminPlayerStatsV2').call({
      'uid': uid,
      if (weeklyPoints != null) 'weeklyPoints': weeklyPoints,
      if (weeklySteals != null) 'weeklySteals': weeklySteals,
      if (totalSteals != null) 'totalSteals': totalSteals,
    });
  }

  Future<List<AdminDuelRowV2>> loadDuels() async {
    final raw = _map(
      (await _functions.httpsCallable('listAdminDuelsV2').call({
        'limit': 100,
      }))
          .data,
      'Invalid admin duels response.',
    );
    return (raw['duels'] as List? ?? const <dynamic>[])
        .whereType<Map>()
        .map((item) => AdminDuelRowV2.fromMap(
              Map<String, dynamic>.from(item),
            ))
        .toList(growable: false);
  }

  Future<void> cancelDuel(String duelId) async {
    await _functions.httpsCallable('cancelAdminDuelV2').call({
      'duelId': duelId,
    });
  }

  Future<List<AdminRankingRowV2>> loadRanking() async {
    final raw = _map(
      (await _functions.httpsCallable('listAdminRankingV2').call()).data,
      'Invalid admin ranking response.',
    );
    return (raw['players'] as List? ?? const <dynamic>[])
        .whereType<Map>()
        .map((item) => AdminRankingRowV2.fromMap(
              Map<String, dynamic>.from(item),
            ))
        .toList(growable: false);
  }

  Future<List<AdminSubscriptionRowV2>> loadSubscriptions() async {
    final raw = _map(
      (await _functions.httpsCallable('listAdminSubscriptionsV2').call()).data,
      'Invalid admin subscriptions response.',
    );
    return (raw['subscriptions'] as List? ?? const <dynamic>[])
        .whereType<Map>()
        .map((item) => AdminSubscriptionRowV2.fromMap(
              Map<String, dynamic>.from(item),
            ))
        .toList(growable: false);
  }

  Future<List<AdminAuditRowV2>> loadAudit() async {
    final raw = _map(
      (await _functions.httpsCallable('listAdminAuditV2').call()).data,
      'Invalid admin audit response.',
    );
    return (raw['entries'] as List? ?? const <dynamic>[])
        .whereType<Map>()
        .map((item) => AdminAuditRowV2.fromMap(
              Map<String, dynamic>.from(item),
            ))
        .toList(growable: false);
  }

  Map<String, dynamic> _map(dynamic value, String message) {
    if (value is! Map) throw StateError(message);
    return Map<String, dynamic>.from(value);
  }
}
