/// Pure game-domain rules for STEAL THE QUESTIONS.
///
/// This file intentionally has no Flutter/Firebase dependency. It is the
/// contract the UI and future server code must implement.
library;

import 'dart:math';

const int kTotalCards = 222;
const int kLegendaryCards = 22;
const int kGoldCards = 50;
const int kEpicCards = 150;

const int kDeckSize = 10;
const int kFreeDeckSlots = 2;
const int kPassDeckSlots = 3;
const int kMaxDeckSlots = 5;

const int kPvpMinimumCollection = 10;
const int kDuelQuestions = 7;
const int kSecondsPerQuestion = 20;
const int kQuestionPhaseSeconds = kDuelQuestions * kSecondsPerQuestion;
const int kClosingPhaseSeconds = 40;
const int kFullDuelSeconds = kQuestionPhaseSeconds + kClosingPhaseSeconds;

enum CardRarity {
  epic,
  gold,
  legendary,
}

class QuestionCard {
  const QuestionCard({
    required this.id,
    required this.rarity,
  });

  final String id;
  final CardRarity rarity;
}

class CardCatalog {
  CardCatalog(List<QuestionCard> cards)
      : cards = List<QuestionCard>.unmodifiable(cards),
        _byId = <String, QuestionCard>{
          for (final card in cards) card.id: card,
        } {
    _validate();
  }

  final List<QuestionCard> cards;
  final Map<String, QuestionCard> _byId;

  QuestionCard operator [](String id) {
    final card = _byId[id];
    if (card == null) {
      throw ArgumentError('Unknown card: $id');
    }
    return card;
  }

  Iterable<QuestionCard> get normalCards =>
      cards.where((card) => card.rarity != CardRarity.legendary);

  Iterable<QuestionCard> get legendaryCards =>
      cards.where((card) => card.rarity == CardRarity.legendary);

  static CardCatalog foundation() {
    final cards = <QuestionCard>[];

    for (int i = 1; i <= kEpicCards; i++) {
      cards.add(QuestionCard(
        id: 'Q${i.toString().padLeft(3, '0')}',
        rarity: CardRarity.epic,
      ));
    }

    for (int i = kEpicCards + 1; i <= kEpicCards + kGoldCards; i++) {
      cards.add(QuestionCard(
        id: 'Q${i.toString().padLeft(3, '0')}',
        rarity: CardRarity.gold,
      ));
    }

    for (int i = kEpicCards + kGoldCards + 1; i <= kTotalCards; i++) {
      cards.add(QuestionCard(
        id: 'Q${i.toString().padLeft(3, '0')}',
        rarity: CardRarity.legendary,
      ));
    }

    return CardCatalog(cards);
  }

  void _validate() {
    if (cards.length != kTotalCards) {
      throw StateError('Catalog must contain exactly $kTotalCards cards.');
    }

    final epic = cards.where((card) => card.rarity == CardRarity.epic).length;
    final gold = cards.where((card) => card.rarity == CardRarity.gold).length;
    final legendary =
        cards.where((card) => card.rarity == CardRarity.legendary).length;

    if (epic != kEpicCards ||
        gold != kGoldCards ||
        legendary != kLegendaryCards) {
      throw StateError('Catalog rarity distribution is invalid.');
    }

    if (_byId.length != cards.length) {
      throw StateError('Card IDs must be unique.');
    }
  }
}

class PlayerCollection {
  PlayerCollection(Iterable<String> ownedCardIds)
      : _owned = <String>{...ownedCardIds};

  final Set<String> _owned;

  int get count => _owned.length;

  bool owns(String cardId) => _owned.contains(cardId);

  Set<String> get ids => Set<String>.unmodifiable(_owned);

  void add(String cardId, CardCatalog catalog) {
    catalog[cardId];
    _owned.add(cardId);
  }

  bool remove(String cardId) => _owned.remove(cardId);

  /// Awards one random unowned normal card during bot onboarding.
  ///
  /// Returns null when onboarding cannot award a card.
  String? grantBotCardRandomly(CardCatalog catalog, Random random) {
    if (count >= kPvpMinimumCollection) {
      return null;
    }

    final available = catalog.normalCards
        .where((card) => !_owned.contains(card.id))
        .toList(growable: false);

    if (available.isEmpty) {
      return null;
    }

    final card = available[random.nextInt(available.length)];
    _owned.add(card.id);
    return card.id;
  }

  bool get canEnterPvp => count >= kPvpMinimumCollection;
}

class PlayerDeck {
  PlayerDeck(Iterable<String> cardIds)
      : cardIds = List<String>.unmodifiable(cardIds);

  final List<String> cardIds;

  bool isValid(PlayerCollection collection) {
    if (cardIds.length != kDeckSize) {
      return false;
    }

    final ids = cardIds.toSet();
    if (ids.length != kDeckSize) {
      return false;
    }

    return ids.every(collection.owns);
  }

  void validate(PlayerCollection collection) {
    if (!isValid(collection)) {
      throw StateError('A deck must contain exactly 10 distinct owned cards.');
    }
  }
}

class WeeklyPass {
  const WeeklyPass({required this.active});

  final bool active;

  int get unlockedDeckSlots =>
      kFreeDeckSlots + (active ? kPassDeckSlots : 0);

  bool get hasFourthAnswerOption => active;
}

class DuelQuestionSelection {
  const DuelQuestionSelection({
    required this.playerCards,
    required this.opponentCards,
  });

  final List<String> playerCards;
  final List<String> opponentCards;

  /// Cards this player should answer during the 7-question duel.
  List<String> questionsForPlayer() => opponentCards;
}

List<String> selectDuelCards(PlayerDeck deck, int seed) {
  if (deck.cardIds.length != kDeckSize ||
      deck.cardIds.toSet().length != kDeckSize) {
    throw StateError('Duel selection requires 10 distinct deck cards.');
  }

  final values = <String>[...deck.cardIds];
  final random = Random(seed);

  for (int i = values.length - 1; i > 0; i--) {
    final j = random.nextInt(i + 1);
    final temp = values[i];
    values[i] = values[j];
    values[j] = temp;
  }

  return List<String>.unmodifiable(values.take(kDuelQuestions));
}

class DuelAnswer {
  const DuelAnswer({
    required this.correct,
    required this.responseTimeMs,
    required this.timedOut,
  });

  final bool correct;
  final int responseTimeMs;
  final bool timedOut;

  int get effectiveResponseTimeMs =>
      timedOut ? kSecondsPerQuestion * 1000 : responseTimeMs;
}

class DuelPerformance {
  DuelPerformance(List<DuelAnswer> answers)
      : answers = List<DuelAnswer>.unmodifiable(answers) {
    if (answers.length != kDuelQuestions) {
      throw ArgumentError('A duel performance must contain 7 answers.');
    }
  }

  final List<DuelAnswer> answers;

  int get correctCount => answers.where((answer) => answer.correct).length;

  int get totalResponseTimeMs =>
      answers.fold<int>(0, (sum, answer) => sum + answer.effectiveResponseTimeMs);
}

enum DuelOutcome {
  playerOneWin,
  playerTwoWin,
  draw,
}

DuelOutcome decideDuelOutcome(
  DuelPerformance playerOne,
  DuelPerformance playerTwo,
) {
  if (playerOne.correctCount > playerTwo.correctCount) {
    return DuelOutcome.playerOneWin;
  }
  if (playerTwo.correctCount > playerOne.correctCount) {
    return DuelOutcome.playerTwoWin;
  }

  if (playerOne.totalResponseTimeMs < playerTwo.totalResponseTimeMs) {
    return DuelOutcome.playerOneWin;
  }
  if (playerTwo.totalResponseTimeMs < playerOne.totalResponseTimeMs) {
    return DuelOutcome.playerTwoWin;
  }

  return DuelOutcome.draw;
}

/// Applies the post-loss onboarding gate without mutating the collection.
bool shouldReturnToBotAfterPvpLoss(PlayerCollection collection) =>
    collection.count < kPvpMinimumCollection;
