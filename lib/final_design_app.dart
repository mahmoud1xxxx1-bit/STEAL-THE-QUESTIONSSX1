import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'backend/firebase_game_api.dart';
import 'game/game_rules.dart';
import 'game/question_bank.dart';
import 'product_app.dart';

const _blue = Color(0xFF2E6BFF);
const _purple = Color(0xFF7A48F5);
const _gold = Color(0xFFFFC94D);
const _coral = Color(0xFFFF6A67);
const _green = Color(0xFF21B573);
const _ink = Color(0xFF183153);
const _muted = Color(0xFF7183A3);
const _page = Color(0xFFF5F8FF);
const _line = Color(0xFFE5EBF5);
const _maxW = 1120.0;

class FinalDesignApp extends StatefulWidget {
  const FinalDesignApp({super.key});
  @override
  State<FinalDesignApp> createState() => _FinalDesignAppState();
}

class _FinalDesignAppState extends State<FinalDesignApp> {
  final DemoPlayerState player = DemoPlayerState();
  final Map<String, List<String>> answerDrafts = {};
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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: player,
      builder: (_, __) {
        if (player.loading) {
          return const Scaffold(backgroundColor: _page, body: Center(child: CircularProgressIndicator()));
        }
        final pages = [
          _Home(arabic: arabic, player: player, openTab: _openTab, openPage: _push),
          _Collection(arabic: arabic, player: player, drafts: answerDrafts),
          _Decks(arabic: arabic, player: player, openPage: _push),
          _Play(arabic: arabic, player: player, openPage: _push),
          _More(arabic: arabic, player: player, openPage: _push),
        ];
        return Directionality(
          textDirection: arabic ? TextDirection.rtl : TextDirection.ltr,
          child: Scaffold(
            backgroundColor: _page,
            appBar: AppBar(
              automaticallyImplyLeading: false,
              toolbarHeight: 66,
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              title: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _maxW),
                  child: Row(children: [
                    Container(width: 40, height: 40, decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [_blue, _purple])), child: const Icon(Icons.question_mark_rounded, color: Colors.white)),
                    const SizedBox(width: 10),
                    const Expanded(child: Text('STEAL THE QUESTIONS', style: TextStyle(color: _ink, fontSize: 14, fontWeight: FontWeight.w900))),
                    _Pill(text: '${player.ownedCount}/$kTotalCards', icon: Icons.style_rounded, color: const Color(0xFFE0A000), bg: const Color(0xFFFFF4CE)),
                    const SizedBox(width: 4),
                    IconButton(onPressed: () => setState(() => arabic = !arabic), icon: Text(arabic ? 'EN' : 'ع', style: const TextStyle(color: _blue, fontWeight: FontWeight.w900))),
                  ]),
                ),
              ),
            ),
            body: IndexedStack(index: tab, children: pages),
            bottomNavigationBar: NavigationBar(
              selectedIndex: tab,
              onDestinationSelected: _openTab,
              backgroundColor: Colors.white,
              indicatorColor: const Color(0xFFEAEFFF),
              height: 68,
              destinations: [
                NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home_rounded, color: _blue), label: arabic ? 'الرئيسية' : 'Home'),
                NavigationDestination(icon: const Icon(Icons.style_outlined), selectedIcon: const Icon(Icons.style_rounded, color: _purple), label: arabic ? 'البطاقات' : 'Cards'),
                NavigationDestination(icon: const Icon(Icons.layers_outlined), selectedIcon: const Icon(Icons.layers_rounded, color: Color(0xFFE0A000)), label: arabic ? 'المجموعات' : 'Decks'),
                NavigationDestination(icon: const Icon(Icons.sports_esports_outlined), selectedIcon: const Icon(Icons.sports_esports_rounded, color: _coral), label: arabic ? 'اللعب' : 'Play'),
                NavigationDestination(icon: const Icon(Icons.more_horiz_rounded), selectedIcon: const Icon(Icons.more_horiz_rounded, color: _blue), label: arabic ? 'المزيد' : 'More'),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openTab(int value) => setState(() => tab = value);
  void _push(Widget page) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
}

class _Home extends StatelessWidget {
  const _Home({required this.arabic, required this.player, required this.openTab, required this.openPage});
  final bool arabic;
  final DemoPlayerState player;
  final ValueChanged<int> openTab;
  final ValueChanged<Widget> openPage;

  @override
  Widget build(BuildContext context) {
    final deckCount = player.decks[player.activeDeck].length;
    return _Scroll(children: [
      Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(26), gradient: const LinearGradient(colors: [Color(0xFF4D8CFF), Color(0xFF8057F4)]), boxShadow: const [BoxShadow(color: Color(0x224C72FF), blurRadius: 18, offset: Offset(0, 8))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(arabic ? 'جاوب، اجمع، نافس... واسرق بطاقة!' : 'Answer, collect, compete... and steal a card!', style: const TextStyle(color: Colors.white, fontSize: 28, height: 1.15, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(arabic ? 'كل شيء في الصفحة الرئيسية يقودك لقرار واحد: ماذا ستلعب الآن؟' : 'Everything here helps one decision: what will you play now?', style: TextStyle(color: Colors.white.withValues(alpha: .9), fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          FilledButton.icon(onPressed: () => openTab(3), style: FilledButton.styleFrom(backgroundColor: _gold, foregroundColor: _ink), icon: const Icon(Icons.play_arrow_rounded), label: Text(arabic ? 'ابدأ اللعب' : 'PLAY NOW')),
        ]),
      ),
      const SizedBox(height: 14),
      _ResponsiveTwo(
        a: _ActionTile(icon: Icons.smart_toy_rounded, color: _blue, title: arabic ? 'ضد البوت' : 'Bot', text: arabic ? 'اجمع البطاقات الأولى بسرعة.' : 'Build your first cards quickly.', onTap: () => openPage(BrightBotPage(arabic: arabic, player: player))),
        b: _ActionTile(icon: Icons.flash_on_rounded, color: _coral, title: arabic ? 'ضد لاعب' : 'PvP', text: player.pvpUnlocked ? (arabic ? 'نافس على سرقة بطاقة.' : 'Compete to steal a card.') : (arabic ? 'يفتح عند 10 بطاقات.' : 'Unlocks at 10 cards.'), onTap: () => openTab(3)),
      ),
      const SizedBox(height: 14),
      _Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _TitleRow(arabic ? 'تقدم المجموعة' : 'Collection progress', '${player.ownedCount}/$kTotalCards'),
        const SizedBox(height: 10),
        ClipRRect(borderRadius: BorderRadius.circular(99), child: LinearProgressIndicator(value: player.ownedCount / kTotalCards, minHeight: 9, backgroundColor: const Color(0xFFE4EAF4))),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _RarityStat('EPIC', _purple, player.ownedCards.where((e) => QuestionBank.byId(e).rarity == CardRarity.epic).length, kEpicCards),
          _RarityStat('GOLD', const Color(0xFFE0A000), player.ownedCards.where((e) => QuestionBank.byId(e).rarity == CardRarity.gold).length, kGoldCards),
          _RarityStat('LEGENDARY', _coral, player.ownedCards.where((e) => QuestionBank.byId(e).rarity == CardRarity.legendary).length, kLegendaryCards),
        ]),
      ])),
      const SizedBox(height: 14),
      _Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _TitleRow(arabic ? 'المجموعة النشطة' : 'Active deck', '$deckCount/$kDeckSize'),
        const SizedBox(height: 10),
        SizedBox(height: 54, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: 10, separatorBuilder: (_, __) => const SizedBox(width: 6), itemBuilder: (_, i) {
          final id = i < deckCount ? player.decks[player.activeDeck][i] : null;
          return _MiniCard(id: id);
        })),
        const SizedBox(height: 10),
        OutlinedButton.icon(onPressed: () => openTab(2), icon: const Icon(Icons.edit_rounded), label: Text(arabic ? 'إدارة الـDecks' : 'Manage decks')),
      ])),
    ]);
  }
}

class _Collection extends StatelessWidget {
  const _Collection({required this.arabic, required this.player, required this.drafts});
  final bool arabic;
  final DemoPlayerState player;
  final Map<String, List<String>> drafts;

  @override
  Widget build(BuildContext context) {
    final owned = QuestionBank.all.where((q) => player.ownedCards.contains(q.id)).toList(growable: false);
    final locked = QuestionBank.all.where((q) => !player.ownedCards.contains(q.id)).toList(growable: false);
    return _Scroll(children: [
      _Heading(arabic ? 'بطاقاتك' : 'Your cards', arabic ? 'المملوكة أولًا. افتح أي بطاقة لرؤية السؤال والإجابة والخيارات.' : 'Owned cards first. Open any card to see the question, answer and choices.'),
      const SizedBox(height: 12),
      _Panel(child: Wrap(spacing: 34, runSpacing: 14, alignment: WrapAlignment.spaceAround, children: [
        _Count('${owned.length}', arabic ? 'مملوكة' : 'Owned', _blue),
        _Count('${locked.length}', arabic ? 'غير مملوكة' : 'Locked', _muted),
        _Count('$kTotalCards', arabic ? 'الإجمالي' : 'Total', const Color(0xFFE0A000)),
      ])),
      const SizedBox(height: 18),
      _TitleRow(arabic ? 'البطاقات المملوكة' : 'Owned cards', '${owned.length}'),
      const SizedBox(height: 8),
      if (owned.isEmpty)
        _Panel(child: Row(children: [const Icon(Icons.smart_toy_rounded, color: _blue), const SizedBox(width: 10), Expanded(child: Text(arabic ? 'ابدأ ضد البوت لتحصل على أول بطاقة.' : 'Play the bot to earn your first card.'))]))
      else
        _CardGrid(cards: owned, owned: true, onTap: (q) => _showCard(context, q)),
      const SizedBox(height: 24),
      _TitleRow(arabic ? 'لم تحصل عليها بعد' : 'Not earned yet', '${locked.length}'),
      const SizedBox(height: 6),
      Text(arabic ? 'تبقى في الأسفل ولا تعرض تفاصيل السؤال قبل امتلاكها.' : 'These stay below and hide question details until earned.', style: const TextStyle(color: _muted, fontSize: 11, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      _CardGrid(cards: locked, owned: false, onTap: (_) {}),
    ]);
  }

  void _showCard(BuildContext context, QuestionContent q) {
    final base = List<String>.from(arabic ? q.answersAr : q.answersEn);
    final extra = arabic ? q.passExtraAr : q.passExtraEn;
    final values = List<String>.from(drafts[q.id] ?? [...base, if (player.weeklyPass) extra]);
    final needed = player.weeklyPass ? 4 : 3;
    while (values.length < needed) values.add('');
    final ctrls = values.map((e) => TextEditingController(text: e)).toList();
    showDialog<void>(context: context, builder: (ctx) => Directionality(textDirection: arabic ? TextDirection.rtl : TextDirection.ltr, child: AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      title: Row(children: [
        _CardBadge(q: q), const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(q.id, style: const TextStyle(color: _ink, fontWeight: FontWeight.w900)), Text(_rarityName(q.rarity), style: TextStyle(color: _rarityColor(q.rarity), fontSize: 9, fontWeight: FontWeight.w900))])),
      ]),
      content: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('QUESTION', style: TextStyle(color: _muted, fontSize: 9, fontWeight: FontWeight.w900)),
        const SizedBox(height: 5),
        Text(arabic ? q.questionAr : q.questionEn, style: const TextStyle(color: _ink, fontSize: 18, height: 1.45, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFEAF9F2), borderRadius: BorderRadius.circular(14)), child: Row(children: [const Icon(Icons.check_circle_rounded, color: _green), const SizedBox(width: 8), Expanded(child: Text(base[q.correctIndex], style: const TextStyle(color: _ink, fontWeight: FontWeight.w900)))])),
        const SizedBox(height: 14),
        Text(arabic ? 'الخيارات المسموحة' : 'Allowed choices', style: const TextStyle(color: _ink, fontSize: 15, fontWeight: FontWeight.w900)),
        const SizedBox(height: 5),
        Text(arabic ? 'الإجابة الصحيحة ثابتة. غيّر الخيارات الأخرى للمعاينة فقط؛ بنك الأسئلة لم نلمسه بعد.' : 'The correct answer stays fixed. Other choices are preview-only; the question bank is untouched.', style: const TextStyle(color: _muted, fontSize: 10, height: 1.4)),
        const SizedBox(height: 9),
        ...List.generate(ctrls.length, (i) => Padding(padding: const EdgeInsets.only(bottom: 8), child: TextField(controller: ctrls[i], readOnly: i == q.correctIndex, decoration: InputDecoration(filled: true, fillColor: i == q.correctIndex ? const Color(0xFFEAF9F2) : const Color(0xFFF6F8FC), prefixIcon: Icon(i == q.correctIndex ? Icons.check_rounded : Icons.edit_rounded, color: i == q.correctIndex ? _green : _blue), labelText: i == q.correctIndex ? (arabic ? 'الإجابة الصحيحة' : 'Correct answer') : '${arabic ? 'خيار' : 'Choice'} ${i + 1}${i == 3 ? ' · Weekly Pass' : ''}', border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none))))),
        if (!player.weeklyPass) Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFFFFF5D5), borderRadius: BorderRadius.circular(12)), child: Text(arabic ? 'الخيار الرابع يظهر فقط للمشترك في Weekly Pass.' : 'The fourth choice appears only with Weekly Pass.', style: const TextStyle(color: _ink, fontSize: 10, fontWeight: FontWeight.w800))),
      ]))),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(arabic ? 'إلغاء' : 'Cancel')), FilledButton(onPressed: () { drafts[q.id] = ctrls.map((c) => c.text.trim()).toList(); Navigator.pop(ctx); }, child: Text(arabic ? 'حفظ للمعاينة' : 'Save preview'))],
    )));
  }
}

class _Decks extends StatelessWidget {
  const _Decks({required this.arabic, required this.player, required this.openPage});
  final bool arabic;
  final DemoPlayerState player;
  final ValueChanged<Widget> openPage;
  @override
  Widget build(BuildContext context) {
    return _Scroll(children: [
      _Heading(arabic ? 'مجموعات اللعب' : 'Decks', arabic ? 'اختر Deck نشطًا وعدّل بطاقاته. كل Deck صالح = 10 بطاقات مختلفة.' : 'Pick an active deck and edit it. A valid deck has 10 distinct cards.'),
      const SizedBox(height: 14),
      ...List.generate(kMaxDeckSlots, (i) {
        final unlocked = i < player.deckSlots;
        final active = i == player.activeDeck;
        final count = player.decks[i].length;
        return Padding(padding: const EdgeInsets.only(bottom: 10), child: _Panel(child: Column(children: [
          Row(children: [
            Container(width: 44, height: 44, decoration: BoxDecoration(color: unlocked ? const Color(0xFFEDE8FF) : const Color(0xFFF0F2F6), borderRadius: BorderRadius.circular(13)), child: Icon(unlocked ? Icons.layers_rounded : Icons.lock_rounded, color: unlocked ? _purple : _muted)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Text('${arabic ? 'المجموعة' : 'Deck'} ${i + 1}', style: const TextStyle(color: _ink, fontSize: 15, fontWeight: FontWeight.w900)), if (active) ...[const SizedBox(width: 7), _Pill(text: arabic ? 'نشطة' : 'ACTIVE', color: _green, bg: const Color(0xFFEAF9F2))]]), Text(unlocked ? '$count/$kDeckSize' : 'Weekly Pass', style: const TextStyle(color: _muted, fontSize: 10, fontWeight: FontWeight.w700))])),
            if (unlocked) OutlinedButton(onPressed: () { player.setActiveDeck(i); }, child: Text(active ? (arabic ? 'مختارة' : 'Selected') : (arabic ? 'اختيار' : 'Select'))) else const Icon(Icons.workspace_premium_rounded, color: Color(0xFFE0A000)),
          ]),
          if (unlocked) ...[const SizedBox(height: 10), Align(alignment: AlignmentDirectional.centerStart, child: FilledButton.icon(onPressed: () => openPage(BrightDeckBuilderPage(arabic: arabic, player: player, deckIndex: i)), icon: const Icon(Icons.edit_rounded), label: Text(arabic ? 'تعديل البطاقات' : 'Edit cards')))],
        ])));
      }),
    ]);
  }
}

class _Play extends StatelessWidget {
  const _Play({required this.arabic, required this.player, required this.openPage});
  final bool arabic;
  final DemoPlayerState player;
  final ValueChanged<Widget> openPage;
  @override
  Widget build(BuildContext context) {
    final deckCount = player.decks[player.activeDeck].length;
    return _Scroll(children: [
      _Heading(arabic ? 'اختر طريقة اللعب' : 'Choose how to play', arabic ? 'اعرف حالة حسابك وDeck قبل بدء أي جولة.' : 'See your account and deck readiness before starting.'),
      const SizedBox(height: 12),
      _Panel(child: Row(children: [const Icon(Icons.layers_rounded, color: _purple), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${arabic ? 'Deck النشط' : 'Active deck'} ${player.activeDeck + 1}', style: const TextStyle(color: _ink, fontWeight: FontWeight.w900)), Text('$deckCount/$kDeckSize', style: TextStyle(color: player.activeDeckReady ? _green : _coral, fontWeight: FontWeight.w900))]))])),
      const SizedBox(height: 12),
      _PlayCard(icon: Icons.smart_toy_rounded, colors: const [Color(0xFF45A9FF), Color(0xFF2E6BFF)], title: arabic ? 'العب ضد البوت' : 'Play vs Bot', text: arabic ? 'قبل 10 بطاقات: إجابة صحيحة تمنح بطاقة جديدة.' : 'Before 10 cards: a correct answer earns a new card.', onTap: () => openPage(BrightBotPage(arabic: arabic, player: player))),
      const SizedBox(height: 12),
      _PlayCard(icon: Icons.flash_on_rounded, colors: const [Color(0xFFFF7B73), Color(0xFFFF4F87)], title: arabic ? 'العب ضد لاعب' : 'Play PvP', text: !player.pvpUnlocked ? (arabic ? 'مقفل حتى تمتلك 10 بطاقات.' : 'Locked until you own 10 cards.') : !player.activeDeckReady ? (arabic ? 'أكمل الـDeck النشط إلى 10 بطاقات.' : 'Complete the active deck to 10 cards.') : !player.authenticated ? (arabic ? 'سجّل الدخول أولًا.' : 'Sign in first.') : (arabic ? 'جاهز: 7 أسئلة، ثم الفائز يسرق بطاقة.' : 'Ready: 7 questions, then the winner steals a card.'), onTap: () async {
        if (!player.authenticated) { openPage(BrightAuthPage(arabic: arabic, player: player)); return; }
        if (!player.pvpUnlocked || !player.activeDeckReady) return;
        try {
          final r = await player.findOrCreateDuel();
          openPage(BrightDuelPage(arabic: arabic, player: player, duelId: r['duelId'] as String));
        } catch (e) {
          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
        }
      }),
      const SizedBox(height: 14),
      _Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(arabic ? 'قواعد سريعة' : 'Quick rules', style: const TextStyle(color: _ink, fontWeight: FontWeight.w900)), const SizedBox(height: 8), ...[(arabic ? '• Deck من 10 بطاقات' : '• 10-card deck'), (arabic ? '• 7 أسئلة × 20 ثانية' : '• 7 questions × 20 seconds'), (arabic ? '• الأكثر صحيحًا يفوز' : '• Most correct answers wins'), (arabic ? '• التعادل يحسم بالوقت' : '• Time breaks ties'), (arabic ? '• الفائز يسرق بطاقة' : '• Winner steals one card')].map((e) => Padding(padding: const EdgeInsets.only(bottom: 5), child: Text(e, style: const TextStyle(color: _muted, fontWeight: FontWeight.w700))))])),
    ]);
  }
}

class _More extends StatelessWidget {
  const _More({required this.arabic, required this.player, required this.openPage});
  final bool arabic;
  final DemoPlayerState player;
  final ValueChanged<Widget> openPage;
  @override
  Widget build(BuildContext context) => _Scroll(children: [
    _Heading(arabic ? 'المزيد' : 'More', arabic ? 'الحساب والتصنيف والاشتراك وشرح اللعبة في مكان واحد.' : 'Account, ranking, pass and help in one place.'),
    const SizedBox(height: 14),
    _Panel(child: Column(children: [
      _Menu(icon: Icons.person_rounded, title: arabic ? 'الحساب' : 'Account', subtitle: player.authenticated ? player.accountLabel : (arabic ? 'غير مسجل' : 'Not signed in'), onTap: () => openPage(BrightAuthPage(arabic: arabic, player: player))),
      const Divider(height: 22),
      _Menu(icon: Icons.emoji_events_rounded, title: arabic ? 'التصنيف' : 'Ranking', subtitle: arabic ? 'البطاقات أولًا ثم الانتصارات' : 'Cards first, then wins', onTap: () => openPage(BrightRankingPage(arabic: arabic, player: player))),
      const Divider(height: 22),
      _Menu(icon: Icons.workspace_premium_rounded, title: 'Weekly Pass', subtitle: arabic ? '3 Decks إضافية + خيار رابع' : '3 extra decks + fourth choice', onTap: () => openPage(BrightPassPage(arabic: arabic, player: player))),
      const Divider(height: 22),
      _Menu(icon: Icons.help_outline_rounded, title: arabic ? 'كيف تعمل اللعبة؟' : 'How it works', subtitle: arabic ? 'المسار الكامل في أقل من دقيقة' : 'The full loop in under a minute', onTap: () => openPage(BrightHowItWorksPage(arabic: arabic))),
    ])),
  ]);
}

class BrightDeckBuilderPage extends StatelessWidget {
  const BrightDeckBuilderPage({super.key, required this.arabic, required this.player, required this.deckIndex});
  final bool arabic;
  final DemoPlayerState player;
  final int deckIndex;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation: player, builder: (_, __) {
    final owned = QuestionBank.all.where((q) => player.ownedCards.contains(q.id)).toList(growable: false);
    final deck = player.decks[deckIndex];
    return _Shell(title: '${arabic ? 'تعديل المجموعة' : 'Edit deck'} ${deckIndex + 1}', arabic: arabic, child: _ScrollBody(children: [
      _Panel(child: Row(children: [Icon(deck.length == 10 ? Icons.check_circle_rounded : Icons.layers_rounded, color: deck.length == 10 ? _green : _purple), const SizedBox(width: 9), Expanded(child: Text(arabic ? 'اختر 10 بطاقات مختلفة من بطاقاتك.' : 'Choose 10 distinct owned cards.', style: const TextStyle(color: _ink, fontWeight: FontWeight.w900))), Text('${deck.length}/10', style: const TextStyle(color: _blue, fontWeight: FontWeight.w900))])),
      const SizedBox(height: 12),
      if (owned.isEmpty) _Panel(child: Text(arabic ? 'لا توجد بطاقات مملوكة بعد.' : 'No owned cards yet.')) else _CardGrid(cards: owned, owned: true, selected: deck.toSet(), onTap: (q) => player.toggleCardInDeck(q.id)),
      const SizedBox(height: 12),
      Row(children: [Expanded(child: OutlinedButton(onPressed: deck.isEmpty ? null : () => player.clearDeck(deckIndex), child: Text(arabic ? 'مسح الكل' : 'Clear all'))), const SizedBox(width: 10), Expanded(child: FilledButton(onPressed: deck.length == 10 ? () async { await player.saveDeck(deckIndex); if (context.mounted) Navigator.pop(context); } : null, child: Text(arabic ? 'حفظ الـDeck' : 'Save deck')))]),
    ]));
  });
}

class BrightBotPage extends StatefulWidget {
  const BrightBotPage({super.key, required this.arabic, required this.player});
  final bool arabic;
  final DemoPlayerState player;
  @override
  State<BrightBotPage> createState() => _BrightBotPageState();
}

class _BrightBotPageState extends State<BrightBotPage> {
  BotRoundData? round;
  Timer? timer;
  int seconds = 20;
  bool busy = true;
  bool answered = false;
  bool correct = false;
  int? selected;
  String error = '';
  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { timer?.cancel(); super.dispose(); }
  Future<void> _load() async {
    timer?.cancel();
    setState(() { busy = true; answered = false; selected = null; correct = false; seconds = 20; error = ''; });
    try {
      final r = await widget.player.startBotRound(arabic: widget.arabic);
      if (!mounted) return;
      setState(() { round = r; busy = false; });
      timer = Timer.periodic(const Duration(seconds: 1), (_) { if (!mounted || answered) return; if (seconds <= 1) _answer(-1); else setState(() => seconds--); });
    } catch (e) { if (mounted) setState(() { busy = false; error = e.toString().replaceFirst('Bad state: ', ''); }); }
  }
  Future<void> _answer(int index) async {
    if (answered || round == null) return;
    timer?.cancel();
    setState(() { answered = true; selected = index; });
    final ok = await widget.player.completeBotRound(round: round!, answerIndex: index);
    if (mounted) setState(() => correct = ok);
  }
  @override
  Widget build(BuildContext context) {
    if (busy) return _Shell(title: widget.arabic ? 'جولة البوت' : 'Bot round', arabic: widget.arabic, child: const Center(child: CircularProgressIndicator()));
    if (round == null) return _Shell(title: widget.arabic ? 'جولة البوت' : 'Bot round', arabic: widget.arabic, child: Center(child: Padding(padding: const EdgeInsets.all(30), child: Text(error))));
    final q = QuestionBank.byId(round!.questionId);
    final answers = q.answers(arabic: widget.arabic, weeklyPass: widget.player.weeklyPass);
    return _Shell(title: widget.arabic ? 'جولة البوت' : 'Bot round', arabic: widget.arabic, child: _ScrollBody(children: [
      Row(children: [Expanded(child: LinearProgressIndicator(value: seconds / 20, minHeight: 8, backgroundColor: const Color(0xFFE5EAF3))), const SizedBox(width: 10), _Pill(text: '${seconds}s', color: seconds <= 5 ? _coral : _blue, bg: const Color(0xFFEAF0FF))]),
      const SizedBox(height: 14),
      _Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${q.id} · ${widget.arabic ? q.categoryAr : q.categoryEn}', style: const TextStyle(color: _purple, fontSize: 10, fontWeight: FontWeight.w900)), const SizedBox(height: 8), Text(widget.arabic ? q.questionAr : q.questionEn, style: const TextStyle(color: _ink, fontSize: 20, height: 1.45, fontWeight: FontWeight.w900))])),
      const SizedBox(height: 12),
      ...List.generate(answers.length, (i) => Padding(padding: const EdgeInsets.only(bottom: 8), child: _Answer(text: answers[i], onTap: answered ? null : () => _answer(i), state: !answered ? 0 : i == q.correctIndex ? 2 : selected == i ? 3 : 1))),
      if (answered) ...[const SizedBox(height: 8), Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: correct ? const Color(0xFFEAF9F2) : const Color(0xFFFFEEEE), borderRadius: BorderRadius.circular(14)), child: Row(children: [Icon(correct ? Icons.celebration_rounded : Icons.info_outline_rounded, color: correct ? _green : _coral), const SizedBox(width: 9), Expanded(child: Text(correct ? (widget.arabic ? 'إجابة صحيحة — حصلت على بطاقة جديدة.' : 'Correct — you earned a new card.') : (widget.arabic ? 'لم تحصل على بطاقة في هذه الجولة.' : 'No card earned this round.'), style: const TextStyle(color: _ink, fontWeight: FontWeight.w900)))])), const SizedBox(height: 10), FilledButton.icon(onPressed: widget.player.pvpUnlocked ? () => Navigator.pop(context) : _load, icon: const Icon(Icons.arrow_forward_rounded), label: Text(widget.player.pvpUnlocked ? (widget.arabic ? 'تم فتح PvP' : 'PvP unlocked') : (widget.arabic ? 'جولة أخرى' : 'Next round')))],
    ]));
  }
}

class BrightAuthPage extends StatefulWidget {
  const BrightAuthPage({super.key, required this.arabic, required this.player});
  final bool arabic;
  final DemoPlayerState player;
  @override
  State<BrightAuthPage> createState() => _BrightAuthPageState();
}
class _BrightAuthPageState extends State<BrightAuthPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool create = false, busy = false;
  String error = '';
  @override void dispose(){email.dispose(); password.dispose(); super.dispose();}
  @override Widget build(BuildContext context) => _Shell(title: widget.arabic ? 'الحساب' : 'Account', arabic: widget.arabic, child: _ScrollBody(children: [
    _Heading(widget.player.authenticated ? (widget.arabic ? 'أنت مسجل الدخول' : 'You are signed in') : (create ? (widget.arabic ? 'إنشاء حساب' : 'Create account') : (widget.arabic ? 'تسجيل الدخول' : 'Sign in')), widget.player.authenticated ? widget.player.accountLabel : (widget.arabic ? 'الحساب مطلوب فقط للـPvP والتصنيف والمزامنة.' : 'An account is only required for PvP, ranking and sync.')),
    const SizedBox(height: 14),
    if (widget.player.authenticated) _Panel(child: Column(children: [const Icon(Icons.verified_user_rounded, color: _green, size: 44), const SizedBox(height: 10), Text(widget.player.accountLabel, style: const TextStyle(color: _ink, fontWeight: FontWeight.w900)), const SizedBox(height: 12), OutlinedButton(onPressed: () async { await widget.player.signOut(); if(context.mounted) Navigator.pop(context); }, child: Text(widget.arabic ? 'تسجيل الخروج' : 'Sign out'))])) else ...[
      TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(labelText: widget.arabic ? 'البريد الإلكتروني' : 'Email', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _line)))),
      const SizedBox(height: 10),
      TextField(controller: password, obscureText: true, decoration: InputDecoration(labelText: widget.arabic ? 'كلمة المرور' : 'Password', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _line)))),
      if (error.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text(error, style: const TextStyle(color: _coral))),
      const SizedBox(height: 12),
      FilledButton(onPressed: busy ? null : () async { setState(() {busy=true; error='';}); try { if(create) await widget.player.signUp(email.text,password.text); else await widget.player.signIn(email.text,password.text); if(context.mounted) Navigator.pop(context); } catch(e){ if(mounted) setState(()=>error=e.toString()); } finally { if(mounted) setState(()=>busy=false); } }, child: Text(create ? (widget.arabic ? 'إنشاء الحساب' : 'Create account') : (widget.arabic ? 'دخول' : 'Sign in'))),
      TextButton(onPressed: () => setState(() => create = !create), child: Text(create ? (widget.arabic ? 'لدي حساب بالفعل' : 'I already have an account') : (widget.arabic ? 'إنشاء حساب جديد' : 'Create a new account'))),
    ],
  ]));
}

class BrightRankingPage extends StatelessWidget {
  const BrightRankingPage({super.key, required this.arabic, required this.player});
  final bool arabic; final DemoPlayerState player;
  @override Widget build(BuildContext context) => _Shell(title: arabic ? 'التصنيف' : 'Ranking', arabic: arabic, child: !player.authenticated ? _NeedLogin(arabic: arabic) : FutureBuilder<List<Map<String,dynamic>>>(future: player.loadRanking(), builder: (_, snap){
    if(!snap.hasData && !snap.hasError) return const Center(child:CircularProgressIndicator());
    if(snap.hasError) return Center(child:Text(snap.error.toString()));
    final rows=snap.data!;
    return _ScrollBody(children:[_Heading(arabic?'التصنيف العالمي':'Global ranking',arabic?'البطاقات أولًا، ثم الانتصارات، ثم الخسائر الأقل.':'Cards first, then wins, then fewer losses.'),const SizedBox(height:12),...List.generate(rows.length,(i){final r=rows[i];return Padding(padding:const EdgeInsets.only(bottom:8),child:_Panel(child:Row(children:[Container(width:36,height:36,decoration:BoxDecoration(color:i<3?const Color(0xFFFFF2C8):const Color(0xFFEAF0FF),borderRadius:BorderRadius.circular(11)),child:Center(child:Text('${i+1}',style:TextStyle(color:i<3?const Color(0xFFE0A000):_blue,fontWeight:FontWeight.w900)))),const SizedBox(width:10),Expanded(child:Text((r['displayName']??r['email']??r['uid']??'Player').toString(),overflow:TextOverflow.ellipsis,style:const TextStyle(color:_ink,fontWeight:FontWeight.w900))),_Pill(text:'${r['ownedCount']??r['cards']??0}',icon:Icons.style_rounded,color:_purple,bg:const Color(0xFFF0EAFE)),const SizedBox(width:6),_Pill(text:'${r['wins']??0}',icon:Icons.emoji_events_rounded,color:_green,bg:const Color(0xFFEAF9F2))])));})]);
  }));
}

class BrightPassPage extends StatelessWidget {
  const BrightPassPage({super.key, required this.arabic, required this.player}); final bool arabic; final DemoPlayerState player;
  @override Widget build(BuildContext context)=>_Shell(title:'Weekly Pass',arabic:arabic,child:_ScrollBody(children:[
    Container(padding:const EdgeInsets.all(22),decoration:BoxDecoration(gradient:const LinearGradient(colors:[Color(0xFFFFD55C),Color(0xFFFFA94D)]),borderRadius:BorderRadius.circular(24)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Icon(Icons.workspace_premium_rounded,color:Colors.white,size:44),const SizedBox(height:12),Text(arabic?'اشتراك أسبوعي بسيط وواضح':'A simple weekly upgrade',style:const TextStyle(color:Colors.white,fontSize:24,fontWeight:FontWeight.w900)),const SizedBox(height:6),Text(arabic?'لا يغيّر قوة السؤال، بل يعطي مرونة أكثر في اللعب.':'It does not make questions stronger; it gives more flexibility.',style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w700))])),
    const SizedBox(height:14),
    _Panel(child:Column(children:[_Feature(Icons.layers_rounded,arabic?'5 Decks بدل 2':'5 decks instead of 2'),const Divider(height:22),_Feature(Icons.add_circle_outline_rounded,arabic?'خيار إجابة رابع':'A fourth answer choice')])),
    const SizedBox(height:14),
    Container(padding:const EdgeInsets.all(13),decoration:BoxDecoration(color:const Color(0xFFFFF6DC),borderRadius:BorderRadius.circular(14)),child:Text(arabic?'إعدادات الشراء الفعلية مؤجلة لمرحلة المتجر حسب خطة المشروع.':'Real purchase wiring stays deferred to the store phase as planned.',style:const TextStyle(color:_ink,fontWeight:FontWeight.w800))),
  ]));
}

class BrightHowItWorksPage extends StatelessWidget {
  const BrightHowItWorksPage({super.key, required this.arabic}); final bool arabic;
  @override Widget build(BuildContext context)=>_Shell(title:arabic?'كيف تعمل اللعبة؟':'How it works',arabic:arabic,child:_ScrollBody(children:[
    _Heading(arabic?'اللعبة في 6 خطوات':'The game in 6 steps',arabic?'مسار واضح من أول سؤال إلى أول سرقة بطاقة.':'A clear path from your first question to your first stolen card.'),const SizedBox(height:14),
    _Step(1,Icons.smart_toy_rounded,arabic?'ابدأ ضد البوت':'Start vs Bot',arabic?'اجب بشكل صحيح لتحصل على بطاقاتك الأولى.':'Answer correctly to earn your first cards.'),
    _Step(2,Icons.style_rounded,arabic?'اجمع 10 بطاقات':'Collect 10 cards',arabic?'بعد 10 بطاقات يفتح PvP.':'PvP unlocks at 10 cards.'),
    _Step(3,Icons.layers_rounded,arabic?'كوّن Deck':'Build a deck',arabic?'اختر 10 بطاقات مختلفة مملوكة.':'Choose 10 distinct owned cards.'),
    _Step(4,Icons.flash_on_rounded,arabic?'ادخل المواجهة':'Enter a duel',arabic?'الخادم يختار 7 بطاقات من Deck الخصم لأسئلتك.':'The server selects 7 opponent-deck cards for your questions.'),
    _Step(5,Icons.timer_rounded,arabic?'جاوب بسرعة ودقة':'Answer fast and accurately',arabic?'الأكثر صحيحًا يفوز والتعادل يحسم بالوقت.':'Most correct wins; time breaks ties.'),
    _Step(6,Icons.front_hand_rounded,arabic?'اسرق بطاقة':'Steal a card',arabic?'الفائز يختار بطاقة واحدة من Deck الخصم.':'The winner chooses one card from the opponent deck.'),
  ]));
}

class BrightDuelPage extends StatefulWidget {
  const BrightDuelPage({super.key, required this.arabic, required this.player, required this.duelId});
  final bool arabic; final DemoPlayerState player; final String duelId;
  @override State<BrightDuelPage> createState()=>_BrightDuelPageState();
}
class _BrightDuelPageState extends State<BrightDuelPage>{
  Timer? poll; Map<String,dynamic>? duel; bool sending=false; int? slot; Map<String,dynamic>? reveal; bool stolen=false;
  @override void initState(){super.initState();_load();poll=Timer.periodic(const Duration(seconds:1),(_)=>_load());}
  @override void dispose(){poll?.cancel();super.dispose();}
  String get role{final uid=widget.player.api?.currentUser?.uid;return duel?['p1Uid']==uid?'p1':'p2';}
  int get mine=>(duel?[role=='p1'?'p1AnsweredCount':'p2AnsweredCount'] as num?)?.toInt()??0;
  int get other=>(duel?[role=='p1'?'p2AnsweredCount':'p1AnsweredCount'] as num?)?.toInt()??0;
  Future<void> _load()async{try{final d=await widget.player.api!.getDuelState(widget.duelId);if(!mounted)return;setState(()=>duel=d);final started=d['startedAt'];DateTime? t;if(started is Timestamp)t=started.toDate();if(d['status']=='playing'&&t!=null&&DateTime.now().difference(t).inSeconds>=kQuestionPhaseSeconds)await widget.player.api!.resolveDuel(widget.duelId);}catch(_){}}
  @override Widget build(BuildContext context){
    if(duel==null)return _Shell(title:'TROLL DUEL',arabic:widget.arabic,child:const Center(child:CircularProgressIndicator()));
    final status=duel!['status']?.toString()??'searching';
    if(status=='searching')return _Shell(title:'TROLL DUEL',arabic:widget.arabic,child:Center(child:Column(mainAxisSize:MainAxisSize.min,children:[const CircularProgressIndicator(),const SizedBox(height:16),Text(widget.arabic?'نبحث عن خصم مناسب...':'Searching for an opponent...',style:const TextStyle(color:_ink,fontSize:18,fontWeight:FontWeight.w900)),const SizedBox(height:6),Text(widget.arabic?'ابق في الشاشة، ستبدأ المواجهة تلقائيًا.':'Stay here; the duel starts automatically.',style:const TextStyle(color:_muted))])));
    final result=duel!['result']?.toString(); if(result!=null&&result!='playing')return _result(result);
    final raw=duel![role=='p1'?'questionsP1':'questionsP2'] as List???const[]; final qs=raw.map((e)=>Map<String,dynamic>.from(e as Map)).toList(); final idx=min(mine,qs.isEmpty?0:qs.length-1); final q=qs.isEmpty?null:qs[idx];
    return _Shell(title:'TROLL DUEL',arabic:widget.arabic,child:_ScrollBody(children:[
      Row(children:[Expanded(child:_Progress(label:widget.arabic?'أنت':'YOU',value:mine)),const SizedBox(width:10),Expanded(child:_Progress(label:widget.arabic?'الخصم':'OPPONENT',value:other))]),
      const SizedBox(height:14),
      _Heading('${widget.arabic?'السؤال':'Question'} ${mine+1}/7',widget.arabic?'سؤال من Deck خصمك. لا تضيع الوقت.':'A question from your opponent deck. Time matters.'),
      const SizedBox(height:12),
      if(q==null)const Center(child:CircularProgressIndicator())else _duelQuestion(q),
    ]));
  }
  Widget _duelQuestion(Map<String,dynamic>q){final text=(q[widget.arabic?'questionAr':'questionEn']??'').toString();final a=List<String>.from(q[widget.arabic?'answersAr':'answersEn'] as List???const[]);final fourth=q[widget.arabic?'fourthAr':'fourthEn']?.toString();if(widget.player.weeklyPass&&fourth!=null&&fourth.isNotEmpty)a.add(fourth);return Column(children:[_Panel(child:Text(text,style:const TextStyle(color:_ink,fontSize:19,height:1.45,fontWeight:FontWeight.w900))),const SizedBox(height:10),...List.generate(a.length,(i)=>Padding(padding:const EdgeInsets.only(bottom:8),child:_Answer(text:a[i],state:0,onTap:sending?null:()async{setState(()=>sending=true);try{await widget.player.api!.submitDuelAnswer(duelId:widget.duelId,questionIndex:mine,answerIndex:i);await _load();}finally{if(mounted)setState(()=>sending=false);}}))) ]);}
  Widget _result(String result){final uid=widget.player.api?.currentUser?.uid;final won=duel!['winnerUid']==uid;final draw=result=='draw';return _Shell(title:widget.arabic?'النتيجة':'Result',arabic:widget.arabic,child:_ScrollBody(children:[Container(padding:const EdgeInsets.all(18),decoration:BoxDecoration(color:draw?const Color(0xFFF0F2F6):won?const Color(0xFFEAF9F2):const Color(0xFFFFEEEE),borderRadius:BorderRadius.circular(18)),child:Text(draw?(widget.arabic?'تعادل — لا توجد سرقة.':'Draw — no steal.'):won?(widget.arabic?'فزت! اختر بطاقة لتسرقها.':'You won! Choose a card to steal.'):(widget.arabic?'خسرت هذه المواجهة.':'You lost this duel.'),style:const TextStyle(color:_ink,fontSize:18,fontWeight:FontWeight.w900))),const SizedBox(height:12),if(won&&!stolen)_steal(),if(!won||draw)FilledButton(onPressed:()=>Navigator.pop(context),child:Text(widget.arabic?'العودة':'Back')),if(stolen)FilledButton(onPressed:()=>Navigator.pop(context),child:Text(widget.arabic?'تمت السرقة — العودة':'Stolen — back'))]));}
  Widget _steal()=>_Panel(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(widget.arabic?'اختر خانة واحدة من Deck الخصم':'Choose one opponent-deck slot',style:const TextStyle(color:_ink,fontWeight:FontWeight.w900)),const SizedBox(height:10),Wrap(spacing:8,runSpacing:8,children:List.generate(10,(i)=>ChoiceChip(label:Text('${i+1}'),selected:slot==i,onSelected:(_)=>setState(()=>slot=i)))),const SizedBox(height:10),OutlinedButton(onPressed:slot==null?null:()async{final r=await widget.player.api!.revealStealTarget(duelId:widget.duelId,slotIndex:slot!);if(mounted)setState(()=>reveal=r);},child:Text(widget.arabic?'كشف البطاقة':'Reveal card')),if(reveal!=null)...[const SizedBox(height:8),Container(width:double.infinity,padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:const Color(0xFFF6F8FC),borderRadius:BorderRadius.circular(12)),child:Text('${reveal!['cardId']} · ${(reveal!['rarity']??'').toString().toUpperCase()}',style:const TextStyle(color:_ink,fontWeight:FontWeight.w900))),const SizedBox(height:8),FilledButton(onPressed:()async{await widget.player.api!.confirmSteal(widget.duelId);await _refresh(widget.player);if(mounted)setState(()=>stolen=true);},child:Text(widget.arabic?'تأكيد السرقة':'Confirm steal'))]]));
}

Future<void> _refresh(DemoPlayerState player) async {
  if (!player.authenticated || player.api == null) return;
  try {
    final d = await player.api!.loadProfile();
    player.ownedCards..clear()..addAll(List<String>.from(d['ownedCards'] as List? ?? const []));
    final ds = d['decks'] as List? ?? const [];
    for (var i=0;i<kMaxDeckSlots;i++){player.decks[i]..clear()..addAll(i<ds.length?List<String>.from(ds[i] as List? ?? const []):const[]);} 
    player.wins=(d['wins'] as num?)?.toInt()??player.wins; player.losses=(d['losses'] as num?)?.toInt()??player.losses; player.activeDeck=((d['activeDeck'] as num?)?.toInt()??player.activeDeck).clamp(0,kMaxDeckSlots-1); player.notifyListeners();
  } catch (_) {}
}

class _Shell extends StatelessWidget { const _Shell({required this.title,required this.arabic,required this.child}); final String title; final bool arabic; final Widget child; @override Widget build(BuildContext context)=>Directionality(textDirection:arabic?TextDirection.rtl:TextDirection.ltr,child:Scaffold(backgroundColor:_page,appBar:AppBar(title:Text(title,style:const TextStyle(color:_ink,fontWeight:FontWeight.w900)),backgroundColor:Colors.white,surfaceTintColor:Colors.white),body:child)); }
class _Scroll extends StatelessWidget { const _Scroll({required this.children}); final List<Widget>children; @override Widget build(BuildContext context)=>SingleChildScrollView(child:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:_maxW),child:Padding(padding:const EdgeInsets.fromLTRB(16,16,16,28),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:children))))); }
class _ScrollBody extends StatelessWidget { const _ScrollBody({required this.children}); final List<Widget>children; @override Widget build(BuildContext context)=>SingleChildScrollView(child:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:_maxW),child:Padding(padding:const EdgeInsets.fromLTRB(16,16,16,28),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:children))))); }
class _Panel extends StatelessWidget { const _Panel({required this.child}); final Widget child; @override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(20),border:Border.all(color:_line),boxShadow:const[BoxShadow(color:Color(0x09183153),blurRadius:10,offset:Offset(0,4))]),child:child); }
class _Heading extends StatelessWidget { const _Heading(this.title,this.subtitle); final String title,subtitle; @override Widget build(BuildContext context)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(color:_ink,fontSize:25,fontWeight:FontWeight.w900)),const SizedBox(height:4),Text(subtitle,style:const TextStyle(color:_muted,fontSize:11,height:1.4,fontWeight:FontWeight.w600))]); }
class _TitleRow extends StatelessWidget { const _TitleRow(this.title,[this.trailing]); final String title; final String?trailing; @override Widget build(BuildContext context)=>Row(children:[Expanded(child:Text(title,style:const TextStyle(color:_ink,fontSize:16,fontWeight:FontWeight.w900))),if(trailing!=null)Text(trailing!,style:const TextStyle(color:_blue,fontSize:12,fontWeight:FontWeight.w900))]); }
class _Pill extends StatelessWidget { const _Pill({required this.text,this.icon,required this.color,required this.bg}); final String text; final IconData?icon; final Color color,bg; @override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.symmetric(horizontal:9,vertical:6),decoration:BoxDecoration(color:bg,borderRadius:BorderRadius.circular(999)),child:Row(mainAxisSize:MainAxisSize.min,children:[if(icon!=null)...[Icon(icon,size:14,color:color),const SizedBox(width:4)],Text(text,style:TextStyle(color:color,fontSize:9,fontWeight:FontWeight.w900))])); }
class _Count extends StatelessWidget { const _Count(this.value,this.label,this.color); final String value,label; final Color color; @override Widget build(BuildContext context)=>SizedBox(width:120,child:Column(children:[Text(value,style:TextStyle(color:color,fontSize:21,fontWeight:FontWeight.w900)),Text(label,style:const TextStyle(color:_muted,fontSize:10,fontWeight:FontWeight.w700))])); }
class _RarityStat extends StatelessWidget { const _RarityStat(this.name,this.color,this.value,this.total); final String name; final Color color; final int value,total; @override Widget build(BuildContext context)=>Container(width:155,padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:color.withValues(alpha:.1),borderRadius:BorderRadius.circular(14)),child:Row(children:[Expanded(child:Text(name,style:TextStyle(color:color,fontSize:9,fontWeight:FontWeight.w900))),Text('$value/$total',style:const TextStyle(color:_ink,fontWeight:FontWeight.w900))])); }
class _ResponsiveTwo extends StatelessWidget { const _ResponsiveTwo({required this.a,required this.b}); final Widget a,b; @override Widget build(BuildContext context)=>LayoutBuilder(builder:(_,c)=>c.maxWidth>620?Row(children:[Expanded(child:a),const SizedBox(width:10),Expanded(child:b)]):Column(children:[a,const SizedBox(height:10),b])); }
class _ActionTile extends StatelessWidget { const _ActionTile({required this.icon,required this.color,required this.title,required this.text,required this.onTap}); final IconData icon; final Color color; final String title,text; final VoidCallback onTap; @override Widget build(BuildContext context)=>Material(color:Colors.transparent,child:InkWell(onTap:onTap,borderRadius:BorderRadius.circular(20),child:Ink(padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(20),border:Border.all(color:_line)),child:Row(children:[Container(width:44,height:44,decoration:BoxDecoration(color:color.withValues(alpha:.12),borderRadius:BorderRadius.circular(13)),child:Icon(icon,color:color)),const SizedBox(width:11),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(color:_ink,fontSize:15,fontWeight:FontWeight.w900)),Text(text,style:const TextStyle(color:_muted,fontSize:10,height:1.35))])),const Icon(Icons.chevron_right_rounded,color:_muted)])))); }
class _MiniCard extends StatelessWidget { const _MiniCard({this.id}); final String?id; @override Widget build(BuildContext context){final q=id==null?null:QuestionBank.byId(id!);final color=q==null?const Color(0xFFDCE3EE):_rarityColor(q.rarity);return Container(width:40,decoration:BoxDecoration(color:q==null?const Color(0xFFEDF1F7):color,borderRadius:BorderRadius.circular(9)),child:Center(child:Text(id==null?'+':id!.replaceFirst('Q',''),style:TextStyle(color:id==null?_muted:Colors.white,fontSize:8,fontWeight:FontWeight.w900))));}}
class _CardGrid extends StatelessWidget { const _CardGrid({required this.cards,required this.owned,required this.onTap,this.selected=const{}}); final List<QuestionContent>cards; final bool owned; final ValueChanged<QuestionContent>onTap; final Set<String>selected; @override Widget build(BuildContext context)=>LayoutBuilder(builder:(_,c){final cols=(c.maxWidth/126).floor().clamp(2,8);return GridView.builder(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),itemCount:cards.length,gridDelegate:SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:cols,childAspectRatio:.92,crossAxisSpacing:9,mainAxisSpacing:9),itemBuilder:(_,i){final q=cards[i];final sel=selected.contains(q.id);final color=_rarityColor(q.rarity);return Material(color:Colors.transparent,child:InkWell(onTap:owned?()=>onTap(q):null,borderRadius:BorderRadius.circular(16),child:Ink(padding:const EdgeInsets.all(8),decoration:BoxDecoration(color:sel?color.withValues(alpha:.1):owned?Colors.white:const Color(0xFFF0F3F8),borderRadius:BorderRadius.circular(16),border:Border.all(color:sel?color:owned?color.withValues(alpha:.5):const Color(0xFFDCE3EE),width:sel?2:1)),child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[_CardBadge(q:q,locked:!owned),const SizedBox(height:6),Text(q.id,style:const TextStyle(color:_ink,fontSize:10,fontWeight:FontWeight.w900)),Text(sel?'SELECTED':_rarityName(q.rarity),style:TextStyle(color:sel?_green:owned?color:_muted,fontSize:7,fontWeight:FontWeight.w900))])));};}); }
class _CardBadge extends StatelessWidget { const _CardBadge({required this.q,this.locked=false}); final QuestionContent q; final bool locked; @override Widget build(BuildContext context){final color=_rarityColor(q.rarity);return Container(width:38,height:46,decoration:BoxDecoration(color:locked?const Color(0xFFE1E6EE):color,borderRadius:BorderRadius.circular(10)),child:Icon(locked?Icons.lock_rounded:Icons.question_mark_rounded,color:locked?_muted:Colors.white,size:21));}}
class _PlayCard extends StatelessWidget { const _PlayCard({required this.icon,required this.colors,required this.title,required this.text,required this.onTap}); final IconData icon; final List<Color>colors; final String title,text; final VoidCallback onTap; @override Widget build(BuildContext context)=>Material(color:Colors.transparent,child:InkWell(onTap:onTap,borderRadius:BorderRadius.circular(22),child:Ink(padding:const EdgeInsets.all(18),decoration:BoxDecoration(gradient:LinearGradient(colors:colors),borderRadius:BorderRadius.circular(22)),child:Row(children:[Container(width:52,height:52,decoration:BoxDecoration(color:Colors.white.withValues(alpha:.2),borderRadius:BorderRadius.circular(16)),child:Icon(icon,color:Colors.white,size:28)),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(color:Colors.white,fontSize:17,fontWeight:FontWeight.w900)),Text(text,style:TextStyle(color:Colors.white.withValues(alpha:.92),fontSize:10,height:1.4,fontWeight:FontWeight.w600))])),const Icon(Icons.chevron_right_rounded,color:Colors.white)])))); }
class _Menu extends StatelessWidget { const _Menu({required this.icon,required this.title,required this.subtitle,required this.onTap}); final IconData icon; final String title,subtitle; final VoidCallback onTap; @override Widget build(BuildContext context)=>InkWell(onTap:onTap,borderRadius:BorderRadius.circular(14),child:Padding(padding:const EdgeInsets.symmetric(vertical:4),child:Row(children:[Container(width:40,height:40,decoration:BoxDecoration(color:const Color(0xFFEAF0FF),borderRadius:BorderRadius.circular(12)),child:Icon(icon,color:_blue,size:21)),const SizedBox(width:11),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(color:_ink,fontSize:13,fontWeight:FontWeight.w900)),Text(subtitle,style:const TextStyle(color:_muted,fontSize:9))])),const Icon(Icons.chevron_right_rounded,color:_muted)]))); }
class _Answer extends StatelessWidget { const _Answer({required this.text,required this.onTap,required this.state}); final String text; final VoidCallback?onTap; final int state; @override Widget build(BuildContext context){final bg=state==2?const Color(0xFFEAF9F2):state==3?const Color(0xFFFFEEEE):Colors.white;final border=state==2?_green:state==3?_coral:_line;return SizedBox(width:double.infinity,child:OutlinedButton(onPressed:onTap,style:OutlinedButton.styleFrom(backgroundColor:bg,foregroundColor:_ink,side:BorderSide(color:border),padding:const EdgeInsets.symmetric(horizontal:14,vertical:15),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(14))),child:Align(alignment:AlignmentDirectional.centerStart,child:Text(text,style:const TextStyle(fontWeight:FontWeight.w800)))));}}
class _Progress extends StatelessWidget { const _Progress({required this.label,required this.value}); final String label; final int value; @override Widget build(BuildContext context)=>_Panel(child:Row(children:[Expanded(child:Text(label,style:const TextStyle(color:_muted,fontSize:9,fontWeight:FontWeight.w900))),Text('$value/7',style:const TextStyle(color:_blue,fontWeight:FontWeight.w900))])); }
class _NeedLogin extends StatelessWidget { const _NeedLogin({required this.arabic}); final bool arabic; @override Widget build(BuildContext context)=>Center(child:Padding(padding:const EdgeInsets.all(28),child:Text(arabic?'سجّل الدخول أولًا لعرض التصنيف.':'Sign in first to view the ranking.',style:const TextStyle(color:_ink,fontWeight:FontWeight.w900)))); }
class _Feature extends StatelessWidget { const _Feature(this.icon,this.text); final IconData icon; final String text; @override Widget build(BuildContext context)=>Row(children:[Icon(icon,color:_purple),const SizedBox(width:10),Expanded(child:Text(text,style:const TextStyle(color:_ink,fontWeight:FontWeight.w900)))]); }
class _Step extends StatelessWidget { const _Step(this.n,this.icon,this.title,this.text); final int n; final IconData icon; final String title,text; @override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.only(bottom:10),child:_Panel(child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Container(width:36,height:36,decoration:BoxDecoration(color:const Color(0xFFEAF0FF),borderRadius:BorderRadius.circular(11)),child:Center(child:Text('$n',style:const TextStyle(color:_blue,fontWeight:FontWeight.w900)))),const SizedBox(width:10),Icon(icon,color:_purple),const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(color:_ink,fontWeight:FontWeight.w900)),const SizedBox(height:2),Text(text,style:const TextStyle(color:_muted,fontSize:10,height:1.35))]))]))); }

Color _rarityColor(CardRarity r)=>switch(r){CardRarity.epic=>_purple,CardRarity.gold=>const Color(0xFFE0A000),CardRarity.legendary=>_coral};
String _rarityName(CardRarity r)=>switch(r){CardRarity.epic=>'EPIC',CardRarity.gold=>'GOLD',CardRarity.legendary=>'LEGENDARY'};
