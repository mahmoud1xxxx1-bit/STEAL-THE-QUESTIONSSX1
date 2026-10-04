import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:steal_the_questions/game/game_rules.dart';

void main() {
  group('card catalog', () {
    test('contains exactly 222 cards with locked rarity distribution', () {
      final catalog = CardCatalog.foundation();

      expect(catalog.cards.length, kTotalCards);
      expect(catalog.cards.where((c) => c.rarity == CardRarity.epic).length,
          kEpicCards);
      expect(catalog.cards.where((c) => c.rarity == CardRarity.gold).length,
          kGoldCards);
      expect(
        catalog.cards.where((c) => c.rarity == CardRarity.legendary).length,
        kLegendaryCards,
      );
    });
  });

  group('bot onboarding', () {
    test('correct reward is one random unowned normal card', () {
      final catalog = CardCatalog.foundation();
      final collection = PlayerCollection(const <String>[]);
      final awarded = collection.grantBotCardRandomly(catalog, Random(7));

      expect(awarded, isNotNull);
      expect(collection.count, 1);
      expect(catalog[awarded!].rarity, isNot(CardRarity.legendary));
      expect(collection.owns(awarded), isTrue);
    });

    test('never awards a duplicate and stops at ten cards', () {
      final catalog = CardCatalog.foundation();
      final collection = PlayerCollection(const <String>[]);

      for (int i = 0; i < kPvpMinimumCollection; i++) {
        collection.grantBotCardRandomly(catalog, Random(i));
      }

      expect(collection.count, kPvpMinimumCollection);
      expect(
        collection.grantBotCardRandomly(catalog, Random(99)),
        isNull,
      );
      expect(collection.count, kPvpMinimumCollection);
      expect(collection.canEnterPvp, isTrue);
    });
  });

  group('decks', () {
    test('a deck requires ten distinct owned cards', () {
      final collection = PlayerCollection(
        List<String>.generate(
          10,
          (i) => 'Q${(i + 1).toString().padLeft(3, '0')}',
        ),
      );

      expect(
        PlayerDeck(collection.ids).isValid(collection),
        isTrue,
      );
      expect(
        PlayerDeck([
          ...collection.ids.take(9),
          'Q001',
        ]).isValid(collection),
        isFalse,
      );
    });

    test('weekly pass unlocks exactly three extra slots and fourth answer', () {
      const free = WeeklyPass(active: false);
      const pass = WeeklyPass(active: true);

      expect(free.unlockedDeckSlots, kFreeDeckSlots);
      expect(pass.unlockedDeckSlots, kMaxDeckSlots);
      expect(pass.hasFourthAnswerOption, isTrue);
      expect(free.hasFourthAnswerOption, isFalse);
    });
  });

  group('duel selection and timing', () {
    test('server seed produces exactly seven unique cards', () {
      final deck = PlayerDeck(
        List<String>.generate(
          kDeckSize,
          (i) => 'Q${(i + 1).toString().padLeft(3, '0')}',
        ),
      );

      final first = selectDuelCards(deck, 12345);
      final second = selectDuelCards(deck, 12345);

      expect(first.length, kDuelQuestions);
      expect(first.toSet().length, kDuelQuestions);
      expect(second, first);
    });

    test('duel timing constants equal the locked three-minute target', () {
      expect(kQuestionPhaseSeconds, 140);
      expect(kClosingPhaseSeconds, 40);
      expect(kFullDuelSeconds, 180);
    });
  });

  group('duel outcome', () {
    DuelAnswer answer({
      required bool correct,
      required int seconds,
      bool timedOut = false,
    }) =>
        DuelAnswer(
          correct: correct,
          responseTimeMs: seconds * 1000,
          timedOut: timedOut,
        );

    test('most correct answers wins', () {
      final one = DuelPerformance(
        List<DuelAnswer>.generate(
          7,
          (i) => answer(correct: i < 5, seconds: 5),
        ),
      );
      final two = DuelPerformance(
        List<DuelAnswer>.generate(
          7,
          (i) => answer(correct: i < 4, seconds: 1),
        ),
      );

      expect(
        decideDuelOutcome(one, two),
        DuelOutcome.playerOneWin,
      );
    });

    test('equal scores use lower total response time', () {
      final one = DuelPerformance(
        List<DuelAnswer>.generate(
          7,
          (i) => answer(correct: i < 5, seconds: 2),
        ),
      );
      final two = DuelPerformance(
        List<DuelAnswer>.generate(
          7,
          (i) => answer(correct: i < 5, seconds: 3),
        ),
      );

      expect(
        decideDuelOutcome(one, two),
        DuelOutcome.playerOneWin,
      );
    });

    test('exact score and time tie produces a draw with no winner', () {
      final performance = DuelPerformance(
        List<DuelAnswer>.generate(
          7,
          (i) => answer(correct: i < 4, seconds: 4),
        ),
      );

      expect(
        decideDuelOutcome(performance, performance),
        DuelOutcome.draw,
      );
    });

    test('timeout counts as the full twenty seconds for tie breaking', () {
      final timedOut = answer(
        correct: false,
        seconds: 1,
        timedOut: true,
      );

      expect(timedOut.effectiveResponseTimeMs, 20000);
    });
  });

  test('loss below ten cards returns player to bot onboarding', () {
    final collection = PlayerCollection(
      List<String>.generate(
        9,
        (i) => 'Q${(i + 1).toString().padLeft(3, '0')}',
      ),
    );

    expect(shouldReturnToBotAfterPvpLoss(collection), isTrue);
    collection.add('Q010', CardCatalog.foundation());
    expect(shouldReturnToBotAfterPvpLoss(collection), isFalse);
  });
}
