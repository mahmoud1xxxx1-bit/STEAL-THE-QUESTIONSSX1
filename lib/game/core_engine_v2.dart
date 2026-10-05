import 'dart:math';

/// Core rules for the new STEAL THE QUESTIONS model.
///
/// Important: this file contains NO real questions. Real content will be
/// supplied later and loaded into [ContentCatalogV2].

const int kDeckSizeV2 = 10;
const int kDuelCardsV2 = 7;
const int kSecondsPerQuestionV2 = 20;
const int kRecentQuestionLimitV2 = 50;
const int kFreeDeckSlotsV2 = 2;
const int kSubscriberDeckSlotsV2 = 5;
const int kFreeAnswerChoicesV2 = 3;
const int kSubscriberAnswerChoicesV2 = 4;
const int kWeeklyWinPointsV2 = 30;
const int kWeeklyLossPointsV2 = -15;
const int kWeeklyDrawPointsV2 = 0;

enum GameCategoryId {
  football,
  anime,
  movies,
  geography,
  animals,
  science,
  general,
}

class CategorySpec {
  const CategorySpec({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.colorHex,
  });

  final GameCategoryId id;
  final String nameAr;
  final String nameEn;
  final int colorHex;
}

const List<CategorySpec> kCategoriesV2 = <CategorySpec>[
  CategorySpec(id: GameCategoryId.football, nameAr: 'كرة القدم', nameEn: 'Football', colorHex: 0xFF19A55A),
  CategorySpec(id: GameCategoryId.anime, nameAr: 'الأنمي', nameEn: 'Anime', colorHex: 0xFF3478F6),
  CategorySpec(id: GameCategoryId.movies, nameAr: 'الأفلام والمسلسلات', nameEn: 'Movies & Series', colorHex: 0xFF8A4FE0),
  CategorySpec(id: GameCategoryId.geography, nameAr: 'الدول والجغرافيا', nameEn: 'Countries & Geography', colorHex: 0xFFE5A51A),
  CategorySpec(id: GameCategoryId.animals, nameAr: 'الحيوانات', nameEn: 'Animals', colorHex: 0xFFE34B4B),
  CategorySpec(id: GameCategoryId.science, nameAr: 'العلوم والتقنية', nameEn: 'Science & Technology', colorHex: 0xFFF06B32),
  CategorySpec(id: GameCategoryId.general, nameAr: 'معلومات عامة', nameEn: 'General Knowledge', colorHex: 0xFF18A7A7),
];

class QuestionItemV2 {
  const QuestionItemV2({
    required this.id,
    required this.packId,
    required this.questionAr,
    required this.questionEn,
    required this.correctAr,
    required this.correctEn,
    required this.wrongAnswersAr,
    required this.wrongAnswersEn,
  });

  final String id;
  final String packId;
  final String questionAr;
  final String questionEn;
  final String correctAr;
  final String correctEn;
  final List<String> wrongAnswersAr;
  final List<String> wrongAnswersEn;
}

/// A collectible card is a topic/pack, not one fixed question.
class QuestionPackV2 {
  const QuestionPackV2({
    required this.id,
    required this.category,
    required this.titleAr,
    required this.titleEn,
    required this.questionIds,
  });

  final String id;
  final GameCategoryId category;
  final String titleAr;
  final String titleEn;
  final List<String> questionIds;
}

class ContentCatalogV2 {
  ContentCatalogV2({
    required Iterable<QuestionPackV2> packs,
    required Iterable<QuestionItemV2> questions,
  })  : packs = Map<String, QuestionPackV2>.unmodifiable({for (final p in packs) p.id: p}),
        questions = Map<String, QuestionItemV2>.unmodifiable({for (final q in questions) q.id: q}) {
    _validate();
  }

  final Map<String, QuestionPackV2> packs;
  final Map<String, QuestionItemV2> questions;

  /// Empty by design until the real question bank is supplied.
  factory ContentCatalogV2.empty() => ContentCatalogV2(packs: const [], questions: const []);

  void _validate() {
    for (final pack in packs.values) {
      if (pack.questionIds.toSet().length != pack.questionIds.length) {
        throw StateError('Pack ${pack.id} contains duplicate question IDs.');
      }
      for (final questionId in pack.questionIds) {
        final question = questions[questionId];
        if (question == null) {
          throw StateError('Pack ${pack.id} references missing question $questionId.');
        }
        if (question.packId != pack.id) {
          throw StateError('Question $questionId belongs to ${question.packId}, not ${pack.id}.');
        }
      }
    }

    for (final question in questions.values) {
      if (!packs.containsKey(question.packId)) {
        throw StateError('Question ${question.id} references missing pack ${question.packId}.');
      }
    }
  }
}

class RecentQuestionHistoryV2 {
  RecentQuestionHistoryV2([Iterable<String> initial = const []]) {
    for (final id in initial) record(id);
  }

  final List<String> _ids = <String>[];

  List<String> get ids => List<String>.unmodifiable(_ids);

  bool contains(String questionId) => _ids.contains(questionId);

  void record(String questionId) {
    _ids.remove(questionId);
    _ids.add(questionId);
    if (_ids.length > kRecentQuestionLimitV2) {
      _ids.removeRange(0, _ids.length - kRecentQuestionLimitV2);
    }
  }
}

class DuelQuestionPickV2 {
  const DuelQuestionPickV2({required this.packId, required this.questionId});

  final String packId;
  final String questionId;
}

class QuestionSelectorV2 {
  const QuestionSelectorV2();

  /// Selects one question per selected pack.
  ///
  /// Priority:
  /// 1) never repeat inside the same match;
  /// 2) avoid the player's recent history;
  /// 3) if a pack is exhausted, reuse the oldest recently seen eligible one.
  List<DuelQuestionPickV2> selectForDuel({
    required List<String> selectedPackIds,
    required ContentCatalogV2 catalog,
    required RecentQuestionHistoryV2 recent,
    required Random random,
  }) {
    final usedInMatch = <String>{};
    final result = <DuelQuestionPickV2>[];

    for (final packId in selectedPackIds) {
      final pack = catalog.packs[packId];
      if (pack == null) throw StateError('Unknown pack $packId.');

      final eligible = pack.questionIds.where((id) => !usedInMatch.contains(id)).toList(growable: false);
      if (eligible.isEmpty) throw StateError('Pack $packId has no usable questions.');

      final fresh = eligible.where((id) => !recent.contains(id)).toList(growable: false);
      final String chosen;
      if (fresh.isNotEmpty) {
        chosen = fresh[random.nextInt(fresh.length)];
      } else {
        chosen = _oldestRecentEligible(eligible, recent.ids) ?? eligible[random.nextInt(eligible.length)];
      }

      usedInMatch.add(chosen);
      recent.record(chosen);
      result.add(DuelQuestionPickV2(packId: packId, questionId: chosen));
    }

    return List<DuelQuestionPickV2>.unmodifiable(result);
  }

  String? _oldestRecentEligible(List<String> eligible, List<String> recentIds) {
    for (final recentId in recentIds) {
      if (eligible.contains(recentId)) return recentId;
    }
    return null;
  }
}

class PlayerDeckV2 {
  PlayerDeckV2(Iterable<String> packIds) : packIds = List<String>.unmodifiable(packIds);

  final List<String> packIds;

  bool isValid(Set<String> ownedPackIds) {
    return packIds.length == kDeckSizeV2 &&
        packIds.toSet().length == kDeckSizeV2 &&
        packIds.every(ownedPackIds.contains);
  }
}

List<String> selectDuelPacksV2(PlayerDeckV2 deck, Random random) {
  if (deck.packIds.length != kDeckSizeV2 || deck.packIds.toSet().length != kDeckSizeV2) {
    throw StateError('A duel deck must contain exactly 10 distinct owned packs.');
  }
  final shuffled = <String>[...deck.packIds]..shuffle(random);
  return List<String>.unmodifiable(shuffled.take(kDuelCardsV2));
}

enum DuelResultV2 { win, loss, draw }

int weeklyPointsForResultV2(DuelResultV2 result) {
  switch (result) {
    case DuelResultV2.win:
      return kWeeklyWinPointsV2;
    case DuelResultV2.loss:
      return kWeeklyLossPointsV2;
    case DuelResultV2.draw:
      return kWeeklyDrawPointsV2;
  }
}

/// Monday-based UTC week key, e.g. 2026-10-05.
String weeklyKeyV2(DateTime now) {
  final utc = now.toUtc();
  final monday = DateTime.utc(utc.year, utc.month, utc.day).subtract(Duration(days: utc.weekday - DateTime.monday));
  return '${monday.year.toString().padLeft(4, '0')}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';
}

class SubscriptionEntitlementV2 {
  const SubscriptionEntitlementV2({required this.active});

  final bool active;

  int get deckSlots => active ? kSubscriberDeckSlotsV2 : kFreeDeckSlotsV2;
  int get answerChoices => active ? kSubscriberAnswerChoicesV2 : kFreeAnswerChoicesV2;
  int get editableWrongChoices => answerChoices - 1;
}

enum WeeklyPodiumPlaceV2 { first, second, third }

class WeeklyPrestigeRewardV2 {
  const WeeklyPrestigeRewardV2({
    required this.place,
    required this.trophyKey,
    required this.frameKey,
    required this.titleKey,
    required this.featuredChampion,
  });

  final WeeklyPodiumPlaceV2 place;
  final String trophyKey;
  final String frameKey;
  final String titleKey;
  final bool featuredChampion;
}

const Map<WeeklyPodiumPlaceV2, WeeklyPrestigeRewardV2> kWeeklyPrestigeRewardsV2 = {
  WeeklyPodiumPlaceV2.first: WeeklyPrestigeRewardV2(
    place: WeeklyPodiumPlaceV2.first,
    trophyKey: 'gold_trophy',
    frameKey: 'weekly_gold_frame',
    titleKey: 'champion_of_the_week',
    featuredChampion: true,
  ),
  WeeklyPodiumPlaceV2.second: WeeklyPrestigeRewardV2(
    place: WeeklyPodiumPlaceV2.second,
    trophyKey: 'silver_trophy',
    frameKey: 'weekly_silver_frame',
    titleKey: 'weekly_runner_up',
    featuredChampion: false,
  ),
  WeeklyPodiumPlaceV2.third: WeeklyPrestigeRewardV2(
    place: WeeklyPodiumPlaceV2.third,
    trophyKey: 'bronze_trophy',
    frameKey: 'weekly_bronze_frame',
    titleKey: 'weekly_third_place',
    featuredChampion: false,
  ),
};

class PrestigeHistoryV2 {
  const PrestigeHistoryV2({
    this.first = 0,
    this.second = 0,
    this.third = 0,
  });

  final int first;
  final int second;
  final int third;

  int get totalPodiums => first + second + third;
}
