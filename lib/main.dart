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
      faceColor: const Color(0xFF121D38),
      borderGradient: const [
        Color(0xFF71E4FF),
        Color(0xFFD49B4A),
        Color(0xFF9C73FF),
      ],
      width: 400,
      height: 520,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const CustomPaint(
            painter: _HoloPatternPainter(),
          ),
          Positioned(
            top: 20,
            left: 22,
            right: 22,
            child: Row(
              children: [
                const _RarityBadge(text: 'EPIC'),
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
                  width: 104,
                  height: 104,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8EF3FF), Color(0xFFA977FF)],
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x8852DDFF),
                        blurRadius: 35,
                        spreadRadius: -6,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.style_rounded,
                    color: Color(0xFF081329),
                    size: 48,
                  ),
                ),
                const SizedBox(height: 22),
                const Text(
                  'STEAL THE',
                  style: TextStyle(
                    letterSpacing: 4.0,
                    fontSize: 12,
                    color: Color(0xFF75E8FF),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'QUESTIONS',
                  style: TextStyle(
                    letterSpacing: 2.6,
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: 86,
                  height: 1,
                  color: const Color(0x66FFD66B),
                ),
                const SizedBox(height: 13),
                Text(
                  arabic ? 'بطاقة سؤال' : 'QUESTION CARD',
                  style: const TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.9,
                    color: Color(0x99FFFFFF),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const Positioned(
            right: 22,
            bottom: 20,
            child: Text(
              'STQ / 001',
              style: TextStyle(
                fontSize: 9,
                letterSpacing: 1.7,
                color: Color(0x66FFFFFF),
                fontWeight: FontWeight.w900,
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
      faceColor: const Color(0xFFF8F4EA),
      borderGradient: const [
        Color(0xFFFFD56A),
        Color(0xFF73E8FF),
        Color(0xFF9A74FF),
      ],
      width: 400,
      height: 520,
      light: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
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
            const SizedBox(height: 20),
            Text(
              arabic ? question.categoryAr : question.categoryEn,
              textAlign: arabic ? TextAlign.right : TextAlign.left,
              style: TextStyle(
                fontSize: 9,
                letterSpacing: arabic ? .4 : 2.2,
                color: const Color(0xFF776C5A),
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 9),
            Text(
              arabic ? question.ar : question.en,
              textAlign: arabic ? TextAlign.right : TextAlign.left,
              style: const TextStyle(
                color: Color(0xFF151B2C),
                fontSize: 25,
                height: 1.17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const Spacer(),
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
              if (i != 2) const SizedBox(height: 9),
            ],
            const SizedBox(height: 14),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: locked
                  ? Row(
                      key: ValueKey<String>(
                        'state-' + correct.toString(),
                      ),
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          correct
                              ? Icons.check_circle_rounded
                              : Icons.error_rounded,
                          size: 18,
                          color: correct
                              ? const Color(0xFF1EAF82)
                              : const Color(0xFFDB526A),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          correct
                              ? (arabic ? 'إجابة صحيحة' : 'CORRECT')
                              : (arabic ? 'إجابة خاطئة' : 'WRONG'),
                          style: TextStyle(
                            fontSize: 10,
                            letterSpacing: arabic ? .1 : 2.0,
                            color: correct
                                ? const Color(0xFF159873)
                                : const Color(0xFFD84B62),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      arabic
                          ? 'أجب قبل انتهاء الوقت'
                          : 'ANSWER BEFORE TIME RUNS OUT',
                      key: const ValueKey<String>('hint'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 9,
                        letterSpacing: arabic ? .1 : 1.4,
                        color: const Color(0xFF8D8372),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ],
        ),
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
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: borderGradient,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xB5000000),
            blurRadius: 48,
            offset: const Offset(0, 24),
          ),
          if (!light)
            const BoxShadow(
              color: Color(0x4548DFFF),
              blurRadius: 36,
              spreadRadius: -6,
            ),
        ],
      ),
      padding: const EdgeInsets.all(2),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          color: faceColor,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: child,
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: light
            ? const Color(0xFFF0D89A)
            : const Color(0x22FFD66B),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: light
              ? const Color(0xFFB68B38)
              : const Color(0x66FFD66B),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 9,
          letterSpacing: 1.45,
          color: light
              ? const Color(0xFF76541A)
              : const Color(0xFFFFD66B),
          fontWeight: FontWeight.w900,
        ),
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
        ? const Color(0xFFE95C71)
        : const Color(0xFF29B9DA);

    return SizedBox(
      width: 58,
      height: 58,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: seconds / kSecondsPerQuestion,
            strokeWidth: 4.5,
            backgroundColor:
                light ? const Color(0xFFDCD5C7) : const Color(0x261A2440),
            valueColor: AlwaysStoppedAnimation<Color>(accent),
          ),
          Center(
            child: Text(
              seconds.toString(),
              style: TextStyle(
                color: light
                    ? const Color(0xFF15203A)
                    : Colors.white,
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

    Color bg = const Color(0xFFF0EBDE);
    Color border = const Color(0xFFD9D1C0);
    Color textColor = const Color(0xFF1A2031);

    if (showCorrect) {
      bg = const Color(0xFFDFF5EC);
      border = const Color(0xFF4CC89A);
    } else if (showWrong) {
      bg = const Color(0xFFFBE1E6);
      border = const Color(0xFFE86D82);
    } else if (selected) {
      bg = const Color(0xFFD9F3F8);
      border = const Color(0xFF4CCAE7);
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: locked ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border, width: 1.2),
          ),
          child: Row(
            textDirection: arabic ? TextDirection.rtl : TextDirection.ltr,
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0x160F1830),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF2A344B),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  text,
                  textAlign: arabic ? TextAlign.right : TextAlign.left,
                  style: const TextStyle(
                    color: Color(0xFF1A2031),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (showCorrect)
                const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF30B88B),
                  size: 20,
                ),
              if (showWrong)
                const Icon(
                  Icons.cancel_rounded,
                  color: Color(0xFFE26379),
                  size: 20,
                ),
            ],
          ),
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
