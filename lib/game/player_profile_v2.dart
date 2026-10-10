import 'core_engine_v2.dart';

/// Source-of-truth player profile shape for the seven-category model.
///
/// This file deliberately contains no real question content.
class PlayerProfileV2 {
  PlayerProfileV2({
    required this.ownedPackIds,
    required this.ownedPackCounts,
    required this.decks,
    required this.activeDeckIndex,
    required this.recentQuestionIds,
    required this.packLastPvpUsedAtMs,
    required this.weekKey,
    required this.weeklyPoints,
    required this.weeklyWins,
    required this.weeklyLosses,
    required this.weeklyDraws,
    required this.weeklySteals,
    required this.totalWins,
    required this.totalLosses,
    required this.totalDraws,
    required this.totalSteals,
    required this.prestige,
    required this.subscriptionActive,
    required this.subscriptionExpiresAt,
    required this.currentTitleKey,
    required this.currentFrameKey,
  });

  factory PlayerProfileV2.empty({DateTime? now}) => PlayerProfileV2(
        ownedPackIds: <String>{},
        ownedPackCounts: <String, int>{},
        decks: List<List<String>>.generate(
          kSubscriberDeckSlotsV2,
          (_) => <String>[],
        ),
        activeDeckIndex: 0,
        recentQuestionIds: <String>[],
        packLastPvpUsedAtMs: <String, int>{},
        weekKey: weeklyKeyV2(now ?? DateTime.now()),
        weeklyPoints: 0,
        weeklyWins: 0,
        weeklyLosses: 0,
        weeklyDraws: 0,
        weeklySteals: 0,
        totalWins: 0,
        totalLosses: 0,
        totalDraws: 0,
        totalSteals: 0,
        prestige: const PrestigeHistoryV2(),
        subscriptionActive: false,
        subscriptionExpiresAt: null,
        currentTitleKey: null,
        currentFrameKey: null,
      );

  final Set<String> ownedPackIds;
  final Map<String, int> ownedPackCounts;
  final List<List<String>> decks;
  int activeDeckIndex;
  List<String> recentQuestionIds;
  Map<String, int> packLastPvpUsedAtMs;

  String weekKey;
  int weeklyPoints;
  int weeklyWins;
  int weeklyLosses;
  int weeklyDraws;
  int weeklySteals;

  int totalWins;
  int totalLosses;
  int totalDraws;
  int totalSteals;

  PrestigeHistoryV2 prestige;
  bool subscriptionActive;
  DateTime? subscriptionExpiresAt;
  String? currentTitleKey;
  String? currentFrameKey;

  SubscriptionEntitlementV2 get entitlement =>
      SubscriptionEntitlementV2(active: subscriptionActive);

  int get ownedCount => ownedPackIds.length;
  bool get pvpUnlocked => ownedCount >= kDeckSizeV2;

  bool get activeDeckReady {
    if (activeDeckIndex < 0 || activeDeckIndex >= entitlement.deckSlots) {
      return false;
    }
    return PlayerDeckV2(decks[activeDeckIndex]).isValid(ownedPackIds);
  }

  void ensureCurrentWeek(DateTime now) {
    final nextKey = weeklyKeyV2(now);
    if (nextKey == weekKey) return;
    weekKey = nextKey;
    weeklyPoints = 0;
    weeklyWins = 0;
    weeklyLosses = 0;
    weeklyDraws = 0;
    weeklySteals = 0;
  }

  void applyDuelResult(DuelResultV2 result, {DateTime? now}) {
    ensureCurrentWeek(now ?? DateTime.now());
    weeklyPoints += weeklyPointsForResultV2(result);
    switch (result) {
      case DuelResultV2.win:
        weeklyWins += 1;
        totalWins += 1;
        break;
      case DuelResultV2.loss:
        weeklyLosses += 1;
        totalLosses += 1;
        break;
      case DuelResultV2.draw:
        weeklyDraws += 1;
        totalDraws += 1;
        break;
    }
  }

  void replaceRecentQuestions(Iterable<String> ids) {
    final recent = RecentQuestionHistoryV2(ids);
    recentQuestionIds = recent.ids;
  }

  bool canUseDeckIndex(int index) =>
      index >= 0 && index < entitlement.deckSlots;

  bool setDeck(int index, Iterable<String> packIds) {
    if (!canUseDeckIndex(index)) return false;
    final candidate = PlayerDeckV2(packIds);
    if (!candidate.isValid(ownedPackIds)) return false;
    decks[index] = List<String>.from(candidate.packIds);
    return true;
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'ownedPackIds': ownedPackIds.toList(growable: false),
        'ownedPackCounts': Map<String, int>.from(ownedPackCounts),
        'decks': decks.map((d) => List<String>.from(d)).toList(growable: false),
        'activeDeckIndex': activeDeckIndex,
        'recentQuestionIds': List<String>.from(recentQuestionIds),
        'packLastPvpUsedAtMs': Map<String, int>.from(packLastPvpUsedAtMs),
        'weekKey': weekKey,
        'weeklyPoints': weeklyPoints,
        'weeklyWins': weeklyWins,
        'weeklyLosses': weeklyLosses,
        'weeklyDraws': weeklyDraws,
        'weeklySteals': weeklySteals,
        'totalWins': totalWins,
        'totalLosses': totalLosses,
        'totalDraws': totalDraws,
        'totalSteals': totalSteals,
        'prestige': <String, int>{
          'first': prestige.first,
          'second': prestige.second,
          'third': prestige.third,
        },
        'subscriptionActive': subscriptionActive,
        'subscriptionExpiresAt': subscriptionExpiresAt?.toUtc().toIso8601String(),
        'currentTitleKey': currentTitleKey,
        'currentFrameKey': currentFrameKey,
      };

  factory PlayerProfileV2.fromMap(Map<String, dynamic> data, {DateTime? now}) {
    final rawDecks = data['decks'] as List? ?? const <dynamic>[];
    final decks = List<List<String>>.generate(
      kSubscriberDeckSlotsV2,
      (index) => index < rawDecks.length && rawDecks[index] is List
          ? List<String>.from(rawDecks[index] as List)
          : <String>[],
    );

    final prestigeMap = data['prestige'] is Map
        ? Map<String, dynamic>.from(data['prestige'] as Map)
        : const <String, dynamic>{};

    final ownedPackIds =
        Set<String>.from(data['ownedPackIds'] as List? ?? const <dynamic>[]);
    final rawCounts = data['ownedPackCounts'] is Map
        ? Map<String, dynamic>.from(data['ownedPackCounts'] as Map)
        : const <String, dynamic>{};
    final ownedPackCounts = <String, int>{
      for (final id in ownedPackIds)
        id: ((rawCounts[id] as num?)?.toInt() ?? 1).clamp(1, 1 << 30).toInt(),
    };

    final rawActivity = data['packLastPvpUsedAtMs'] is Map
        ? Map<String, dynamic>.from(data['packLastPvpUsedAtMs'] as Map)
        : const <String, dynamic>{};
    final packLastPvpUsedAtMs = <String, int>{
      for (final id in ownedPackIds)
        if ((rawActivity[id] as num?) != null)
          id: (rawActivity[id] as num).toInt(),
    };

    final profile = PlayerProfileV2(
      ownedPackIds: ownedPackIds,
      ownedPackCounts: ownedPackCounts,
      decks: decks,
      activeDeckIndex: (data['activeDeckIndex'] as num?)?.toInt() ?? 0,
      recentQuestionIds: RecentQuestionHistoryV2(
        List<String>.from(data['recentQuestionIds'] as List? ?? const <dynamic>[]),
      ).ids,
      packLastPvpUsedAtMs: packLastPvpUsedAtMs,
      weekKey: (data['weekKey'] as String?) ?? weeklyKeyV2(now ?? DateTime.now()),
      weeklyPoints: (data['weeklyPoints'] as num?)?.toInt() ?? 0,
      weeklyWins: (data['weeklyWins'] as num?)?.toInt() ?? 0,
      weeklyLosses: (data['weeklyLosses'] as num?)?.toInt() ?? 0,
      weeklyDraws: (data['weeklyDraws'] as num?)?.toInt() ?? 0,
      weeklySteals: (data['weeklySteals'] as num?)?.toInt() ?? 0,
      totalWins: (data['totalWins'] as num?)?.toInt() ?? 0,
      totalLosses: (data['totalLosses'] as num?)?.toInt() ?? 0,
      totalDraws: (data['totalDraws'] as num?)?.toInt() ?? 0,
      totalSteals: (data['totalSteals'] as num?)?.toInt() ?? 0,
      prestige: PrestigeHistoryV2(
        first: (prestigeMap['first'] as num?)?.toInt() ?? 0,
        second: (prestigeMap['second'] as num?)?.toInt() ?? 0,
        third: (prestigeMap['third'] as num?)?.toInt() ?? 0,
      ),
      subscriptionActive: data['subscriptionActive'] == true,
      subscriptionExpiresAt: data['subscriptionExpiresAt'] is String
          ? DateTime.tryParse(data['subscriptionExpiresAt'] as String)
          : null,
      currentTitleKey: data['currentTitleKey'] as String?,
      currentFrameKey: data['currentFrameKey'] as String?,
    );

    if (!profile.canUseDeckIndex(profile.activeDeckIndex)) {
      profile.activeDeckIndex = 0;
    }
    profile.ensureCurrentWeek(now ?? DateTime.now());
    return profile;
  }
}
