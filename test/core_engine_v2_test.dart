import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:steal_the_questions/game/core_engine_v2.dart';

QuestionItemV2 q(String id, String pack) => QuestionItemV2(
      id: id,
      packId: pack,
      questionAr: 'سؤال',
      questionEn: 'Question',
      correctAr: 'صح',
      correctEn: 'Correct',
      wrongAnswersAr: const ['خطأ 1', 'خطأ 2', 'خطأ 3'],
      wrongAnswersEn: const ['Wrong 1', 'Wrong 2', 'Wrong 3'],
    );

void main() {
  test('seven categories are fixed and unique', () {
    expect(kCategoriesV2.length, 7);
    expect(kCategoriesV2.map((c) => c.id).toSet().length, 7);
    expect(kCategoriesV2.map((c) => c.colorHex).toSet().length, 7);
  });

  test('catalog accepts empty content until real questions are supplied', () {
    final catalog = ContentCatalogV2.empty();
    expect(catalog.packs, isEmpty);
    expect(catalog.questions, isEmpty);
  });

  test('card is a pack and can contain multiple questions', () {
    final catalog = ContentCatalogV2(
      packs: const [
        QuestionPackV2(
          id: 'football_world_cup',
          category: GameCategoryId.football,
          titleAr: 'كأس العالم',
          titleEn: 'World Cup',
          questionIds: ['q1', 'q2', 'q3'],
        ),
      ],
      questions: [q('q1', 'football_world_cup'), q('q2', 'football_world_cup'), q('q3', 'football_world_cup')],
    );

    expect(catalog.packs['football_world_cup']!.questionIds.length, 3);
  });

  test('selector avoids recently seen questions when fresh questions exist', () {
    final catalog = ContentCatalogV2(
      packs: const [
        QuestionPackV2(
          id: 'p1',
          category: GameCategoryId.general,
          titleAr: 'عام',
          titleEn: 'General',
          questionIds: ['q1', 'q2'],
        ),
      ],
      questions: [q('q1', 'p1'), q('q2', 'p1')],
    );
    final recent = RecentQuestionHistoryV2(['q1']);

    final picked = const QuestionSelectorV2().selectForDuel(
      selectedPackIds: const ['p1'],
      catalog: catalog,
      recent: recent,
      random: Random(1),
    );

    expect(picked.single.questionId, 'q2');
  });

  test('recent question history keeps only the latest 50 unique sightings', () {
    final recent = RecentQuestionHistoryV2();
    for (var i = 0; i < 60; i++) {
      recent.record('q$i');
    }
    expect(recent.ids.length, 50);
    expect(recent.contains('q0'), isFalse);
    expect(recent.contains('q59'), isTrue);
  });

  test('deck remains exactly 10 distinct owned packs', () {
    final owned = {for (var i = 0; i < 10; i++) 'p$i'};
    final deck = PlayerDeckV2(owned);
    expect(deck.isValid(owned), isTrue);
    expect(PlayerDeckV2([...owned.take(9), 'p0']).isValid(owned), isFalse);
  });

  test('weekly ranking is win +30 loss -15 draw 0', () {
    expect(weeklyPointsForResultV2(DuelResultV2.win), 30);
    expect(weeklyPointsForResultV2(DuelResultV2.loss), -15);
    expect(weeklyPointsForResultV2(DuelResultV2.draw), 0);
  });

  test('monthly subscription entitlement changes decks and answer choices only', () {
    const free = SubscriptionEntitlementV2(active: false);
    const paid = SubscriptionEntitlementV2(active: true);

    expect(free.deckSlots, 2);
    expect(free.answerChoices, 3);
    expect(free.editableWrongChoices, 2);
    expect(paid.deckSlots, 5);
    expect(paid.answerChoices, 4);
    expect(paid.editableWrongChoices, 3);
  });

  test('weekly prestige rewards contain permanent podium identity', () {
    final first = kWeeklyPrestigeRewardsV2[WeeklyPodiumPlaceV2.first]!;
    expect(first.trophyKey, 'gold_trophy');
    expect(first.featuredChampion, isTrue);
  });
}
