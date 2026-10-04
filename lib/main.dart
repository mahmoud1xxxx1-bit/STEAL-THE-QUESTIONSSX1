import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const StealTheQuestionsApp());

class StealTheQuestionsApp extends StatelessWidget {
  const StealTheQuestionsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'STEAL THE QUESTIONS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF070B13),
        useMaterial3: true,
      ),
      home: const DuelPrototypePage(),
    );
  }
}

class DuelPrototypePage extends StatefulWidget {
  const DuelPrototypePage({super.key});
  @override
  State<DuelPrototypePage> createState() => _DuelPrototypePageState();
}

class _DuelPrototypePageState extends State<DuelPrototypePage> {
  static const questions = <Map<String, dynamic>>[
    {'q': 'Which planet is known as the Red Planet?', 'a': ['Mars', 'Venus', 'Jupiter'], 'c': 0},
    {'q': 'What is the largest ocean on Earth?', 'a': ['Atlantic', 'Pacific', 'Indian'], 'c': 1},
    {'q': 'How many continents are there?', 'a': ['5', '6', '7'], 'c': 2},
  ];

  Timer? _timer;
  int _index = 0;
  int _seconds = 6;
  int _score = 0;
  int _selected = -1;
  bool _locked = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _seconds = 6);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_locked || _finished) return;
      if (_seconds <= 1) {
        timer.cancel();
        _answer(-1);
      } else {
        setState(() => _seconds -= 1);
      }
    });
  }

  Future<void> _answer(int choice) async {
    if (_locked || _finished) return;
    _timer?.cancel();
    await HapticFeedback.selectionClick();
    final correct = choice == questions[_index]['c'];
    setState(() {
      _selected = choice;
      _locked = true;
      if (correct) _score += 1;
    });
    await Future<void>.delayed(const Duration(milliseconds: 850));
    if (!mounted) return;
    if (_index == questions.length - 1) {
      setState(() => _finished = true);
    } else {
      setState(() {
        _index += 1;
        _selected = -1;
        _locked = false;
      });
      _startTimer();
    }
  }

  void _restart() {
    setState(() {
      _index = 0;
      _seconds = 6;
      _score = 0;
      _selected = -1;
      _locked = false;
      _finished = false;
    });
    _startTimer();
  }

  @override
  Widget build(BuildContext context) {
    final q = questions[_index];
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            const _Atmosphere(),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  _TopBar(score: _score, index: _index, total: questions.length),
                  const SizedBox(height: 20),
                  Expanded(
                    child: _finished
                        ? _Finish(score: _score, total: questions.length, onRestart: _restart)
                        : Column(
                            children: [
                              const _OpponentRow(),
                              const SizedBox(height: 16),
                              Expanded(
                                child: Center(
                                  child: _QuestionCard(
                                    number: _index + 1,
                                    question: q['q'] as String,
                                    answers: List<String>.from(q['a'] as List),
                                    correctIndex: q['c'] as int,
                                    selected: _selected,
                                    locked: _locked,
                                    seconds: _seconds,
                                    onAnswer: _answer,
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
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.score, required this.index, required this.total});
  final int score;
  final int index;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: const LinearGradient(
                  colors: [Color(0xFF6BD8FF), Color(0xFFA76BFF)],
                ),
              ),
              child: const Icon(Icons.style_rounded, color: Color(0xFF07101A), size: 19),
            ),
            const SizedBox(width: 10),
            const Text(
              'STEAL THE QUESTIONS',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.4),
            ),
          ],
        ),
        const Spacer(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('DUEL', style: TextStyle(color: Colors.white.withValues(alpha: .45), letterSpacing: 2)),
            Text(
              (index + 1).toString() + '/' + total.toString() + '  •  ' + score.toString(),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ],
    );
  }
}

class _OpponentRow extends StatelessWidget {
  const _OpponentRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        _PlayerChip(name: 'YOU', score: '0', active: true),
        Spacer(),
        Text('6 SEC', style: TextStyle(fontSize: 10, letterSpacing: 1.8, fontWeight: FontWeight.w900)),
        Spacer(),
        _PlayerChip(name: 'RIVAL', score: '0', active: false),
      ],
    );
  }
}

class _PlayerChip extends StatelessWidget {
  const _PlayerChip({required this.name, required this.score, required this.active});
  final String name;
  final String score;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (!active) ...[const _Avatar(active: false), const SizedBox(width: 7)],
        Column(
          crossAxisAlignment: active ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          children: [
            Text(name, style: TextStyle(fontSize: 9, letterSpacing: 1.4, color: Colors.white.withValues(alpha: .48), fontWeight: FontWeight.w800)),
            Text(score, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          ],
        ),
        if (active) ...[const SizedBox(width: 7), const _Avatar(active: true)],
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
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF121A2A),
        border: Border.all(
          color: active ? const Color(0xFF72D7FF) : Colors.white.withValues(alpha: .1),
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        active ? 'Y' : 'R',
        style: TextStyle(fontWeight: FontWeight.w900, color: active ? const Color(0xFF72D7FF) : Colors.white70),
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.number,
    required this.question,
    required this.answers,
    required this.correctIndex,
    required this.selected,
    required this.locked,
    required this.seconds,
    required this.onAnswer,
  });

  final int number;
  final String question;
  final List<String> answers;
  final int correctIndex;
  final int selected;
  final bool locked;
  final int seconds;
  final ValueChanged<int> onAnswer;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 540, maxHeight: 650),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF101625),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white.withValues(alpha: .09)),
          boxShadow: const [
            BoxShadow(color: Color(0x99000000), blurRadius: 42, offset: Offset(0, 20)),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF182338),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '#' + number.toString().padLeft(2, '0'),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: 58,
                  height: 58,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: seconds / 6,
                        strokeWidth: 5,
                        backgroundColor: Colors.white.withValues(alpha: .05),
                        valueColor: AlwaysStoppedAnimation(
                          seconds <= 2 ? const Color(0xFFFF6D78) : const Color(0xFF6BD8FF),
                        ),
                      ),
                      Center(
                        child: Text(seconds.toString(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Spacer(),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('QUESTION', style: TextStyle(fontSize: 10, letterSpacing: 2.5, color: Colors.white.withValues(alpha: .4), fontWeight: FontWeight.w900)),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(question, style: const TextStyle(fontSize: 27, height: 1.15, fontWeight: FontWeight.w900)),
            ),
            const Spacer(),
            for (int i = 0; i < answers.length; i++) ...[
              _AnswerButton(
                index: i,
                text: answers[i],
                correct: correctIndex == i,
                selected: selected == i,
                locked: locked,
                onTap: () => onAnswer(i),
              ),
              if (i < answers.length - 1) const SizedBox(height: 10),
            ],
            const SizedBox(height: 14),
            Text(
              locked
                  ? (selected == correctIndex ? 'CORRECT' : (selected == -1 ? 'TIME' : 'WRONG'))
                  : 'Choose before the card closes.',
              style: TextStyle(
                color: locked && selected == correctIndex
                    ? const Color(0xFF53E3AE)
                    : Colors.white.withValues(alpha: .4),
                fontWeight: FontWeight.w900,
                letterSpacing: 1.7,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnswerButton extends StatelessWidget {
  const _AnswerButton({
    required this.index,
    required this.text,
    required this.correct,
    required this.selected,
    required this.locked,
    required this.onTap,
  });

  final int index;
  final String text;
  final bool correct;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Color border = Colors.white.withValues(alpha: .09);
    Color bg = const Color(0xFF141D2F);
    if (locked && correct) {
      border = const Color(0xFF53E3AE);
      bg = const Color(0x1524C890);
    } else if (locked && selected) {
      border = const Color(0xFFFF6D78);
      bg = const Color(0x18FF5968);
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: locked ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border, width: 1.2),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .05),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(String.fromCharCode(65 + index), style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
              const SizedBox(width: 11),
              Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800))),
              if (locked && correct) const Icon(Icons.check_circle_rounded, size: 20, color: Color(0xFF53E3AE)),
              if (locked && selected && !correct) const Icon(Icons.cancel_rounded, size: 20, color: Color(0xFFFF6D78)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Finish extends StatelessWidget {
  const _Finish({required this.score, required this.total, required this.onRestart});
  final int score;
  final int total;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: const Color(0xFF101625),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white.withValues(alpha: .09)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.workspace_premium_rounded, size: 52, color: Color(0xFF6BD8FF)),
            const SizedBox(height: 16),
            const Text('ROUND COMPLETE', style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.w900, fontSize: 12)),
            const SizedBox(height: 8),
            Text(score.toString() + ' / ' + total.toString(), style: const TextStyle(fontSize: 54, fontWeight: FontWeight.w900)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onRestart,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF6BD8FF),
                  foregroundColor: const Color(0xFF06101A),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: const Text('PLAY AGAIN', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Atmosphere extends StatelessWidget {
  const _Atmosphere();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -130,
            left: -90,
            child: Container(
              width: 320,
              height: 320,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0x284A9DFF), Color(0x00070B13)],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -150,
            right: -110,
            child: Container(
              width: 360,
              height: 360,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0x1F9968FF), Color(0x00070B13)],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
