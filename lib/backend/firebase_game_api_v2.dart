import 'package:cloud_functions/cloud_functions.dart';

import '../game/player_profile_v2.dart';

class WeeklyRankingPlayerV2 {
  const WeeklyRankingPlayerV2({
    required this.rank,
    required this.uid,
    required this.displayName,
    required this.weeklyPoints,
    required this.weeklyWins,
    required this.weeklyLosses,
    required this.weeklyDraws,
    required this.currentTitleKey,
    required this.currentFrameKey,
  });

  final int rank;
  final String uid;
  final String displayName;
  final int weeklyPoints;
  final int weeklyWins;
  final int weeklyLosses;
  final int weeklyDraws;
  final String? currentTitleKey;
  final String? currentFrameKey;

  factory WeeklyRankingPlayerV2.fromMap(Map<String, dynamic> data) =>
      WeeklyRankingPlayerV2(
        rank: (data['rank'] as num?)?.toInt() ?? 0,
        uid: data['uid'] as String? ?? '',
        displayName: data['displayName'] as String? ?? 'PLAYER',
        weeklyPoints: (data['weeklyPoints'] as num?)?.toInt() ?? 0,
        weeklyWins: (data['weeklyWins'] as num?)?.toInt() ?? 0,
        weeklyLosses: (data['weeklyLosses'] as num?)?.toInt() ?? 0,
        weeklyDraws: (data['weeklyDraws'] as num?)?.toInt() ?? 0,
        currentTitleKey: data['currentTitleKey'] as String?,
        currentFrameKey: data['currentFrameKey'] as String?,
      );
}

class WeeklyRankingV2 {
  const WeeklyRankingV2({required this.weekKey, required this.players});

  final String weekKey;
  final List<WeeklyRankingPlayerV2> players;
}

class StealOptionsV2 {
  const StealOptionsV2({
    required this.packIds,
    required this.alreadyConfirmed,
  });

  final List<String> packIds;
  final bool alreadyConfirmed;
}

class StealConfirmationV2 {
  const StealConfirmationV2({
    required this.packId,
    required this.alreadyConfirmed,
    required this.loserPvpUnlocked,
    required this.loserOwnedCount,
    required this.winnerProfile,
  });

  final String? packId;
  final bool alreadyConfirmed;
  final bool loserPvpUnlocked;
  final int loserOwnedCount;
  final PlayerProfileV2? winnerProfile;
}

class FirebaseGameApiV2 {
  FirebaseGameApiV2({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  Future<PlayerProfileV2> ensureProfile() async {
    final response = await _functions.httpsCallable('ensureProfileV2').call();
    return _profileFromResponse(response.data);
  }

  Future<PlayerProfileV2> loadProfile() async {
    final response = await _functions.httpsCallable('getProfileV2').call();
    return _profileFromResponse(response.data);
  }

  Future<PlayerProfileV2> saveDeck({
    required int deckIndex,
    required List<String> packIds,
  }) async {
    final response = await _functions.httpsCallable('saveDeckV2').call({
      'deckIndex': deckIndex,
      'packIds': packIds,
    });
    return _profileFromResponse(response.data);
  }

  Future<PlayerProfileV2> setActiveDeck(int deckIndex) async {
    final response = await _functions.httpsCallable('setActiveDeckV2').call({
      'deckIndex': deckIndex,
    });
    return _profileFromResponse(response.data);
  }

  Future<WeeklyRankingV2> loadWeeklyRanking() async {
    final response = await _functions.httpsCallable('getWeeklyRankingV2').call();
    final raw = _asMap(response.data, 'Invalid weekly ranking response.');
    final playersRaw = raw['players'] as List? ?? const <dynamic>[];
    return WeeklyRankingV2(
      weekKey: raw['weekKey'] as String? ?? '',
      players: playersRaw
          .whereType<Map>()
          .map((p) => WeeklyRankingPlayerV2.fromMap(Map<String, dynamic>.from(p)))
          .toList(growable: false),
    );
  }

  Future<StealOptionsV2> loadStealOptions(String duelId) async {
    final response = await _functions.httpsCallable('getStealOptionsV2').call({
      'duelId': duelId,
    });
    final raw = _asMap(response.data, 'Invalid steal options response.');
    return StealOptionsV2(
      packIds: List<String>.from(raw['packIds'] as List? ?? const <dynamic>[]),
      alreadyConfirmed: raw['alreadyConfirmed'] == true,
    );
  }

  Future<StealConfirmationV2> confirmSteal({
    required String duelId,
    required String packId,
  }) async {
    final response = await _functions.httpsCallable('confirmStealV2').call({
      'duelId': duelId,
      'packId': packId,
    });
    final raw = _asMap(response.data, 'Invalid steal confirmation response.');
    final profileRaw = raw['winnerProfile'];
    return StealConfirmationV2(
      packId: raw['packId'] as String?,
      alreadyConfirmed: raw['alreadyConfirmed'] == true,
      loserPvpUnlocked: raw['loserPvpUnlocked'] == true,
      loserOwnedCount: (raw['loserOwnedCount'] as num?)?.toInt() ?? 0,
      winnerProfile: profileRaw is Map
          ? PlayerProfileV2.fromMap(Map<String, dynamic>.from(profileRaw))
          : null,
    );
  }

  PlayerProfileV2 _profileFromResponse(dynamic raw) {
    final data = _asMap(raw, 'Invalid V2 profile response.');
    final profileRaw = data['profile'];
    if (profileRaw is! Map) throw StateError('Missing V2 profile payload.');
    return PlayerProfileV2.fromMap(Map<String, dynamic>.from(profileRaw));
  }

  Map<String, dynamic> _asMap(dynamic raw, String error) {
    if (raw is! Map) throw StateError(error);
    return Map<String, dynamic>.from(raw);
  }
}
