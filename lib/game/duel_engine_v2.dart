import 'dart:math';

import 'core_engine_v2.dart';

class DuelAnswerV2 {
  const DuelAnswerV2({
    required this.correct,
    required this.elapsedMs,
  });

  final bool correct;
  final int elapsedMs;

  int get normalizedElapsedMs {
    const maxMs = kSecondsPerQuestionV2 * 1000;
    if (elapsedMs < 0) return 0;
    if (elapsedMs > maxMs) return maxMs;
    return elapsedMs;
  }
}

class DuelScoreV2 {
  const DuelScoreV2({
    required this.correctAnswers,
    required this.totalElapsedMs,
  });

  final int correctAnswers;
  final int totalElapsedMs;
}

DuelScoreV2 scoreDuelAnswersV2(Iterable<DuelAnswerV2> answers) {
  final list = answers.toList(growable: false);
  if (list.length != kDuelCardsV2) {
    throw StateError('A duel result requires exactly $kDuelCardsV2 answers.');
  }
  return DuelScoreV2(
    correctAnswers: list.where((answer) => answer.correct).length,
    totalElapsedMs: list.fold<int>(0, (sum, answer) => sum + answer.normalizedElapsedMs),
  );
}

DuelResultV2 resultForPlayerV2({
  required DuelScoreV2 player,
  required DuelScoreV2 opponent,
}) {
  if (player.correctAnswers > opponent.correctAnswers) return DuelResultV2.win;
  if (player.correctAnswers < opponent.correctAnswers) return DuelResultV2.loss;
  if (player.totalElapsedMs < opponent.totalElapsedMs) return DuelResultV2.win;
  if (player.totalElapsedMs > opponent.totalElapsedMs) return DuelResultV2.loss;
  return DuelResultV2.draw;
}

List<String> botRewardCandidatesV2({
  required Iterable<String> allPackIds,
  required Set<String> ownedPackIds,
}) {
  if (ownedPackIds.length >= kDeckSizeV2) return const <String>[];
  final unique = <String>{};
  for (final id in allPackIds) {
    final normalized = id.trim();
    if (normalized.isNotEmpty && !ownedPackIds.contains(normalized)) {
      unique.add(normalized);
    }
  }
  return List<String>.unmodifiable(unique);
}

String chooseBotRewardPackV2({
  required Iterable<String> allPackIds,
  required Set<String> ownedPackIds,
  required Random random,
}) {
  final candidates = botRewardCandidatesV2(
    allPackIds: allPackIds,
    ownedPackIds: ownedPackIds,
  );
  if (candidates.isEmpty) {
    throw StateError('No eligible V2 bot reward pack is available.');
  }
  return candidates[random.nextInt(candidates.length)];
}

List<String> stealablePackIdsV2({
  required Iterable<String> opponentDeckPackIds,
  required Set<String> winnerOwnedPackIds,
}) {
  final deck = opponentDeckPackIds.toList(growable: false);
  if (deck.length != kDeckSizeV2 || deck.toSet().length != kDeckSizeV2) {
    throw StateError('Opponent deck must contain exactly 10 distinct packs.');
  }
  return List<String>.unmodifiable(
    deck.where((id) => !winnerOwnedPackIds.contains(id)),
  );
}

class StealTransferV2 {
  const StealTransferV2({
    required this.winnerOwnedPackIds,
    required this.loserOwnedPackIds,
    required this.loserPvpUnlocked,
  });

  final Set<String> winnerOwnedPackIds;
  final Set<String> loserOwnedPackIds;
  final bool loserPvpUnlocked;
}

StealTransferV2 applyStealV2({
  required String packId,
  required Set<String> winnerOwnedPackIds,
  required Set<String> loserOwnedPackIds,
  required Iterable<String> opponentDeckPackIds,
}) {
  final eligible = stealablePackIdsV2(
    opponentDeckPackIds: opponentDeckPackIds,
    winnerOwnedPackIds: winnerOwnedPackIds,
  );
  if (!eligible.contains(packId)) {
    throw StateError('Selected pack is not eligible to steal.');
  }
  if (!loserOwnedPackIds.contains(packId)) {
    throw StateError('Opponent no longer owns the selected pack.');
  }

  final nextWinner = <String>{...winnerOwnedPackIds, packId};
  final nextLoser = <String>{...loserOwnedPackIds}..remove(packId);

  return StealTransferV2(
    winnerOwnedPackIds: Set<String>.unmodifiable(nextWinner),
    loserOwnedPackIds: Set<String>.unmodifiable(nextLoser),
    loserPvpUnlocked: nextLoser.length >= kDeckSizeV2,
  );
}
