import 'package:cloud_functions/cloud_functions.dart';

import '../game/player_profile_v2.dart';

class BotStatusV2 {
  const BotStatusV2({
    required this.botUnlocked,
    required this.ownedCount,
    required this.targetCount,
    required this.contentAvailable,
  });

  final bool botUnlocked;
  final int ownedCount;
  final int targetCount;
  final bool contentAvailable;
}

class BotRoundV2 {
  const BotRoundV2({
    required this.roundId,
    required this.cardId,
    required this.questionId,
    required this.prompt,
    required this.choices,
    required this.timeoutMs,
  });

  final String roundId;
  final String cardId;
  final String questionId;
  final String? prompt;
  final List<String> choices;
  final int timeoutMs;
}

class BotAnswerResultV2 {
  const BotAnswerResultV2({
    required this.alreadyResolved,
    required this.correct,
    required this.awarded,
    required this.awardedCardId,
    required this.botUnlocked,
    required this.profile,
  });

  final bool alreadyResolved;
  final bool correct;
  final bool awarded;
  final String? awardedCardId;
  final bool botUnlocked;
  final PlayerProfileV2 profile;
}

class BotApiV2 {
  BotApiV2({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  Future<BotStatusV2> loadStatus() async {
    final response = await _functions.httpsCallable('getBotStatusV2').call();
    final raw = _map(response.data);
    return BotStatusV2(
      botUnlocked: raw['botUnlocked'] == true,
      ownedCount: (raw['ownedCount'] as num?)?.toInt() ?? 0,
      targetCount: (raw['targetCount'] as num?)?.toInt() ?? 10,
      contentAvailable: raw['contentAvailable'] == true,
    );
  }

  Future<BotRoundV2> startRound({required bool arabic}) async {
    final response = await _functions.httpsCallable('startBotRoundV2').call({
      'language': arabic ? 'ar' : 'en',
    });
    final raw = _map(response.data);
    return BotRoundV2(
      roundId: raw['roundId'] as String? ?? '',
      cardId: raw['cardId'] as String? ?? '',
      questionId: raw['questionId'] as String? ?? '',
      prompt: raw['prompt'] as String?,
      choices: List<String>.from(raw['choices'] as List? ?? const <dynamic>[]),
      timeoutMs: (raw['timeoutMs'] as num?)?.toInt() ?? 20000,
    );
  }

  Future<BotAnswerResultV2> submitAnswer({
    required String roundId,
    required int selectedIndex,
  }) async {
    final response = await _functions.httpsCallable('submitBotAnswerV2').call({
      'roundId': roundId,
      'selectedIndex': selectedIndex,
    });
    final raw = _map(response.data);
    final profileRaw = raw['profile'];
    if (profileRaw is! Map) {
      throw StateError('Missing V2 profile in bot answer response.');
    }
    return BotAnswerResultV2(
      alreadyResolved: raw['alreadyResolved'] == true,
      correct: raw['correct'] == true,
      awarded: raw['awarded'] == true,
      awardedCardId: raw['awardedCardId'] as String?,
      botUnlocked: raw['botUnlocked'] == true,
      profile: PlayerProfileV2.fromMap(Map<String, dynamic>.from(profileRaw)),
    );
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is! Map) throw StateError('Invalid V2 bot response.');
    return Map<String, dynamic>.from(value);
  }
}
