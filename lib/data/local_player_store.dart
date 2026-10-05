import 'package:shared_preferences/shared_preferences.dart';

class LocalPlayerSnapshot {
  const LocalPlayerSnapshot({
    required this.ownedCards,
    required this.decks,
    required this.weeklyPass,
    required this.weeklyPassExpiresAt,
    required this.wins,
    required this.losses,
    required this.activeDeck,
    required this.tutorialComplete,
  });

  final List<String> ownedCards;
  final List<List<String>> decks;
  final bool weeklyPass;
  final DateTime? weeklyPassExpiresAt;
  final int wins;
  final int losses;
  final int activeDeck;
  final bool tutorialComplete;
}

class LocalPlayerStore {
  static const _ownedKey = 'stq_owned_cards';
  static const _passKey = 'stq_weekly_pass';
  static const _passExpiryKey = 'stq_weekly_pass_expiry';
  static const _winsKey = 'stq_wins';
  static const _lossesKey = 'stq_losses';
  static const _activeDeckKey = 'stq_active_deck';
  static const _tutorialKey = 'stq_tutorial_complete';
  static const _deckPrefix = 'stq_deck_';

  final SharedPreferencesAsync _prefs = SharedPreferencesAsync();

  Future<LocalPlayerSnapshot> load() async {
    final owned = await _prefs.getStringList(_ownedKey) ?? const <String>[];
    final decks = <List<String>>[];
    for (int i = 0; i < 5; i++) {
      decks.add(await _prefs.getStringList(_deckPrefix + i.toString()) ?? const <String>[]);
    }
    final expiryRaw = await _prefs.getString(_passExpiryKey);
    DateTime? expiry;
    if (expiryRaw != null) expiry = DateTime.tryParse(expiryRaw);
    final savedPass = await _prefs.getBool(_passKey) ?? false;
    final passActive = savedPass && expiry != null && expiry.isAfter(DateTime.now());
    return LocalPlayerSnapshot(
      ownedCards: List<String>.from(owned),
      decks: decks,
      weeklyPass: passActive,
      weeklyPassExpiresAt: expiry,
      wins: await _prefs.getInt(_winsKey) ?? 0,
      losses: await _prefs.getInt(_lossesKey) ?? 0,
      activeDeck: await _prefs.getInt(_activeDeckKey) ?? 0,
      tutorialComplete: await _prefs.getBool(_tutorialKey) ?? false,
    );
  }

  Future<void> save({
    required Iterable<String> ownedCards,
    required List<List<String>> decks,
    required bool weeklyPass,
    required DateTime? weeklyPassExpiresAt,
    required int wins,
    required int losses,
    required int activeDeck,
    required bool tutorialComplete,
  }) async {
    await _prefs.setStringList(_ownedKey, ownedCards.toList(growable: false));
    for (int i = 0; i < decks.length && i < 5; i++) {
      await _prefs.setStringList(_deckPrefix + i.toString(), decks[i]);
    }
    await _prefs.setBool(_passKey, weeklyPass);
    if (weeklyPassExpiresAt == null) {
      await _prefs.remove(_passExpiryKey);
    } else {
      await _prefs.setString(_passExpiryKey, weeklyPassExpiresAt.toIso8601String());
    }
    await _prefs.setInt(_winsKey, wins);
    await _prefs.setInt(_lossesKey, losses);
    await _prefs.setInt(_activeDeckKey, activeDeck);
    await _prefs.setBool(_tutorialKey, tutorialComplete);
  }
}
