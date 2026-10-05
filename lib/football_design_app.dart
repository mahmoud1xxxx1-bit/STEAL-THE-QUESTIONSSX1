import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'final_design_app_v2.dart';
import 'game/game_rules.dart';
import 'game/question_bank.dart';
import 'product_app.dart';

class FootballDesignApp extends StatefulWidget {
  const FootballDesignApp({super.key});

  @override
  State<FootballDesignApp> createState() => _FootballDesignAppState();
}

class _FootballDesignAppState extends State<FootballDesignApp> {
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
          FootballHomeScreen(
            arabic: arabic,
            player: player,
            openTab: (value) => setState(() => tab = value),
            push: push,
          ),
          FootballCollectionScreen(
            arabic: arabic,
            player: player,
            prefs: prefs,
            savedChoices: savedChoices,
          ),
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
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(colors: [blue, purple]),
                        ),
                        child: const Icon(Icons.sports_soccer_rounded, color: Colors.white),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('STEAL THE QUESTIONS', style: TextStyle(color: ink, fontSize: 14, fontWeight: FontWeight.w900)),
                            Text('FOOTBALL EDITION', style: TextStyle(color: green, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1.1)),
                          ],
                        ),
                      ),
                      AppPill(
                        text: '${player.ownedCount}/$kTotalCards',
                        color: const Color(0xFFE0A000),
                        bg: const Color(0xFFFFF4CE),
                        icon: Icons.style_rounded,
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        onPressed: () => setState(() => arabic = !arabic),
                        icon: Text(arabic ? 'EN' : 'ع', style: const TextStyle(color: blue, fontWeight: FontWeight.w900)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            body: Stack(
              children: [
                const Positioned.fill(child: IgnorePointer(child: FootballBackdrop())),
                IndexedStack(index: tab, children: screens),
              ],
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: tab,
              onDestinationSelected: (value) => setState(() => tab = value),
              backgroundColor: Colors.white,
              indicatorColor: const Color(0xFFEAEFFF),
              height: 68,
              destinations: [
                NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home_rounded, color: blue), label: arabic ? 'الرئيسية' : 'Home'),
                NavigationDestination(icon: const Icon(Icons.style_outlined), selectedIcon: const Icon(Icons.style_rounded, color: purple), label: arabic ? 'البطاقات' : 'Cards'),
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

class FootballHomeScreen extends StatelessWidget {
  const FootballHomeScreen({
    super.key,
    required this.arabic,
    required this.player,
    required this.openTab,
    required this.push,
  });

  final bool arabic;
  final DemoPlayerState player;
  final ValueChanged<int> openTab;
  final ValueChanged<Widget> push;

  @override
  Widget build(BuildContext context) {
    final deckCount = player.decks[player.activeDeck].length;
    return AppScroll(
      children: [
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: const LinearGradient(colors: [Color(0xFF4D8CFF), Color(0xFF8057F4)]),
            boxShadow: const [BoxShadow(color: Color(0x224C72FF), blurRadius: 18, offset: Offset(0, 8))],
          ),
          child: Stack(
            children: [
              const Positioned.fill(child: CustomPaint(painter: FootballHeroPainter())),
              PositionedDirectional(
                end: -22,
                top: -18,
                child: Icon(Icons.sports_soccer_rounded, size: 150, color: Colors.white.withValues(alpha: .11)),
              ),
              Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: .16), borderRadius: BorderRadius.circular(999)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.sports_soccer_rounded, color: Colors.white, size: 15),
                          const SizedBox(width: 6),
                          Text(arabic ? 'نسخة كرة القدم' : 'FOOTBALL EDITION', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      arabic ? 'جاوب، اجمع، نافس... واسرق بطاقة!' : 'Answer, collect, compete... and steal a card!',
                      style: const TextStyle(color: Colors.white, fontSize: 28, height: 1.15, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      arabic ? 'ملعبك هو المعرفة: اجمع بطاقات كرة القدم، جهّز Deck، وادخل المواجهة.' : 'Knowledge is your pitch: collect football cards, prepare a deck, and enter the duel.',
                      style: TextStyle(color: Colors.white.withValues(alpha: .9), fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => openTab(3),
                      style: FilledButton.styleFrom(backgroundColor: gold, foregroundColor: ink),
                      icon: const Icon(Icons.sports_soccer_rounded),
                      label: Text(arabic ? 'ابدأ المباراة' : 'START MATCH'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        ResponsiveTwo(
          a: ActionTile(
            icon: Icons.sports_soccer_rounded,
            color: blue,
            title: arabic ? 'تدريب ضد البوت' : 'Bot training',
            text: arabic ? 'اجمع البطاقات الأولى.' : 'Build your first cards.',
            onTap: () => push(BotPage(arabic: arabic, player: player)),
          ),
          b: ActionTile(
            icon: Icons.emoji_events_rounded,
            color: coral,
            title: arabic ? 'مواجهة لاعب' : 'PvP match',
            text: player.pvpUnlocked
                ? (arabic ? 'نافس واسرق بطاقة.' : 'Compete and steal a card.')
                : (arabic ? 'يفتح عند 10 بطاقات.' : 'Unlocks at 10 cards.'),
            onTap: () => openTab(3),
          ),
        ),
        const SizedBox(height: 14),
        AppPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.sports_score_rounded, color: green),
                  const SizedBox(width: 8),
                  Expanded(child: TitleRow(arabic ? 'تقدم المجموعة' : 'Collection progress', '${player.ownedCount}/$kTotalCards')),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(value: player.ownedCount / kTotalCards, minHeight: 9, backgroundColor: const Color(0xFFE4EAF4)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        AppPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TitleRow(arabic ? 'تشكيلتك النشطة' : 'Active lineup', '$deckCount/$kDeckSize'),
              const SizedBox(height: 10),
              SizedBox(
                height: 54,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: 10,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (_, i) => MiniCard(id: i < deckCount ? player.decks[player.activeDeck][i] : null),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => openTab(2),
                icon: const Icon(Icons.tune_rounded),
                label: Text(arabic ? 'إدارة الـDecks' : 'Manage decks'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class FootballCollectionScreen extends StatelessWidget {
  const FootballCollectionScreen({
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

  @override
  Widget build(BuildContext context) {
    final owned = QuestionBank.all.where((q) => player.ownedCards.contains(q.id)).toList(growable: false);
    final locked = QuestionBank.all.where((q) => !player.ownedCards.contains(q.id)).toList(growable: false);
    return AppScroll(
      children: [
        const FootballSectionTag(),
        const SizedBox(height: 8),
        AppHeading(
          arabic ? 'بطاقاتك' : 'Your cards',
          arabic ? 'افتح البطاقة لتعديل الخيارات الخاطئة. الإجابة الصحيحة تبقى ثابتة.' : 'Open a card to edit its wrong choices. The correct answer stays fixed.',
        ),
        const SizedBox(height: 12),
        AppPanel(
          child: Wrap(
            spacing: 34,
            runSpacing: 14,
            alignment: WrapAlignment.spaceAround,
            children: [
              CountStat('${owned.length}', arabic ? 'مملوكة' : 'Owned', blue),
              CountStat('${locked.length}', arabic ? 'غير مملوكة' : 'Locked', muted),
              CountStat('$kTotalCards', arabic ? 'الإجمالي' : 'Total', const Color(0xFFE0A000)),
            ],
          ),
        ),
        const SizedBox(height: 18),
        TitleRow(arabic ? 'البطاقات المملوكة' : 'Owned cards', '${owned.length}'),
        const SizedBox(height: 8),
        if (owned.isEmpty)
          AppPanel(
            child: Row(
              children: [
                const Icon(Icons.sports_soccer_rounded, color: blue),
                const SizedBox(width: 10),
                Expanded(child: Text(arabic ? 'ابدأ ضد البوت لتحصل على أول بطاقة.' : 'Play the bot to earn your first card.')),
              ],
            ),
          )
        else
          FootballCardGrid(cards: owned, enabled: true, selected: const {}, onTap: (q) => showCard(context, q)),
        const SizedBox(height: 24),
        TitleRow(arabic ? 'لم تحصل عليها بعد' : 'Not earned yet', '${locked.length}'),
        const SizedBox(height: 8),
        FootballCardGrid(cards: locked, enabled: false, selected: const {}, onTap: (_) {}),
      ],
    );
  }

  Future<void> showCard(BuildContext context, QuestionContent q) async {
    final base = List<String>.from(arabic ? q.answersAr : q.answersEn);
    final key = choiceKey(q.id);
    final stored = savedChoices[key] ?? await prefs.getStringList(key);
    final needed = player.weeklyPass ? 4 : 3;
    final values = List<String>.from(
      stored ?? <String>[...base, if (player.weeklyPass) (arabic ? q.passExtraAr : q.passExtraEn)],
    );
    while (values.length < needed) {
      values.add(arabic ? 'خيار جديد' : 'New choice');
    }
    if (values.length > needed) values.removeRange(needed, values.length);
    values[q.correctIndex] = base[q.correctIndex];
    final ctrls = values.map((value) => TextEditingController(text: value)).toList(growable: false);
    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: arabic ? TextDirection.rtl : TextDirection.ltr,
        child: AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          title: Row(
            children: [
              FootballCardBadge(q: q),
              const SizedBox(width: 10),
              Expanded(child: Text('${q.id} · ${rarityName(q.rarity)}', style: const TextStyle(color: ink, fontWeight: FontWeight.w900))),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(arabic ? q.questionAr : q.questionEn, style: const TextStyle(color: ink, fontSize: 18, height: 1.45, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFFEAF9F2), borderRadius: BorderRadius.circular(14)),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: green),
                        const SizedBox(width: 8),
                        Expanded(child: Text(base[q.correctIndex], style: const TextStyle(color: ink, fontWeight: FontWeight.w900))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    player.weeklyPass
                        ? (arabic ? '4 خيارات — تستطيع تغيير 3 خيارات خاطئة' : '4 choices — edit 3 wrong choices')
                        : (arabic ? '3 خيارات — تستطيع تغيير خيارين خاطئين' : '3 choices — edit 2 wrong choices'),
                    style: const TextStyle(color: ink, fontSize: 15, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 9),
                  ...List.generate(
                    ctrls.length,
                    (i) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TextField(
                        controller: ctrls[i],
                        readOnly: i == q.correctIndex,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: i == q.correctIndex ? const Color(0xFFEAF9F2) : const Color(0xFFF6F8FC),
                          prefixIcon: Icon(i == q.correctIndex ? Icons.check_rounded : Icons.edit_rounded, color: i == q.correctIndex ? green : blue),
                          labelText: i == q.correctIndex
                              ? (arabic ? 'الإجابة الصحيحة' : 'Correct answer')
                              : '${arabic ? 'خيار خاطئ' : 'Wrong choice'} ${i + 1}${i == 3 ? ' · Monthly Pass' : ''}',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                  ),
                  if (!player.weeklyPass)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: const Color(0xFFFFF5D5), borderRadius: BorderRadius.circular(12)),
                      child: Text(
                        arabic ? 'Monthly Pass يضيف خيارًا رابعًا ويتيح تعديل 3 خيارات خاطئة.' : 'Monthly Pass adds a fourth choice and lets you edit 3 wrong choices.',
                        style: const TextStyle(color: ink, fontSize: 10, fontWeight: FontWeight.w800),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(arabic ? 'إلغاء' : 'Cancel')),
            FilledButton(
              onPressed: () async {
                final next = ctrls.map((controller) => controller.text.trim()).toList(growable: false);
                next[q.correctIndex] = base[q.correctIndex];
                final normalized = next.map((value) => value.toLowerCase()).toList(growable: false);
                if (next.any((value) => value.isEmpty) || normalized.toSet().length != normalized.length) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text(arabic ? 'كل الخيارات مطلوبة ويجب أن تكون مختلفة.' : 'All choices are required and must be different.')),
                  );
                  return;
                }
                savedChoices[key] = List<String>.from(next);
                await prefs.setStringList(key, next);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(arabic ? 'تم حفظ خيارات البطاقة.' : 'Card choices saved.')),
                  );
                }
              },
              child: Text(arabic ? 'حفظ الخيارات' : 'Save choices'),
            ),
          ],
        ),
      ),
    );

    for (final controller in ctrls) {
      controller.dispose();
    }
  }
}

class FootballDecksScreen extends StatelessWidget {
  const FootballDecksScreen({super.key, required this.arabic, required this.player, required this.push});

  final bool arabic;
  final DemoPlayerState player;
  final ValueChanged<Widget> push;

  @override
  Widget build(BuildContext context) {
    return AppScroll(
      children: [
        const FootballSectionTag(),
        const SizedBox(height: 8),
        AppHeading(
          arabic ? 'مجموعات اللعب' : 'Decks',
          arabic ? 'المجاني يملك 2 Decks، والمشترك يملك 5.' : 'Free players have 2 decks; subscribers have 5.',
        ),
        const SizedBox(height: 14),
        ...List.generate(kMaxDeckSlots, (i) {
          final unlocked = i < player.deckSlots;
          final active = i == player.activeDeck;
          final count = player.decks[i].length;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppPanel(
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: unlocked ? const Color(0xFFE7F8EE) : const Color(0xFFF0F2F6),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(unlocked ? Icons.sports_soccer_rounded : Icons.lock_rounded, color: unlocked ? green : muted),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${arabic ? 'المجموعة' : 'Deck'} ${i + 1}', style: const TextStyle(color: ink, fontSize: 15, fontWeight: FontWeight.w900)),
                            Text(
                              unlocked ? '$count/$kDeckSize${active ? ' · ACTIVE' : ''}' : 'Monthly Pass',
                              style: const TextStyle(color: muted, fontSize: 10, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                      if (unlocked)
                        OutlinedButton(
                          onPressed: () => player.setActiveDeck(i),
                          child: Text(active ? (arabic ? 'مختارة' : 'Selected') : (arabic ? 'اختيار' : 'Select')),
                        )
                      else
                        const Icon(Icons.workspace_premium_rounded, color: Color(0xFFE0A000)),
                    ],
                  ),
                  if (unlocked) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: FilledButton.icon(
                        onPressed: () => push(DeckBuilderPage(arabic: arabic, player: player, deckIndex: i)),
                        icon: const Icon(Icons.edit_rounded),
                        label: Text(arabic ? 'تعديل البطاقات' : 'Edit cards'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class FootballMoreScreen extends StatelessWidget {
  const FootballMoreScreen({super.key, required this.arabic, required this.player, required this.push});

  final bool arabic;
  final DemoPlayerState player;
  final ValueChanged<Widget> push;

  @override
  Widget build(BuildContext context) {
    return AppScroll(
      children: [
        const FootballSectionTag(),
        const SizedBox(height: 8),
        AppHeading(arabic ? 'المزيد' : 'More', arabic ? 'الحساب، الترتيب، الاشتراك، وطريقة اللعب.' : 'Account, ranking, subscription, and game guide.'),
        const SizedBox(height: 14),
        AppPanel(
          child: Column(
            children: [
              MenuRow(
                icon: Icons.person_rounded,
                title: arabic ? 'الحساب' : 'Account',
                subtitle: player.authenticated ? player.accountLabel : (arabic ? 'غير مسجل' : 'Not signed in'),
                onTap: () => push(AuthPage(arabic: arabic, player: player)),
              ),
              const Divider(height: 22),
              MenuRow(
                icon: Icons.emoji_events_rounded,
                title: arabic ? 'التصنيف' : 'Ranking',
                subtitle: arabic ? 'المنافسة والترتيب' : 'Competition and ranking',
                onTap: () => push(RankingPage(arabic: arabic, player: player)),
              ),
              const Divider(height: 22),
              MenuRow(
                icon: Icons.workspace_premium_rounded,
                title: r'Monthly Pass · $10',
                subtitle: arabic ? '5 Decks + 4 خيارات + تعديل 3 خيارات خاطئة' : '5 decks + 4 choices + edit 3 wrong choices',
                onTap: () => push(FootballMonthlyPassPage(arabic: arabic, player: player)),
              ),
              const Divider(height: 22),
              MenuRow(
                icon: Icons.help_outline_rounded,
                title: arabic ? 'كيف تعمل اللعبة؟' : 'How it works',
                subtitle: arabic ? 'المسار الكامل في أقل من دقيقة' : 'The full loop in under a minute',
                onTap: () => push(HowPage(arabic: arabic)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class FootballMonthlyPassPage extends StatelessWidget {
  const FootballMonthlyPassPage({super.key, required this.arabic, required this.player});

  final bool arabic;
  final DemoPlayerState player;

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Monthly Pass',
      arabic: arabic,
      child: AppBody(
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFFFD55C), Color(0xFFFFA94D)]),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 44),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: .22), borderRadius: BorderRadius.circular(999)),
                      child: const Text(r'$10 / MONTH', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  arabic ? 'اشتراك شهري بسيط وواضح' : 'A simple monthly upgrade',
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Text(
                  player.weeklyPass
                      ? (arabic ? 'اشتراكك نشط الآن.' : 'Your subscription is active.')
                      : (arabic ? 'مرونة أكبر في بناء الـDecks وخيارات البطاقات.' : 'More flexibility for decks and card choices.'),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          AppPanel(
            child: Column(
              children: [
                FeatureRow(Icons.layers_rounded, arabic ? '5 Decks بدل 2' : '5 decks instead of 2'),
                const Divider(height: 22),
                FeatureRow(Icons.add_circle_outline_rounded, arabic ? '4 خيارات بدل 3' : '4 choices instead of 3'),
                const Divider(height: 22),
                FeatureRow(Icons.edit_rounded, arabic ? 'تعديل 3 خيارات خاطئة بدل خيارين' : 'Edit 3 wrong choices instead of 2'),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(color: const Color(0xFFFFF6DC), borderRadius: BorderRadius.circular(14)),
            child: Text(
              arabic ? 'ربط الدفع الفعلي بالمتجر سيبقى لمرحلة المتجر كما اتفقنا.' : 'Real store purchase wiring remains deferred to the store phase as planned.',
              style: const TextStyle(color: ink, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class FootballCardGrid extends StatelessWidget {
  const FootballCardGrid({
    super.key,
    required this.cards,
    required this.enabled,
    required this.selected,
    required this.onTap,
  });

  final List<QuestionContent> cards;
  final bool enabled;
  final Set<String> selected;
  final ValueChanged<QuestionContent> onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final cols = (constraints.maxWidth / 126).floor().clamp(2, 8);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cards.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            childAspectRatio: .92,
            crossAxisSpacing: 9,
            mainAxisSpacing: 9,
          ),
          itemBuilder: (_, i) {
            final q = cards[i];
            final chosen = selected.contains(q.id);
            final color = rarityColor(q.rarity);
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: enabled ? () => onTap(q) : null,
                borderRadius: BorderRadius.circular(16),
                child: Ink(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: chosen ? color.withValues(alpha: .1) : enabled ? Colors.white : const Color(0xFFF0F3F8),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: chosen ? color : enabled ? color.withValues(alpha: .5) : const Color(0xFFDCE3EE),
                      width: chosen ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FootballCardBadge(q: q, locked: !enabled),
                      const SizedBox(height: 6),
                      Text(q.id, style: const TextStyle(color: ink, fontSize: 10, fontWeight: FontWeight.w900)),
                      Text(
                        chosen ? 'SELECTED' : rarityName(q.rarity),
                        style: TextStyle(color: chosen ? green : enabled ? color : muted, fontSize: 7, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class FootballCardBadge extends StatelessWidget {
  const FootballCardBadge({super.key, required this.q, this.locked = false});

  final QuestionContent q;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final color = rarityColor(q.rarity);
    return Container(
      width: 38,
      height: 46,
      decoration: BoxDecoration(color: locked ? const Color(0xFFE1E6EE) : color, borderRadius: BorderRadius.circular(10)),
      child: Icon(
        locked ? Icons.lock_rounded : Icons.sports_soccer_rounded,
        color: locked ? muted : Colors.white,
        size: 21,
      ),
    );
  }
}

class FootballSectionTag extends StatelessWidget {
  const FootballSectionTag({super.key});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: const Color(0xFFE7F8EE), borderRadius: BorderRadius.circular(999)),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sports_soccer_rounded, color: green, size: 15),
            SizedBox(width: 6),
            Text('FOOTBALL', style: TextStyle(color: green, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
          ],
        ),
      ),
    );
  }
}

class FootballBackdrop extends StatelessWidget {
  const FootballBackdrop({super.key});

  @override
  Widget build(BuildContext context) => CustomPaint(painter: FootballBackdropPainter());
}

class FootballBackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = green.withValues(alpha: .045)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final field = Rect.fromLTWH(size.width * .05, size.height * .05, size.width * .9, size.height * .9);
    canvas.drawRRect(RRect.fromRectAndRadius(field, const Radius.circular(24)), paint);
    canvas.drawLine(Offset(size.width / 2, field.top), Offset(size.width / 2, field.bottom), paint);
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), 42, paint);
    canvas.drawRect(Rect.fromCenter(center: Offset(field.left + 28, size.height / 2), width: 56, height: 130), paint);
    canvas.drawRect(Rect.fromCenter(center: Offset(field.right - 28, size.height / 2), width: 56, height: 130), paint);

    final net = Paint()
      ..color = blue.withValues(alpha: .025)
      ..strokeWidth = .8;
    for (double y = 0; y < size.height; y += 42) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y + 80), net);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class FootballHeroPainter extends CustomPainter {
  const FootballHeroPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: .12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final field = Rect.fromLTWH(size.width * .48, 18, size.width * .48, size.height - 36);
    canvas.drawRRect(RRect.fromRectAndRadius(field, const Radius.circular(16)), paint);
    canvas.drawLine(Offset(field.center.dx, field.top), Offset(field.center.dx, field.bottom), paint);
    canvas.drawCircle(field.center, 28, paint);
    canvas.drawRect(Rect.fromCenter(center: Offset(field.left + 18, field.center.dy), width: 36, height: 80), paint);
    canvas.drawRect(Rect.fromCenter(center: Offset(field.right - 18, field.center.dy), width: 36, height: 80), paint);

    final net = Paint()
      ..color = Colors.white.withValues(alpha: .07)
      ..strokeWidth = .7;
    for (double x = field.left; x <= field.right; x += 18) {
      canvas.drawLine(Offset(x, field.top), Offset(x, field.bottom), net);
    }
    for (double y = field.top; y <= field.bottom; y += 18) {
      canvas.drawLine(Offset(field.left, y), Offset(field.right, y), net);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
