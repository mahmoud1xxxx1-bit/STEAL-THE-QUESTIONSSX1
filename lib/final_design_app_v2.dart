import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'backend/firebase_game_api.dart';
import 'game/game_rules.dart';
import 'game/question_bank.dart';
import 'product_app.dart';

const blue = Color(0xFF2E6BFF);
const purple = Color(0xFF7A48F5);
const gold = Color(0xFFFFC94D);
const coral = Color(0xFFFF6A67);
const green = Color(0xFF21B573);
const ink = Color(0xFF183153);
const muted = Color(0xFF7183A3);
const page = Color(0xFFF5F8FF);
const line = Color(0xFFE5EBF5);
const maxW = 1120.0;

class FinalDesignAppV2 extends StatefulWidget {
  const FinalDesignAppV2({super.key});
  @override
  State<FinalDesignAppV2> createState() => _FinalDesignAppV2State();
}

class _FinalDesignAppV2State extends State<FinalDesignAppV2> {
  final DemoPlayerState player = DemoPlayerState();
  final Map<String, List<String>> drafts = {};
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

  void push(Widget page) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: player,
      builder: (_, __) {
        if (player.loading) {
          return const Scaffold(backgroundColor: page, body: Center(child: CircularProgressIndicator()));
        }
        final screens = <Widget>[
          HomeScreen(arabic: arabic, player: player, openTab: (v) => setState(() => tab = v), push: push),
          CollectionScreen(arabic: arabic, player: player, drafts: drafts),
          DecksScreen(arabic: arabic, player: player, push: push),
          PlayScreen(arabic: arabic, player: player, push: push),
          MoreScreen(arabic: arabic, player: player, push: push),
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
                    Container(width: 40, height: 40, decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [blue, purple])), child: const Icon(Icons.question_mark_rounded, color: Colors.white)),
                    const SizedBox(width: 10),
                    const Expanded(child: Text('STEAL THE QUESTIONS', style: TextStyle(color: ink, fontSize: 14, fontWeight: FontWeight.w900))),
                    AppPill(text: '${player.ownedCount}/$kTotalCards', color: const Color(0xFFE0A000), bg: const Color(0xFFFFF4CE), icon: Icons.style_rounded),
                    const SizedBox(width: 4),
                    IconButton(onPressed: () => setState(() => arabic = !arabic), icon: Text(arabic ? 'EN' : 'ع', style: const TextStyle(color: blue, fontWeight: FontWeight.w900))),
                  ]),
                ),
              ),
            ),
            body: IndexedStack(index: tab, children: screens),
            bottomNavigationBar: NavigationBar(
              selectedIndex: tab,
              onDestinationSelected: (v) => setState(() => tab = v),
              backgroundColor: Colors.white,
              indicatorColor: const Color(0xFFEAEFFF),
              height: 68,
              destinations: [
                NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home_rounded, color: blue), label: arabic ? 'الرئيسية' : 'Home'),
                NavigationDestination(icon: const Icon(Icons.style_outlined), selectedIcon: const Icon(Icons.style_rounded, color: purple), label: arabic ? 'البطاقات' : 'Cards'),
                NavigationDestination(icon: const Icon(Icons.layers_outlined), selectedIcon: const Icon(Icons.layers_rounded, color: Color(0xFFE0A000)), label: arabic ? 'المجموعات' : 'Decks'),
                NavigationDestination(icon: const Icon(Icons.sports_esports_outlined), selectedIcon: const Icon(Icons.sports_esports_rounded, color: coral), label: arabic ? 'اللعب' : 'Play'),
                NavigationDestination(icon: const Icon(Icons.more_horiz_rounded), selectedIcon: const Icon(Icons.more_horiz_rounded, color: blue), label: arabic ? 'المزيد' : 'More'),
              ],
            ),
          ),
        );
      },
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.arabic, required this.player, required this.openTab, required this.push});
  final bool arabic;
  final DemoPlayerState player;
  final ValueChanged<int> openTab;
  final ValueChanged<Widget> push;

  @override
  Widget build(BuildContext context) {
    final deckCount = player.decks[player.activeDeck].length;
    return AppScroll(children: [
      Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(26), gradient: const LinearGradient(colors: [Color(0xFF4D8CFF), Color(0xFF8057F4)]), boxShadow: const [BoxShadow(color: Color(0x224C72FF), blurRadius: 18, offset: Offset(0, 8))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(arabic ? 'جاوب، اجمع، نافس... واسرق بطاقة!' : 'Answer, collect, compete... and steal a card!', style: const TextStyle(color: Colors.white, fontSize: 28, height: 1.15, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(arabic ? 'اللعب واضح: اجمع بطاقاتك، جهّز Deck، ثم ادخل المواجهة.' : 'Collect cards, prepare a deck, then enter a duel.', style: TextStyle(color: Colors.white.withValues(alpha: .9), fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          FilledButton.icon(onPressed: () => openTab(3), style: FilledButton.styleFrom(backgroundColor: gold, foregroundColor: ink), icon: const Icon(Icons.play_arrow_rounded), label: Text(arabic ? 'ابدأ اللعب' : 'PLAY NOW')),
        ]),
      ),
      const SizedBox(height: 14),
      ResponsiveTwo(
        a: ActionTile(icon: Icons.smart_toy_rounded, color: blue, title: arabic ? 'ضد البوت' : 'Bot', text: arabic ? 'اجمع البطاقات الأولى.' : 'Build your first cards.', onTap: () => push(BotPage(arabic: arabic, player: player))),
        b: ActionTile(icon: Icons.flash_on_rounded, color: coral, title: arabic ? 'ضد لاعب' : 'PvP', text: player.pvpUnlocked ? (arabic ? 'نافس واسرق بطاقة.' : 'Compete and steal a card.') : (arabic ? 'يفتح عند 10 بطاقات.' : 'Unlocks at 10 cards.'), onTap: () => openTab(3)),
      ),
      const SizedBox(height: 14),
      AppPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TitleRow(arabic ? 'تقدم المجموعة' : 'Collection progress', '${player.ownedCount}/$kTotalCards'),
        const SizedBox(height: 10),
        ClipRRect(borderRadius: BorderRadius.circular(99), child: LinearProgressIndicator(value: player.ownedCount / kTotalCards, minHeight: 9, backgroundColor: const Color(0xFFE4EAF4))),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          RarityStat('EPIC', purple, player.ownedCards.where((e) => QuestionBank.byId(e).rarity == CardRarity.epic).length, kEpicCards),
          RarityStat('GOLD', const Color(0xFFE0A000), player.ownedCards.where((e) => QuestionBank.byId(e).rarity == CardRarity.gold).length, kGoldCards),
          RarityStat('LEGENDARY', coral, player.ownedCards.where((e) => QuestionBank.byId(e).rarity == CardRarity.legendary).length, kLegendaryCards),
        ]),
      ])),
      const SizedBox(height: 14),
      AppPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TitleRow(arabic ? 'الـDeck النشط' : 'Active deck', '$deckCount/$kDeckSize'),
        const SizedBox(height: 10),
        SizedBox(height: 54, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: 10, separatorBuilder: (_, __) => const SizedBox(width: 6), itemBuilder: (_, i) => MiniCard(id: i < deckCount ? player.decks[player.activeDeck][i] : null))),
        const SizedBox(height: 10),
        OutlinedButton.icon(onPressed: () => openTab(2), icon: const Icon(Icons.edit_rounded), label: Text(arabic ? 'إدارة الـDecks' : 'Manage decks')),
      ])),
    ]);
  }
}

class CollectionScreen extends StatelessWidget {
  const CollectionScreen({super.key, required this.arabic, required this.player, required this.drafts});
  final bool arabic;
  final DemoPlayerState player;
  final Map<String, List<String>> drafts;

  @override
  Widget build(BuildContext context) {
    final owned = QuestionBank.all.where((q) => player.ownedCards.contains(q.id)).toList(growable: false);
    final locked = QuestionBank.all.where((q) => !player.ownedCards.contains(q.id)).toList(growable: false);
    return AppScroll(children: [
      AppHeading(arabic ? 'بطاقاتك' : 'Your cards', arabic ? 'المملوكة في الأعلى. افتح البطاقة لترى السؤال والإجابة والخيارات.' : 'Owned cards first. Open a card to see the question, answer and choices.'),
      const SizedBox(height: 12),
      AppPanel(child: Wrap(spacing: 34, runSpacing: 14, alignment: WrapAlignment.spaceAround, children: [CountStat('${owned.length}', arabic ? 'مملوكة' : 'Owned', blue), CountStat('${locked.length}', arabic ? 'غير مملوكة' : 'Locked', muted), CountStat('$kTotalCards', arabic ? 'الإجمالي' : 'Total', const Color(0xFFE0A000))])),
      const SizedBox(height: 18),
      TitleRow(arabic ? 'البطاقات المملوكة' : 'Owned cards', '${owned.length}'),
      const SizedBox(height: 8),
      if (owned.isEmpty)
        AppPanel(child: Row(children: [const Icon(Icons.smart_toy_rounded, color: blue), const SizedBox(width: 10), Expanded(child: Text(arabic ? 'ابدأ ضد البوت لتحصل على أول بطاقة.' : 'Play the bot to earn your first card.'))]))
      else
        CardGrid(cards: owned, enabled: true, selected: const {}, onTap: (q) => showCard(context, q)),
      const SizedBox(height: 24),
      TitleRow(arabic ? 'لم تحصل عليها بعد' : 'Not earned yet', '${locked.length}'),
      const SizedBox(height: 6),
      Text(arabic ? 'تبقى بالأسفل ولا تعرض تفاصيلها قبل امتلاكها.' : 'They stay below and hide details until earned.', style: const TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      CardGrid(cards: locked, enabled: false, selected: const {}, onTap: (_) {}),
    ]);
  }

  void showCard(BuildContext context, QuestionContent q) {
    final base = List<String>.from(arabic ? q.answersAr : q.answersEn);
    final values = List<String>.from(drafts[q.id] ?? [...base, if (player.weeklyPass) (arabic ? q.passExtraAr : q.passExtraEn)]);
    final needed = player.weeklyPass ? 4 : 3;
    while (values.length < needed) values.add('');
    final ctrls = values.map((e) => TextEditingController(text: e)).toList();
    showDialog<void>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: arabic ? TextDirection.rtl : TextDirection.ltr,
        child: AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          title: Row(children: [CardBadge(q: q), const SizedBox(width: 10), Expanded(child: Text('${q.id} · ${rarityName(q.rarity)}', style: const TextStyle(color: ink, fontWeight: FontWeight.w900)))]),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(arabic ? q.questionAr : q.questionEn, style: const TextStyle(color: ink, fontSize: 18, height: 1.45, fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFEAF9F2), borderRadius: BorderRadius.circular(14)), child: Row(children: [const Icon(Icons.check_circle_rounded, color: green), const SizedBox(width: 8), Expanded(child: Text(base[q.correctIndex], style: const TextStyle(color: ink, fontWeight: FontWeight.w900)))])),
                const SizedBox(height: 14),
                Text(arabic ? 'الخيارات المسموحة' : 'Allowed choices', style: const TextStyle(color: ink, fontSize: 15, fontWeight: FontWeight.w900)),
                const SizedBox(height: 5),
                Text(arabic ? 'الإجابة الصحيحة ثابتة. تعديل بقية الخيارات هنا للمعاينة فقط.' : 'The correct answer stays fixed. Other edits are preview-only.', style: const TextStyle(color: muted, fontSize: 10)),
                const SizedBox(height: 9),
                ...List.generate(ctrls.length, (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TextField(
                    controller: ctrls[i],
                    readOnly: i == q.correctIndex,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: i == q.correctIndex ? const Color(0xFFEAF9F2) : const Color(0xFFF6F8FC),
                      prefixIcon: Icon(i == q.correctIndex ? Icons.check_rounded : Icons.edit_rounded, color: i == q.correctIndex ? green : blue),
                      labelText: i == q.correctIndex ? (arabic ? 'الإجابة الصحيحة' : 'Correct answer') : '${arabic ? 'خيار' : 'Choice'} ${i + 1}${i == 3 ? ' · Weekly Pass' : ''}',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    ),
                  ),
                )),
                if (!player.weeklyPass)
                  Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFFFFF5D5), borderRadius: BorderRadius.circular(12)), child: Text(arabic ? 'الخيار الرابع يظهر فقط مع Weekly Pass.' : 'The fourth choice appears only with Weekly Pass.', style: const TextStyle(color: ink, fontSize: 10, fontWeight: FontWeight.w800))),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(arabic ? 'إلغاء' : 'Cancel')),
            FilledButton(onPressed: () { drafts[q.id] = ctrls.map((c) => c.text.trim()).toList(); Navigator.pop(ctx); }, child: Text(arabic ? 'حفظ للمعاينة' : 'Save preview')),
          ],
        ),
      ),
    );
  }
}

class DecksScreen extends StatelessWidget {
  const DecksScreen({super.key, required this.arabic, required this.player, required this.push});
  final bool arabic;
  final DemoPlayerState player;
  final ValueChanged<Widget> push;

  @override
  Widget build(BuildContext context) {
    return AppScroll(children: [
      AppHeading(arabic ? 'مجموعات اللعب' : 'Decks', arabic ? 'اختر Deck نشطًا، ثم عدّل بطاقاته. الصالح يحتوي 10 بطاقات مختلفة.' : 'Pick an active deck, then edit its cards. A valid deck has 10 distinct cards.'),
      const SizedBox(height: 14),
      ...List.generate(kMaxDeckSlots, (i) {
        final unlocked = i < player.deckSlots;
        final active = i == player.activeDeck;
        final count = player.decks[i].length;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: AppPanel(child: Column(children: [
            Row(children: [
              Container(width: 44, height: 44, decoration: BoxDecoration(color: unlocked ? const Color(0xFFEDE8FF) : const Color(0xFFF0F2F6), borderRadius: BorderRadius.circular(13)), child: Icon(unlocked ? Icons.layers_rounded : Icons.lock_rounded, color: unlocked ? purple : muted)),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${arabic ? 'المجموعة' : 'Deck'} ${i + 1}', style: const TextStyle(color: ink, fontSize: 15, fontWeight: FontWeight.w900)), Text(unlocked ? '$count/$kDeckSize${active ? ' · ACTIVE' : ''}' : 'Weekly Pass', style: const TextStyle(color: muted, fontSize: 10, fontWeight: FontWeight.w700))])),
              if (unlocked) OutlinedButton(onPressed: () => player.setActiveDeck(i), child: Text(active ? (arabic ? 'مختارة' : 'Selected') : (arabic ? 'اختيار' : 'Select'))) else const Icon(Icons.workspace_premium_rounded, color: Color(0xFFE0A000)),
            ]),
            if (unlocked) ...[const SizedBox(height: 10), Align(alignment: AlignmentDirectional.centerStart, child: FilledButton.icon(onPressed: () => push(DeckBuilderPage(arabic: arabic, player: player, deckIndex: i)), icon: const Icon(Icons.edit_rounded), label: Text(arabic ? 'تعديل البطاقات' : 'Edit cards')))],
          ])),
        );
      }),
    ]);
  }
}

class DeckBuilderPage extends StatelessWidget {
  const DeckBuilderPage({super.key, required this.arabic, required this.player, required this.deckIndex});
  final bool arabic;
  final DemoPlayerState player;
  final int deckIndex;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: player,
      builder: (_, __) {
        final owned = QuestionBank.all.where((q) => player.ownedCards.contains(q.id)).toList(growable: false);
        final deck = player.decks[deckIndex];
        return AppShell(
          title: '${arabic ? 'تعديل المجموعة' : 'Edit deck'} ${deckIndex + 1}',
          arabic: arabic,
          child: AppBody(children: [
            AppPanel(child: Row(children: [Icon(deck.length == 10 ? Icons.check_circle_rounded : Icons.layers_rounded, color: deck.length == 10 ? green : purple), const SizedBox(width: 9), Expanded(child: Text(arabic ? 'اختر 10 بطاقات مختلفة.' : 'Choose 10 distinct cards.', style: const TextStyle(color: ink, fontWeight: FontWeight.w900))), Text('${deck.length}/10', style: const TextStyle(color: blue, fontWeight: FontWeight.w900))])),
            const SizedBox(height: 12),
            if (owned.isEmpty) AppPanel(child: Text(arabic ? 'لا توجد بطاقات مملوكة بعد.' : 'No owned cards yet.')) else CardGrid(cards: owned, enabled: true, selected: deck.toSet(), onTap: (q) => player.toggleCardInDeck(q.id)),
            const SizedBox(height: 12),
            Row(children: [Expanded(child: OutlinedButton(onPressed: deck.isEmpty ? null : () => player.clearDeck(deckIndex), child: Text(arabic ? 'مسح الكل' : 'Clear all'))), const SizedBox(width: 10), Expanded(child: FilledButton(onPressed: deck.length == 10 ? () async { await player.saveDeck(deckIndex); if (context.mounted) Navigator.pop(context); } : null, child: Text(arabic ? 'حفظ الـDeck' : 'Save deck')))]),
          ]),
        );
      },
    );
  }
}

class PlayScreen extends StatelessWidget {
  const PlayScreen({super.key, required this.arabic, required this.player, required this.push});
  final bool arabic;
  final DemoPlayerState player;
  final ValueChanged<Widget> push;

  @override
  Widget build(BuildContext context) {
    final count = player.decks[player.activeDeck].length;
    return AppScroll(children: [
      AppHeading(arabic ? 'اختر طريقة اللعب' : 'Choose how to play', arabic ? 'حالة الحساب والـDeck ظاهرة قبل الدخول حتى لا يفاجأ اللاعب بشروط ناقصة.' : 'Account and deck readiness are shown before entering.'),
      const SizedBox(height: 12),
      AppPanel(child: Row(children: [const Icon(Icons.layers_rounded, color: purple), const SizedBox(width: 10), Expanded(child: Text('${arabic ? 'Deck النشط' : 'Active deck'} ${player.activeDeck + 1}', style: const TextStyle(color: ink, fontWeight: FontWeight.w900))), Text('$count/10', style: TextStyle(color: player.activeDeckReady ? green : coral, fontWeight: FontWeight.w900))])),
      const SizedBox(height: 12),
      PlayTile(icon: Icons.smart_toy_rounded, colors: const [Color(0xFF45A9FF), Color(0xFF2E6BFF)], title: arabic ? 'العب ضد البوت' : 'Play vs Bot', text: arabic ? 'قبل 10 بطاقات: الإجابة الصحيحة تمنح بطاقة جديدة.' : 'Before 10 cards: a correct answer earns a new card.', onTap: () => push(BotPage(arabic: arabic, player: player))),
      const SizedBox(height: 12),
      PlayTile(
        icon: Icons.flash_on_rounded,
        colors: const [Color(0xFFFF7B73), Color(0xFFFF4F87)],
        title: arabic ? 'العب ضد لاعب' : 'Play PvP',
        text: !player.pvpUnlocked ? (arabic ? 'مقفل حتى تمتلك 10 بطاقات.' : 'Locked until you own 10 cards.') : !player.activeDeckReady ? (arabic ? 'أكمل الـDeck النشط إلى 10.' : 'Complete the active deck to 10.') : !player.authenticated ? (arabic ? 'سجّل الدخول أولًا.' : 'Sign in first.') : (arabic ? 'جاهز: 7 أسئلة، ثم الفائز يسرق بطاقة.' : 'Ready: 7 questions, then the winner steals a card.'),
        onTap: () async {
          if (!player.authenticated) { push(AuthPage(arabic: arabic, player: player)); return; }
          if (!player.pvpUnlocked || !player.activeDeckReady) return;
          try {
            final r = await player.findOrCreateDuel();
            push(DuelPage(arabic: arabic, player: player, duelId: r['duelId'] as String));
          } catch (e) {
            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
          }
        },
      ),
      const SizedBox(height: 14),
      AppPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(arabic ? 'قواعد المواجهة' : 'Duel rules', style: const TextStyle(color: ink, fontWeight: FontWeight.w900)), const SizedBox(height: 8), ...[
        arabic ? '• Deck من 10 بطاقات' : '• 10-card deck',
        arabic ? '• 7 أسئلة × 20 ثانية' : '• 7 questions × 20 seconds',
        arabic ? '• الأكثر صحيحًا يفوز' : '• Most correct wins',
        arabic ? '• التعادل يحسم بالوقت' : '• Time breaks ties',
        arabic ? '• الفائز يسرق بطاقة' : '• Winner steals a card',
      ].map((e) => Padding(padding: const EdgeInsets.only(bottom: 5), child: Text(e, style: const TextStyle(color: muted, fontWeight: FontWeight.w700))))])),
    ]);
  }
}

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key, required this.arabic, required this.player, required this.push});
  final bool arabic;
  final DemoPlayerState player;
  final ValueChanged<Widget> push;

  @override
  Widget build(BuildContext context) {
    return AppScroll(children: [
      AppHeading(arabic ? 'المزيد' : 'More', arabic ? 'الأشياء الثانوية هنا حتى تبقى الصفحات الأساسية بسيطة.' : 'Secondary items stay here so core screens remain simple.'),
      const SizedBox(height: 14),
      AppPanel(child: Column(children: [
        MenuRow(icon: Icons.person_rounded, title: arabic ? 'الحساب' : 'Account', subtitle: player.authenticated ? player.accountLabel : (arabic ? 'غير مسجل' : 'Not signed in'), onTap: () => push(AuthPage(arabic: arabic, player: player))),
        const Divider(height: 22),
        MenuRow(icon: Icons.emoji_events_rounded, title: arabic ? 'التصنيف' : 'Ranking', subtitle: arabic ? 'البطاقات أولًا ثم الانتصارات' : 'Cards first, then wins', onTap: () => push(RankingPage(arabic: arabic, player: player))),
        const Divider(height: 22),
        MenuRow(icon: Icons.workspace_premium_rounded, title: 'Weekly Pass', subtitle: arabic ? '3 Decks إضافية + خيار رابع' : '3 extra decks + fourth choice', onTap: () => push(PassPage(arabic: arabic))),
        const Divider(height: 22),
        MenuRow(icon: Icons.help_outline_rounded, title: arabic ? 'كيف تعمل اللعبة؟' : 'How it works', subtitle: arabic ? 'المسار الكامل في أقل من دقيقة' : 'The full loop in under a minute', onTap: () => push(HowPage(arabic: arabic))),
      ])),
    ]);
  }
}

class BotPage extends StatefulWidget {
  const BotPage({super.key, required this.arabic, required this.player});
  final bool arabic;
  final DemoPlayerState player;
  @override
  State<BotPage> createState() => _BotPageState();
}

class _BotPageState extends State<BotPage> {
  BotRoundData? round;
  Timer? timer;
  int seconds = 20;
  bool busy = true;
  bool answered = false;
  bool correct = false;
  int? selected;
  String error = '';

  @override
  void initState() { super.initState(); load(); }
  @override
  void dispose() { timer?.cancel(); super.dispose(); }

  Future<void> load() async {
    timer?.cancel();
    setState(() { busy = true; answered = false; selected = null; correct = false; seconds = 20; error = ''; });
    try {
      final r = await widget.player.startBotRound(arabic: widget.arabic);
      if (!mounted) return;
      setState(() { round = r; busy = false; });
      timer = Timer.periodic(const Duration(seconds: 1), (_) { if (!mounted || answered) return; if (seconds <= 1) answer(-1); else setState(() => seconds--); });
    } catch (e) {
      if (mounted) setState(() { busy = false; error = e.toString().replaceFirst('Bad state: ', ''); });
    }
  }

  Future<void> answer(int index) async {
    if (answered || round == null) return;
    timer?.cancel();
    setState(() { answered = true; selected = index; });
    final ok = await widget.player.completeBotRound(round: round!, answerIndex: index);
    if (mounted) setState(() => correct = ok);
  }

  @override
  Widget build(BuildContext context) {
    if (busy) return AppShell(title: widget.arabic ? 'جولة البوت' : 'Bot round', arabic: widget.arabic, child: const Center(child: CircularProgressIndicator()));
    if (round == null) return AppShell(title: widget.arabic ? 'جولة البوت' : 'Bot round', arabic: widget.arabic, child: Center(child: Padding(padding: const EdgeInsets.all(30), child: Text(error))));
    final q = QuestionBank.byId(round!.questionId);
    final answers = q.answers(arabic: widget.arabic, weeklyPass: widget.player.weeklyPass);
    return AppShell(
      title: widget.arabic ? 'جولة البوت' : 'Bot round',
      arabic: widget.arabic,
      child: AppBody(children: [
        Row(children: [Expanded(child: LinearProgressIndicator(value: seconds / 20, minHeight: 8, backgroundColor: const Color(0xFFE5EAF3))), const SizedBox(width: 10), AppPill(text: '${seconds}s', color: seconds <= 5 ? coral : blue, bg: const Color(0xFFEAF0FF))]),
        const SizedBox(height: 14),
        AppPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${q.id} · ${widget.arabic ? q.categoryAr : q.categoryEn}', style: const TextStyle(color: purple, fontSize: 10, fontWeight: FontWeight.w900)), const SizedBox(height: 8), Text(widget.arabic ? q.questionAr : q.questionEn, style: const TextStyle(color: ink, fontSize: 20, height: 1.45, fontWeight: FontWeight.w900))])),
        const SizedBox(height: 12),
        ...List.generate(answers.length, (i) => Padding(padding: const EdgeInsets.only(bottom: 8), child: AnswerButton(text: answers[i], state: !answered ? 0 : i == q.correctIndex ? 2 : selected == i ? 3 : 1, onTap: answered ? null : () => answer(i)))),
        if (answered) ...[
          const SizedBox(height: 8),
          Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: correct ? const Color(0xFFEAF9F2) : const Color(0xFFFFEEEE), borderRadius: BorderRadius.circular(14)), child: Row(children: [Icon(correct ? Icons.celebration_rounded : Icons.info_outline_rounded, color: correct ? green : coral), const SizedBox(width: 9), Expanded(child: Text(correct ? (widget.arabic ? 'إجابة صحيحة — حصلت على بطاقة.' : 'Correct — you earned a card.') : (widget.arabic ? 'لا توجد بطاقة في هذه الجولة.' : 'No card this round.'), style: const TextStyle(color: ink, fontWeight: FontWeight.w900)))])),
          const SizedBox(height: 10),
          FilledButton.icon(onPressed: widget.player.pvpUnlocked ? () => Navigator.pop(context) : load, icon: const Icon(Icons.arrow_forward_rounded), label: Text(widget.player.pvpUnlocked ? (widget.arabic ? 'تم فتح PvP' : 'PvP unlocked') : (widget.arabic ? 'جولة أخرى' : 'Next round'))),
        ],
      ]),
    );
  }
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key, required this.arabic, required this.player});
  final bool arabic;
  final DemoPlayerState player;
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool create = false;
  bool busy = false;
  String error = '';

  @override
  void dispose() { email.dispose(); password.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: widget.arabic ? 'الحساب' : 'Account',
      arabic: widget.arabic,
      child: AppBody(children: [
        AppHeading(widget.player.authenticated ? (widget.arabic ? 'أنت مسجل الدخول' : 'You are signed in') : (create ? (widget.arabic ? 'إنشاء حساب' : 'Create account') : (widget.arabic ? 'تسجيل الدخول' : 'Sign in')), widget.player.authenticated ? widget.player.accountLabel : (widget.arabic ? 'الحساب مطلوب للـPvP والتصنيف والمزامنة.' : 'An account is required for PvP, ranking and sync.')),
        const SizedBox(height: 14),
        if (widget.player.authenticated)
          AppPanel(child: Column(children: [const Icon(Icons.verified_user_rounded, color: green, size: 44), const SizedBox(height: 10), Text(widget.player.accountLabel, style: const TextStyle(color: ink, fontWeight: FontWeight.w900)), const SizedBox(height: 12), OutlinedButton(onPressed: () async { await widget.player.signOut(); if (context.mounted) Navigator.pop(context); }, child: Text(widget.arabic ? 'تسجيل الخروج' : 'Sign out'))]))
        else ...[
          TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(labelText: widget.arabic ? 'البريد الإلكتروني' : 'Email')),
          const SizedBox(height: 10),
          TextField(controller: password, obscureText: true, decoration: InputDecoration(labelText: widget.arabic ? 'كلمة المرور' : 'Password')),
          if (error.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text(error, style: const TextStyle(color: coral))),
          const SizedBox(height: 12),
          FilledButton(onPressed: busy ? null : submit, child: Text(create ? (widget.arabic ? 'إنشاء الحساب' : 'Create account') : (widget.arabic ? 'دخول' : 'Sign in'))),
          TextButton(onPressed: () => setState(() => create = !create), child: Text(create ? (widget.arabic ? 'لدي حساب بالفعل' : 'I already have an account') : (widget.arabic ? 'إنشاء حساب جديد' : 'Create a new account'))),
        ],
      ]),
    );
  }

  Future<void> submit() async {
    setState(() { busy = true; error = ''; });
    try {
      if (create) await widget.player.signUp(email.text, password.text); else await widget.player.signIn(email.text, password.text);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}

class RankingPage extends StatelessWidget {
  const RankingPage({super.key, required this.arabic, required this.player});
  final bool arabic;
  final DemoPlayerState player;

  @override
  Widget build(BuildContext context) {
    if (!player.authenticated) return AppShell(title: arabic ? 'التصنيف' : 'Ranking', arabic: arabic, child: Center(child: Text(arabic ? 'سجّل الدخول أولًا لعرض التصنيف.' : 'Sign in first to view ranking.', style: const TextStyle(color: ink, fontWeight: FontWeight.w900))));
    return AppShell(
      title: arabic ? 'التصنيف' : 'Ranking',
      arabic: arabic,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: player.loadRanking(),
        builder: (_, snap) {
          if (!snap.hasData && !snap.hasError) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) return Center(child: Text(snap.error.toString()));
          final rows = snap.data!;
          return AppBody(children: [
            AppHeading(arabic ? 'التصنيف العالمي' : 'Global ranking', arabic ? 'البطاقات أولًا، ثم الانتصارات، ثم الخسائر الأقل.' : 'Cards first, then wins, then fewer losses.'),
            const SizedBox(height: 12),
            ...List.generate(rows.length, (i) {
              final r = rows[i];
              return Padding(padding: const EdgeInsets.only(bottom: 8), child: AppPanel(child: Row(children: [
                Container(width: 36, height: 36, decoration: BoxDecoration(color: i < 3 ? const Color(0xFFFFF2C8) : const Color(0xFFEAF0FF), borderRadius: BorderRadius.circular(11)), child: Center(child: Text('${i + 1}', style: TextStyle(color: i < 3 ? const Color(0xFFE0A000) : blue, fontWeight: FontWeight.w900)))),
                const SizedBox(width: 10),
                Expanded(child: Text((r['displayName'] ?? r['email'] ?? r['uid'] ?? 'Player').toString(), overflow: TextOverflow.ellipsis, style: const TextStyle(color: ink, fontWeight: FontWeight.w900))),
                AppPill(text: '${r['ownedCount'] ?? r['cards'] ?? 0}', color: purple, bg: const Color(0xFFF0EAFE), icon: Icons.style_rounded),
                const SizedBox(width: 6),
                AppPill(text: '${r['wins'] ?? 0}', color: green, bg: const Color(0xFFEAF9F2), icon: Icons.emoji_events_rounded),
              ])));
            }),
          ]);
        },
      ),
    );
  }
}

class PassPage extends StatelessWidget {
  const PassPage({super.key, required this.arabic});
  final bool arabic;
  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Weekly Pass',
      arabic: arabic,
      child: AppBody(children: [
        Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFFFD55C), Color(0xFFFFA94D)]), borderRadius: BorderRadius.circular(24)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 44), const SizedBox(height: 12), Text(arabic ? 'اشتراك أسبوعي بسيط وواضح' : 'A simple weekly upgrade', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)), const SizedBox(height: 6), Text(arabic ? 'مرونة أكثر بدون تحويل اللعبة إلى Pay-to-Win.' : 'More flexibility without turning the game into pay-to-win.', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))])),
        const SizedBox(height: 14),
        AppPanel(child: Column(children: [FeatureRow(Icons.layers_rounded, arabic ? '5 Decks بدل 2' : '5 decks instead of 2'), const Divider(height: 22), FeatureRow(Icons.add_circle_outline_rounded, arabic ? 'خيار إجابة رابع' : 'A fourth answer choice')])),
        const SizedBox(height: 14),
        Container(padding: const EdgeInsets.all(13), decoration: BoxDecoration(color: const Color(0xFFFFF6DC), borderRadius: BorderRadius.circular(14)), child: Text(arabic ? 'الدفع الفعلي سيُربط في مرحلة المتجر كما اتفقنا، وليس أثناء التصميم.' : 'Real purchase wiring stays deferred to the store phase as planned.', style: const TextStyle(color: ink, fontWeight: FontWeight.w800))),
      ]),
    );
  }
}

class HowPage extends StatelessWidget {
  const HowPage({super.key, required this.arabic});
  final bool arabic;
  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: arabic ? 'كيف تعمل اللعبة؟' : 'How it works',
      arabic: arabic,
      child: AppBody(children: [
        AppHeading(arabic ? 'اللعبة في 6 خطوات' : 'The game in 6 steps', arabic ? 'من أول سؤال إلى سرقة أول بطاقة.' : 'From your first question to your first stolen card.'),
        const SizedBox(height: 14),
        StepRow(1, Icons.smart_toy_rounded, arabic ? 'ابدأ ضد البوت' : 'Start vs Bot', arabic ? 'اجب بشكل صحيح لتحصل على بطاقاتك الأولى.' : 'Answer correctly to earn your first cards.'),
        StepRow(2, Icons.style_rounded, arabic ? 'اجمع 10 بطاقات' : 'Collect 10 cards', arabic ? 'بعدها يفتح PvP.' : 'Then PvP unlocks.'),
        StepRow(3, Icons.layers_rounded, arabic ? 'كوّن Deck' : 'Build a deck', arabic ? 'اختر 10 بطاقات مختلفة.' : 'Choose 10 distinct cards.'),
        StepRow(4, Icons.flash_on_rounded, arabic ? 'ابدأ المواجهة' : 'Enter a duel', arabic ? 'الخادم يختار 7 أسئلة من Deck الخصم.' : 'The server selects 7 questions from the opponent deck.'),
        StepRow(5, Icons.timer_rounded, arabic ? 'جاوب بسرعة ودقة' : 'Answer fast and accurately', arabic ? 'الأكثر صحيحًا يفوز والتعادل يحسم بالوقت.' : 'Most correct wins; time breaks ties.'),
        StepRow(6, Icons.front_hand_rounded, arabic ? 'اسرق بطاقة' : 'Steal a card', arabic ? 'الفائز يختار بطاقة من Deck الخصم.' : 'The winner chooses a card from the opponent deck.'),
      ]),
    );
  }
}

class DuelPage extends StatefulWidget {
  const DuelPage({super.key, required this.arabic, required this.player, required this.duelId});
  final bool arabic;
  final DemoPlayerState player;
  final String duelId;
  @override
  State<DuelPage> createState() => _DuelPageState();
}

class _DuelPageState extends State<DuelPage> {
  Timer? poll;
  Map<String, dynamic>? duel;
  bool sending = false;
  int? slot;
  Map<String, dynamic>? reveal;
  bool stolen = false;

  @override
  void initState() {
    super.initState();
    load();
    poll = Timer.periodic(const Duration(seconds: 1), (_) => load());
  }

  @override
  void dispose() { poll?.cancel(); super.dispose(); }

  String get role {
    final uid = widget.player.api?.currentUser?.uid;
    return duel?['p1Uid'] == uid ? 'p1' : 'p2';
  }

  int get mine => (duel?[role == 'p1' ? 'p1AnsweredCount' : 'p2AnsweredCount'] as num?)?.toInt() ?? 0;
  int get other => (duel?[role == 'p1' ? 'p2AnsweredCount' : 'p1AnsweredCount'] as num?)?.toInt() ?? 0;

  Future<void> load() async {
    try {
      final d = await widget.player.api!.getDuelState(widget.duelId);
      if (!mounted) return;
      setState(() => duel = d);
      final started = d['startedAt'];
      DateTime? t;
      if (started is Timestamp) t = started.toDate();
      if (d['status'] == 'playing' && t != null && DateTime.now().difference(t).inSeconds >= kQuestionPhaseSeconds) {
        await widget.player.api!.resolveDuel(widget.duelId);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (duel == null) return AppShell(title: 'TROLL DUEL', arabic: widget.arabic, child: const Center(child: CircularProgressIndicator()));
    final status = duel!['status']?.toString() ?? 'searching';
    if (status == 'searching') {
      return AppShell(title: 'TROLL DUEL', arabic: widget.arabic, child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const CircularProgressIndicator(), const SizedBox(height: 16), Text(widget.arabic ? 'نبحث عن خصم مناسب...' : 'Searching for an opponent...', style: const TextStyle(color: ink, fontSize: 18, fontWeight: FontWeight.w900)), const SizedBox(height: 6), Text(widget.arabic ? 'ابق في الشاشة وستبدأ المواجهة تلقائيًا.' : 'Stay here; the duel starts automatically.', style: const TextStyle(color: muted))])));
    }
    final result = duel!['result']?.toString();
    if (result != null && result != 'playing') return resultView(result);

    final listValue = duel![role == 'p1' ? 'questionsP1' : 'questionsP2'] as List? ?? const [];
    final questions = listValue.map((e) => Map<String, dynamic>.from(e as Map)).toList(growable: false);
    final idx = min(mine, questions.isEmpty ? 0 : questions.length - 1);
    final current = questions.isEmpty ? null : questions[idx];
    return AppShell(
      title: 'TROLL DUEL',
      arabic: widget.arabic,
      child: AppBody(children: [
        Row(children: [Expanded(child: ProgressBox(label: widget.arabic ? 'أنت' : 'YOU', value: mine)), const SizedBox(width: 10), Expanded(child: ProgressBox(label: widget.arabic ? 'الخصم' : 'OPPONENT', value: other))]),
        const SizedBox(height: 14),
        AppHeading('${widget.arabic ? 'السؤال' : 'Question'} ${mine + 1}/7', widget.arabic ? 'سؤال من Deck خصمك. الوقت مهم.' : 'A question from your opponent deck. Time matters.'),
        const SizedBox(height: 12),
        if (current == null) const Center(child: CircularProgressIndicator()) else duelQuestion(current),
      ]),
    );
  }

  Widget duelQuestion(Map<String, dynamic> q) {
    final text = (q[widget.arabic ? 'questionAr' : 'questionEn'] ?? '').toString();
    final answersRaw = q[widget.arabic ? 'answersAr' : 'answersEn'] as List? ?? const [];
    final answers = List<String>.from(answersRaw);
    final fourth = q[widget.arabic ? 'fourthAr' : 'fourthEn']?.toString();
    if (widget.player.weeklyPass && fourth != null && fourth.isNotEmpty) answers.add(fourth);
    return Column(children: [
      AppPanel(child: Text(text, style: const TextStyle(color: ink, fontSize: 19, height: 1.45, fontWeight: FontWeight.w900))),
      const SizedBox(height: 10),
      ...List.generate(answers.length, (i) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: AnswerButton(
          text: answers[i],
          state: 0,
          onTap: sending ? null : () async {
            setState(() => sending = true);
            try {
              await widget.player.api!.submitDuelAnswer(duelId: widget.duelId, questionIndex: mine, answerIndex: i);
              await load();
            } finally {
              if (mounted) setState(() => sending = false);
            }
          },
        ),
      )),
    ]);
  }

  Widget resultView(String result) {
    final uid = widget.player.api?.currentUser?.uid;
    final won = duel!['winnerUid'] == uid;
    final draw = result == 'draw';
    return AppShell(
      title: widget.arabic ? 'النتيجة' : 'Result',
      arabic: widget.arabic,
      child: AppBody(children: [
        Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: draw ? const Color(0xFFF0F2F6) : won ? const Color(0xFFEAF9F2) : const Color(0xFFFFEEEE), borderRadius: BorderRadius.circular(18)), child: Text(draw ? (widget.arabic ? 'تعادل — لا توجد سرقة.' : 'Draw — no steal.') : won ? (widget.arabic ? 'فزت! اختر بطاقة لتسرقها.' : 'You won! Choose a card to steal.') : (widget.arabic ? 'خسرت هذه المواجهة.' : 'You lost this duel.'), style: const TextStyle(color: ink, fontSize: 18, fontWeight: FontWeight.w900))),
        const SizedBox(height: 12),
        if (won && !stolen) stealPanel(),
        if (!won || draw) FilledButton(onPressed: () => Navigator.pop(context), child: Text(widget.arabic ? 'العودة' : 'Back')),
        if (stolen) FilledButton(onPressed: () => Navigator.pop(context), child: Text(widget.arabic ? 'تمت السرقة — العودة' : 'Stolen — back')),
      ]),
    );
  }

  Widget stealPanel() {
    return AppPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(widget.arabic ? 'اختر خانة واحدة من Deck الخصم' : 'Choose one opponent-deck slot', style: const TextStyle(color: ink, fontWeight: FontWeight.w900)),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: List.generate(10, (i) => ChoiceChip(label: Text('${i + 1}'), selected: slot == i, onSelected: (_) => setState(() => slot = i)))),
      const SizedBox(height: 10),
      OutlinedButton(onPressed: slot == null ? null : () async { final r = await widget.player.api!.revealStealTarget(duelId: widget.duelId, slotIndex: slot!); if (mounted) setState(() => reveal = r); }, child: Text(widget.arabic ? 'كشف البطاقة' : 'Reveal card')),
      if (reveal != null) ...[
        const SizedBox(height: 8),
        Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFF6F8FC), borderRadius: BorderRadius.circular(12)), child: Text('${reveal!['cardId']} · ${(reveal!['rarity'] ?? '').toString().toUpperCase()}', style: const TextStyle(color: ink, fontWeight: FontWeight.w900))),
        const SizedBox(height: 8),
        FilledButton(onPressed: () async { await widget.player.api!.confirmSteal(widget.duelId); await refreshPlayer(widget.player); if (mounted) setState(() => stolen = true); }, child: Text(widget.arabic ? 'تأكيد السرقة' : 'Confirm steal')),
      ],
    ]));
  }
}

Future<void> refreshPlayer(DemoPlayerState player) async {
  if (!player.authenticated || player.api == null) return;
  try {
    final d = await player.api!.loadProfile();
    player.ownedCards..clear()..addAll(List<String>.from(d['ownedCards'] as List? ?? const []));
    final decks = d['decks'] as List? ?? const [];
    for (var i = 0; i < kMaxDeckSlots; i++) {
      player.decks[i]
        ..clear()
        ..addAll(i < decks.length ? List<String>.from(decks[i] as List? ?? const []) : const []);
    }
    player.wins = (d['wins'] as num?)?.toInt() ?? player.wins;
    player.losses = (d['losses'] as num?)?.toInt() ?? player.losses;
    player.activeDeck = ((d['activeDeck'] as num?)?.toInt() ?? player.activeDeck).clamp(0, kMaxDeckSlots - 1);
    player.notifyListeners();
  } catch (_) {}
}

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.title, required this.arabic, required this.child});
  final String title;
  final bool arabic;
  final Widget child;
  @override
  Widget build(BuildContext context) => Directionality(textDirection: arabic ? TextDirection.rtl : TextDirection.ltr, child: Scaffold(backgroundColor: page, appBar: AppBar(title: Text(title, style: const TextStyle(color: ink, fontWeight: FontWeight.w900)), backgroundColor: Colors.white, surfaceTintColor: Colors.white), body: child));
}

class AppScroll extends StatelessWidget {
  const AppScroll({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: maxW), child: Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 28), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children)))));
}

class AppBody extends StatelessWidget {
  const AppBody({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: maxW), child: Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 28), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children)))));
}

class AppPanel extends StatelessWidget {
  const AppPanel({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: line), boxShadow: const [BoxShadow(color: Color(0x09183153), blurRadius: 10, offset: Offset(0, 4))]), child: child);
}

class AppHeading extends StatelessWidget {
  const AppHeading(this.title, this.subtitle, {super.key});
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: ink, fontSize: 25, fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text(subtitle, style: const TextStyle(color: muted, fontSize: 11, height: 1.4, fontWeight: FontWeight.w600))]);
}

class TitleRow extends StatelessWidget {
  const TitleRow(this.title, [this.trailing]);
  final String title;
  final String? trailing;
  @override
  Widget build(BuildContext context) => Row(children: [Expanded(child: Text(title, style: const TextStyle(color: ink, fontSize: 16, fontWeight: FontWeight.w900))), if (trailing != null) Text(trailing!, style: const TextStyle(color: blue, fontSize: 12, fontWeight: FontWeight.w900))]);
}

class AppPill extends StatelessWidget {
  const AppPill({super.key, required this.text, required this.color, required this.bg, this.icon});
  final String text;
  final Color color;
  final Color bg;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6), decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)), child: Row(mainAxisSize: MainAxisSize.min, children: [if (icon != null) ...[Icon(icon, size: 14, color: color), const SizedBox(width: 4)], Text(text, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900))]));
}

class CountStat extends StatelessWidget {
  const CountStat(this.value, this.label, this.color, {super.key});
  final String value;
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => SizedBox(width: 120, child: Column(children: [Text(value, style: TextStyle(color: color, fontSize: 21, fontWeight: FontWeight.w900)), Text(label, style: const TextStyle(color: muted, fontSize: 10, fontWeight: FontWeight.w700))]));
}

class RarityStat extends StatelessWidget {
  const RarityStat(this.name, this.color, this.value, this.total, {super.key});
  final String name;
  final Color color;
  final int value;
  final int total;
  @override
  Widget build(BuildContext context) => Container(width: 155, padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withValues(alpha: .1), borderRadius: BorderRadius.circular(14)), child: Row(children: [Expanded(child: Text(name, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900))), Text('$value/$total', style: const TextStyle(color: ink, fontWeight: FontWeight.w900))]));
}

class ResponsiveTwo extends StatelessWidget {
  const ResponsiveTwo({super.key, required this.a, required this.b});
  final Widget a;
  final Widget b;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (_, c) => c.maxWidth > 620 ? Row(children: [Expanded(child: a), const SizedBox(width: 10), Expanded(child: b)]) : Column(children: [a, const SizedBox(height: 10), b]));
}

class ActionTile extends StatelessWidget {
  const ActionTile({super.key, required this.icon, required this.color, required this.title, required this.text, required this.onTap});
  final IconData icon;
  final Color color;
  final String title;
  final String text;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(color: Colors.transparent, child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(20), child: Ink(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: line)), child: Row(children: [Container(width: 44, height: 44, decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: color)), const SizedBox(width: 11), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: ink, fontSize: 15, fontWeight: FontWeight.w900)), Text(text, style: const TextStyle(color: muted, fontSize: 10, height: 1.35))])), const Icon(Icons.chevron_right_rounded, color: muted)]))));
}

class MiniCard extends StatelessWidget {
  const MiniCard({super.key, this.id});
  final String? id;
  @override
  Widget build(BuildContext context) {
    final q = id == null ? null : QuestionBank.byId(id!);
    final color = q == null ? const Color(0xFFDCE3EE) : rarityColor(q.rarity);
    return Container(width: 40, decoration: BoxDecoration(color: q == null ? const Color(0xFFEDF1F7) : color, borderRadius: BorderRadius.circular(9)), child: Center(child: Text(id == null ? '+' : id!.replaceFirst('Q', ''), style: TextStyle(color: id == null ? muted : Colors.white, fontSize: 8, fontWeight: FontWeight.w900))));
  }
}

class CardGrid extends StatelessWidget {
  const CardGrid({super.key, required this.cards, required this.enabled, required this.selected, required this.onTap});
  final List<QuestionContent> cards;
  final bool enabled;
  final Set<String> selected;
  final ValueChanged<QuestionContent> onTap;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (_, c) {
    final cols = (c.maxWidth / 126).floor().clamp(2, 8);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cards.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, childAspectRatio: .92, crossAxisSpacing: 9, mainAxisSpacing: 9),
      itemBuilder: (_, i) {
        final q = cards[i];
        final chosen = selected.contains(q.id);
        final color = rarityColor(q.rarity);
        return Material(color: Colors.transparent, child: InkWell(onTap: enabled ? () => onTap(q) : null, borderRadius: BorderRadius.circular(16), child: Ink(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: chosen ? color.withValues(alpha: .1) : enabled ? Colors.white : const Color(0xFFF0F3F8), borderRadius: BorderRadius.circular(16), border: Border.all(color: chosen ? color : enabled ? color.withValues(alpha: .5) : const Color(0xFFDCE3EE), width: chosen ? 2 : 1)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CardBadge(q: q, locked: !enabled), const SizedBox(height: 6), Text(q.id, style: const TextStyle(color: ink, fontSize: 10, fontWeight: FontWeight.w900)), Text(chosen ? 'SELECTED' : rarityName(q.rarity), style: TextStyle(color: chosen ? green : enabled ? color : muted, fontSize: 7, fontWeight: FontWeight.w900))]))));
      },
    );
  });
}

class CardBadge extends StatelessWidget {
  const CardBadge({super.key, required this.q, this.locked = false});
  final QuestionContent q;
  final bool locked;
  @override
  Widget build(BuildContext context) {
    final color = rarityColor(q.rarity);
    return Container(width: 38, height: 46, decoration: BoxDecoration(color: locked ? const Color(0xFFE1E6EE) : color, borderRadius: BorderRadius.circular(10)), child: Icon(locked ? Icons.lock_rounded : Icons.question_mark_rounded, color: locked ? muted : Colors.white, size: 21));
  }
}

class PlayTile extends StatelessWidget {
  const PlayTile({super.key, required this.icon, required this.colors, required this.title, required this.text, required this.onTap});
  final IconData icon;
  final List<Color> colors;
  final String title;
  final String text;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(color: Colors.transparent, child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(22), child: Ink(padding: const EdgeInsets.all(18), decoration: BoxDecoration(gradient: LinearGradient(colors: colors), borderRadius: BorderRadius.circular(22)), child: Row(children: [Container(width: 52, height: 52, decoration: BoxDecoration(color: Colors.white.withValues(alpha: .2), borderRadius: BorderRadius.circular(16)), child: Icon(icon, color: Colors.white, size: 28)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)), Text(text, style: TextStyle(color: Colors.white.withValues(alpha: .92), fontSize: 10, height: 1.4, fontWeight: FontWeight.w600))])), const Icon(Icons.chevron_right_rounded, color: Colors.white)]))));
}

class MenuRow extends StatelessWidget {
  const MenuRow({super.key, required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(14), child: Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [Container(width: 40, height: 40, decoration: BoxDecoration(color: const Color(0xFFEAF0FF), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: blue, size: 21)), const SizedBox(width: 11), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: ink, fontSize: 13, fontWeight: FontWeight.w900)), Text(subtitle, style: const TextStyle(color: muted, fontSize: 9))])), const Icon(Icons.chevron_right_rounded, color: muted)])));
}

class AnswerButton extends StatelessWidget {
  const AnswerButton({super.key, required this.text, required this.state, required this.onTap});
  final String text;
  final int state;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final bg = state == 2 ? const Color(0xFFEAF9F2) : state == 3 ? const Color(0xFFFFEEEE) : Colors.white;
    final border = state == 2 ? green : state == 3 ? coral : line;
    return SizedBox(width: double.infinity, child: OutlinedButton(onPressed: onTap, style: OutlinedButton.styleFrom(backgroundColor: bg, foregroundColor: ink, side: BorderSide(color: border), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), child: Align(alignment: AlignmentDirectional.centerStart, child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800)))));
  }
}

class ProgressBox extends StatelessWidget {
  const ProgressBox({super.key, required this.label, required this.value});
  final String label;
  final int value;
  @override
  Widget build(BuildContext context) => AppPanel(child: Row(children: [Expanded(child: Text(label, style: const TextStyle(color: muted, fontSize: 9, fontWeight: FontWeight.w900))), Text('$value/7', style: const TextStyle(color: blue, fontWeight: FontWeight.w900))]));
}

class FeatureRow extends StatelessWidget {
  const FeatureRow(this.icon, this.text, {super.key});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Row(children: [Icon(icon, color: purple), const SizedBox(width: 10), Expanded(child: Text(text, style: const TextStyle(color: ink, fontWeight: FontWeight.w900)))]);
}

class StepRow extends StatelessWidget {
  const StepRow(this.n, this.icon, this.title, this.text, {super.key});
  final int n;
  final IconData icon;
  final String title;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 10), child: AppPanel(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(width: 36, height: 36, decoration: BoxDecoration(color: const Color(0xFFEAF0FF), borderRadius: BorderRadius.circular(11)), child: Center(child: Text('$n', style: const TextStyle(color: blue, fontWeight: FontWeight.w900)))), const SizedBox(width: 10), Icon(icon, color: purple), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: ink, fontWeight: FontWeight.w900)), const SizedBox(height: 2), Text(text, style: const TextStyle(color: muted, fontSize: 10, height: 1.35))]))])));
}

Color rarityColor(CardRarity r) {
  switch (r) {
    case CardRarity.epic: return purple;
    case CardRarity.gold: return const Color(0xFFE0A000);
    case CardRarity.legendary: return coral;
  }
}

String rarityName(CardRarity r) {
  switch (r) {
    case CardRarity.epic: return 'EPIC';
    case CardRarity.gold: return 'GOLD';
    case CardRarity.legendary: return 'LEGENDARY';
  }
}
