import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const int kTotalQuestions = 7;
const int kSecondsPerQuestion = 20;

void main() {
  runApp(const StealTheQuestionsApp());
}

class StealTheQuestionsApp extends StatelessWidget {
  const StealTheQuestionsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'STEAL THE QUESTIONS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        useMaterial3: true,
        fontFamily: 'Arial',
        scaffoldBackgroundColor: const Color(0xFF0D1630),
      ),
      home: const DuelDesignPrototype(),
    );
  }
}

class _QuestionData {
  const _QuestionData({
    required this.en,
    required this.ar,
    required this.enAnswers,
    required this.arAnswers,
    required this.correctIndex,
    required this.categoryEn,
    required this.categoryAr,
  });

  final String en;
  final String ar;
  final List<String> enAnswers;
  final List<String> arAnswers;
  final int correctIndex;
  final String categoryEn;
  final String categoryAr;
}

class DuelDesignPrototype extends StatefulWidget {
  const DuelDesignPrototype({super.key});

  @override
  State<DuelDesignPrototype> createState() => _DuelDesignPrototypeState();
}

enum _Stage { duel, result, steal, claimed }

class _DuelDesignPrototypeState extends State<DuelDesignPrototype>
    with TickerProviderStateMixin {
  static const int totalQuestions = 7;
  static const int deckSize = 10;
  static const int secondsPerQuestion = 20;

  static const List<_QuestionData> _questions = <_QuestionData>[
    _QuestionData(
      en: 'Which planet is known as the Red Planet?',
      ar: 'أي كوكب يُعرف بالكوكب الأحمر؟',
      enAnswers: ['Mars', 'Venus', 'Jupiter'],
      arAnswers: ['المريخ', 'الزهرة', 'المشتري'],
      correctIndex: 0,
      categoryEn: 'SCIENCE',
      categoryAr: 'علوم',
    ),
    _QuestionData(
      en: 'What is the largest ocean on Earth?',
      ar: 'ما هو أكبر محيط على الأرض؟',
      enAnswers: ['Atlantic Ocean', 'Pacific Ocean', 'Indian Ocean'],
      arAnswers: ['الأطلسي', 'الهادئ', 'الهندي'],
      correctIndex: 1,
      categoryEn: 'GEOGRAPHY',
      categoryAr: 'جغرافيا',
    ),
    _QuestionData(
      en: 'How many continents are there?',
      ar: 'كم عدد القارات في العالم؟',
      enAnswers: ['5', '6', '7'],
      arAnswers: ['5', '6', '7'],
      correctIndex: 2,
      categoryEn: 'WORLD',
      categoryAr: 'العالم',
    ),
    _QuestionData(
      en: 'Which animal is the fastest on land?',
      ar: 'ما أسرع حيوان على اليابسة؟',
      enAnswers: ['Lion', 'Cheetah', 'Horse'],
      arAnswers: ['الأسد', 'الفهد', 'الحصان'],
      correctIndex: 1,
      categoryEn: 'NATURE',
      categoryAr: 'طبيعة',
    ),
    _QuestionData(
      en: 'Which language has the most native speakers?',
      ar: 'ما اللغة التي لديها أكبر عدد من المتحدثين الأصليين؟',
      enAnswers: ['Spanish', 'English', 'Mandarin'],
      arAnswers: ['الإسبانية', 'الإنجليزية', 'الماندرين'],
      correctIndex: 2,
      categoryEn: 'CULTURE',
      categoryAr: 'ثقافة',
    ),
    _QuestionData(
      en: 'Which country is home to Kyoto?',
      ar: 'في أي دولة تقع مدينة كيوتو؟',
      enAnswers: ['China', 'Japan', 'Thailand'],
      arAnswers: ['الصين', 'اليابان', 'تايلاند'],
      correctIndex: 1,
      categoryEn: 'TRAVEL',
      categoryAr: 'سفر',
    ),
    _QuestionData(
      en: 'What is the hardest natural substance?',
      ar: 'ما أقسى مادة طبيعية؟',
      enAnswers: ['Iron', 'Diamond', 'Quartz'],
      arAnswers: ['الحديد', 'الألماس', 'الكوارتز'],
      correctIndex: 1,
      categoryEn: 'SCIENCE',
      categoryAr: 'علوم',
    ),
  ];

  late final AnimationController _flip;
  late final AnimationController _enter;
  late final AnimationController _pulse;
  late final AnimationController _stealIn;
  Timer? _timer;

  bool _arabic = false;
  _Stage _stage = _Stage.duel;
  int _questionIndex = 0;
  int _seconds = secondsPerQuestion;
  int _score = 0;
  int _rivalScore = 0;
  int _selected = -1;
  bool _locked = false;
  bool _correct = false;
  int _stolenIndex = -1;

  _QuestionData get _question => _questions[_questionIndex];

  @override
  void initState() {
    super.initState();
    _flip = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    );
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _stealIn = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    );
    _startQuestion();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _flip.dispose();
    _enter.dispose();
    _pulse.dispose();
    _stealIn.dispose();
    super.dispose();
  }

  void _startQuestion() {
    _timer?.cancel();
    setState(() {
      _seconds = secondsPerQuestion;
      _selected = -1;
      _locked = false;
      _correct = false;
    });
    _flip
      ..reset()
      ..forward();
    _enter
      ..reset()
      ..forward();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _locked || _stage != _Stage.duel) {
        return;
      }
      if (_seconds <= 1) {
        timer.cancel();
        _answer(-1);
      } else {
        setState(() {
          _seconds -= 1;
        });
      }
    });
  }

  Future<void> _answer(int value) async {
    if (_locked || _stage != _Stage.duel) {
      return;
    }

    _timer?.cancel();
    await HapticFeedback.selectionClick();

    final bool isCorrect = value == _question.correctIndex;
    setState(() {
      _selected = value;
      _locked = true;
      _correct = isCorrect;
      if (isCorrect) {
        _score += 1;
      }
      if (!isCorrect && _questionIndex.isEven) {
        _rivalScore = math.min(totalQuestions, _rivalScore + 1);
      }
    });

    _pulse
      ..reset()
      ..forward();

    await Future<void>.delayed(const Duration(milliseconds: 950));
    if (!mounted) {
      return;
    }

    if (_questionIndex == totalQuestions - 1) {
      setState(() {
        _stage = _Stage.result;
      });
      return;
    }

    setState(() {
      _questionIndex += 1;
    });
    _startQuestion();
  }

  void _beginSteal() {
    setState(() {
      _stage = _Stage.steal;
      _stolenIndex = -1;
    });
    _stealIn
      ..reset()
      ..forward();
  }

  void _selectSteal(int index) {
    if (_stolenIndex != -1) {
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() {
      _stolenIndex = index;
    });
    _stealIn
      ..reset()
      ..forward();
  }

  void _claimCard() {
    HapticFeedback.heavyImpact();
    setState(() {
      _stage = _Stage.claimed;
    });
  }

  void _reset() {
    _timer?.cancel();
    setState(() {
      _stage = _Stage.duel;
      _questionIndex = 0;
      _seconds = secondsPerQuestion;
      _score = 0;
      _rivalScore = 0;
      _selected = -1;
      _locked = false;
      _correct = false;
      _stolenIndex = -1;
    });
    _startQuestion();
  }

  void _toggleLanguage() {
    setState(() {
      _arabic = !_arabic;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: _arabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF142C54),
                Color(0xFF3D2B79),
                Color(0xFF10214A),
              ],
            ),
          ),
          child: Stack(
            children: [
              const _AmbientLights(),
              SafeArea(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 360),
                  child: _buildStage(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStage() {
    switch (_stage) {
      case _Stage.duel:
        return _buildDuel();
      case _Stage.result:
        return _buildResult();
      case _Stage.steal:
        return _buildSteal();
      case _Stage.claimed:
        return _buildClaimed();
    }
  }

  Widget _buildDuel() {
    final bool compact = MediaQuery.sizeOf(context).height < 760;
    final String progress =
        (_questionIndex + 1).toString() + ' / ' + totalQuestions.toString();

    return Column(
      key: const ValueKey<String>('duel'),
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(18, compact ? 8 : 14, 18, 8),
          child: _ArenaHeader(
            arabic: _arabic,
            score: _score,
            rivalScore: _rivalScore,
            progress: progress,
            onLanguage: _toggleLanguage,
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bool wide = constraints.maxWidth >= 900;
              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1180),
                    child: Column(
                      children: [
                        _BattleLine(arabic: _arabic, deckSize: deckSize),
                        const SizedBox(height: 12),
                        if (wide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Expanded(
                                child: _DeckStack(
                                  mine: true,
                                ),
                              ),
                              const SizedBox(width: 18),
                              _buildAnimatedCard(),
                              const SizedBox(width: 18),
                              const Expanded(
                                child: _DeckStack(
                                  mine: false,
                                ),
                              ),
                            ],
                          )
                        else
                          _buildAnimatedCard(),
                        const SizedBox(height: 12),
                        _DeckRail(
                          active: _questionIndex,
                          size: deckSize,
                          arabic: _arabic,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAnimatedCard() {
    return AnimatedBuilder(
      animation: Listenable.merge([_flip, _enter, _pulse]),
      builder: (context, child) {
        final double enter =
            Curves.easeOutCubic.transform(_enter.value);
        final double pulse =
            Curves.easeOutCubic.transform(_pulse.value);
        final double flip = _flip.value;
        final double scale =
            0.97 + (0.03 * enter) + (0.006 * pulse);
        final double y = 18 * (1 - enter);
        final double shake = _locked && !_correct
            ? math.sin(pulse * math.pi * 6) * 3
            : 0;

        return Transform.translate(
          offset: Offset(shake, y),
          child: Transform.scale(
            scale: scale,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(math.pi * flip),
              child: flip < 0.5
                  ? _CardBack(
                      arabic: _arabic,
                      category: _arabic
                          ? _question.categoryAr
                          : _question.categoryEn,
                    )
                  : Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.rotationY(math.pi),
                      child: _QuestionCard(
                        arabic: _arabic,
                        question: _question,
                        seconds: _seconds,
                        selected: _selected,
                        locked: _locked,
                        correct: _correct,
                        onAnswer: _answer,
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildResult() {
    final bool won = _score >= _rivalScore;
    return Center(
      key: const ValueKey<String>('result'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: _GlassPanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _RoundCrown(won: won),
              const SizedBox(height: 16),
              Text(
                _arabic ? 'انتهت المواجهة' : 'DUEL COMPLETE',
                style: const TextStyle(
                  fontSize: 13,
                  letterSpacing: 2.2,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFFFD66B),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _score.toString() + '  —  ' + _rivalScore.toString(),
                style: const TextStyle(
                  fontSize: 52,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                won
                    ? (_arabic ? 'لقد فزت. حان وقت السرقة.' : 'You won. Time to steal.')
                    : (_arabic ? 'هذه الجولة للخصم.' : 'This round goes to the rival.'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .74),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: won ? _beginSteal : _reset,
                  icon: Icon(won ? Icons.auto_awesome : Icons.refresh_rounded),
                  label: Text(won
                      ? (_arabic ? 'ابدأ السرقة' : 'START STEAL')
                      : (_arabic ? 'مواجهة جديدة' : 'NEW DUEL')),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD66B),
                    foregroundColor: const Color(0xFF241D10),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(17),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSteal() {
    return Column(
      key: const ValueKey<String>('steal'),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
          child: Row(
            children: [
              Icon(
                Icons.lock_open_rounded,
                color: const Color(0xFFFFD66B),
                size: 28,
              ),
              const SizedBox(width: 8),
              Text(
                _arabic ? 'مرحلة السرقة' : 'STEAL PHASE',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.8,
                ),
              ),
              const Spacer(),
              _Pill(
                text: _arabic ? '40 ثانية' : '40 SEC',
                color: const Color(0xFFFFD66B),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1040),
                child: Column(
                  children: [
                    Text(
                      _arabic ? 'اختر بطاقة واحدة من خصمك' : 'CHOOSE ONE CARD FROM YOUR RIVAL',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        shadows: const [
                          Shadow(
                            color: Color(0x5538DFFF),
                            blurRadius: 18,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _arabic
                          ? 'هذه البطاقة ستنتقل إلى مجموعتك.'
                          : 'This card will move into your collection.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .62),
                      ),
                    ),
                    const SizedBox(height: 22),
                    AnimatedBuilder(
                      animation: _stealIn,
                      builder: (context, child) {
                        final double v = Curves.easeOutBack.transform(
                          _stealIn.value,
                        );
                        return Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 12,
                          runSpacing: 14,
                          children: List<Widget>.generate(
                            deckSize,
                            (index) => _StealCard(
                              index: index,
                              selected: _stolenIndex == index,
                              revealed: _stolenIndex == index,
                              animation: v,
                              onTap: () => _selectSteal(index),
                              arabic: _arabic,
                            ),
                          ),
                        );
                      },
                    ),
                    if (_stolenIndex != -1) ...[
                      const SizedBox(height: 22),
                      _StealAction(
                        index: _stolenIndex,
                        arabic: _arabic,
                        onClaim: _claimCard,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildClaimed() {
    return Center(
      key: const ValueKey<String>('claimed'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: _GlassPanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _GoldenSeal(),
              const SizedBox(height: 18),
              Text(
                _arabic ? 'تمت السرقة' : 'CARD STOLEN',
                style: const TextStyle(
                  color: Color(0xFFFFD66B),
                  fontSize: 14,
                  letterSpacing: 2.4,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _arabic
                    ? 'أصبحت البطاقة رقم ' + (_stolenIndex + 1).toString() + ' ملكك.'
                    : 'CARD ' + (_stolenIndex + 1).toString() + ' IS YOURS.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _arabic
                    ? 'تمت إضافة بطاقة جديدة إلى مجموعتك.'
                    : 'A new card has been added to your collection.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .62),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _reset,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF6FE3FF),
                    foregroundColor: const Color(0xFF071522),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(17),
                    ),
                  ),
                  child: Text(
                    _arabic ? 'المواجهة التالية' : 'NEXT DUEL',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArenaHeader extends StatelessWidget {
  const _ArenaHeader({
    required this.arabic,
    required this.score,
    required this.rivalScore,
    required this.progress,
    required this.onLanguage,
  });

  final bool arabic;
  final int score;
  final int rivalScore;
  final String progress;
  final VoidCallback onLanguage;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MatchPlayer(
            arabic: arabic,
            label: arabic ? 'أنت' : 'YOU',
            sublabel: arabic ? 'مجموعتك' : 'YOUR COLLECTION',
            score: score,
            left: true,
          ),
        ),
        const SizedBox(width: 10),
        _QuestionProgress(
          progress: progress,
          arabic: arabic,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MatchPlayer(
            arabic: arabic,
            label: arabic ? 'الخصم' : 'RIVAL',
            sublabel: arabic ? 'خصمك' : 'OPPONENT',
            score: rivalScore,
            left: false,
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: onLanguage,
          tooltip: arabic ? 'English' : 'العربية',
          style: IconButton.styleFrom(
            backgroundColor: const Color(0x331D2940),
            foregroundColor: const Color(0xFFF3E8CA),
            side: const BorderSide(color: Color(0x355F708E)),
          ),
          icon: Text(
            arabic ? 'EN' : 'ع',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

class _MatchPlayer extends StatelessWidget {
  const _MatchPlayer({
    required this.arabic,
    required this.label,
    required this.sublabel,
    required this.score,
    required this.left,
  });

  final bool arabic;
  final String label;
  final String sublabel;
  final int score;
  final bool left;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xB91A2435),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: left
              ? const Color(0x5C73B7CE)
              : const Color(0x5CBF7480),
        ),
      ),
      child: Row(
        textDirection: left ? TextDirection.ltr : TextDirection.rtl,
        children: [
          _ProfileMedallion(left: left),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  left ? CrossAxisAlignment.start : CrossAxisAlignment.end,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: left
                        ? const Color(0xFF8DE2EC)
                        : const Color(0xFFE89BA5),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sublabel,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF8995A8),
                    fontSize: 8,
                    letterSpacing: 1.0,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            score.toString(),
            style: const TextStyle(
              color: Color(0xFFF7E3A6),
              fontSize: 25,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionProgress extends StatelessWidget {
  const _QuestionProgress({
    required this.progress,
    required this.arabic,
  });

  final String progress;
  final bool arabic;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF121A29),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x5B7A6D52)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            arabic ? 'السؤال' : 'QUESTION',
            style: const TextStyle(
              color: Color(0xFFB9A87B),
              fontSize: 8,
              letterSpacing: 2.1,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            progress,
            style: const TextStyle(
              color: Color(0xFFFFF4D6),
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileMedallion extends StatelessWidget {
  const _ProfileMedallion({required this.left});
  final bool left;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF243147),
        border: Border.all(
          color: left
              ? const Color(0xFF6FC5D5)
              : const Color(0xFFD27883),
          width: 1.4,
        ),
      ),
      alignment: Alignment.center,
      child: Icon(
        left ? Icons.person_outline_rounded : Icons.shield_outlined,
        size: 21,
        color: left
            ? const Color(0xFF8DE2EC)
            : const Color(0xFFE89BA5),
      ),
    );
  }
}

class _ScoreBox extends StatelessWidget {
  const _ScoreBox({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final int value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0x3816243F),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: .07)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 8,
              letterSpacing: 1.1,
              color: accent,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value.toString(),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _BattleLine extends StatelessWidget {
  const _BattleLine({
    required this.arabic,
    required this.deckSize,
  });

  final bool arabic;
  final int deckSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0x7A141D2C),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0x2F7B8AA0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              arabic ? 'مواجهة مباشرة' : 'HEAD-TO-HEAD',
              style: const TextStyle(
                color: Color(0xFFE8D8B5),
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Column(
            children: [
              Text(
                arabic ? 'سطح من 10 • 7 تُسحب' : '10-CARD DECK • 7 DRAWN',
                style: const TextStyle(
                  color: Color(0xFF9DA8B8),
                  fontSize: 8,
                  letterSpacing: 1.25,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                arabic ? '20 ثانية للسؤال' : '20 SECONDS EACH',
                style: const TextStyle(
                  color: Color(0xFF6EBAC7),
                  fontSize: 8,
                  letterSpacing: 1.0,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          Expanded(
            child: Text(
              arabic ? 'اسرق بطاقة واحدة' : 'WINNER STEALS ONE',
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: Color(0xFFE8D8B5),
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerBadge extends StatelessWidget {
  const _PlayerBadge({
    required this.name,
    required this.active,
  });

  final String name;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (!active) ...[
          const _Avatar(
            active: false,
          ),
          const SizedBox(width: 7),
        ],
        Column(
          crossAxisAlignment: active
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.end,
          children: [
            Text(
              name,
              style: TextStyle(
                fontSize: 9,
                letterSpacing: 1.2,
                color: active
                    ? const Color(0xFF70E7FF)
                    : const Color(0xFFFF8CB4),
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              active ? 'COLLECTOR' : 'RIVAL',
              style: TextStyle(
                fontSize: 8,
                color: Colors.white.withValues(alpha: .35),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        if (active) ...[
          const SizedBox(width: 7),
          const _Avatar(
            active: true,
          ),
        ],
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 31,
      height: 31,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0x50121B32),
        border: Border.all(
          color: active
              ? const Color(0xFF70E7FF)
              : const Color(0xFFFF8CB4),
          width: 1.4,
        ),
      ),
      alignment: Alignment.center,
      child: Icon(
        active ? Icons.person_rounded : Icons.shield_rounded,
        size: 16,
        color: active
            ? const Color(0xFF70E7FF)
            : const Color(0xFFFF8CB4),
      ),
    );
  }
}

class _CardBack extends StatelessWidget {
  const _CardBack({
    required this.arabic,
    required this.category,
  });

  final bool arabic;
  final String category;

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      faceColor: const Color(0xFF1D273D),
      borderGradient: const [
        Color(0xFFD4AF61),
        Color(0xFF7086A1),
        Color(0xFFD4AF61),
      ],
      width: 390,
      height: 510,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const CustomPaint(painter: _CardBackPainter()),
          Positioned(
            top: 19,
            left: 20,
            right: 20,
            child: Row(
              children: [
                _RarityBadge(text: arabic ? 'إبيك' : 'EPIC'),
                const Spacer(),
                Text(
                  category.toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFFBCC6D3),
                    fontSize: 9,
                    letterSpacing: 1.45,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Center(
            child: Container(
              width: 198,
              height: 198,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF182237),
                border: Border.all(
                  color: const Color(0xFFCAA755),
                  width: 2,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x55000000),
                    blurRadius: 30,
                    offset: Offset(0, 14),
                  ),
                ],
              ),
              child: const Center(
                child: Text(
                  'STQ',
                  style: TextStyle(
                    color: Color(0xFFF1D98C),
                    fontSize: 46,
                    letterSpacing: 4,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 70,
            left: 32,
            right: 32,
            child: Column(
              children: [
                Text(
                  arabic ? 'اسرق السؤال' : 'STEAL THE QUESTION',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFF1D98C),
                    fontSize: 13,
                    letterSpacing: 2.1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  arabic ? 'بطاقة من مجموعتك' : 'A CARD FROM YOUR COLLECTION',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF9EACBD),
                    fontSize: 8,
                    letterSpacing: 1.25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const Positioned(
            left: 24,
            bottom: 20,
            child: Text(
              'STQ • 001',
              style: TextStyle(
                color: Color(0x638999AB),
                fontSize: 8,
                letterSpacing: 1.6,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.arabic,
    required this.question,
    required this.seconds,
    required this.selected,
    required this.locked,
    required this.correct,
    required this.onAnswer,
  });

  final bool arabic;
  final _QuestionData question;
  final int seconds;
  final int selected;
  final bool locked;
  final bool correct;
  final ValueChanged<int> onAnswer;

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      faceColor: const Color(0xFFF2E8CF),
      borderGradient: const [
        Color(0xFFE0C477),
        Color(0xFF8A9BA9),
        Color(0xFFE0C477),
      ],
      width: 390,
      height: 510,
      light: true,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const CustomPaint(painter: _CardFacePainter()),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
            child: Column(
              crossAxisAlignment:
                  arabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _RarityBadge(
                      text: arabic ? 'إبيك' : 'EPIC',
                      light: true,
                    ),
                    const Spacer(),
                    _TimerRing(seconds: seconds, light: true),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE6D4A6),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(
                        arabic ? question.categoryAr : question.categoryEn,
                        style: const TextStyle(
                          color: Color(0xFF465267),
                          fontSize: 8,
                          letterSpacing: .9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      arabic ? 'بطاقة سؤال' : 'QUESTION CARD',
                      style: const TextStyle(
                        color: Color(0xFF85765A),
                        fontSize: 8,
                        letterSpacing: 1.15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(17, 17, 17, 18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F1DE),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: const Color(0xFFD0BC87),
                      width: 1.2,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1E453B2A),
                        blurRadius: 14,
                        offset: Offset(0, 7),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.help_outline_rounded,
                        color: Color(0xFFAF8941),
                        size: 26,
                      ),
                      const SizedBox(height: 9),
                      Text(
                        arabic ? question.ar : question.en,
                        textAlign: arabic ? TextAlign.right : TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF1E2838),
                          fontSize: 22,
                          height: 1.16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      for (int i = 0; i < 3; i++) ...[
                        _ChoiceButton(
                          arabic: arabic,
                          label: String.fromCharCode(65 + i),
                          text: arabic
                              ? question.arAnswers[i]
                              : question.enAnswers[i],
                          selected: selected == i,
                          correct: question.correctIndex == i,
                          locked: locked,
                          onTap: () => onAnswer(i),
                        ),
                        if (i != 2) const SizedBox(height: 7),
                      ],
                      const SizedBox(height: 8),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 160),
                        child: locked
                            ? Text(
                                correct
                                    ? (arabic ? 'إجابة صحيحة' : 'CORRECT')
                                    : (arabic ? 'إجابة خاطئة' : 'WRONG'),
                                key: ValueKey<String>(
                                  'state-' + correct.toString(),
                                ),
                                style: TextStyle(
                                  color: correct
                                      ? const Color(0xFF2D8C6B)
                                      : const Color(0xFFB44E5A),
                                  fontSize: 9,
                                  letterSpacing: 1.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              )
                            : Text(
                                arabic
                                    ? 'اختر إجابة قبل انتهاء الوقت'
                                    : 'CHOOSE BEFORE TIME RUNS OUT',
                                key: const ValueKey<String>('hint'),
                                style: const TextStyle(
                                  color: Color(0xFF87785C),
                                  fontSize: 8,
                                  letterSpacing: 1.05,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell({
    required this.child,
    required this.faceColor,
    required this.borderGradient,
    required this.width,
    required this.height,
    this.light = false,
  });

  final Widget child;
  final Color faceColor;
  final List<Color> borderGradient;
  final double width;
  final double height;
  final bool light;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: borderGradient,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x78000000),
            blurRadius: 30,
            offset: Offset(0, 17),
          ),
        ],
      ),
      padding: const EdgeInsets.all(4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: faceColor,
          border: Border.all(
            color: light
                ? const Color(0xFFB69C67)
                : const Color(0x4BFFFFFF),
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(17),
          child: Stack(
            fit: StackFit.expand,
            children: [
              child,
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _CardFramePainter(light: light),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RarityBadge extends StatelessWidget {
  const _RarityBadge({
    required this.text,
    this.light = false,
  });

  final String text;
  final bool light;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: light
            ? const Color(0xFFDDBE6A)
            : const Color(0xFF2B344A),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: light
              ? const Color(0xFF8F6C2E)
              : const Color(0xFF9A7A3F),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.diamond_outlined,
            size: 11,
            color: light
                ? const Color(0xFF614715)
                : const Color(0xFFE4C67F),
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: light
                  ? const Color(0xFF614715)
                  : const Color(0xFFE9D69E),
              fontSize: 8,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimerRing extends StatelessWidget {
  const _TimerRing({
    required this.seconds,
    this.light = false,
  });

  final int seconds;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final Color accent = seconds <= 5
        ? const Color(0xFFC45560)
        : const Color(0xFF2D9EAA);

    return Container(
      width: 58,
      height: 58,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: light
            ? const Color(0xFFF8F0DD)
            : const Color(0xFF182236),
        border: Border.all(
          color: const Color(0xFFAF965C),
          width: 1.2,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: seconds / kSecondsPerQuestion,
            strokeWidth: 4,
            backgroundColor: const Color(0x2A6D6A62),
            valueColor: AlwaysStoppedAnimation<Color>(accent),
          ),
          Center(
            child: Text(
              seconds.toString(),
              style: TextStyle(
                color: light
                    ? const Color(0xFF202939)
                    : const Color(0xFFF1E5C9),
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({
    required this.arabic,
    required this.label,
    required this.text,
    required this.selected,
    required this.correct,
    required this.locked,
    required this.onTap,
  });

  final bool arabic;
  final String label;
  final String text;
  final bool selected;
  final bool correct;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool showCorrect = locked && correct;
    final bool showWrong = locked && selected && !correct;

    Color fill = const Color(0xFF233047);
    Color border = const Color(0xFF536276);
    Color accent = const Color(0xFFD9B45C);

    if (showCorrect) {
      fill = const Color(0xFF214A43);
      border = const Color(0xFF58B89C);
      accent = const Color(0xFF7DE0C2);
    } else if (showWrong) {
      fill = const Color(0xFF512D38);
      border = const Color(0xFFC76A78);
      accent = const Color(0xFFFF9DAA);
    } else if (selected) {
      fill = const Color(0xFF294B5C);
      border = const Color(0xFF6CC3D0);
      accent = const Color(0xFF94E9F3);
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: locked ? null : onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: border,
              width: selected ? 1.6 : 1.0,
            ),
          ),
          child: Row(
            textDirection: arabic ? TextDirection.rtl : TextDirection.ltr,
            children: [
              _ChoiceBadge(
                label: label,
                accent: accent,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  textAlign: arabic ? TextAlign.right : TextAlign.left,
                  style: const TextStyle(
                    color: Color(0xFFF7F0DD),
                    fontSize: 14,
                    height: 1.05,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (showCorrect)
                Icon(
                  Icons.check_rounded,
                  color: accent,
                  size: 19,
                ),
              if (showWrong)
                Icon(
                  Icons.close_rounded,
                  color: accent,
                  size: 19,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChoiceBadge extends StatelessWidget {
  const _ChoiceBadge({
    required this.label,
    required this.accent,
  });

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 31,
      height: 31,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF182235),
        border: Border.all(
          color: accent,
          width: 1.2,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: accent,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _DeckRail extends StatelessWidget {
  const _DeckRail({
    required this.active,
    required this.size,
    required this.arabic,
  });

  final int active;
  final int size;
  final bool arabic;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x9E151E30),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x355F7188)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            arabic ? 'سطحك' : 'YOUR DECK',
            style: const TextStyle(
              color: Color(0xFFB9A87B),
              fontSize: 8,
              letterSpacing: 1.3,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 9),
          for (int i = 0; i < size; i++)
            _MiniDeckCard(
              active: i == active,
              number: i + 1,
            ),
        ],
      ),
    );
  }
}

class _MiniDeckCard extends StatelessWidget {
  const _MiniDeckCard({
    required this.active,
    required this.number,
  });

  final bool active;
  final int number;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: active ? 25 : 18,
      height: active ? 34 : 27,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: active
            ? const Color(0xFF36505C)
            : const Color(0xFF263348),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: active
              ? const Color(0xFFD4AF61)
              : const Color(0xFF53657B),
          width: active ? 1.4 : .8,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        number.toString(),
        style: TextStyle(
          color: active
              ? const Color(0xFFF3D88F)
              : const Color(0xFFAAB4C3),
          fontSize: 8,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _DeckStack extends StatelessWidget {
  const _DeckStack({required this.mine});
  final bool mine;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 270,
      child: Align(
        alignment: mine ? Alignment.centerLeft : Alignment.centerRight,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 150,
              height: 190,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    left: 23,
                    top: 12,
                    child: Transform.rotate(
                      angle: mine ? -.12 : .12,
                      child: const _StackCard(depth: 3),
                    ),
                  ),
                  Positioned(
                    left: 15,
                    top: 6,
                    child: Transform.rotate(
                      angle: mine ? -.06 : .06,
                      child: const _StackCard(depth: 2),
                    ),
                  ),
                  Transform.rotate(
                    angle: mine ? -.015 : .015,
                    child: const _StackCard(depth: 1),
                  ),
                ],
              ),
            ),
            Text(
              mine ? 'YOUR CARDS' : 'RIVAL CARDS',
              style: const TextStyle(
                color: Color(0xFFA7B1C0),
                fontSize: 8,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '10',
              style: TextStyle(
                color: mine
                    ? const Color(0xFF7FD8E4)
                    : const Color(0xFFDB8A92),
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StackCard extends StatelessWidget {
  const _StackCard({required this.depth});
  final int depth;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 112,
      height: 160,
      decoration: BoxDecoration(
        color: const Color(0xFF202B40),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF8A7140)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Center(
        child: Text(
          'STQ',
          style: TextStyle(
            color: depth == 1
                ? const Color(0xFFE7CE87)
                : const Color(0xFF708196),
            fontSize: depth == 1 ? 25 : 19,
            letterSpacing: 2.4,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _StealCard extends StatelessWidget {
  const _StealCard({
    required this.index,
    required this.selected,
    required this.revealed,
    required this.animation,
    required this.onTap,
    required this.arabic,
  });

  final int index;
  final bool selected;
  final bool revealed;
  final double animation;
  final VoidCallback onTap;
  final bool arabic;

  @override
  Widget build(BuildContext context) {
    final double lift = selected ? -10 * animation : 0;

    return Transform.translate(
      offset: Offset(0, lift),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 118,
          height: 158,
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF2E4357)
                : const Color(0xFF243247),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: selected
                  ? const Color(0xFFE0BE67)
                  : const Color(0xFF5D6B7C),
              width: selected ? 2 : 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x50000000),
                blurRadius: 15,
                offset: Offset(0, 9),
              ),
            ],
          ),
          child: Stack(
            children: [
              const Positioned.fill(
                child: CustomPaint(painter: _SmallCardBackPainter()),
              ),
              Center(
                child: revealed
                    ? const Text(
                        'STQ',
                        style: TextStyle(
                          color: Color(0xFFEED48B),
                          fontSize: 28,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w900,
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'STQ',
                            style: TextStyle(
                              color: Color(0xFFD8BF7E),
                              fontSize: 24,
                              letterSpacing: 2,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            (arabic ? 'بطاقة ' : 'CARD ') + (index + 1).toString(),
                            style: const TextStyle(
                              color: Color(0xFFB8C3D0),
                              fontSize: 8,
                              letterSpacing: 1.0,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallCardBackPainter extends CustomPainter {
  const _SmallCardBackPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0x355E748C);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(9, 9, size.width - 18, size.height - 18),
        const Radius.circular(10),
      ),
      p,
    );
    canvas.drawCircle(size.center(Offset.zero), size.width * .23, p);
    final Paint gold = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0x4CA98C45);
    canvas.drawCircle(size.center(Offset.zero), size.width * .32, gold);
  }
}

class _StealAction extends StatelessWidget {
  const _StealAction({
    required this.index,
    required this.arabic,
    required this.onClaim,
  });

  final int index;
  final bool arabic;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 580),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xC0162137),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x55FFD66B)),
      ),
      child: Row(
        children: [
          const _GoldenSeal(size: 54),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  arabic ? 'بطاقة محددة' : 'CARD SELECTED',
                  style: const TextStyle(
                    color: Color(0xFFFFD66B),
                    fontSize: 10,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  arabic
                      ? 'هل تريد سرقة البطاقة ' + (index + 1).toString() + '؟'
                      : 'Steal card ' + (index + 1).toString() + '?',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: onClaim,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFFD66B),
              foregroundColor: const Color(0xFF241D10),
              padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              arabic ? 'اسرقها' : 'STEAL',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.text,
    required this.color,
  });

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withValues(alpha: .055),
        border: Border.all(
          color: Colors.white.withValues(alpha: .09),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 9,
          letterSpacing: 1.1,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 540),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        color: const Color(0xDE15213B),
        border: Border.all(color: Colors.white.withValues(alpha: .10)),
        boxShadow: const [
          BoxShadow(
            color: Color(0xA8000000),
            blurRadius: 55,
            offset: Offset(0, 26),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _RoundCrown extends StatelessWidget {
  const _RoundCrown({required this.won});

  final bool won;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 78,
      height: 78,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: won
              ? const [Color(0xFFFFEEAA), Color(0xFFFFB83D)]
              : const [Color(0xFFC3CAD6), Color(0xFF6D7484)],
        ),
        boxShadow: [
          BoxShadow(
            color: won ? const Color(0x66FFCE5A) : const Color(0x332B3550),
            blurRadius: 28,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Icon(
        won ? Icons.emoji_events_rounded : Icons.shield_rounded,
        size: 39,
        color: won ? const Color(0xFF473517) : const Color(0xFF1F2A3E),
      ),
    );
  }
}

class _GoldenSeal extends StatelessWidget {
  const _GoldenSeal({this.size = 68});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFFFFF0AE), Color(0xFFFFB83A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x66FFD46A),
            blurRadius: 26,
            spreadRadius: -4,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.auto_awesome_rounded,
        color: Color(0xFF4A3414),
        size: 30,
      ),
    );
  }
}

class _HoloPatternPainter extends CustomPainter {
  const _HoloPatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = size.center(Offset.zero);
    final Paint line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0x287EEAFF);

    final Paint soft = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = const Color(0x1BFFD66B);

    for (double r = 70; r < size.width; r += 52) {
      canvas.drawCircle(c, r, line);
    }

    for (int i = 0; i < 16; i++) {
      final double a = (math.pi * 2 * i) / 16;
      canvas.drawLine(
        c + Offset(math.cos(a), math.sin(a)) * 40,
        c + Offset(math.cos(a), math.sin(a)) * size.width,
        soft,
      );
    }

    final Path diamond = Path()
      ..moveTo(c.dx, c.dy - 72)
      ..lineTo(c.dx + 72, c.dy)
      ..lineTo(c.dx, c.dy + 72)
      ..lineTo(c.dx - 72, c.dy)
      ..close();

    canvas.drawPath(diamond, line);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

class _CardFacePainter extends CustomPainter {
  const _CardFacePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0x3C8B7441);

    final Paint faint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0x1E59667A);

    for (double y = 88; y < size.height - 28; y += 62) {
      canvas.drawLine(
        Offset(18, y),
        Offset(size.width - 18, y),
        faint,
      );
    }

    final Offset c = Offset(size.width * .5, size.height * .52);
    for (double r = 115; r < 200; r += 27) {
      canvas.drawCircle(c, r, faint);
    }

    final Path diamond = Path()
      ..moveTo(c.dx, c.dy - 60)
      ..lineTo(c.dx + 60, c.dy)
      ..lineTo(c.dx, c.dy + 60)
      ..lineTo(c.dx - 60, c.dy)
      ..close();
    canvas.drawPath(diamond, line);

    final Paint corner = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = const Color(0x7A9E7A42);

    _corner(canvas, corner, const Offset(13, 13), 1, 1);
    _corner(canvas, corner, Offset(size.width - 13, 13), -1, 1);
    _corner(canvas, corner, const Offset(13, size.height - 13), 1, -1);
    _corner(canvas, corner, Offset(size.width - 13, size.height - 13), -1, -1);
  }

  void _corner(
    Canvas canvas,
    Paint paint,
    Offset p,
    double sx,
    double sy,
  ) {
    final Path path = Path()
      ..moveTo(p.dx, p.dy + 18 * sy)
      ..lineTo(p.dx, p.dy)
      ..lineTo(p.dx + 18 * sx, p.dy);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CardBackPainter extends CustomPainter {
  const _CardBackPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = size.center(Offset.zero);
    final Paint line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0x3F6E849B);
    final Paint gold = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0x5B9C7A3E);

    for (double r = 48; r < size.width * .66; r += 28) {
      canvas.drawCircle(c, r, line);
    }

    for (int i = 0; i < 12; i++) {
      final double a = math.pi * 2 * i / 12;
      canvas.drawLine(
        c + Offset(math.cos(a), math.sin(a)) * 74,
        c + Offset(math.cos(a), math.sin(a)) * size.width * .5,
        gold,
      );
    }

    final Path outer = Path()
      ..moveTo(c.dx, c.dy - 152)
      ..lineTo(c.dx + 152, c.dy)
      ..lineTo(c.dx, c.dy + 152)
      ..lineTo(c.dx - 152, c.dy)
      ..close();
    canvas.drawPath(outer, gold);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CardFramePainter extends CustomPainter {
  const _CardFramePainter({required this.light});

  final bool light;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint outer = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = light
          ? const Color(0x4A8C744A)
          : const Color(0x4A92A5BB);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(10, 10, size.width - 20, size.height - 20),
        const Radius.circular(14),
      ),
      outer,
    );

    final Paint gold = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = light
          ? const Color(0x6D9C7A3E)
          : const Color(0x638E7139);

    for (final Offset p0 in [
      const Offset(27, 27),
      Offset(size.width - 27, 27),
      const Offset(27, 483),
      Offset(size.width - 27, 483),
    ]) {
      final double sx = p0.dx < size.width / 2 ? 1 : -1;
      final double sy = p0.dy < size.height / 2 ? 1 : -1;
      final Path path = Path()
        ..moveTo(p0.dx, p0.dy + 17 * sy)
        ..lineTo(p0.dx, p0.dy)
        ..lineTo(p0.dx + 17 * sx, p0.dy);
      canvas.drawPath(path, gold);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AmbientLights extends StatelessWidget {
  const _AmbientLights();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: const _ArenaBackdropPainter(),
        size: Size.infinite,
      ),
    );
  }
}

class _ArenaBackdropPainter extends CustomPainter {
  const _ArenaBackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint top = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF162237),
          Color(0xFF0F1726),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, top);

    final Paint floor = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0x00111A29),
          Color(0xB20B101A),
        ],
      ).createShader(
        Rect.fromLTWH(0, size.height * .55, size.width, size.height * .45),
      );
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * .55, size.width, size.height * .45),
      floor,
    );

    final Paint grid = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0x203F5972);

    for (int i = -8; i <= 8; i++) {
      final double x = size.width / 2 + i * 74;
      canvas.drawLine(
        Offset(size.width / 2, size.height * .58),
        Offset(x + i * 28, size.height),
        grid,
      );
    }

    for (int i = 0; i < 6; i++) {
      final double y = size.height * .62 + i * 42;
      canvas.drawLine(
        Offset(size.width * .08, y),
        Offset(size.width * .92, y),
        grid,
      );
    }

    final Paint frame = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = const Color(0x305F7890);

    final RRect stage = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        16,
        16,
        size.width - 32,
        size.height - 32,
      ),
      const Radius.circular(18),
    );
    canvas.drawRRect(stage, frame);

    final Path centerMark = Path()
      ..moveTo(size.width * .5, size.height * .13)
      ..lineTo(size.width * .5 + 24, size.height * .16)
      ..lineTo(size.width * .5, size.height * .19)
      ..lineTo(size.width * .5 - 24, size.height * .16)
      ..close();
    final Paint mark = Paint()..color = const Color(0x3ABF9B4F);
    canvas.drawPath(centerMark, mark);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
