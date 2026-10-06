import 'package:cloud_functions/cloud_functions.dart';

import '../game/player_profile_v2.dart';

class PublicPlayerProfileV2 {
  const PublicPlayerProfileV2({
    required this.uid,
    required this.displayName,
    required this.ownedCount,
    required this.totalWins,
    required this.totalLosses,
    required this.totalDraws,
    required this.firstPlaces,
    required this.secondPlaces,
    required this.thirdPlaces,
    required this.currentTitleKey,
    required this.currentFrameKey,
    required this.unlockedTitleKeys,
    required this.unlockedFrameKeys,
  });

  final String uid;
  final String displayName;
  final int ownedCount;
  final int totalWins;
  final int totalLosses;
  final int totalDraws;
  final int firstPlaces;
  final int secondPlaces;
  final int thirdPlaces;
  final String? currentTitleKey;
  final String? currentFrameKey;
  final List<String> unlockedTitleKeys;
  final List<String> unlockedFrameKeys;

  factory PublicPlayerProfileV2.fromMap(Map<String, dynamic> data) {
    final prestige = data['prestige'] is Map
        ? Map<String, dynamic>.from(data['prestige'] as Map)
        : const <String, dynamic>{};
    return PublicPlayerProfileV2(
      uid: data['uid'] as String? ?? '',
      displayName: data['displayName'] as String? ?? 'PLAYER',
      ownedCount: (data['ownedCount'] as num?)?.toInt() ?? 0,
      totalWins: (data['totalWins'] as num?)?.toInt() ?? 0,
      totalLosses: (data['totalLosses'] as num?)?.toInt() ?? 0,
      totalDraws: (data['totalDraws'] as num?)?.toInt() ?? 0,
      firstPlaces: (prestige['first'] as num?)?.toInt() ?? 0,
      secondPlaces: (prestige['second'] as num?)?.toInt() ?? 0,
      thirdPlaces: (prestige['third'] as num?)?.toInt() ?? 0,
      currentTitleKey: data['currentTitleKey'] as String?,
      currentFrameKey: data['currentFrameKey'] as String?,
      unlockedTitleKeys: List<String>.from(
        data['unlockedTitleKeys'] as List? ?? const <dynamic>[],
      ),
      unlockedFrameKeys: List<String>.from(
        data['unlockedFrameKeys'] as List? ?? const <dynamic>[],
      ),
    );
  }
}

class SubscriptionStatusV2 {
  const SubscriptionStatusV2({
    required this.active,
    required this.expiresAt,
    required this.source,
    required this.productId,
    required this.deckSlots,
    required this.answerChoices,
    required this.editableWrongChoices,
    this.profile,
  });

  final bool active;
  final DateTime? expiresAt;
  final String? source;
  final String? productId;
  final int deckSlots;
  final int answerChoices;
  final int editableWrongChoices;
  final PlayerProfileV2? profile;
}

class ProfileFeaturesApiV2 {
  ProfileFeaturesApiV2({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  Future<PublicPlayerProfileV2> loadPublicProfile({String? uid}) async {
    final response = await _functions.httpsCallable('getPublicProfileV2').call({
      if (uid != null && uid.trim().isNotEmpty) 'uid': uid.trim(),
    });
    final raw = _map(response.data, 'Invalid public profile response.');
    final profileRaw = raw['profile'];
    if (profileRaw is! Map) {
      throw StateError('Missing public V2 profile payload.');
    }
    return PublicPlayerProfileV2.fromMap(
      Map<String, dynamic>.from(profileRaw),
    );
  }

  Future<PlayerProfileV2> equipPrestige({
    String? titleKey,
    String? frameKey,
  }) async {
    final response = await _functions.httpsCallable('equipPrestigeV2').call({
      'titleKey': titleKey,
      'frameKey': frameKey,
    });
    final raw = _map(response.data, 'Invalid prestige response.');
    final profileRaw = raw['profile'];
    if (profileRaw is! Map) {
      throw StateError('Missing V2 profile after prestige update.');
    }
    return PlayerProfileV2.fromMap(Map<String, dynamic>.from(profileRaw));
  }

  Future<bool> verifySubscriptionPurchase({
    required String productId,
    required String source,
    required String serverVerificationData,
    String? purchaseId,
  }) async {
    final response = await _functions.httpsCallable('verifySubscriptionPurchaseV2').call({
      'productId': productId,
      'source': source,
      'platform': source,
      'serverVerificationData': serverVerificationData,
      'purchaseId': purchaseId,
    });
    final raw = _map(response.data, 'Invalid purchase verification response.');
    return raw['verified'] == true;
  }

  Future<SubscriptionStatusV2> loadSubscriptionStatus() async {
    final response =
        await _functions.httpsCallable('getSubscriptionStatusV2').call();
    return _subscriptionFromResponse(response.data);
  }

  Future<SubscriptionStatusV2> refreshSubscription() async {
    final response =
        await _functions.httpsCallable('refreshSubscriptionV2').call();
    return _subscriptionFromResponse(response.data);
  }

  SubscriptionStatusV2 _subscriptionFromResponse(dynamic value) {
    final raw = _map(value, 'Invalid subscription response.');
    final expiresAtMs = (raw['expiresAtMs'] as num?)?.toInt();
    final profileRaw = raw['profile'];
    return SubscriptionStatusV2(
      active: raw['active'] == true,
      expiresAt: expiresAtMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(expiresAtMs, isUtc: true),
      source: raw['source'] as String?,
      productId: raw['productId'] as String?,
      deckSlots: (raw['deckSlots'] as num?)?.toInt() ?? 2,
      answerChoices: (raw['answerChoices'] as num?)?.toInt() ?? 3,
      editableWrongChoices:
          (raw['editableWrongChoices'] as num?)?.toInt() ?? 2,
      profile: profileRaw is Map
          ? PlayerProfileV2.fromMap(Map<String, dynamic>.from(profileRaw))
          : null,
    );
  }

  Map<String, dynamic> _map(dynamic value, String error) {
    if (value is! Map) throw StateError(error);
    return Map<String, dynamic>.from(value);
  }
}
