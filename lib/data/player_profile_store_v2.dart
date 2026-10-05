import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../game/player_profile_v2.dart';

abstract class PlayerProfileStoreV2 {
  Future<PlayerProfileV2> load();
  Future<void> save(PlayerProfileV2 profile);
  Future<void> clear();
}

class SharedPreferencesPlayerProfileStoreV2 implements PlayerProfileStoreV2 {
  SharedPreferencesPlayerProfileStoreV2({SharedPreferencesAsync? preferences})
      : _preferences = preferences ?? SharedPreferencesAsync();

  static const String storageKey = 'stq_player_profile_v2';

  final SharedPreferencesAsync _preferences;

  @override
  Future<PlayerProfileV2> load() async {
    final raw = await _preferences.getString(storageKey);
    if (raw == null || raw.trim().isEmpty) {
      return PlayerProfileV2.empty();
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return PlayerProfileV2.empty();
      return PlayerProfileV2.fromMap(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return PlayerProfileV2.empty();
    }
  }

  @override
  Future<void> save(PlayerProfileV2 profile) async {
    await _preferences.setString(storageKey, jsonEncode(profile.toMap()));
  }

  @override
  Future<void> clear() => _preferences.remove(storageKey);
}

class MemoryPlayerProfileStoreV2 implements PlayerProfileStoreV2 {
  MemoryPlayerProfileStoreV2([PlayerProfileV2? initial]) : _value = initial;

  PlayerProfileV2? _value;

  @override
  Future<PlayerProfileV2> load() async {
    final value = _value;
    if (value == null) return PlayerProfileV2.empty();
    return PlayerProfileV2.fromMap(value.toMap());
  }

  @override
  Future<void> save(PlayerProfileV2 profile) async {
    _value = PlayerProfileV2.fromMap(profile.toMap());
  }

  @override
  Future<void> clear() async {
    _value = null;
  }
}
