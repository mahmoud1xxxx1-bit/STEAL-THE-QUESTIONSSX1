import 'package:flutter/material.dart';

import 'game/game_rules.dart';
import 'game/question_bank.dart';
import 'product_app.dart';

class BrightStealTheQuestionsHome extends StatefulWidget {
  const BrightStealTheQuestionsHome({super.key});

  @override
  State<BrightStealTheQuestionsHome> createState() => _BrightStealTheQuestionsHomeState();
}

class _BrightStealTheQuestionsHomeState extends State<BrightStealTheQuestionsHome> {
  final DemoPlayerState player = DemoPlayerState();
  int tab = 0;
  bool arabic = true;

  static const _blue = Color(0xFF2E6BFF);
  static const _purple = Color(0xFF7A48F5);
  static const _gold = Color(0xFFFFC94D);
  static const _coral = Color(0xFFFF6A67);
  static const _ink = Color(0xFF183153);
  static const _muted = Color(0xFF7183A3);
  static const _page = Color(0xFFF5F8FF);

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

  void _openLegacy() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const StealTheQuestionsHome()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: player,
      builder: (context, _) {
        if (player.loading) {
          return const Scaffold(
            backgroundColor: _page,
            body: Center(child: CircularProgressIndicator(color: _blue)),
          );
        }

        final pages = <Widget>[
          _home(),
          _collection(),
          _decks(),
          _play(),
          _more(),
        ];

        return Directionality(
          textDirection: arabic ? TextDirection.rtl : TextDirection.ltr,
          child: Scaffold(
            backgroundColor: _page,
            appBar: _topBar(),
            body: IndexedStack(index: tab, children: pages),
            bottomNavigationBar: _bottomBar(),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _topBar() {
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 0,
      toolbarHeight: 72,
      titleSpacing: 16,
      title: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [_blue, _purple]),
            ),
            child: const Icon(Icons.question_mark_rounded, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(arabic ? 'مرحبًا بك' : 'Welcome back', style: const TextStyle(color: _muted, fontSize: 11, fontWeight: FontWeight.w700)),
                const Text('STEAL THE QUESTIONS', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _ink, fontSize: 14, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(color: const Color(0xFFFFF2C8), borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              const Icon(Icons.style_rounded, size: 17, color: Color(0xFFE49C00)),
              const SizedBox(width: 5),
              Text('${player.ownedCount}/$kTotalCards', style: const TextStyle(color: _ink, fontSize: 12, fontWeight: FontWeight.w900)),
            ]),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: () => setState(() => arabic = !arabic),
            icon: Text(arabic ? 'EN' : 'ع', style: const TextStyle(color: _blue, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  Widget _bottomBar() {
    return NavigationBar(
      height: 72,
      backgroundColor: Colors.white,
      indicatorColor: const Color(0xFFE9EEFF),
      selectedIndex: tab,
      onDestinationSelected: (value) => setState(() => tab = value),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      destinations: [
        NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home_rounded, color: _blue), label: arabic ? 'الرئيسية' : 'Home'),
        NavigationDestination(icon: const Icon(Icons.style_outlined), selectedIcon: const Icon(Icons.style_rounded, color: _purple), label: arabic ? 'المجموعة' : 'Collection'),
        NavigationDestination(icon: const Icon(Icons.layers_outlined), selectedIcon: const Icon(Icons.layers_rounded, color: _gold), label: arabic ? 'المجموعات' : 'Decks'),
        NavigationDestination(icon: const Icon(Icons.sports_esports_outlined), selectedIcon: const Icon(Icons.sports_esports_rounded, color: _coral), label: arabic ? 'اللعب' : 'Play'),
        NavigationDestination(icon: const Icon(Icons.more_horiz_rounded), selectedIcon: const Icon(Icons.more_horiz_rounded, color: _blue), label: arabic ? 'المزيد' : 'More'),
      ],
    );
  }

  Widget _home() {
    final pvpReady = player.pvpUnlocked;
    final deckCount = player.decks[player.activeDeck].length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF4E8CFF), Color(0xFF8356F6)]),
            boxShadow: const [BoxShadow(color: Color(0x334E79FF), blurRadius: 22, offset: Offset(0, 10))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 56,
                  height: 70,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: .16), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: .35))),
                  child: const Icon(Icons.question_mark_rounded, color: Colors.white, size: 34),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: .16), borderRadius: BorderRadius.circular(999)),
                  child: Text(pvpReady ? (arabic ? 'PvP مفتوح' : 'PvP unlocked') : (arabic ? '${player.ownedCount}/10 للـ PvP' : '${player.ownedCount}/10 to PvP'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11)),
                ),
              ]),
              const SizedBox(height: 18),
              Text(arabic ? 'جاوب، اجمع، نافس... واسرق بطاقة!' : 'Answer, collect, compete... and steal a card!', style: const TextStyle(color: Colors.white, fontSize: 27, height: 1.12, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text(arabic ? 'كل جولة تقرّبك من مجموعة أقوى وترتيب أعلى.' : 'Every round moves you toward a stronger collection and a higher rank.', style: TextStyle(color: Colors.white.withValues(alpha: .9), fontSize: 12, height: 1.45, fontWeight: FontWeight.w600)),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => setState(() => tab = 3),
                  style: FilledButton.styleFrom(backgroundColor: _gold, foregroundColor: _ink, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(arabic ? 'ابدأ اللعب الآن' : 'PLAY NOW', style: const TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _modeCard(icon: Icons.smart_toy_rounded, color: _blue, title: arabic ? 'ضد البوت' : 'Bot', subtitle: arabic ? 'اجمع بطاقات جديدة' : 'Collect new cards', onTap: _openLegacy)),
          const SizedBox(width: 10),
          Expanded(child: _modeCard(icon: Icons.flash_on_rounded, color: _coral, title: arabic ? 'ضد لاعب' : 'PvP', subtitle: arabic ? (pvpReady ? 'نافس واسرق بطاقة' : 'يفتح عند 10 بطاقات') : (pvpReady ? 'Compete and steal' : 'Unlocks at 10 cards'), onTap: _openLegacy)),
        ]),
        const SizedBox(height: 14),
        _panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _sectionTitle(arabic ? 'تقدم مجموعتك' : 'Collection progress', trailing: '${player.ownedCount}/$kTotalCards'),
            const SizedBox(height: 12),
            ClipRRect(borderRadius: BorderRadius.circular(999), child: LinearProgressIndicator(value: player.ownedCount / kTotalCards, minHeight: 10, color: _blue, backgroundColor: const Color(0xFFE3E9F5))),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: _rarityMini('EPIC', _purple, player.ownedCards.where((id) => QuestionBank.byId(id).rarity == CardRarity.epic).length, kEpicCards)),
              const SizedBox(width: 8),
              Expanded(child: _rarityMini('GOLD', _gold, player.ownedCards.where((id) => QuestionBank.byId(id).rarity == CardRarity.gold).length, kGoldCards)),
              const SizedBox(width: 8),
              Expanded(child: _rarityMini('LEGEND', _coral, player.ownedCards.where((id) => QuestionBank.byId(id).rarity == CardRarity.legendary).length, kLegendaryCards)),
            ]),
          ]),
        ),
        const SizedBox(height: 14),
        _panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _sectionTitle(arabic ? 'مجموعة اللعب الحالية' : 'Current deck', trailing: '$deckCount/$kDeckSize'),
            const SizedBox(height: 12),
            SizedBox(
              height: 64,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: kDeckSize,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, i) {
                  final has = i < deckCount;
                  final id = has ? player.decks[player.activeDeck][i] : null;
                  final rarity = id == null ? CardRarity.epic : QuestionBank.byId(id).rarity;
                  return _miniCard(id: id, rarity: rarity);
                },
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(onPressed: () => setState(() => tab = 2), icon: const Icon(Icons.edit_rounded), label: Text(arabic ? 'تعديل المجموعات' : 'Manage decks')),
          ]),
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _smallLink(icon: Icons.workspace_premium_rounded, color: _gold, title: 'Weekly Pass', onTap: _openLegacy)),
          const SizedBox(width: 10),
          Expanded(child: _smallLink(icon: Icons.emoji_events_rounded, color: _blue, title: arabic ? 'التصنيف' : 'Ranking', onTap: _openLegacy)),
        ]),
      ],
    );
  }

  Widget _collection() {
    final cards = QuestionBank.all;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _pageHeading(arabic ? 'المجموعة' : 'Collection', arabic ? 'كل بطاقة تملكها تقرّبك من الصدارة.' : 'Every card you own moves you closer to the top.'),
        const SizedBox(height: 14),
        _panel(child: Row(children: [
          Expanded(child: _bigNumber('${player.ownedCount}', arabic ? 'مملوكة' : 'Owned', _blue)),
          Expanded(child: _bigNumber('${kTotalCards - player.ownedCount}', arabic ? 'متبقية' : 'Remaining', _purple)),
          Expanded(child: _bigNumber('$kTotalCards', arabic ? 'الإجمالي' : 'Total', _gold)),
        ])),
        const SizedBox(height: 14),
        GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: .72, crossAxisSpacing: 10, mainAxisSpacing: 10),
          itemCount: cards.length,
          itemBuilder: (_, i) {
            final q = cards[i];
            final owned = player.ownedCards.contains(q.id);
            return _collectionCard(q, owned);
          },
        ),
      ],
    );
  }

  Widget _decks() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _pageHeading(arabic ? 'مجموعات اللعب' : 'Decks', arabic ? 'كوّن 10 بطاقات جاهزة للمواجهة.' : 'Build 10-card decks ready for battle.'),
        const SizedBox(height: 14),
        ...List.generate(kMaxDeckSlots, (i) {
          final unlocked = i < player.deckSlots;
          final count = player.decks[i].length;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _panel(
              child: Row(children: [
                Container(width: 48, height: 48, decoration: BoxDecoration(color: unlocked ? const Color(0xFFE9EEFF) : const Color(0xFFF1F3F7), borderRadius: BorderRadius.circular(15)), child: Icon(unlocked ? Icons.layers_rounded : Icons.lock_rounded, color: unlocked ? _purple : _muted)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${arabic ? 'المجموعة' : 'Deck'} ${i + 1}', style: const TextStyle(color: _ink, fontWeight: FontWeight.w900, fontSize: 16)),
                  const SizedBox(height: 3),
                  Text(unlocked ? '$count/$kDeckSize' : 'Weekly Pass', style: const TextStyle(color: _muted, fontSize: 12, fontWeight: FontWeight.w700)),
                ])),
                if (unlocked) FilledButton(onPressed: _openLegacy, child: Text(arabic ? 'تعديل' : 'Edit')) else const Icon(Icons.workspace_premium_rounded, color: _gold),
              ]),
            ),
          );
        }),
      ],
    );
  }

  Widget _play() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _pageHeading(arabic ? 'اختر طريقة اللعب' : 'Choose how to play', arabic ? 'كل جولة لها هدف واضح ومكافأة واضحة.' : 'Every round has a clear goal and reward.'),
        const SizedBox(height: 14),
        _playCard(Icons.smart_toy_rounded, const [Color(0xFF46A6FF), Color(0xFF2E6BFF)], arabic ? 'العب ضد البوت' : 'Play vs Bot', arabic ? 'أجب بشكل صحيح لتحصل على بطاقة جديدة حتى تصل إلى 10 بطاقات.' : 'Answer correctly to earn new cards until you reach 10.', _openLegacy),
        const SizedBox(height: 12),
        _playCard(Icons.flash_on_rounded, const [Color(0xFFFF7C73), Color(0xFFFF4F87)], arabic ? 'العب ضد لاعب' : 'Play PvP', player.pvpUnlocked ? (arabic ? 'اختر Deck من 10 بطاقات ونافس على سرقة بطاقة.' : 'Choose a 10-card deck and compete to steal a card.') : (arabic ? 'مقفل مؤقتًا حتى تمتلك 10 بطاقات.' : 'Locked until you own 10 cards.'), _openLegacy),
      ],
    );
  }

  Widget _more() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _pageHeading(arabic ? 'المزيد' : 'More', arabic ? 'كل ما تحتاجه بدون ازدحام.' : 'Everything you need without clutter.'),
        const SizedBox(height: 14),
        _panel(child: Column(children: [
          _menuRow(Icons.person_rounded, arabic ? 'الحساب' : 'Account', player.authenticated ? player.accountLabel : (arabic ? 'وضع المعاينة المحلية' : 'Local preview mode'), _openLegacy),
          const Divider(height: 22),
          _menuRow(Icons.emoji_events_rounded, arabic ? 'التصنيف' : 'Ranking', arabic ? 'شاهد ترتيب اللاعبين' : 'View player ranking', _openLegacy),
          const Divider(height: 22),
          _menuRow(Icons.workspace_premium_rounded, 'Weekly Pass', arabic ? 'حتى 5 Decks وخيار إجابة رابع' : 'Up to 5 decks and a fourth answer option', _openLegacy),
          const Divider(height: 22),
          _menuRow(Icons.help_outline_rounded, arabic ? 'كيف تعمل اللعبة؟' : 'How it works', arabic ? 'شرح سريع لقواعد اللعبة' : 'A quick guide to the rules', _openLegacy),
        ])),
      ],
    );
  }

  Widget _modeCard({required IconData icon, required Color color, required String title, required String subtitle, required VoidCallback onTap}) => Material(color: Colors.transparent, child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(22), child: Ink(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), boxShadow: const [BoxShadow(color: Color(0x110C2E62), blurRadius: 14, offset: Offset(0, 6))]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(width: 42, height: 42, decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: color)), const SizedBox(height: 12), Text(title, style: const TextStyle(color: _ink, fontWeight: FontWeight.w900, fontSize: 16)), const SizedBox(height: 4), Text(subtitle, style: const TextStyle(color: _muted, fontSize: 11, height: 1.35))]))));

  Widget _panel({required Widget child}) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFE7ECF5)), boxShadow: const [BoxShadow(color: Color(0x0D183153), blurRadius: 12, offset: Offset(0, 5))]), child: child);

  Widget _sectionTitle(String title, {String? trailing}) => Row(children: [Expanded(child: Text(title, style: const TextStyle(color: _ink, fontSize: 16, fontWeight: FontWeight.w900))), if (trailing != null) Text(trailing, style: const TextStyle(color: _blue, fontSize: 13, fontWeight: FontWeight.w900))]);

  Widget _rarityMini(String label, Color color, int value, int total) => Container(padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 7), decoration: BoxDecoration(color: color.withValues(alpha: .1), borderRadius: BorderRadius.circular(15)), child: Column(children: [Text('$value/$total', style: const TextStyle(color: _ink, fontWeight: FontWeight.w900, fontSize: 14)), const SizedBox(height: 3), Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900))]));

  Widget _miniCard({String? id, required CardRarity rarity}) {
    final color = _rarityColor(rarity);
    return Container(width: 44, decoration: BoxDecoration(gradient: id == null ? null : LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [color.withValues(alpha: .8), color]), color: id == null ? const Color(0xFFEDF1F7) : null, borderRadius: BorderRadius.circular(10), border: Border.all(color: id == null ? const Color(0xFFDCE3EE) : color)), child: Center(child: Text(id == null ? '+' : id.replaceFirst('Q', ''), style: TextStyle(color: id == null ? _muted : Colors.white, fontSize: 9, fontWeight: FontWeight.w900))));
  }

  Widget _smallLink({required IconData icon, required Color color, required String title, required VoidCallback onTap}) => Material(color: Colors.transparent, child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(18), child: Ink(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE7ECF5))), child: Row(children: [Container(width: 36, height: 36, decoration: BoxDecoration(color: color.withValues(alpha: .14), borderRadius: BorderRadius.circular(11)), child: Icon(icon, color: color, size: 21)), const SizedBox(width: 9), Expanded(child: Text(title, style: const TextStyle(color: _ink, fontWeight: FontWeight.w900, fontSize: 13))), const Icon(Icons.chevron_right_rounded, color: _muted)]))));

  Widget _pageHeading(String title, String subtitle) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: _ink, fontSize: 28, fontWeight: FontWeight.w900)), const SizedBox(height: 5), Text(subtitle, style: const TextStyle(color: _muted, fontSize: 12, height: 1.4, fontWeight: FontWeight.w600))]);

  Widget _bigNumber(String value, String label, Color color) => Column(children: [Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w900)), const SizedBox(height: 3), Text(label, style: const TextStyle(color: _muted, fontSize: 10, fontWeight: FontWeight.w700))]);

  Widget _collectionCard(QuestionContent q, bool owned) {
    final color = _rarityColor(q.rarity);
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(color: owned ? Colors.white : const Color(0xFFF0F3F8), borderRadius: BorderRadius.circular(17), border: Border.all(color: owned ? color.withValues(alpha: .7) : const Color(0xFFDCE3EE), width: owned ? 1.5 : 1)),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 42, height: 52, decoration: BoxDecoration(gradient: owned ? LinearGradient(colors: [color.withValues(alpha: .75), color]) : null, color: owned ? null : const Color(0xFFE1E6EE), borderRadius: BorderRadius.circular(10)), child: Icon(owned ? Icons.question_mark_rounded : Icons.lock_rounded, color: owned ? Colors.white : _muted)),
        const SizedBox(height: 8),
        Text(q.id, style: const TextStyle(color: _ink, fontWeight: FontWeight.w900, fontSize: 11)),
        const SizedBox(height: 3),
        Text(_rarityName(q.rarity), style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 8)),
      ]),
    );
  }

  Widget _playCard(IconData icon, List<Color> colors, String title, String subtitle, VoidCallback onTap) => Material(color: Colors.transparent, child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(24), child: Ink(padding: const EdgeInsets.all(20), decoration: BoxDecoration(gradient: LinearGradient(colors: colors), borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: colors.last.withValues(alpha: .22), blurRadius: 18, offset: const Offset(0, 8))]), child: Row(children: [Container(width: 56, height: 56, decoration: BoxDecoration(color: Colors.white.withValues(alpha: .2), borderRadius: BorderRadius.circular(18)), child: Icon(icon, color: Colors.white, size: 30)), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)), const SizedBox(height: 5), Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: .9), fontSize: 11, height: 1.4, fontWeight: FontWeight.w600))])), const Icon(Icons.chevron_right_rounded, color: Colors.white)]))));

  Widget _menuRow(IconData icon, String title, String subtitle, VoidCallback onTap) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(14), child: Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [Container(width: 42, height: 42, decoration: BoxDecoration(color: const Color(0xFFE9EEFF), borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: _blue)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: _ink, fontSize: 14, fontWeight: FontWeight.w900)), const SizedBox(height: 2), Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _muted, fontSize: 10))])), const Icon(Icons.chevron_right_rounded, color: _muted)])));

  Color _rarityColor(CardRarity rarity) {
    switch (rarity) {
      case CardRarity.epic:
        return _purple;
      case CardRarity.gold:
        return const Color(0xFFE7A800);
      case CardRarity.legendary:
        return _coral;
    }
  }

  String _rarityName(CardRarity rarity) {
    switch (rarity) {
      case CardRarity.epic:
        return 'EPIC';
      case CardRarity.gold:
        return 'GOLD';
      case CardRarity.legendary:
        return 'LEGENDARY';
    }
  }
}
