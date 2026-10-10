import 'package:cloud_functions/cloud_functions.dart';

import '../game/player_profile_v2.dart';

class CustomWrongChoicesV2 {
  const CustomWrongChoicesV2({required this.cardId, required this.questionId, required this.language, required this.choices, required this.maxChoices});
  final String cardId;
  final String questionId;
  final String language;
  final List<String> choices;
  final int maxChoices;
}

class WeeklyRankingPlayerV2 {
  const WeeklyRankingPlayerV2({required this.rank, required this.uid, required this.displayName, required this.weeklyPoints, required this.weeklyWins, required this.weeklyLosses, required this.weeklyDraws, required this.weeklySteals, required this.totalSteals, required this.currentTitleKey, required this.currentFrameKey});
  final int rank;
  final String uid;
  final String displayName;
  final int weeklyPoints;
  final int weeklyWins;
  final int weeklyLosses;
  final int weeklyDraws;
  final int weeklySteals;
  final int totalSteals;
  final String? currentTitleKey;
  final String? currentFrameKey;
  factory WeeklyRankingPlayerV2.fromMap(Map<String, dynamic> data) => WeeklyRankingPlayerV2(
        rank: (data['rank'] as num?)?.toInt() ?? 0,
        uid: data['uid'] as String? ?? '',
        displayName: data['displayName'] as String? ?? 'PLAYER',
        weeklyPoints: (data['weeklyPoints'] as num?)?.toInt() ?? 0,
        weeklyWins: (data['weeklyWins'] as num?)?.toInt() ?? 0,
        weeklyLosses: (data['weeklyLosses'] as num?)?.toInt() ?? 0,
        weeklyDraws: (data['weeklyDraws'] as num?)?.toInt() ?? 0,
        weeklySteals: (data['weeklySteals'] as num?)?.toInt() ?? 0,
        totalSteals: (data['totalSteals'] as num?)?.toInt() ?? 0,
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
  const StealOptionsV2({required this.packIds, required this.alreadyConfirmed});
  final List<String> packIds;
  final bool alreadyConfirmed;
}

class StealConfirmationV2 {
  const StealConfirmationV2({required this.packId, required this.alreadyConfirmed, required this.loserPvpUnlocked, required this.loserOwnedCount, required this.winnerProfile});
  final String? packId;
  final bool alreadyConfirmed;
  final bool loserPvpUnlocked;
  final int loserOwnedCount;
  final PlayerProfileV2? winnerProfile;
}

class MatchmakingStatusV2 {
  const MatchmakingStatusV2({required this.status, required this.duelId});
  final String status;
  final String? duelId;
  bool get searching => status == 'searching';
  bool get matched => status == 'matched' && duelId != null;
}

class DuelPrepQuestionV2 {
  const DuelPrepQuestionV2({
    required this.questionId,
    required this.prompt,
    required this.blocked,
  });

  final String questionId;
  final String prompt;
  final bool blocked;
}

class DuelPrepCardV2 {
  const DuelPrepCardV2({
    required this.packId,
    required this.questions,
    required this.selectableCount,
  });

  final String packId;
  final List<DuelPrepQuestionV2> questions;
  final int selectableCount;
}

class DuelPreparationV2 {
  const DuelPreparationV2({
    required this.duelId,
    required this.requiredSelections,
    required this.cards,
    required this.canSubmit,
    required this.prepared,
    required this.opponentPrepared,
    required this.questionPlanReady,
  });

  final String duelId;
  final int requiredSelections;
  final List<DuelPrepCardV2> cards;
  final bool canSubmit;
  final bool prepared;
  final bool opponentPrepared;
  final bool questionPlanReady;
}

class DuelStateV2 {
  const DuelStateV2({required this.duelId, required this.status, required this.questionPlanReady, required this.answeredCount, required this.opponentAnsweredCount, required this.totalQuestions, required this.winnerUid, required this.loserUid, required this.result, required this.stealConfirmed, required this.stolenPackId});
  final String duelId;
  final String status;
  final bool questionPlanReady;
  final int answeredCount;
  final int opponentAnsweredCount;
  final int totalQuestions;
  final String? winnerUid;
  final String? loserUid;
  final String? result;
  final bool stealConfirmed;
  final String? stolenPackId;
  bool get finished => status == 'finished';
}

class DuelQuestionV2 {
  const DuelQuestionV2({required this.complete, required this.questionIndex, required this.packId, required this.questionId, required this.publicQuestion, required this.timeoutMs});
  final bool complete;
  final int questionIndex;
  final String? packId;
  final String? questionId;
  final Map<String, dynamic>? publicQuestion;
  final int timeoutMs;
}

class DuelAnswerReceiptV2 {
  const DuelAnswerReceiptV2({required this.correct, required this.elapsedMs, required this.answeredCount, required this.totalQuestions});
  final bool correct;
  final int elapsedMs;
  final int answeredCount;
  final int totalQuestions;
}

class FirebaseGameApiV2 {
  FirebaseGameApiV2({FirebaseFunctions? functions}) : _functions = functions ?? FirebaseFunctions.instance;
  final FirebaseFunctions _functions;

  Future<PlayerProfileV2> ensureProfile() async {
    final response = await _functions.httpsCallable('ensureProfileV2').call();
    return _profileFromResponse(response.data);
  }

  Future<PlayerProfileV2> loadProfile() async {
    final response = await _functions.httpsCallable('getProfileV2').call();
    return _profileFromResponse(response.data);
  }

  Future<PlayerProfileV2> saveDeck({required int deckIndex, required List<String> packIds}) async {
    final response = await _functions.httpsCallable('saveDeckV2').call({'deckIndex': deckIndex, 'packIds': packIds});
    return _profileFromResponse(response.data);
  }

  Future<PlayerProfileV2> setActiveDeck(int deckIndex) async {
    final response = await _functions.httpsCallable('setActiveDeckV2').call({'deckIndex': deckIndex});
    return _profileFromResponse(response.data);
  }

  Future<CustomWrongChoicesV2> loadCustomWrongChoices({required String cardId, required String questionId, required bool arabic}) async {
    final response = await _functions.httpsCallable('getCustomWrongChoicesV2').call({
      'cardId': cardId,
      'questionId': questionId,
      'language': arabic ? 'ar' : 'en',
    });
    return _customChoicesFromResponse(response.data);
  }

  Future<CustomWrongChoicesV2> saveCustomWrongChoices({required String cardId, required String questionId, required bool arabic, required List<String> choices}) async {
    final response = await _functions.httpsCallable('saveCustomWrongChoicesV2').call({
      'cardId': cardId,
      'questionId': questionId,
      'language': arabic ? 'ar' : 'en',
      'choices': choices,
    });
    return _customChoicesFromResponse(response.data);
  }

  Future<MatchmakingStatusV2> findOrCreateDuel() async {
    final response = await _functions.httpsCallable('findOrCreateDuelV2').call();
    return _matchStatusFromResponse(response.data);
  }

  Future<MatchmakingStatusV2> loadMatchStatus() async {
    final response = await _functions.httpsCallable('getMatchStatusV2').call();
    return _matchStatusFromResponse(response.data);
  }

  Future<void> cancelMatchmaking() async {
    await _functions.httpsCallable('cancelMatchmakingV2').call();
  }

  Future<DuelPreparationV2> loadDuelPreparation({
    required String duelId,
    required bool arabic,
  }) async {
    final response = await _functions.httpsCallable('getDuelPreparationV2').call({
      'duelId': duelId,
      'language': arabic ? 'ar' : 'en',
    });
    return _duelPreparationFromResponse(response.data);
  }

  Future<DuelStateV2> submitDuelPreparation({
    required String duelId,
    required bool arabic,
    required List<Map<String, String>> selections,
  }) async {
    final response = await _functions.httpsCallable('submitDuelPreparationV2').call({
      'duelId': duelId,
      'language': arabic ? 'ar' : 'en',
      'selections': selections,
    });
    return _duelStateFromResponse(response.data);
  }

  Future<DuelStateV2> loadDuelState(String duelId) async {
    final response = await _functions.httpsCallable('getDuelStateV2').call({'duelId': duelId});
    return _duelStateFromResponse(response.data);
  }

  Future<DuelStateV2> prepareDuelQuestions({required String duelId, required bool arabic}) async {
    final response = await _functions.httpsCallable('prepareDuelQuestionsV2').call({
      'duelId': duelId,
      'language': arabic ? 'ar' : 'en',
    });
    return _duelStateFromResponse(response.data);
  }

  Future<DuelQuestionV2> startNextQuestion(String duelId) async {
    final response = await _functions.httpsCallable('startNextQuestionV2').call({'duelId': duelId});
    final raw = _asMap(response.data, 'Invalid duel question response.');
    final publicQuestion = raw['question'];
    return DuelQuestionV2(
      complete: raw['complete'] == true,
      questionIndex: (raw['questionIndex'] as num?)?.toInt() ?? 0,
      packId: raw['packId'] as String?,
      questionId: raw['questionId'] as String?,
      publicQuestion: publicQuestion is Map ? Map<String, dynamic>.from(publicQuestion) : null,
      timeoutMs: (raw['timeoutMs'] as num?)?.toInt() ?? 20000,
    );
  }

  Future<DuelAnswerReceiptV2> submitDuelAnswer({required String duelId, required int questionIndex, required int selectedIndex}) async {
    final response = await _functions.httpsCallable('submitDuelAnswerV2').call({'duelId': duelId, 'questionIndex': questionIndex, 'selectedIndex': selectedIndex});
    final raw = _asMap(response.data, 'Invalid duel answer response.');
    return DuelAnswerReceiptV2(
      correct: raw['correct'] == true,
      elapsedMs: (raw['elapsedMs'] as num?)?.toInt() ?? 0,
      answeredCount: (raw['answeredCount'] as num?)?.toInt() ?? 0,
      totalQuestions: (raw['totalQuestions'] as num?)?.toInt() ?? 7,
    );
  }

  Future<DuelStateV2> finalizeDuel(String duelId) async {
    final response = await _functions.httpsCallable('finalizeDuelV2').call({'duelId': duelId});
    return _duelStateFromResponse(response.data);
  }

  Future<WeeklyRankingV2> loadWeeklyRanking() async {
    final response = await _functions.httpsCallable('getWeeklyRankingV2').call();
    final raw = _asMap(response.data, 'Invalid weekly ranking response.');
    final playersRaw = raw['players'] as List? ?? const <dynamic>[];
    return WeeklyRankingV2(
      weekKey: raw['weekKey'] as String? ?? '',
      players: playersRaw.whereType<Map>().map((p) => WeeklyRankingPlayerV2.fromMap(Map<String, dynamic>.from(p))).toList(growable: false),
    );
  }

  Future<StealOptionsV2> loadStealOptions(String duelId) async {
    final response = await _functions.httpsCallable('getStealOptionsV2').call({'duelId': duelId});
    final raw = _asMap(response.data, 'Invalid steal options response.');
    return StealOptionsV2(packIds: List<String>.from(raw['packIds'] as List? ?? const <dynamic>[]), alreadyConfirmed: raw['alreadyConfirmed'] == true);
  }

  Future<StealConfirmationV2> confirmSteal({required String duelId, required String packId}) async {
    final response = await _functions.httpsCallable('confirmStealV2').call({'duelId': duelId, 'packId': packId});
    final raw = _asMap(response.data, 'Invalid steal confirmation response.');
    final profileRaw = raw['winnerProfile'];
    return StealConfirmationV2(
      packId: raw['packId'] as String?,
      alreadyConfirmed: raw['alreadyConfirmed'] == true,
      loserPvpUnlocked: raw['loserPvpUnlocked'] == true,
      loserOwnedCount: (raw['loserOwnedCount'] as num?)?.toInt() ?? 0,
      winnerProfile: profileRaw is Map ? PlayerProfileV2.fromMap(Map<String, dynamic>.from(profileRaw)) : null,
    );
  }

  CustomWrongChoicesV2 _customChoicesFromResponse(dynamic raw) {
    final data = _asMap(raw, 'Invalid custom choices response.');
    return CustomWrongChoicesV2(
      cardId: data['cardId'] as String? ?? '',
      questionId: data['questionId'] as String? ?? '',
      language: data['language'] as String? ?? 'ar',
      choices: List<String>.from(data['choices'] as List? ?? const <dynamic>[]),
      maxChoices: (data['maxChoices'] as num?)?.toInt() ?? 0,
    );
  }

  DuelPreparationV2 _duelPreparationFromResponse(dynamic raw) {
    final data = _asMap(raw, 'Invalid duel preparation response.');
    final cardsRaw = data['cards'] as List? ?? const <dynamic>[];
    final cards = cardsRaw.whereType<Map>().map((cardRaw) {
      final card = Map<String, dynamic>.from(cardRaw);
      final questionsRaw = card['questions'] as List? ?? const <dynamic>[];
      return DuelPrepCardV2(
        packId: card['packId'] as String? ?? '',
        selectableCount: (card['selectableCount'] as num?)?.toInt() ?? 0,
        questions: questionsRaw.whereType<Map>().map((questionRaw) {
          final question = Map<String, dynamic>.from(questionRaw);
          return DuelPrepQuestionV2(
            questionId: question['questionId'] as String? ?? '',
            prompt: question['prompt'] as String? ?? '',
            blocked: question['blocked'] == true,
          );
        }).toList(growable: false),
      );
    }).toList(growable: false);
    return DuelPreparationV2(
      duelId: data['duelId'] as String? ?? '',
      requiredSelections: (data['requiredSelections'] as num?)?.toInt() ?? 7,
      cards: cards,
      canSubmit: data['canSubmit'] == true,
      prepared: data['prepared'] == true,
      opponentPrepared: data['opponentPrepared'] == true,
      questionPlanReady: data['questionPlanReady'] == true,
    );
  }

  MatchmakingStatusV2 _matchStatusFromResponse(dynamic raw) {
    final data = _asMap(raw, 'Invalid matchmaking response.');
    return MatchmakingStatusV2(status: data['status'] as String? ?? 'idle', duelId: data['duelId'] as String?);
  }

  DuelStateV2 _duelStateFromResponse(dynamic raw) {
    final data = _asMap(raw, 'Invalid duel state response.');
    return DuelStateV2(
      duelId: data['duelId'] as String? ?? '',
      status: data['status'] as String? ?? 'matched',
      questionPlanReady: data['questionPlanReady'] == true,
      answeredCount: (data['answeredCount'] as num?)?.toInt() ?? 0,
      opponentAnsweredCount: (data['opponentAnsweredCount'] as num?)?.toInt() ?? 0,
      totalQuestions: (data['totalQuestions'] as num?)?.toInt() ?? 7,
      winnerUid: data['winnerUid'] as String?,
      loserUid: data['loserUid'] as String?,
      result: data['result'] as String?,
      stealConfirmed: data['stealConfirmed'] == true,
      stolenPackId: data['stolenPackId'] as String?,
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
