import 'game/game_rules.dart';

class QuestionContent {
  const QuestionContent({
    required this.id,
    required this.rarity,
    required this.categoryEn,
    required this.categoryAr,
    required this.questionEn,
    required this.questionAr,
    required this.answersEn,
    required this.answersAr,
    required this.correctIndex,
    required this.passExtraEn,
    required this.passExtraAr,
  });

  final String id;
  final CardRarity rarity;
  final String categoryEn;
  final String categoryAr;
  final String questionEn;
  final String questionAr;
  final List<String> answersEn;
  final List<String> answersAr;
  final int correctIndex;
  final String passExtraEn;
  final String passExtraAr;

  List<String> answers({required bool arabic, required bool weeklyPass}) {
    final values = List<String>.unmodifiable(arabic ? answersAr : answersEn);
    if (!weeklyPass) return values;
    return List<String>.unmodifiable([...values, arabic ? passExtraAr : passExtraEn]);
  }
}

class QuestionBank {
  QuestionBank._();

  static final List<QuestionContent> all = _build();
  static final Map<String, QuestionContent> _byId = {
    for (final item in all) item.id: item,
  };

  static QuestionContent byId(String id) {
    final value = _byId[id];
    if (value == null) throw ArgumentError('Unknown question card: ' + id);
    return value;
  }

  static Iterable<QuestionContent> get normal =>
      all.where((q) => q.rarity != CardRarity.legendary);

  static void validate() {
    if (all.length != kTotalCards) {
      throw StateError('Question bank must contain exactly $kTotalCards cards.');
    }
    if (_byId.length != all.length) throw StateError('Question card IDs must be unique.');
    for (final q in all) {
      if (q.answersEn.length != 3 ||
          q.answersAr.length != 3 ||
          q.correctIndex < 0 ||
          q.correctIndex > 2 ||
          q.passExtraEn.isEmpty ||
          q.passExtraAr.isEmpty) {
        throw StateError('Invalid question content for ' + q.id);
      }
    }
  }

  static List<QuestionContent> _build() {
    const categoryPairs = <List<String>>[
      ['Geography', 'جغرافيا'],
      ['Science', 'علوم'],
      ['Math', 'رياضيات'],
      ['Technology', 'تقنية'],
      ['Culture', 'ثقافة'],
      ['Language', 'لغة'],
    ];
    final facts = <_Fact>[
$dartFacts
    ];

    final valuePoolEn = facts.map((f) => f.valueEn).toList(growable: false);
    final valuePoolAr = facts.map((f) => f.valueAr).toList(growable: false);
    final labelPoolEn = facts.map((f) => f.labelEn).toList(growable: false);
    final labelPoolAr = facts.map((f) => f.labelAr).toList(growable: false);
    final categoryPoolEn = categoryPairs.map((e) => e[0]).toList(growable: false);
    final categoryPoolAr = categoryPairs.map((e) => e[1]).toList(growable: false);

    final result = <QuestionContent>[];
    for (int i = 0; i < facts.length; i++) {
      final f = facts[i];

      final id1 = 'Q' + (result.length + 1).toString().padLeft(3, '0');
      final choice1 = _choices(valuePoolEn, valuePoolAr, f.valueEn, f.valueAr, i, 0);
      result.add(_make(
        id1,
        f,
        'What is the key fact for “' + f.labelEn + '”?',
        'ما المعلومة الصحيحة عن «' + f.labelAr + '»؟',
        choice1,
      ));

      final id2 = 'Q' + (result.length + 1).toString().padLeft(3, '0');
      final choice2 = _choices(labelPoolEn, labelPoolAr, f.labelEn, f.labelAr, i, 1);
      result.add(_make(
        id2,
        f,
        'Which item is associated with “' + f.valueEn + '”?',
        'ما العنصر المرتبط بـ«' + f.valueAr + '»؟',
        choice2,
      ));

      final id3 = 'Q' + (result.length + 1).toString().padLeft(3, '0');
      final choice3 = _choices(categoryPoolEn, categoryPoolAr, f.categoryEn, f.categoryAr, i, 2);
      result.add(_make(
        id3,
        f,
        'Which category best fits “' + f.labelEn + '”?',
        'ما الفئة الأنسب لـ«' + f.labelAr + '»؟',
        choice3,
      ));
    }

    if (result.length != kTotalCards) {
      throw StateError('Generated ' + result.length.toString() + ' questions, expected ' + kTotalCards.toString() + '.');
    }
    return List<QuestionContent>.unmodifiable(result);
  }

  static QuestionContent _make(
    String id,
    _Fact f,
    String questionEn,
    String questionAr,
    _Choice choice,
  ) {
    return QuestionContent(
      id: id,
      rarity: _rarityFor(id),
      categoryEn: f.categoryEn,
      categoryAr: f.categoryAr,
      questionEn: questionEn,
      questionAr: questionAr,
      answersEn: choice.en,
      answersAr: choice.ar,
      correctIndex: choice.correctIndex,
      passExtraEn: choice.extraEn,
      passExtraAr: choice.extraAr,
    );
  }

  static CardRarity _rarityFor(String id) {
    final number = int.parse(id.substring(1));
    if (number <= 150) return CardRarity.epic;
    if (number <= 200) return CardRarity.gold;
    return CardRarity.legendary;
  }

  static _Choice _choices(
    List<String> poolEn,
    List<String> poolAr,
    String correctEn,
    String correctAr,
    int index,
    int variant,
  ) {
    final wrongEn = <String>[];
    final wrongAr = <String>[];
    int cursor = (index * 17 + variant * 11) % poolEn.length;
    while (wrongEn.length < 3) {
      final candidateEn = poolEn[cursor % poolEn.length];
      final candidateAr = poolAr[cursor % poolAr.length];
      cursor++;
      if (candidateEn == correctEn || wrongEn.contains(candidateEn)) continue;
      wrongEn.add(candidateEn);
      wrongAr.add(candidateAr);
    }

    final correctPosition = (index + variant) % 3;
    final answersEn = <String>[];
    final answersAr = <String>[];
    int wrongCursor = 0;
    for (int i = 0; i < 3; i++) {
      if (i == correctPosition) {
        answersEn.add(correctEn);
        answersAr.add(correctAr);
      } else {
        answersEn.add(wrongEn[wrongCursor]);
        answersAr.add(wrongAr[wrongCursor]);
        wrongCursor++;
      }
    }

    String extraEn = '';
    String extraAr = '';
    for (int step = 0; step < poolEn.length; step++) {
      final candidateEn = poolEn[(cursor + step) % poolEn.length];
      final candidateAr = poolAr[(cursor + step) % poolAr.length];
      if (candidateEn != correctEn && !answersEn.contains(candidateEn)) {
        extraEn = candidateEn;
        extraAr = candidateAr;
        break;
      }
    }

    return _Choice(
      en: List<String>.unmodifiable(answersEn),
      ar: List<String>.unmodifiable(answersAr),
      correctIndex: correctPosition,
      extraEn: extraEn,
      extraAr: extraAr,
    );
  }
}

class _Fact {
  const _Fact(this.labelEn, this.valueEn, this.categoryEn, this.labelAr, this.valueAr, this.categoryAr);
  final String labelEn;
  final String valueEn;
  final String categoryEn;
  final String labelAr;
  final String valueAr;
  final String categoryAr;
}

class _Choice {
  const _Choice({
    required this.en,
    required this.ar,
    required this.correctIndex,
    required this.extraEn,
    required this.extraAr,
  });
  final List<String> en;
  final List<String> ar;
  final int correctIndex;
  final String extraEn;
  final String extraAr;
}
