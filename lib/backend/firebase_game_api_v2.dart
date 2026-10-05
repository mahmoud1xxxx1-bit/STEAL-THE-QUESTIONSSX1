import 'package:cloud_functions/cloud_functions.dart';

import '../game/player_profile_v2.dart';

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

  PlayerProfileV2 _profileFromResponse(dynamic raw) {
    if (raw is! Map) throw StateError('Invalid V2 profile response.');
    final data = Map<String, dynamic>.from(raw);
    final profileRaw = data['profile'];
    if (profileRaw is! Map) throw StateError('Missing V2 profile payload.');
    return PlayerProfileV2.fromMap(Map<String, dynamic>.from(profileRaw));
  }
}
