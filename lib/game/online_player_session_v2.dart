import '../backend/bot_api_v2.dart';
import '../backend/firebase_game_api_v2.dart';
import '../backend/profile_features_api_v2.dart';
import '../data/player_profile_store_v2.dart';
import 'core_engine_v2.dart';
import 'player_profile_v2.dart';

/// Coordinates the local V2 profile cache with server-authoritative APIs.
/// No question content lives here.
class OnlinePlayerSessionV2 {
  OnlinePlayerSessionV2({
    required this.store,
    required this.api,
    required this.botApi,
    ProfileFeaturesApiV2? profileApi,
  }) : profileApi = profileApi ?? ProfileFeaturesApiV2();

  final PlayerProfileStoreV2 store;
  final FirebaseGameApiV2 api;
  final BotApiV2 botApi;
  final ProfileFeaturesApiV2 profileApi;
  PlayerProfileV2? _profile;
  bool _remoteConnected = false;

  bool get initialized => _profile != null;
  bool get remoteConnected => _remoteConnected;
  PlayerProfileV2 get profile {
    final value = _profile;
    if (value == null) {
      throw StateError('OnlinePlayerSessionV2 is not initialized.');
    }
    return value;
  }

  Future<PlayerProfileV2> initialize() async {
    try {
      _profile = await api.ensureProfile();
      _remoteConnected = true;
      await store.save(_profile!);
    } catch (_) {
      _remoteConnected = false;
      _profile = await store.load();
    }
    return profile;
  }

  Future<PlayerProfileV2> refreshProfile() async {
    try {
      final remote = await api.loadProfile();
      _remoteConnected = true;
      _profile = remote;
      await store.save(remote);
      return remote;
    } catch (_) {
      _remoteConnected = false;
      _profile ??= await store.load();
      return profile;
    }
  }

  Future<PlayerProfileV2> saveDeck(int deckIndex, List<String> packIds) async {
    try {
      final remote = await api.saveDeck(
        deckIndex: deckIndex,
        packIds: packIds,
      );
      _remoteConnected = true;
      _profile = remote;
      await store.save(remote);
      return remote;
    } catch (_) {
      _remoteConnected = false;
      final current = profile;
      if (!current.setDeck(deckIndex, packIds)) {
        throw StateError('INVALID_LOCAL_DECK');
      }
      await store.save(current);
      return current;
    }
  }

  Future<PlayerProfileV2> setActiveDeck(int deckIndex) async {
    try {
      final remote = await api.setActiveDeck(deckIndex);
      _remoteConnected = true;
      _profile = remote;
      await store.save(remote);
      return remote;
    } catch (_) {
      _remoteConnected = false;
      final current = profile;
      if (!current.canUseDeckIndex(deckIndex) ||
          !PlayerDeckV2(current.decks[deckIndex]).isValid(current.ownedPackIds)) {
        throw StateError('INVALID_LOCAL_DECK');
      }
      current.activeDeckIndex = deckIndex;
      await store.save(current);
      return current;
    }
  }

  Future<PlayerProfileV2> resetSparkOnboarding() async {
    final fresh = PlayerProfileV2.empty(now: DateTime.now());
    _profile = fresh;
    _remoteConnected = false;
    await store.save(fresh);
    return fresh;
  }

  Future<PlayerProfileV2> ensureSparkTestProfile() async {
    final current = profile;
    if (current.ownedPackIds.length < 12) {
      for (var i = 1; i <= 14; i++) {
        final id = 'spark_test_card_${i.toString().padLeft(2, '0')}';
        current.ownedPackIds.add(id);
        current.ownedPackCounts[id] = current.ownedPackCounts[id] ?? 1;
      }
    }
    if (!PlayerDeckV2(current.decks[0]).isValid(current.ownedPackIds)) {
      current.decks[0] = current.ownedPackIds.take(kDeckSizeV2).toList(growable: false);
      current.activeDeckIndex = 0;
    }
    await store.save(current);
    return current;
  }

  Future<PlayerProfileV2> saveSparkTestProfile() async {
    await store.save(profile);
    return profile;
  }

  Future<PlayerProfileV2> applySparkTestResult(DuelResultV2 result) async {
    profile.applyDuelResult(result);
    await store.save(profile);
    return profile;
  }

  Future<PlayerProfileV2> addSparkTestCard(String packId) async {
    profile.ownedPackIds.add(packId);
    profile.ownedPackCounts[packId] =
        (profile.ownedPackCounts[packId] ?? 0) + 1;
    await store.save(profile);
    return profile;
  }

  Future<PlayerProfileV2> setSparkTestSubscription(bool active) async {
    profile.subscriptionActive = active;
    profile.subscriptionExpiresAt =
        active ? DateTime.now().add(const Duration(days: 30)) : null;
    await store.save(profile);
    return profile;
  }

  Future<PlayerProfileV2> equipSparkTestPrestige() async {
    profile.currentTitleKey = 'champion_of_the_week';
    profile.currentFrameKey = 'weekly_gold_frame';
    await store.save(profile);
    return profile;
  }

  Future<CustomWrongChoicesV2> customWrongChoices({
    required String cardId,
    required String questionId,
    required bool arabic,
  }) =>
      api.loadCustomWrongChoices(
        cardId: cardId,
        questionId: questionId,
        arabic: arabic,
      );

  Future<CustomWrongChoicesV2> saveCustomWrongChoices({
    required String cardId,
    required String questionId,
    required bool arabic,
    required List<String> choices,
  }) =>
      api.saveCustomWrongChoices(
        cardId: cardId,
        questionId: questionId,
        arabic: arabic,
        choices: choices,
      );

  Future<BotStatusV2> botStatus() => botApi.loadStatus();

  Future<BotRoundV2> startBotRound({required bool arabic}) =>
      botApi.startRound(arabic: arabic);

  Future<BotAnswerResultV2> submitBotAnswer({
    required String roundId,
    required int selectedIndex,
  }) async {
    final result = await botApi.submitAnswer(
      roundId: roundId,
      selectedIndex: selectedIndex,
    );
    _profile = result.profile;
    await store.save(result.profile);
    return result;
  }

  Future<MatchmakingStatusV2> startMatchmaking() =>
      api.findOrCreateDuel();

  Future<MatchmakingStatusV2> matchStatus() =>
      api.loadMatchStatus();

  Future<void> cancelMatchmaking() =>
      api.cancelMatchmaking();

  Future<DuelStateV2> duelState(String duelId) =>
      api.loadDuelState(duelId);

  Future<DuelPreparationV2> duelPreparation({
    required String duelId,
    required bool arabic,
  }) =>
      api.loadDuelPreparation(duelId: duelId, arabic: arabic);

  Future<DuelStateV2> submitDuelPreparation({
    required String duelId,
    required bool arabic,
    required List<Map<String, String>> selections,
  }) =>
      api.submitDuelPreparation(
        duelId: duelId,
        arabic: arabic,
        selections: selections,
      );

  Future<DuelStateV2> prepareDuelQuestions({
    required String duelId,
    required bool arabic,
  }) async {
    final state = await api.prepareDuelQuestions(
      duelId: duelId,
      arabic: arabic,
    );
    await refreshProfile();
    return state;
  }

  Future<DuelQuestionV2> startNextQuestion(String duelId) =>
      api.startNextQuestion(duelId);

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

  Future<StealOptionsV2> stealOptions(String duelId) =>
      api.loadStealOptions(duelId);

  Future<StealConfirmationV2> confirmSteal({
    required String duelId,
    required String packId,
  }) async {
    final confirmation = await api.confirmSteal(
      duelId: duelId,
      packId: packId,
    );
    if (confirmation.winnerProfile != null) {
      _profile = confirmation.winnerProfile;
      await store.save(_profile!);
    } else {
      await refreshProfile();
    }
    return confirmation;
  }

  Future<WeeklyRankingV2> weeklyRanking() =>
      api.loadWeeklyRanking();

  Future<PublicPlayerProfileV2> publicProfile({String? uid}) =>
      profileApi.loadPublicProfile(uid: uid);

  Future<PlayerProfileV2> equipPrestige({
    String? titleKey,
    String? frameKey,
  }) async {
    final remote = await profileApi.equipPrestige(
      titleKey: titleKey,
      frameKey: frameKey,
    );
    _profile = remote;
    await store.save(remote);
    return remote;
  }

  Future<bool> verifySubscriptionPurchase({
    required String productId,
    required String source,
    required String serverVerificationData,
    String? purchaseId,
  }) =>
      profileApi.verifySubscriptionPurchase(
        productId: productId,
        source: source,
        serverVerificationData: serverVerificationData,
        purchaseId: purchaseId,
      );

  Future<SubscriptionStatusV2> subscriptionStatus() =>
      profileApi.loadSubscriptionStatus();

  Future<SubscriptionStatusV2> refreshSubscription() async {
    final status = await profileApi.refreshSubscription();
    if (status.profile != null) {
      _profile = status.profile;
      await store.save(_profile!);
    } else {
      await refreshProfile();
    }
    return status;
  }
}
