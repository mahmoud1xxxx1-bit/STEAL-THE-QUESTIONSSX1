import '../backend/firebase_game_api_v2.dart';
import '../data/player_profile_store_v2.dart';
import 'player_profile_v2.dart';

/// Coordinates the local V2 profile cache with the server-authoritative API.
/// No question content lives here.
class OnlinePlayerSessionV2 {
  OnlinePlayerSessionV2({
    required this.store,
    required this.api,
  });

  final PlayerProfileStoreV2 store;
  final FirebaseGameApiV2 api;
  PlayerProfileV2? _profile;

  bool get initialized => _profile != null;
  PlayerProfileV2 get profile {
    final value = _profile;
    if (value == null) throw StateError('OnlinePlayerSessionV2 is not initialized.');
    return value;
  }

  Future<PlayerProfileV2> initialize() async {
    try {
      _profile = await api.ensureProfile();
      await store.save(_profile!);
    } catch (_) {
      _profile = await store.load();
    }
    return profile;
  }

  Future<PlayerProfileV2> refreshProfile() async {
    final remote = await api.loadProfile();
    _profile = remote;
    await store.save(remote);
    return remote;
  }

  Future<PlayerProfileV2> saveDeck(int deckIndex, List<String> packIds) async {
    final remote = await api.saveDeck(deckIndex: deckIndex, packIds: packIds);
    _profile = remote;
    await store.save(remote);
    return remote;
  }

  Future<PlayerProfileV2> setActiveDeck(int deckIndex) async {
    final remote = await api.setActiveDeck(deckIndex);
    _profile = remote;
    await store.save(remote);
    return remote;
  }

  Future<MatchmakingStatusV2> startMatchmaking() => api.findOrCreateDuel();
  Future<MatchmakingStatusV2> matchStatus() => api.loadMatchStatus();
  Future<void> cancelMatchmaking() => api.cancelMatchmaking();
  Future<DuelStateV2> duelState(String duelId) => api.loadDuelState(duelId);
  Future<DuelQuestionV2> startNextQuestion(String duelId) => api.startNextQuestion(duelId);

  Future<DuelAnswerReceiptV2> submitAnswer({
    required String duelId,
    required int questionIndex,
    required int selectedIndex,
  }) =>
      api.submitDuelAnswer(
        duelId: duelId,
        questionIndex: questionIndex,
        selectedIndex: selectedIndex,
      );

  Future<DuelStateV2> finalizeDuel(String duelId) async {
    final state = await api.finalizeDuel(duelId);
    await refreshProfile();
    return state;
  }

  Future<StealOptionsV2> stealOptions(String duelId) => api.loadStealOptions(duelId);

  Future<StealConfirmationV2> confirmSteal({
    required String duelId,
    required String packId,
  }) async {
    final confirmation = await api.confirmSteal(duelId: duelId, packId: packId);
    if (confirmation.winnerProfile != null) {
      _profile = confirmation.winnerProfile;
      await store.save(_profile!);
    } else {
      await refreshProfile();
    }
    return confirmation;
  }

  Future<WeeklyRankingV2> weeklyRanking() => api.loadWeeklyRanking();
}
