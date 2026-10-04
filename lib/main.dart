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
    final String progress = (_questionIndex + 1).toString() +
        ' / ' +
        totalQuestions.toString();

    return Column(
      key: const ValueKey<String>('duel'),
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(18, compact ? 10 : 18, 18, 0),
          child: _ArenaHeader(
            arabic: _arabic,
            score: _score,
            rivalScore: _rivalScore,
            progress: progress,
            onLanguage: _toggleLanguage,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 980),
                child: Column(
                  children: [
                    _BattleLine(
                      arabic: _arabic,
                      deckSize: deckSize,
                    ),
                    const SizedBox(height: 12),
                    AnimatedBuilder(
                      animation: Listenable.merge([_flip, _enter, _pulse]),
                      builder: (context, child) {
                        final double enter = Curves.easeOutCubic.transform(_enter.value);
                        final double pulse = Curves.easeOutCubic.transform(_pulse.value);
                        final double flip = _flip.value;
                        final double scale = 0.95 + (0.05 * enter) + (0.012 * pulse);
                        final double y = 26 * (1 - enter);
                        final double shake =
                            _locked && !_correct
                                ? math.sin(pulse * math.pi * 6) * 4
                                : 0;

                        return Transform.translate(
                          offset: Offset(shake, y),
                          child: Transform.scale(
                            scale: scale,
                            child: Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.identity()
                                ..setEntry(3, 2, 0.0013)
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
                    ),
                    const SizedBox(height: 14),
                    _DeckRail(
                      active: _questionIndex,
                      size: deckSize,
                      arabic: _arabic,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
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
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7EE8FF), Color(0xFFB47CFF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x5539D9FF),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.style_rounded,
                  color: Color(0xFF091326),
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  'STEAL THE\nQUESTIONS',
                  style: const TextStyle(
                    fontSize: 11,
                    height: 0.95,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.6,
                  ),
                ),
              ),
            ],
          ),
        ),
        _ScoreBox(
          label: arabic ? 'أنت' : 'YOU',
          value: score,
          accent: const Color(0xFF70E7FF),
        ),
        const SizedBox(width: 7),
        _Pill(text: progress, color: Colors.white70),
        const SizedBox(width: 7),
        _ScoreBox(
          label: arabic ? 'خصم' : 'RIVAL',
          value: rivalScore,
          accent: const Color(0xFFFF8CB4),
        ),
        const SizedBox(width: 7),
        OutlinedButton(
          onPressed: onLanguage,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(54, 40),
            side: BorderSide(color: Colors.white.withValues(alpha: .16)),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(13),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10),
          ),
          child: Text(
            arabic ? 'EN' : 'ع',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
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
    return Row(
      children: [
        const _PlayerBadge(
          name: 'YOU',
          active: true,
        ),
        const Spacer(),
        Column(
          children: [
            Text(
              arabic ? 'المواجهة' : 'CARD DUEL',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 1.8,
                color: Colors.white.withValues(alpha: .58),
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '10 ' + (arabic ? 'بطاقات' : 'CARDS') + '  •  7 ' +
                  (arabic ? 'أسئلة' : 'QUESTIONS'),
              style: TextStyle(
                fontSize: 9,
                letterSpacing: 1.0,
                color: Colors.white.withValues(alpha: .4),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const Spacer(),
        const _PlayerBadge(
          name: 'RIVAL',
          active: false,
        ),
      ],
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
      faceColor: const Color(0xFF111935),
      borderGradient: const [
        Color(0xFFFFD36A),
        Color(0xFF54E1FF),
        Color(0xFF9A6BFF),
        Color(0xFFFFD36A),
      ],
      width: 400,
      height: 520,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const CustomPaint(painter: _CardBackPainter()),
          Positioned(
            top: 18,
            left: 20,
            right: 20,
            child: Row(
              children: [
                _RarityBadge(text: arabic ? 'إبيك' : 'EPIC'),
                const Spacer(),
                Text(
                  category,
                  style: const TextStyle(
                    fontSize: 9,
                    letterSpacing: 1.8,
                    color: Color(0x99FFFFFF),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 132,
                  height: 132,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      colors: [
                        Color(0xFFFFF0AF),
                        Color(0xFFFFC34D),
                        Color(0xFF7A4DFF),
                      ],
                      stops: [0.0, 0.58, 1.0],
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x6658E4FF),
                        blurRadius: 36,
                        spreadRadius: 2,
                      ),
                      BoxShadow(
                        color: Color(0x554E3B9A),
                        blurRadius: 50,
                        spreadRadius: -6,
                      ),
                    ],
                  ),
                  child: Container(
                    margin: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF111935),
                      border: Border.all(
                        color: const Color(0xA6FFE19A),
                        width: 1.4,
                      ),
                    ),
                    child: const Center(
                      child: Text(
                        'STQ',
                        style: TextStyle(
                          fontSize: 34,
                          letterSpacing: 1.8,
                          color: Color(0xFFFFE7A0),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  arabic ? 'اسرق السؤال' : 'STEAL THE',
                  style: const TextStyle(
                    letterSpacing: 3.6,
                    fontSize: 11,
                    color: Color(0xFF74E8FF),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  arabic ? 'الأسئلة' : 'QUESTIONS',
                  style: const TextStyle(
                    letterSpacing: 3.0,
                    fontSize: 27,
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x241D2447),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0x3DFFE07A)),
                  ),
                  child: Text(
                    arabic ? 'بطاقة نادرة' : 'COLLECTIBLE QUESTION',
                    style: const TextStyle(
                      fontSize: 8,
                      letterSpacing: 1.35,
                      color: Color(0xD1FFFFFF),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Positioned(
            left: 22,
            bottom: 20,
            child: Text(
              'STQ • 001',
              style: TextStyle(
                fontSize: 9,
                letterSpacing: 1.8,
                color: Color(0x66FFFFFF),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Positioned(
            right: 20,
            bottom: 18,
            child: Text(
              arabic ? 'مجموعة 01' : 'COLLECTION 01',
              style: const TextStyle(
                fontSize: 8,
                letterSpacing: 1.3,
                color: Color(0x59FFFFFF),
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
      faceColor: const Color(0xFF141A37),
      borderGradient: const [
        Color(0xFFFFD66F),
        Color(0xFF55E4FF),
        Color(0xFF8F63FF),
        Color(0xFFFFC84D),
      ],
      width: 400,
      height: 520,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const CustomPaint(painter: _CardFacePainter()),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
            child: Column(
              crossAxisAlignment:
                  arabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _RarityBadge(text: arabic ? 'إبيك' : 'EPIC'),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        arabic ? 'سؤال تنافسي' : 'COMPETITIVE QUESTION',
                        textAlign: arabic ? TextAlign.right : TextAlign.left,
                        style: TextStyle(
                          fontSize: 8,
                          letterSpacing: arabic ? .1 : 1.35,
                          color: const Color(0x8EFFFFFF),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    _TimerRing(seconds: seconds),
                  ],
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0x25FFD66F),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0x5CFFD66F)),
                      ),
                      child: Text(
                        arabic ? question.categoryAr : question.categoryEn,
                        style: const TextStyle(
                          fontSize: 8,
                          color: Color(0xFFFFD878),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _questionNo(0) + ' / ' + kTotalQuestions.toString(),
                      style: const TextStyle(
                        fontSize: 8,
                        letterSpacing: 1.35,
                        color: Color(0x66FFFFFF),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 13),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 19),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xE92B3561),
                        Color(0xF0181F42),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(23),
                    border: Border.all(
                      color: const Color(0x5E9BEFFF),
                      width: 1,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x35000000),
                        blurRadius: 22,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    textDirection:
                        arabic ? TextDirection.rtl : TextDirection.ltr,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        margin: EdgeInsets.only(
                          right: arabic ? 0 : 12,
                          left: arabic ? 12 : 0,
                        ),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFFFFDF7C),
                              Color(0xFFB66BFF),
                            ],
                          ),
                        ),
                        child: const Icon(
                          Icons.question_mark_rounded,
                          color: Color(0xFF121731),
                          size: 21,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          arabic ? question.ar : question.en,
                          textAlign: arabic ? TextAlign.right : TextAlign.left,
                          style: const TextStyle(
                            color: Color(0xFFF9F5EA),
                            fontSize: 24,
                            height: 1.18,
                            fontWeight: FontWeight.w900,
                          ),
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
                        if (i != 2) const SizedBox(height: 8),
                      ],
                      const SizedBox(height: 10),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: locked
                            ? Container(
                                key: ValueKey<String>(
                                  'state-' + correct.toString(),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: correct
                                      ? const Color(0x2538E2AE)
                                      : const Color(0x25FF6985),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: correct
                                        ? const Color(0x5E38E2AE)
                                        : const Color(0x5EFF6985),
                                  ),
                                ),
                                child: Text(
                                  correct
                                      ? (arabic
                                          ? 'إجابة صحيحة'
                                          : 'CORRECT • KEEP GOING')
                                      : (arabic
                                          ? 'إجابة خاطئة'
                                          : 'WRONG • NEXT CARD'),
                                  style: TextStyle(
                                    fontSize: 9,
                                    letterSpacing: arabic ? .05 : 1.15,
                                    color: correct
                                        ? const Color(0xFF72F2C0)
                                        : const Color(0xFFFF879A),
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              )
                            : Text(
                                arabic
                                    ? 'اختر إجابة قبل انتهاء العداد'
                                    : 'LOCK AN ANSWER BEFORE THE TIMER ENDS',
                                key: const ValueKey<String>('hint'),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 8,
                                  letterSpacing: arabic ? .05 : 1.1,
                                  color: const Color(0x78FFFFFF),
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

  String _questionNo(int offset) {
    return (offset + 1).toString().padLeft(2, '0');
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
        borderRadius: BorderRadius.circular(34),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: borderGradient,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x99000000),
            blurRadius: 42,
            offset: Offset(0, 24),
          ),
          BoxShadow(
            color: Color(0x3358E4FF),
            blurRadius: 30,
            spreadRadius: -8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(3),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(31),
          color: faceColor,
          border: Border.all(
            color: light
                ? const Color(0x66FFFFFF)
                : const Color(0x45FFFFFF),
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
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
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFE78A),
            Color(0xFFBD7BDE),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xA6FFF1B2),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55FFD76A),
            blurRadius: 18,
            spreadRadius: -5,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.diamond_rounded,
            size: 11,
            color: light
                ? const Color(0xFF6F4518)
                : const Color(0xFF261A3F),
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              fontSize: 8,
              letterSpacing: 1.2,
              color: Color(0xFF2A193B),
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
        ? const Color(0xFFFF6B85)
        : const Color(0xFF59E5FF);

    return Container(
      width: 58,
      height: 58,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0x20101632),
        border: Border.all(
          color: const Color(0x4CFFFFFF),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: .20),
            blurRadius: 18,
            spreadRadius: -3,
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: seconds / kSecondsPerQuestion,
            strokeWidth: 4,
            backgroundColor: light
                ? const Color(0x33211D30)
                : const Color(0x33FFFFFF),
            valueColor: AlwaysStoppedAnimation<Color>(accent),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  seconds.toString(),
                  style: TextStyle(
                    color: light ? const Color(0xFF171C32) : Colors.white,
                    fontSize: 15,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  'SEC',
                  style: TextStyle(
                    color: light
                        ? const Color(0xFF7C7080)
                        : const Color(0x73FFFFFF),
                    fontSize: 6,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w900,
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

    Color border = const Color(0x334E5C8B);
    Color top = const Color(0xCC26325E);
    Color bottom = const Color(0xE6151B39);
    Color labelFill = const Color(0x25FFFFFF);
    Color textColor = const Color(0xFFF7F3E8);
    Color accent = const Color(0xFF64DFF8);

    if (showCorrect) {
      border = const Color(0xB34BE4B1);
      top = const Color(0xCC1E564B);
      bottom = const Color(0xEE14332F);
      accent = const Color(0xFF76F5C2);
    } else if (showWrong) {
      border = const Color(0xB3FF6C86);
      top = const Color(0xCC5A263B);
      bottom = const Color(0xEE351625);
      accent = const Color(0xFFFF8398);
    } else if (selected) {
      border = const Color(0xC85DE5FF);
      top = const Color(0xCC275A73);
      bottom = const Color(0xEE172D47);
      accent = const Color(0xFF8CEBFF);
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: locked ? null : onTap,
        borderRadius: BorderRadius.circular(15),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 170),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [top, bottom],
            ),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: border,
              width: selected ? 1.5 : 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 10,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            textDirection: arabic ? TextDirection.rtl : TextDirection.ltr,
            children: [
              if (!arabic) ...[
                _ChoiceBadge(label: label, accent: accent, fill: labelFill),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  text,
                  textAlign: arabic ? TextAlign.right : TextAlign.left,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 14,
                    height: 1.05,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (arabic) ...[
                const SizedBox(width: 10),
                _ChoiceBadge(label: label, accent: accent, fill: labelFill),
              ],
              if (showCorrect) ...[
                const SizedBox(width: 6),
                Icon(Icons.check_circle_rounded, color: accent, size: 18),
              ],
              if (showWrong) ...[
                const SizedBox(width: 5),
                Icon(Icons.close_rounded, color: accent, size: 20),
              ],
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
    required this.fill,
  });

  final String label;
  final Color accent;
  final Color fill;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 31,
      height: 31,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fill,
        border: Border.all(
          color: accent.withValues(alpha: .75),
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: .12),
            blurRadius: 8,
          ),
        ],
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0x2A0C1730),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: .09),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            arabic ? 'بطاقاتي' : 'MY DECK',
            style: TextStyle(
              fontSize: 9,
              letterSpacing: arabic ? .2 : 1.5,
              color: Colors.white.withValues(alpha: .55),
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 9),
          for (int i = 0; i < size; i++)
            Container(
              width: i == active ? 27 : 19,
              height: i == active ? 35 : 27,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(7),
                gradient: LinearGradient(
                  colors: i < kTotalQuestions
                      ? const [Color(0xFF4C719D), Color(0xFF223553)]
                      : const [Color(0xFF3A395A), Color(0xFF24213D)],
                ),
                border: Border.all(
                  color: i == active
                      ? const Color(0xFF72E7FF)
                      : Colors.white.withValues(alpha: .07),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                (i + 1).toString(),
                style: TextStyle(
                  fontSize: 8,
                  color: i == active
                      ? const Color(0xFFC7F7FF)
                      : Colors.white.withValues(alpha: .55),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
        ],
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
    final double lift = selected ? -12 * animation : 0;
    return Transform.translate(
      offset: Offset(0, lift),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 122,
          height: 164,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF6B84A9),
                Color(0xFF293956),
                Color(0xFF221A43),
              ],
            ),
            border: Border.all(
              color: selected
                  ? const Color(0xFFFFD66B)
                  : Colors.white.withValues(alpha: .10),
              width: selected ? 2 : 1,
            ),
            boxShadow: [
              if (selected)
                const BoxShadow(
                  color: Color(0x6054DFFF),
                  blurRadius: 28,
                  spreadRadius: -5,
                ),
            ],
          ),
          child: revealed
              ? const Center(
                  child: Icon(
                    Icons.style_rounded,
                    color: Color(0xFFFFD66B),
                    size: 40,
                  ),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.lock_outline_rounded,
                      color: Color(0xFF7DEAFF),
                      size: 30,
                    ),
                    const SizedBox(height: 9),
                    Text(
                      (arabic ? 'بطاقة ' : 'CARD ') + (index + 1).toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      arabic ? 'اضغط للاختيار' : 'TAP TO PICK',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .45),
                        fontSize: 8,
                        letterSpacing: 1.0,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
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
    final Paint halo = Paint()
      ..shader = const RadialGradient(
        colors: [
          Color(0x543F58C8),
          Color(0x00141A37),
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * .55, size.height * .48),
          radius: size.width * .78,
        ),
      );
    canvas.drawRect(Offset.zero & size, halo);

    final Paint cyan = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0x274DE6FF);
    final Paint gold = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = const Color(0x2DFFD66F);

    for (double r = 120; r < size.width * .75; r += 32) {
      canvas.drawCircle(
        Offset(size.width * .5, size.height * .53),
        r,
        cyan,
      );
    }

    for (int i = 0; i < 7; i++) {
      final double y = 98 + i * 58;
      canvas.drawLine(
        Offset(16, y),
        Offset(size.width - 16, y),
        cyan,
      );
    }

    final Path left = Path()
      ..moveTo(0, 122)
      ..lineTo(42, 96)
      ..lineTo(68, 122)
      ..lineTo(42, 150)
      ..close();
    canvas.drawPath(left, gold);

    final Path right = Path()
      ..moveTo(size.width, 165)
      ..lineTo(size.width - 42, 139)
      ..lineTo(size.width - 68, 165)
      ..lineTo(size.width - 42, 191)
      ..close();
    canvas.drawPath(right, cyan);

    final Paint micro = Paint()..color = const Color(0x24FFFFFF);
    for (int i = 0; i < 18; i++) {
      final double x = 14 + (i * 37) % (size.width.toInt() - 28);
      final double y = 70 + (i * 53) % (size.height.toInt() - 110);
      canvas.drawCircle(Offset(x, y), i.isEven ? 1.2 : .7, micro);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CardBackPainter extends CustomPainter {
  const _CardBackPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = size.center(Offset.zero);
    final Paint cyan = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.15
      ..color = const Color(0x3A48E3FF);
    final Paint violet = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0x32B36DFF);
    final Paint gold = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.35
      ..color = const Color(0x34FFD56A);

    for (double r = 48; r < size.width * .76; r += 31) {
      canvas.drawCircle(c, r, cyan);
    }

    for (int i = 0; i < 14; i++) {
      final double a = math.pi * 2 * i / 14;
      final Offset inner = c + Offset(math.cos(a), math.sin(a)) * 76;
      final Offset outer = c + Offset(math.cos(a), math.sin(a)) * size.width * .55;
      canvas.drawLine(inner, outer, violet);
    }

    final Path diamond = Path()
      ..moveTo(c.dx, c.dy - 154)
      ..lineTo(c.dx + 154, c.dy)
      ..lineTo(c.dx, c.dy + 154)
      ..lineTo(c.dx - 154, c.dy)
      ..close();
    canvas.drawPath(diamond, gold);

    final Paint edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0x35FFFFFF);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(16, 16, size.width - 32, size.height - 32),
        const Radius.circular(27),
      ),
      edge,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CardFramePainter extends CustomPainter {
  const _CardFramePainter({required this.light});

  final bool light;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0x4594EFFF);

    final RRect r = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(29),
    );
    canvas.drawRRect(r.deflate(9), p);

    final Paint gold = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..color = const Color(0x5DFFD66F);

    final List<Offset> corners = [
      const Offset(30, 30),
      Offset(size.width - 30, 30),
      const Offset(30, 490),
      Offset(size.width - 30, 490),
    ];

    for (final Offset p0 in corners) {
      final double sx = p0.dx < size.width / 2 ? 1 : -1;
      final double sy = p0.dy < size.height / 2 ? 1 : -1;
      final Path path = Path()
        ..moveTo(p0.dx, p0.dy + 20 * sy)
        ..lineTo(p0.dx, p0.dy)
        ..lineTo(p0.dx + 20 * sx, p0.dy);
      canvas.drawPath(path, gold);
    }

    final Paint side = Paint()
      ..color = const Color(0x1F6DE7FF);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(7, 7, size.width - 14, size.height - 14),
        const Radius.circular(27),
      ),
      side,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AmbientLights extends StatelessWidget {
  const _AmbientLights();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -150,
            left: -130,
            child: Container(
              width: 430,
              height: 430,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Color(0x5363E5FF),
                    Color(0x00142C54),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 80,
            right: -140,
            child: Container(
              width: 430,
              height: 430,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Color(0x4E9D63FF),
                    Color(0x003D2B79),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -190,
            left: 140,
            child: Container(
              width: 520,
              height: 520,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Color(0x3ED2A14D),
                    Color(0x0010214A),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
