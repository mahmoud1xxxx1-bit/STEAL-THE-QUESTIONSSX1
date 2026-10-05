import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:steal_the_questions/game/core_engine_v2.dart';
import 'package:steal_the_questions/game/duel_engine_v2.dart';

void main() {
  test('duel winner is decided by correct answers first', () {
    final player = scoreDuelAnswersV2([
      for (var i = 0; i < 7; i++) DuelAnswerV2(correct: i < 5, elapsedMs: 10000),
    ]);
    final opponent = scoreDuelAnswersV2([
      for (var i = 0; i < 7; i++) DuelAnswerV2(correct: i < 4, elapsedMs: 1000),
    ]);
    expect(resultForPlayerV2(player: player, opponent: opponent), DuelResultV2.win);
  });

  test('equal correct answers use lower total response time', () {
    final fast = scoreDuelAnswersV2([
      for (var i = 0; i < 7; i++) DuelAnswerV2(correct: i < 4, elapsedMs: 5000),
    ]);
    final slow = scoreDuelAnswersV2([
      for (var i = 0; i < 7; i++) DuelAnswerV2(correct: i < 4, elapsedMs: 6000),
    ]);
    expect(resultForPlayerV2(player: fast, opponent: slow), DuelResultV2.win);
  });

  test('exact score and time produces draw', () {
    final a = scoreDuelAnswersV2([
      for (var i = 0; i < 7; i++) DuelAnswerV2(correct: i < 3, elapsedMs: 7000),
    ]);
    final b = scoreDuelAnswersV2([
      for (var i = 0; i < 7; i++) DuelAnswerV2(correct: i < 3, elapsedMs: 7000),
    ]);
    expect(resultForPlayerV2(player: a, opponent: b), DuelResultV2.draw);
  });

  test('answer time is clamped to twenty seconds', () {
    final score = scoreDuelAnswersV2([
      for (var i = 0; i < 7; i++) const DuelAnswerV2(correct: false, elapsedMs: 999999),
    ]);
    expect(score.totalElapsedMs, 7 * 20000);
  });

  test('bot only rewards unowned packs while player has fewer than ten', () {
    final owned = <String>{'p1', 'p2'};
    final candidates = botRewardCandidatesV2(
      allPackIds: const ['p1', 'p2', 'p3', 'p4', 'p4'],
      ownedPackIds: owned,
    );
    expect(candidates.toSet(), {'p3', 'p4'});
    expect(
      chooseBotRewardPackV2(
        allPackIds: const ['p1', 'p2', 'p3'],
        ownedPackIds: owned,
        random: Random(1),
      ),
      'p3',
    );
  });

  test('bot stops when collection reaches ten packs', () {
    final owned = {for (var i = 0; i < 10; i++) 'p$i'};
    expect(
      botRewardCandidatesV2(allPackIds: const ['extra'], ownedPackIds: owned),
      isEmpty,
    );
  });

  test('winner cannot steal a pack already owned', () {
    final opponentDeck = [for (var i = 0; i < 10; i++) 'p$i'];
    final stealable = stealablePackIdsV2(
      opponentDeckPackIds: opponentDeck,
      winnerOwnedPackIds: {'p0', 'p1', 'p2'},
    );
    expect(stealable, isNot(contains('p0')));
    expect(stealable.length, 7);
  });

  test('steal transfer is atomic in domain result and can relock pvp', () {
    final loserOwned = {for (var i = 0; i < 10; i++) 'p$i'};
    final opponentDeck = loserOwned.toList(growable: false);
    final transfer = applyStealV2(
      packId: 'p9',
      winnerOwnedPackIds: {'x1', 'x2'},
      loserOwnedPackIds: loserOwned,
      opponentDeckPackIds: opponentDeck,
    );
    expect(transfer.winnerOwnedPackIds.contains('p9'), isTrue);
    expect(transfer.loserOwnedPackIds.contains('p9'), isFalse);
    expect(transfer.loserOwnedPackIds.length, 9);
    expect(transfer.loserPvpUnlocked, isFalse);
  });
}
