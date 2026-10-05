import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'football_design_app.dart';
import 'final_design_app_v2.dart';
import 'game/game_rules.dart';
import 'game/question_bank.dart';
import 'product_app.dart';

class FootballDesignAppV2 extends StatefulWidget {
  const FootballDesignAppV2({super.key});

  @override
  State<FootballDesignAppV2> createState() => _FootballDesignAppV2State();
}

class _FootballDesignAppV2State extends State<FootballDesignAppV2> {
  final DemoPlayerState player = DemoPlayerState();
  final SharedPreferencesAsync prefs = SharedPreferencesAsync();
  final Map<String, List<String>> savedChoices = <String, List<String>>{};
  int tab = 0;
  bool arabic = true;

  @override
  void initState() {
    super.initState();
    player.initialize();
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  void push(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: player,
      builder: (_, __) {
        if (player.loading) {
          return const Scaffold(backgroundColor: page, body: Center(child: CircularProgressIndicator()));
        }

        final screens = <Widget>[
          FootballHomeScreen(arabic: arabic, player: player, openTab: (value) => setState(() => tab = value), push: push),
          FootballCardsManagerScreen(arabic: arabic, player: player, prefs: prefs, savedChoices: savedChoices),
          FootballDecksScreen(arabic: arabic, player: player, push: push),
          PlayScreen(arabic: arabic, player: player, push: push),
          FootballMoreScreen(arabic: arabic, player: player, push: push),
        ];

        return Directionality(
          textDirection: arabic ? TextDirection.rtl : TextDirection.ltr,
          child: Scaffold(
            backgroundColor: page,
            appBar: AppBar(
              automaticallyImplyLeading: false,
              toolbarHeight: 66,
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              title: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: maxW),
                  child: Row(children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [blue, purple])),
                      child: const Icon(Icons.sports_soccer_rounded, color: Colors.white),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        Text('STEAL THE QUESTIONS', style: TextStyle(color: ink, fontSize: 14, fontWeight: FontWeight.w900)),
                        Text('FOOTBALL EDITION', style: TextStyle(color: green, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1.1)),
                      ]),
                    ),
                    AppPill(text: '${player.ownedCount}/$kTotalCards', color: const Color(0xFFE0A000), bg: const Color(0xFFFFF4CE), icon: Icons.style_rounded),
                    const SizedBox(width: 4),
                    IconButton(onPressed: () => setState(() => arabic = !arabic), icon: Text(arabic ? 'EN' : 'ع', style: const TextStyle(color: blue, fontWeight: FontWeight.w900))),
                  ]),
                ),
              ),
            ),
            body: Stack(children: [
              const Positioned.fill(child: IgnorePointer(child: FootballBackdrop())),
              IndexedStack(index: tab, children: screens),
            ]),
            bottomNavigationBar: NavigationBar(
              selectedIndex: tab,
              onDestinationSelected: (value) => setState(() => tab = value),
              backgroundColor: Colors.white,
              indicatorColor: const Color(0xFFEAEFFF),
              height: 68,
              destinations: [
                NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home_rounded, color: blue), label: arabic ? 'الرئيسية' : 'Home'),
                NavigationDestination(icon: const Icon(Icons.style_outlined), selectedIcon: const Icon(Icons.style_rounded, color: purple), label: arabic ? 'بطاقاتي' : 'My cards'),
                NavigationDestination(icon: const Icon(Icons.layers_outlined), selectedIcon: const Icon(Icons.layers_rounded, color: Color(0xFFE0A000)), label: arabic ? 'المجموعات' : 'Decks'),
                NavigationDestination(icon: const Icon(Icons.sports_soccer), selectedIcon: const Icon(Icons.sports_soccer_rounded, color: coral), label: arabic ? 'اللعب' : 'Play'),
                NavigationDestination(icon: const Icon(Icons.more_horiz_rounded), selectedIcon: const Icon(Icons.more_horiz_rounded, color: blue), label: arabic ? 'المزيد' : 'More'),
              ],
            ),
          ),
        );
      },
    );
  }
}

class FootballCardsManagerScreen extends StatelessWidget {
  const FootballCardsManagerScreen({
    super.key,
    required this.arabic,
    required this.player,
    required this.prefs,
    required this.savedChoices,
  });

  final bool arabic;
  final DemoPlayerState player;
  final SharedPreferencesAsync prefs;
  final Map<String, List<String>> savedChoices;

  String choiceKey(String cardId) => 'stq_football_choices_${arabic ? 'ar' : 'en'}_$cardId';

  Future<List<String>> choicesFor(QuestionContent q) async {
    final base = List<String>.from(arabic ? q.answersAr : q.answersEn);
    final key = choiceKey(q.id);
    final stored = savedChoices[key] ?? await prefs.getStringList(key);
    final needed = player.weeklyPass ? 4 : 3;
    final values = List<String>.from(stored ?? <String>[...base, if (player.weeklyPass) (arabic ? q.passExtraAr : q.passExtraEn)]);
    while (values.length < needed) values.add(arabic ? 'خيار جديد' : 'New choice');
    if (values.length > needed) values.removeRange(needed, values.length);
    values[q.correctIndex] = base[q.correctIndex];
    savedChoices[key] = List<String>.from(values);
    return values;
  }

  @override
  Widget build(BuildContext context) {
    final owned = QuestionBank.all.where((q) => player.ownedCards.contains(q.id)).toList(growable: false);
    final locked = QuestionBank.all.where((q) => !player.ownedCards.contains(q.id)).toList(growable: false);

    return AppScroll(children: [
      const FootballSectionTag(),
      const SizedBox(height: 8),
      AppHeading(
        arabic ? 'بطاقاتي وأسئلتي' : 'My cards & questions',
        arabic ? 'كل بطاقة تملكها تعرض السؤال والإجابة الصحيحة وخياراتك هنا مباشرة.' : 'Every owned card shows its question, correct answer and your choices directly here.',
      ),
      const SizedBox(height: 12),
      AppPanel(
        child: Wrap(spacing: 34, runSpacing: 14, alignment: WrapAlignment.spaceAround, children: [
          CountStat('${owned.length}', arabic ? 'مملوكة' : 'Owned', blue),
          CountStat('${locked.length}', arabic ? 'غير مملوكة' : 'Locked', muted),
          CountStat('$kTotalCards', arabic ? 'الإجمالي' : 'Total', const Color(0xFFE0A000)),
        ]),
      ),
      const SizedBox(height: 18),
      TitleRow(arabic ? 'بطاقاتي' : 'My cards', '${owned.length}'),
      const SizedBox(height: 8),
      if (owned.isEmpty)
        AppPanel(child: Row(children: [
          const Icon(Icons.sports_soccer_rounded, color: blue),
          const SizedBox(width: 10),
          Expanded(child: Text(arabic ? 'لا تملك بطاقات بعد. العب ضد البوت لتحصل على أول بطاقة.' : 'You do not own cards yet. Play the bot to earn your first card.')),
        ]))
      else
        ...owned.map((q) => Padding(padding: const EdgeInsets.only(bottom: 10), child: ownedCard(context, q))),
      const SizedBox(height: 18),
      TitleRow(arabic ? 'بطاقات لم تحصل عليها بعد' : 'Cards not earned yet', '${locked.length}'),
      const SizedBox(height: 6),
      Text(arabic ? 'هذه البطاقات تبقى مقفلة ولا تعرض السؤال قبل امتلاكها.' : 'These cards stay locked and hide the question until you own them.', style: const TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      FootballCardGrid(cards: locked, enabled: false, selected: const {}, onTap: (_) {}),
    ]);
  }

  Widget ownedCard(BuildContext context, QuestionContent q) {
    final base = arabic ? q.answersAr : q.answersEn;
    return AppPanel(
      child: FutureBuilder<List<String>>(
        future: choicesFor(q),
        builder: (context, snap) {
          final choices = snap.data ?? List<String>.from(base);
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              FootballCardBadge(q: q),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${q.id} · ${rarityName(q.rarity)}', style: const TextStyle(color: muted, fontSize: 10, fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text(arabic ? q.questionAr : q.questionEn, style: const TextStyle(color: ink, fontSize: 16, height: 1.35, fontWeight: FontWeight.w900)),
              ])),
            ]),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFEAF9F2), borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                const Icon(Icons.check_circle_rounded, color: green, size: 19),
                const SizedBox(width: 7),
                Expanded(child: Text('${arabic ? 'الإجابة الصحيحة' : 'Correct'}: ${base[q.correctIndex]}', style: const TextStyle(color: ink, fontWeight: FontWeight.w900))),
              ]),
            ),
            const SizedBox(height: 8),
            Text(arabic ? 'خيارات اللاعب:' : 'Player choices:', style: const TextStyle(color: muted, fontSize: 10, fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: List.generate(choices.length, (i) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                decoration: BoxDecoration(
                  color: i == q.correctIndex ? const Color(0xFFEAF9F2) : const Color(0xFFF3F6FB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: i == q.correctIndex ? const Color(0xFFBCE7D2) : line),
                ),
                child: Text(choices[i], style: TextStyle(color: i == q.correctIndex ? green : ink, fontSize: 11, fontWeight: FontWeight.w800)),
              )),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: () => editChoices(context, q),
              icon: const Icon(Icons.edit_rounded),
              label: Text(player.weeklyPass
                  ? (arabic ? 'تعديل 3 خيارات خاطئة' : 'Edit 3 wrong choices')
                  : (arabic ? 'تعديل الخيارين الخاطئين' : 'Edit 2 wrong choices')),
            ),
          ]);
        },
      ),
    );
  }

  Future<void> editChoices(BuildContext context, QuestionContent q) async {
    final base = List<String>.from(arabic ? q.answersAr : q.answersEn);
    final key = choiceKey(q.id);
    final values = await choicesFor(q);
    final ctrls = values.map((v) => TextEditingController(text: v)).toList(growable: false);
    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: arabic ? TextDirection.rtl : TextDirection.ltr,
        child: AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          title: Text(arabic ? 'تعديل خيارات ${q.id}' : 'Edit ${q.id} choices', style: const TextStyle(color: ink, fontWeight: FontWeight.w900)),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(arabic ? q.questionAr : q.questionEn, style: const TextStyle(color: ink, fontSize: 17, height: 1.4, fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                ...List.generate(ctrls.length, (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TextField(
                    controller: ctrls[i],
                    readOnly: i == q.correctIndex,
                    decoration: InputDecoration(
                      labelText: i == q.correctIndex ? (arabic ? 'الإجابة الصحيحة — ثابتة' : 'Correct answer — fixed') : (arabic ? 'خيار خاطئ — قابل للتعديل' : 'Wrong choice — editable'),
                      prefixIcon: Icon(i == q.correctIndex ? Icons.check_rounded : Icons.edit_rounded, color: i == q.correctIndex ? green : blue),
                      filled: true,
                      fillColor: i == q.correctIndex ? const Color(0xFFEAF9F2) : const Color(0xFFF6F8FC),
                    ),
                  ),
                )),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(arabic ? 'إلغاء' : 'Cancel')),
            FilledButton(
              onPressed: () async {
                final next = ctrls.map((c) => c.text.trim()).toList(growable: false);
                next[q.correctIndex] = base[q.correctIndex];
                final normalized = next.map((v) => v.toLowerCase()).toList(growable: false);
                if (next.any((v) => v.isEmpty) || normalized.toSet().length != normalized.length) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(arabic ? 'كل الخيارات مطلوبة ويجب أن تكون مختلفة.' : 'All choices are required and must be different.')));
                  return;
                }
                savedChoices[key] = List<String>.from(next);
                await prefs.setStringList(key, next);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  (context as Element).markNeedsBuild();
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(arabic ? 'تم حفظ خيارات البطاقة.' : 'Card choices saved.')));
                }
              },
              child: Text(arabic ? 'حفظ' : 'Save'),
            ),
          ],
        ),
      ),
    );

    for (final c in ctrls) {
      c.dispose();
    }
  }
}
