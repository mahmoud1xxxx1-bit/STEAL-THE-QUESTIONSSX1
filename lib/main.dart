import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0B1020),
        fontFamily: 'Arial',
      ),
      home: const GamePrototype(),
    );
  }
}

class GamePrototype extends StatefulWidget {
  const GamePrototype({super.key});

  @override
  State<GamePrototype> createState() => _GamePrototypeState();
}

enum _Screen { duel, steal, done }

class _Question {
  const _Question({
    required this.text,
    required this.answers,
    required this.correct,
    required this.category,
  });

  final String text;
  final List<String> answers;
  final int correct;
  final String category;
}

class _GamePrototypeState extends State<GamePrototype>
    with TickerProviderStateMixin {
  static const int questionsPerDuel = 7;
  static const int deckSize = 10;
  static const int secondsPerQuestion = 20;

  static const _questions = <_Question>[
    _Question(
      text: 'Which planet is known as the Red Planet?',
      answers: ['Mars', 'Venus', 'Jupiter'],
      correct: 0,
      category: 'SCIENCE',
    ),
    _Question(
      text: 'What is the largest ocean on Earth?',
      answers: ['Atlantic', 'Pacific', 'Indian'],
      correct: 1,
      category: 'GEOGRAPHY',
    ),
    _Question(
      text: 'How many continents are there?',
      answers: ['5', '6', '7'],
      correct: 2,
      category: 'WORLD',
    ),
    _Question(
      text: 'Which animal is the fastest on land?',
      answers: ['Lion', 'Cheetah', 'Horse'],
      correct: 1,
      category: 'NATURE',
    ),
    _Question(
      text: 'Which language has the most native speakers?',
      answers: ['Spanish', 'English', 'Mandarin'],
      correct: 2,
      category: 'CULTURE',
    ),
    _Question(
      text: 'Which country is home to the city of Kyoto?',
      answers: ['China', 'Japan', 'Thailand'],
      correct: 1,
      category: 'TRAVEL',
    ),
    _Question(
      text: 'What is the hardest natural substance?',
      answers: ['Iron', 'Diamond', 'Quartz'],
      correct: 1,
      category: 'SCIENCE',
    ),
  ];

  final _opponentCards = List.generate(
    deckSize,
    (index) => 'CARD \${{index + 1}',
  );

  late final AnimationController _cardFlip;
  late final AnimationController _cardEnter;
  late final AnimationController _result;
  late final AnimationController _steal;
  Timer? _timer;

  _Screen _screen = _Screen.duel;
  int _questionIndex = 0;
  int _seconds = secondsPerQuestion;
  int _yourScore = 0;
  int _rivalScore = 0;
  int _selected = -1;
  bool _locked = false;
  bool _showResult = false;
  bool _wasCorrect = false;
  int _stolenIndex = -1;
  bool _revealedSteal = false;

  _Question get _question => _questions[_questionIndex];

  @override
  void initState() {
    super.initState();
    _cardFlip = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _cardEnter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _result = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _steal = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _startQuestion(first: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cardFlip.dispose();
    _cardEnter.dispose();
    _result.dispose();
    _steal.dispose();
    super.dispose();
  }

  void _startQuestion({bool first = false}) {
    _timer?.cancel();
    setState(() {
      _seconds = secondsPerQuestion;
      _selected = -1;
      _locked = false;
      _showResult = false;
    });
    _cardFlip
      ..reset()
      ..forward();
    _cardEnter
      ..reset()
      ..forward();
    if (!first) {
      _result.reset();
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _locked || _screen != _Screen.duel) return;
      if (_seconds <= 1) {
        timer.cancel();
        _submitAnswer(-1);
      } else {
        setState(() => _seconds--);
      }
    });
  }

  Future<void> _submitAnswer(int answer) async {
    if (_locked || _screen != _Screen.duel) return;
    _timer?.cancel();
    await SystemSound.play(SystemSoundType.click);
    await HapticFeedback.selectionClick();

    final correct = answer == _question.correct;
    setState(() {
      _selected = answer;
      _locked = true;
      _showResult = true;
      _wasCorrect = correct;
      if (correct) _yourScore++;
    });
    _result.forward(from: 0);

    await Future<void>.delayed(const Duration(milliseconds: 780));
    if (!mounted) return;

    if (_questionIndex >= questionsPerDuel - 1) {
      setState(() => _screen = _Screen.steal);
      _steal.forward(from: 0);
      return;
    }

    setState(() => _questionIndex++);
    _startQuestion();
  }

  void _chooseSteal(int index) {
    if (_revealedSteal) return;
    SystemSound.play(SystemSoundType.click);
    HapticFeedback.mediumImpact();
    setState(() {
      _stolenIndex = index;
      _revealedSteal = true;
    });
    _steal.forward(from: 0);
  }

  void _finishSteal() {
    setState(() => _screen = _Screen.done);
    HapticFeedback.heavyImpact();
  }

  void _restart() {
    _timer?.cancel();
    setState(() {
      _screen = _Screen.duel;
      _questionIndex = 0;
      _seconds = secondsPerQuestion;
      _yourScore = 0;
      _rivalScore = 0;
      _selected = -1;
      _locked = false;
      _showResult = false;
      _wasCorrect = false;
      _stolenIndex = -1;
      _revealedSteal = false;
    });
    _startQuestion(first: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0C1730),
              Color(0xFF17133A),
              Color(0xFF0B1020),
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              const _BackgroundGlow(),
              if (_screen == _Screen.duel) _buildDuel(),
              if (_screen == _Screen.steal) _buildSteal(),
              if (_screen == _Screen.done) _buildDone(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDuel() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 760;
        return Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(18, compact ? 10 : 18, 18, 0),
              child: _DuelHeader(
                yourScore: _yourScore,
                rivalScore: _rivalScore,
                questionNumber: _questionIndex + 1,
              ),
            ),
            SizedBox(height: compact ? 8 : 18),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 920),
                    child: Column(
                      children: [
                        AnimatedBuilder(
                          animation: Listenable.merge(
                            [_cardFlip, _cardEnter, _result],
                          ),
                          builder: (context, child) {
                            final enter = Curves.easeOutCubic.transform(
                              _cardEnter.value,
                            );
                            final flip = _cardFlip.value;
                            final result = Curves.easeOutCubic.transform(
                              _result.value,
                            );
                            final scale = 0.965 + (0.035 * enter);
                            final y = 26 * (1 - enter);
                            final shake = _showResult && !_wasCorrect
                                ? math.sin(result * math.pi * 5) * 4
                                : 0.0;
                            return Transform.translate(
                              offset: Offset(shake, y),
                              child: Transform.scale(
                                scale: scale,
                                child: Transform(
                                  alignment: Alignment.center,
                                  transform: Matrix4.identity()
                                    ..setEntry(3, 2, 0.0012)
                                    ..rotateY(math.pi * flip),
                                  child: flip < 0.5
                                      ? _CardBack(
                                          category: _question.category,
                                          compact: compact,
                                        )
                                      : Transform(
                                          alignment: Alignment.center,
                                          transform:
                                              Matrix4.rotationY(math.pi),
                                          child: _QuestionCard(
                                            question: _question,
                                            seconds: _seconds,
                                            selected: _selected,
                                            locked: _locked,
                                            correctIndex: _question.correct,
                                            compact: compact,
                                            onAnswer: _submitAnswer,
                                            showResult: _showResult,
                                            wasCorrect: _wasCorrect,
                                          ),
                                        ),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        _DeckRail(size: deckSize, active: _questionIndex),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSteal() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth > 760;
          return Column(
            children: [
              _StealHeader(
                yourScore: _yourScore,
                rivalScore: _rivalScore,
              ),
              const SizedBox(height: 18),
              Expanded(
                child: SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 980),
                    child: Column(
                      children: [
                        _StealTitle(
                          revealed: _revealedSteal,
                          wide: wide,
                        ),
                        const SizedBox(height: 16),
                        AnimatedBuilder(
                          animation: _steal,
                          builder: (context, _) {
                            return Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                for (int i = 0; i < _opponentCards.length; i++)
                                  _StealCard(
                                    index: i,
                                    selected: _stolenIndex == i,
                                    revealed:
                                        _revealedSteal && _stolenIndex == i,
                                    animationValue: _steal.value,
                                    onTap: () => _chooseSteal(i),
                                  ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                        if (_revealedSteal)
                          _StealConfirm(
                            cardIndex: _stolenIndex,
                            onDone: _finishSteal,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDone() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: const Color(0xE9121A2E),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withValues(alpha: .09)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 50,
                offset: Offset(0, 24),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _MedalIcon(),
              const SizedBox(height: 16),
              const Text(
                'CARD STOLEN',
                style: TextStyle(
                  fontSize: 14,
                  letterSpacing: 2.2,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFFFD66B),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You stole CARD \${{_stolenIndex + 1}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your next duel starts with a bigger collection.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .55),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _restart,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD66B),
                    foregroundColor: const Color(0xFF171114),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'PLAY NEXT DUEL',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
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
}

class _DuelHeader extends StatelessWidget {
  const _DuelHeader({
    required this.yourScore,
    required this.rivalScore,
    required this.questionNumber,
  });

  final int yourScore;
  final int rivalScore;
  final int questionNumber;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _HeaderBrand(),
        const Spacer(),
        _ScorePill(
          label: 'YOU',
          value: yourScore,
          accent: const Color(0xFF6EE7FF),
        ),
        const SizedBox(width: 8),
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: .06),
            border: Border.all(color: Colors.white.withValues(alpha: .08)),
          ),
          alignment: Alignment.center,
          child: Text(
            questionNumber.toString(),
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
          ),
        ),
        const SizedBox(width: 8),
        _ScorePill(
          label: 'RIVAL',
          value: rivalScore,
          accent: const Color(0xFFFF79A9),
        ),
      ],
    );
  }
}

class _HeaderBrand extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: const LinearGradient(
              colors: [Color(0xFF71E5FF), Color(0xFFAD73FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: const [
              BoxShadow(color: Color(0x355CD9FF), blurRadius: 20),
            ],
          ),
          child: const Icon(
            Icons.layers_rounded,
            color: Color(0xFF08101D),
            size: 20,
          ),
        ),
        const SizedBox(width: 10),
        const Text(
          'STEAL THE\nQUESTIONS',
          style: TextStyle(
            fontSize: 10,
            height: 0.95,
            letterSpacing: 1.4,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _ScorePill extends StatelessWidget {
  const _ScorePill({
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
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        color: const Color(0x73151E33),
        border: Border.all(color: Colors.white.withValues(alpha: .07)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              letterSpacing: 1.2,
              color: accent,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            value.toString(),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _CardBack extends StatelessWidget {
  const _CardBack({
    required this.category,
    required this.compact,
  });

  final String category;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return _SignatureCardShell(
      child: SizedBox(
        width: compact ? 318 : 390,
        height: compact ? 440 : 500,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const CustomPaint(painter: _CardPatternPainter()),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 74,
                    height: 74,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: .05),
                      border: Border.all(
                        color: const Color(0xFF6FE3FF).withValues(alpha: .55),
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.style_rounded,
                      color: Color(0xFFFFD66B),
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'STEAL THE',
                    style: TextStyle(
                      letterSpacing: 3,
                      fontSize: 12,
                      color: Color(0xFF83E9FF),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Text(
                    'QUESTIONS',
                    style: TextStyle(
                      letterSpacing: 2.2,
                      fontSize: 23,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    category,
                    style: TextStyle(
                      letterSpacing: 2,
                      fontSize: 10,
                      color: Colors.white.withValues(alpha: .4),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const Positioned(left: 24, top: 24, child: _RarityBadge(text: 'EPIC')),
            const Positioned(
              right: 24,
              bottom: 24,
              child: Text(
                'QUESTION CARD',
                style: TextStyle(
                  fontSize: 9,
                  letterSpacing: 1.4,
                  color: Color(0x66FFFFFF),
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

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.question,
    required this.seconds,
    required this.selected,
    required this.locked,
    required this.correctIndex,
    required this.compact,
    required this.onAnswer,
    required this.showResult,
    required this.wasCorrect,
  });

  final _Question question;
  final int seconds;
  final int selected;
  final bool locked;
  final int correctIndex;
  final bool compact;
  final ValueChanged<int> onAnswer;
  final bool showResult;
  final bool wasCorrect;

  @override
  Widget build(BuildContext context) {
    return _SignatureCardShell(
      child: SizedBox(
        width: compact ? 318 : 390,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            compact ? 18 : 24,
            compact ? 18 : 24,
            compact ? 18 : 24,
            compact ? 18 : 22,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const _RarityBadge(text: 'EPIC'),
                  const Spacer(),
                  _TimerBadge(seconds: seconds),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                question.category,
                style: TextStyle(
                  fontSize: 9,
                  letterSpacing: 2.3,
                  color: Colors.white.withValues(alpha: .42),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                question.text,
                style: TextStyle(
                  fontSize: compact ? 21 : 25,
                  height: 1.16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.35,
                ),
              ),
              const SizedBox(height: 20),
              for (int i = 0; i < 3; i++) ...[
                _Choice(
                  label: String.fromCharCode(65 + i),
                  text: question.answers[i],
                  selected: selected == i,
                  correct: correctIndex == i,
                  locked: locked,
                  onTap: () => onAnswer(i),
                ),
                if (i != 2) const SizedBox(height: 9),
              ],
              const SizedBox(height: 15),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: showResult
                    ? Row(
                        key: ValueKey(
                          question.text + wasCorrect.toString(),
                        ),
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            wasCorrect ? Icons.bolt_rounded : Icons.close_rounded,
                            size: 17,
                            color: wasCorrect
                                ? const Color(0xFF5DE5B1)
                                : const Color(0xFFFF6F86),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            wasCorrect ? 'CORRECT' : 'WRONG',
                            style: TextStyle(
                              color: wasCorrect
                                  ? const Color(0xFF5DE5B1)
                                  : const Color(0xFFFF6F86),
                              fontSize: 10,
                              letterSpacing: 1.8,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        'Answer before time runs out',
                        key: const ValueKey('hint'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white.withValues(alpha: .34),
                          fontWeight: FontWeight.w700,
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

class _SignatureCardShell extends StatelessWidget {
  const _SignatureCardShell({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(31),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF405372),
            Color(0xFFB18B52),
            Color(0xFF2E3F5A),
          ],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 48,
            offset: Offset(0, 24),
          ),
          BoxShadow(
            color: Color(0x2637D6FF),
            blurRadius: 40,
            spreadRadius: -10,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(1.2),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF182746),
                  Color(0xFF10182B),
                  Color(0xFF151333),
                ],
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _RarityBadge extends StatelessWidget {
  const _RarityBadge({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x23FFD66C),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x77FFD66C)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFFFFD66B),
          fontSize: 9,
          letterSpacing: 1.6,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _TimerBadge extends StatelessWidget {
  const _TimerBadge({required this.seconds});
  final int seconds;

  @override
  Widget build(BuildContext context) {
    final urgent = seconds <= 5;
    final accent =
        urgent ? const Color(0xFFFF6F86) : const Color(0xFF6FE3FF);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(11),
        color: accent.withValues(alpha: .08),
        border: Border.all(color: accent.withValues(alpha: .45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 15, color: accent),
          const SizedBox(width: 5),
          Text(
            seconds.toString().padLeft(2, '0'),
            style: TextStyle(
              color: accent,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.text,
    required this.selected,
    required this.correct,
    required this.locked,
    required this.onTap,
  });

  final String label;
  final String text;
  final bool selected;
  final bool correct;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final showCorrect = locked && correct;
    final showWrong = locked && selected && !correct;

    Color border = Colors.white.withValues(alpha: .08);
    Color bg = const Color(0x161A263D);
    if (showCorrect) {
      border = const Color(0xFF55DFAB);
      bg = const Color(0x1555DFAB);
    } else if (showWrong) {
      border = const Color(0xFFFF6E82);
      bg = const Color(0x16FF6E82);
    } else if (selected) {
      border = const Color(0xFF76DFFF);
      bg = const Color(0x1576DFFF);
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: locked ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .055),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
              ),
              if (showCorrect)
                const Icon(Icons.check_circle_rounded, size: 19, color: Color(0xFF55DFAB)),
              if (showWrong)
                const Icon(Icons.cancel_rounded, size: 19, color: Color(0xFFFF6E82)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeckRail extends StatelessWidget {
  const _DeckRail({required this.size, required this.active});
  final int size;
  final int active;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          'YOUR DECK',
          style: TextStyle(
            fontSize: 9,
            letterSpacing: 1.7,
            color: Colors.white.withValues(alpha: .36),
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(width: 10),
        for (int i = 0; i < size; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: i == active ? 23 : 18,
            height: i == active ? 31 : 27,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              gradient: LinearGradient(
                colors: i < 7
                    ? const [Color(0xFF4C6D98), Color(0xFF233552)]
                    : const [Color(0xFF252B45), Color(0xFF191C31)],
              ),
              border: Border.all(
                color: i == active
                    ? const Color(0xFF6EE7FF)
                    : Colors.white.withValues(alpha: .06),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              (i + 1).toString(),
              style: TextStyle(
                fontSize: 8,
                color: i == active ? const Color(0xFFB5F4FF) : Colors.white54,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
      ],
    );
  }
}

class _StealHeader extends StatelessWidget {
  const _StealHeader({
    required this.yourScore,
    required this.rivalScore,
  });

  final int yourScore;
  final int rivalScore;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.bolt_rounded, color: Color(0xFFFFD66B), size: 26),
        const SizedBox(width: 8),
        const Text(
          'DUEL COMPLETE',
          style: TextStyle(fontSize: 12, letterSpacing: 2, fontWeight: FontWeight.w900),
        ),
        const Spacer(),
        Text(
          '$yourScore  —  $rivalScore',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}

class _StealTitle extends StatelessWidget {
  const _StealTitle({required this.revealed, required this.wide});
  final bool revealed;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          revealed ? 'CARD CLAIMED' : 'STEAL ONE CARD',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: wide ? 30 : 25,
            fontWeight: FontWeight.w900,
            letterSpacing: -.6,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          revealed
              ? 'The card is moving to your collection.'
              : 'Choose one card from the rival’s ten-card deck.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: .52),
            fontSize: 12,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _StealCard extends StatelessWidget {
  const _StealCard({
    required this.index,
    required this.selected,
    required this.revealed,
    required this.animationValue,
    required this.onTap,
  });

  final int index;
  final bool selected;
  final bool revealed;
  final double animationValue;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lift = selected ? -10.0 * animationValue : 0.0;
    return Transform.translate(
      offset: Offset(0, lift),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 190),
          width: 116,
          height: 155,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(19),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: revealed
                  ? const [Color(0xFF233D4A), Color(0xFF0E1A26)]
                  : const [Color(0xFF293A5D), Color(0xFF151C31)],
            ),
            border: Border.all(
              color: selected
                  ? const Color(0xFFFFD66B)
                  : Colors.white.withValues(alpha: .08),
              width: selected ? 2 : 1,
            ),
            boxShadow: [
              if (selected)
                const BoxShadow(
                  color: Color(0x3856DFFF),
                  blurRadius: 24,
                  spreadRadius: -6,
                ),
            ],
          ),
          child: Center(
            child: revealed
                ? const Icon(
                    Icons.style_rounded,
                    color: Color(0xFFFFD66B),
                    size: 32,
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.help_outline_rounded,
                        color: Color(0xFF75DFFF),
                        size: 28,
                      ),
                      const SizedBox(height: 9),
                      Text(
                        'CARD \${{index + 1}',
                        style: const TextStyle(
                          fontSize: 9,
                          letterSpacing: 1.1,
                          fontWeight: FontWeight.w900,
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _StealConfirm extends StatelessWidget {
  const _StealConfirm({
    required this.cardIndex,
    required this.onDone,
  });

  final int cardIndex;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0xAE101928),
        border: Border.all(color: const Color(0x55FFD66B)),
      ),
      child: Row(
        children: [
          const _MedalIcon(size: 46),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CARD \${{cardIndex + 1}  •  EPIC',
                  style: const TextStyle(
                    color: Color(0xFFFFD66B),
                    fontSize: 10,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'CARD \${{cardIndex + 1} is yours.',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: onDone,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFFD66B),
              foregroundColor: const Color(0xFF171114),
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
            ),
            child: const Text(
              'TAKE IT',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _MedalIcon extends StatelessWidget {
  const _MedalIcon({this.size = 62});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFFFFE89A), Color(0xFFFFB739)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x44FFCF54),
            blurRadius: 24,
            spreadRadius: -3,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.auto_awesome_rounded,
        color: const Color(0xFF322514),
        size: 29,
      ),
    );
  }
}

class _BackgroundGlow extends StatelessWidget {
  const _BackgroundGlow();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -170,
            left: -110,
            child: Container(
              width: 420,
              height: 420,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0x3059D8FF), Color(0x000B1020)],
                ),
              ),
            ),
          ),
          Positioned(
            right: -150,
            bottom: -170,
            child: Container(
              width: 470,
              height: 470,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0x2E9D61FF), Color(0x000B1020)],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardPatternPainter extends CustomPainter {
  const _CardPatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = const Color(0x267DE5FF);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0x18FFFFFF);

    for (double r = 48; r < size.width; r += 54) {
      canvas.drawCircle(center, r, ring);
    }

    for (int i = 0; i < 12; i++) {
      final a = (math.pi * 2 / 12) * i;
      final p1 = center + Offset(math.cos(a), math.sin(a)) * 44;
      final p2 = center + Offset(math.cos(a), math.sin(a)) * size.width;
      canvas.drawLine(p1, p2, line);
    }

    final diamond = Path()
      ..moveTo(center.dx, center.dy - 62)
      ..lineTo(center.dx + 62, center.dy)
      ..lineTo(center.dx, center.dy + 62)
      ..lineTo(center.dx - 62, center.dy)
      ..close();
    canvas.drawPath(diamond, ring);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
