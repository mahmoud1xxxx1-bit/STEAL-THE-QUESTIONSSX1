import 'package:flutter/material.dart';
import 'game/game_rules.dart';

class DemoPlayerState extends ChangeNotifier {
  final Set<String> ownedCards = <String>{};
  final List<String> deck = <String>[];
  bool weeklyPass = false;
  int wins = 0;
  int losses = 0;

  int get ownedCount => ownedCards.length;
  bool get pvpUnlocked => ownedCount >= kPvpMinimumCollection;
  int get deckSlots => weeklyPass ? kMaxDeckSlots : kFreeDeckSlots;

  void awardBotCard() {
    if (pvpUnlocked) return;
    final catalog = CardCatalog.foundation();
    final card = catalog.cards.firstWhere(
      (c) => !ownedCards.contains(c.id) && c.rarity != CardRarity.legendary,
    );
    ownedCards.add(card.id);
    notifyListeners();
  }

  void wrongBotAnswer() => notifyListeners();

  void prepareDeck() {
    if (ownedCount < kDeckSize) return;
    deck
      ..clear()
      ..addAll(ownedCards.take(kDeckSize));
    notifyListeners();
  }
}

class StealTheQuestionsHome extends StatefulWidget {
  const StealTheQuestionsHome({super.key});

  @override
  State<StealTheQuestionsHome> createState() => _StealTheQuestionsHomeState();
}

class _StealTheQuestionsHomeState extends State<StealTheQuestionsHome> {
  final DemoPlayerState player = DemoPlayerState();
  bool arabic = false;
  int tab = 0;

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: player,
      builder: (context, _) {
        final pages = <Widget>[
          _HomePage(arabic: arabic, player: player, open: (v) => setState(() => tab = v)),
          _CollectionPage(arabic: arabic, player: player),
          _DecksPage(arabic: arabic, player: player),
          _PlayPage(arabic: arabic, player: player),
          _MorePage(arabic: arabic, player: player),
        ];

        return Directionality(
          textDirection: arabic ? TextDirection.rtl : TextDirection.ltr,
          child: Scaffold(
            appBar: AppBar(
              automaticallyImplyLeading: false,
              title: const Text(
                'STEAL THE QUESTIONS',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 1.3),
              ),
              actions: [
                TextButton(
                  onPressed: () => setState(() => arabic = !arabic),
                  child: Text(arabic ? 'EN' : 'ع', style: const TextStyle(fontWeight: FontWeight.w900)),
                ),
                const SizedBox(width: 8),
              ],
            ),
            body: SafeArea(top: false, child: IndexedStack(index: tab, children: pages)),
            bottomNavigationBar: NavigationBar(
              selectedIndex: tab,
              onDestinationSelected: (v) => setState(() => tab = v),
              destinations: [
                NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home_rounded), label: arabic ? 'الرئيسية' : 'HOME'),
                NavigationDestination(icon: const Icon(Icons.style_outlined), selectedIcon: const Icon(Icons.style_rounded), label: arabic ? 'البطاقات' : 'CARDS'),
                NavigationDestination(icon: const Icon(Icons.view_carousel_outlined), selectedIcon: const Icon(Icons.view_carousel_rounded), label: arabic ? 'المجموعات' : 'DECKS'),
                NavigationDestination(icon: const Icon(Icons.sports_mma_outlined), selectedIcon: const Icon(Icons.sports_mma_rounded), label: arabic ? 'اللعب' : 'PLAY'),
                NavigationDestination(icon: const Icon(Icons.more_horiz_rounded), selectedIcon: const Icon(Icons.more_horiz_rounded), label: arabic ? 'المزيد' : 'MORE'),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HomePage extends StatelessWidget {
  const _HomePage({required this.arabic, required this.player, required this.open});
  final bool arabic;
  final DemoPlayerState player;
  final ValueChanged<int> open;

  @override
  Widget build(BuildContext context) {
    final locked = !player.pvpUnlocked;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: const Color(0xFF131C29),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0x2AF3C86B)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'THE COLLECTION IS THE GAME',
                style: TextStyle(color: Color(0xFFF3C86B), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5),
              ),
              const SizedBox(height: 12),
              Text(
                locked ? (arabic ? 'أكمل 10 بطاقات لفتح PvP' : 'REACH 10 CARDS TO UNLOCK PVP') : (arabic ? 'PvP مفتوح' : 'PVP IS UNLOCKED'),
                style: const TextStyle(fontSize: 29, height: 1.05, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              Text(
                locked
                    ? (arabic ? 'ابدأ مع Bot. كل إجابة صحيحة تمنح بطاقة غير مملوكة.' : 'Start with the Bot. Every correct answer awards one unowned card.')
                    : (arabic ? 'اختر مجموعة من 10 بطاقات وابدأ المواجهة.' : 'Choose a 10-card deck and enter the duel.'),
                style: const TextStyle(color: Color(0xFF96A1B1), height: 1.45),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () => open(3),
                icon: Icon(locked ? Icons.smart_toy_rounded : Icons.sports_mma_rounded),
                label: Text(locked ? (arabic ? 'تدريب Bot' : 'BOT TRAINING') : (arabic ? 'العب PvP' : 'PLAY PVP')),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: _Metric(label: arabic ? 'البطاقات' : 'CARDS', value: '${player.ownedCount}/$kTotalCards')),
            const SizedBox(width: 10),
            Expanded(child: _Metric(label: arabic ? 'المجموعات' : 'DECKS', value: '${player.deckSlots}/$kMaxDeckSlots')),
            const SizedBox(width: 10),
            Expanded(child: _Metric(label: arabic ? 'الانتصارات' : 'WINS', value: '${player.wins}')),
          ],
        ),
        const SizedBox(height: 22),
        _TitleBlock(
          title: arabic ? 'تقدمك' : 'YOUR PROGRESS',
          subtitle: arabic ? 'الحد الأدنى للدخول إلى PvP هو 10 بطاقات.' : 'PvP unlocks at 10 owned cards.',
        ),
        const SizedBox(height: 10),
        _ProgressPanel(arabic: arabic, player: player, open: open),
        const SizedBox(height: 22),
        _TitleBlock(
          title: arabic ? 'أقسام اللعبة' : 'GAME AREAS',
          subtitle: arabic ? 'الصفحة الرئيسية مرتبطة بكل أقسام المنتج.' : 'The home screen exposes the main product areas.',
        ),
        const SizedBox(height: 10),
        _AreaButton(icon: Icons.style_rounded, title: arabic ? 'المجموعة' : 'COLLECTION', text: arabic ? '222 بطاقة فريدة' : '222 unique cards', onTap: () => open(1)),
        _AreaButton(icon: Icons.view_carousel_rounded, title: arabic ? 'المجموعات' : 'DECKS', text: arabic ? '2 مجانية + 3 Weekly Pass' : '2 free + 3 Weekly Pass', onTap: () => open(2)),
        _AreaButton(icon: Icons.sports_mma_rounded, title: 'TROLL DUEL', text: arabic ? '7 أسئلة • 20 ثانية' : '7 questions • 20 seconds', onTap: () => open(3)),
        _AreaButton(icon: Icons.more_horiz_rounded, title: arabic ? 'الترتيب / Pass / الإعدادات' : 'RANKING / PASS / SETTINGS', text: '', onTap: () => open(4)),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: const Color(0xFF111824), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0x1FFFFFFF))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF7F8B9C), fontSize: 8, fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _TitleBlock extends StatelessWidget {
  const _TitleBlock({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: Color(0xFF7F8B9C), fontSize: 11)),
      ],
    );
  }
}

class _ProgressPanel extends StatelessWidget {
  const _ProgressPanel({required this.arabic, required this.player, required this.open});
  final bool arabic;
  final DemoPlayerState player;
  final ValueChanged<int> open;

  @override
  Widget build(BuildContext context) {
    final value = (player.ownedCount / kPvpMinimumCollection).clamp(0.0, 1.0);
    return InkWell(
      onTap: () => open(3),
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(color: const Color(0xFF111824), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0x1FFFFFFF))),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.lock_open_rounded, color: Color(0xFFF3C86B)),
                const SizedBox(width: 10),
                Expanded(child: Text(arabic ? 'Bot حتى 10 بطاقات' : 'Bot onboarding until 10 cards', style: const TextStyle(fontWeight: FontWeight.w900))),
                Text('${player.ownedCount}/$kPvpMinimumCollection', style: const TextStyle(color: Color(0xFFF3C86B), fontWeight: FontWeight.w900)),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(borderRadius: BorderRadius.circular(99), child: LinearProgressIndicator(value: value, minHeight: 7, backgroundColor: const Color(0xFF283242))),
            const SizedBox(height: 10),
            Text(arabic ? 'الصحيح = بطاقة جديدة • الخطأ = لا بطاقة' : 'Correct = new card • Wrong = no card', style: const TextStyle(color: Color(0xFF7F8B9C), fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _AreaButton extends StatelessWidget {
  const _AreaButton({required this.icon, required this.title, required this.text, required this.onTap});
  final IconData icon;
  final String title;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: ListTile(
        onTap: onTap,
        tileColor: const Color(0xFF111824),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: Color(0x1FFFFFFF))),
        leading: Icon(icon, color: const Color(0xFF78D9D0)),
        title: Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
        subtitle: text.isEmpty ? null : Text(text, style: const TextStyle(color: Color(0xFF7F8B9C), fontSize: 10)),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

class _CollectionPage extends StatelessWidget {
  const _CollectionPage({required this.arabic, required this.player});
  final bool arabic;
  final DemoPlayerState player;

  @override
  Widget build(BuildContext context) {
    final catalog = CardCatalog.foundation();
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
      children: [
        Text(arabic ? 'المجموعة' : 'COLLECTION', style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
        const SizedBox(height: 5),
        Text(arabic ? '222 بطاقة فريدة. لا توجد نسخ مكررة للاعب الواحد.' : '222 unique cards. No duplicate Card IDs per player.', style: const TextStyle(color: Color(0xFF7F8B9C), fontSize: 11)),
        const SizedBox(height: 15),
        Row(
          children: [
            Expanded(child: _Metric(label: 'EPIC', value: '$kEpicCards')),
            const SizedBox(width: 8),
            Expanded(child: _Metric(label: 'GOLD', value: '$kGoldCards')),
            const SizedBox(width: 8),
            Expanded(child: _Metric(label: 'LEGENDARY', value: '$kLegendaryCards')),
          ],
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: kTotalCards,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 9, mainAxisSpacing: 9, childAspectRatio: .85),
          itemBuilder: (context, index) {
            final card = catalog.cards[index];
            final owned = player.ownedCards.contains(card.id);
            final accent = card.rarity == CardRarity.legendary ? const Color(0xFFF3C86B) : card.rarity == CardRarity.gold ? const Color(0xFFD1AD5C) : const Color(0xFF78D9D0);
            return Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: owned ? const Color(0xFF172131) : const Color(0xFF0F151F),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: owned ? accent.withValues(alpha: .45) : const Color(0x171FFFFFFF)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(owned ? Icons.style_rounded : Icons.lock_rounded, color: accent, size: 24),
                  const SizedBox(height: 7),
                  Text(card.id, style: TextStyle(color: owned ? accent : const Color(0xFF5E697A), fontSize: 8, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(owned ? (arabic ? 'مملوكة' : 'OWNED') : (arabic ? 'مقفلة' : 'LOCKED'), style: const TextStyle(color: Color(0xFF7F8B9C), fontSize: 7, fontWeight: FontWeight.w900)),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _DecksPage extends StatelessWidget {
  const _DecksPage({required this.arabic, required this.player});
  final bool arabic;
  final DemoPlayerState player;

  @override
  Widget build(BuildContext context) {
    final ready = player.ownedCount >= kDeckSize;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
      children: [
        Text(arabic ? 'المجموعات' : 'DECKS', style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
        const SizedBox(height: 5),
        Text(arabic ? 'كل مجموعة تحتوي 10 بطاقات مختلفة.' : 'Every deck contains exactly 10 distinct cards.', style: const TextStyle(color: Color(0xFF7F8B9C), fontSize: 11)),
        const SizedBox(height: 15),
        for (int i = 0; i < kMaxDeckSlots; i++) ...[
          ListTile(
            tileColor: const Color(0xFF111824),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: Color(0x1FFFFFFF))),
            leading: Icon(i < player.deckSlots ? Icons.view_carousel_rounded : Icons.lock_rounded, color: i < player.deckSlots ? const Color(0xFFF3C86B) : const Color(0xFF5E697A)),
            title: Text(arabic ? 'مجموعة ${i + 1}' : 'DECK ${i + 1}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
            subtitle: Text(
              i >= player.deckSlots
                  ? (arabic ? 'مفتوحة مع Weekly Pass' : 'Unlock with Weekly Pass')
                  : i == 0 && ready
                      ? (arabic ? 'جاهزة 10 / 10' : 'READY 10 / 10')
                      : (arabic ? 'متاحة' : 'AVAILABLE'),
              style: const TextStyle(color: Color(0xFF7F8B9C), fontSize: 10),
            ),
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: ready ? player.prepareDeck : null,
          icon: const Icon(Icons.build_rounded),
          label: Text(arabic ? 'بناء المجموعة الأولى تلقائيًا' : 'BUILD FIRST DECK'),
        ),
        const SizedBox(height: 10),
        Text(arabic ? 'يمكن إعادة استخدام البطاقة في أكثر من مجموعة.' : 'A card can be reused in more than one deck.', style: const TextStyle(color: Color(0xFF7F8B9C), fontSize: 11)),
      ],
    );
  }
}

class _PlayPage extends StatelessWidget {
  const _PlayPage({required this.arabic, required this.player});
  final bool arabic;
  final DemoPlayerState player;

  @override
  Widget build(BuildContext context) {
    final pvpOpen = player.pvpUnlocked;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
      children: [
        _PageTitle(
          title: arabic ? 'اللعب' : 'PLAY',
          body: arabic
              ? 'هيكل أوضاع اللعب فقط. لم تتم إضافة الأسئلة بعد.'
              : 'Game-mode structure only. Question content has not been added yet.',
          count: pvpOpen ? 'READY' : 'LOCKED',
        ),
        const SizedBox(height: 12),
        _ModePanel(
          icon: Icons.smart_toy_rounded,
          title: 'BOT TRAINING',
          body: arabic
              ? 'يظهر هنا مسار التدريب الأولي. سيتم ربطه لاحقًا ببنك الأسئلة.'
              : 'The onboarding mode lives here and will connect to the question bank later.',
          action: 'LATER',
        ),
        const SizedBox(height: 10),
        _ModePanel(
          icon: Icons.sports_mma_rounded,
          title: 'TROLL DUEL',
          body: pvpOpen
              ? (arabic
                  ? 'PvP مفتوح. نحتاج الـbackend والمطابقة والمحتوى قبل التشغيل.'
                  : 'PvP is unlocked. Backend, matchmaking and content are still required.')
              : (arabic
                  ? 'مغلق حتى تملك 10 بطاقات.'
                  : 'Locked until 10 cards are owned.'),
          action: pvpOpen ? 'PENDING' : 'LOCKED',
        ),
        const SizedBox(height: 12),
        _InfoBox(
          icon: Icons.rule_rounded,
          text: arabic
              ? 'لا توجد أسئلة حقيقية أو مباراة فعلية في هذا التحديث.'
              : 'No real questions or live matches are included in this update.',
        ),
      ],
    );
  }
}

class _MorePage extends StatelessWidget {

  const _MorePage({required this.arabic, required this.player});
  final bool arabic;
  final DemoPlayerState player;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
      children: [
        Text(arabic ? 'المزيد' : 'MORE', style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
        const SizedBox(height: 14),
        _MoreTile(icon: Icons.emoji_events_rounded, title: arabic ? 'الترتيب' : 'RANKING', subtitle: arabic ? 'عدد البطاقات هو الأساس الرئيسي.' : 'Cards owned are the primary metric.', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _SimplePage(title: 'RANKING', body: arabic ? 'الأول: 1 LEGENDARY • الثاني: 3 GOLD • الثالث: 2 GOLD' : '#1: 1 LEGENDARY • #2: 3 GOLD • #3: 2 GOLD')))),
        const SizedBox(height: 8),
        _MoreTile(icon: Icons.workspace_premium_rounded, title: 'WEEKLY PASS', subtitle: arabic ? '+3 مجموعات + خيار إجابة رابع' : '+3 deck slots + fourth answer option', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _PassPage(arabic: arabic, player: player)))),
        const SizedBox(height: 8),
        _MoreTile(icon: Icons.settings_rounded, title: arabic ? 'الإعدادات' : 'SETTINGS', subtitle: arabic ? 'اللغة والإعدادات العامة' : 'Language and general settings', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _SimplePage(title: 'SETTINGS', body: arabic ? 'العربية / English' : 'English / العربية')))),
      ],
    );
  }
}


class _ModePanel extends StatelessWidget {
  const _ModePanel({
    required this.icon,
    required this.title,
    required this.body,
    required this.action,
  });

  final IconData icon;
  final String title;
  final String body;
  final String action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xFF111824),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x1FFFFFFF)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF78D9D0), size: 29),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                const SizedBox(height: 5),
                Text(body, style: const TextStyle(color: Color(0xFF7F8B9C), fontSize: 10, height: 1.4)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(action, style: const TextStyle(color: Color(0xFFF3C86B), fontSize: 9, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _PageTitle extends StatelessWidget {
  const _PageTitle({
    required this.title,
    required this.body,
    required this.count,
  });

  final String title;
  final String body;
  final String count;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(body, style: const TextStyle(color: Color(0xFF7F8B9C), fontSize: 11, height: 1.4)),
            ],
          ),
        ),
        Text(count, style: const TextStyle(color: Color(0xFFF3C86B), fontWeight: FontWeight.w900)),
      ],
    );
  }
}

class _MoreTile extends StatelessWidget {
  const _MoreTile({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      tileColor: const Color(0xFF111824),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      leading: Icon(icon, color: const Color(0xFFF3C86B)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
      subtitle: Text(subtitle, style: const TextStyle(color: Color(0xFF7F8B9C), fontSize: 10)),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }
}

class _PassPage extends StatefulWidget {
  const _PassPage({required this.arabic, required this.player});
  final bool arabic;
  final DemoPlayerState player;

  @override
  State<_PassPage> createState() => _PassPageState();
}

class _PassPageState extends State<_PassPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('WEEKLY PASS')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text(widget.player.weeklyPass ? (widget.arabic ? 'الـPass فعال' : 'PASS ACTIVE') : 'WEEKLY PASS', style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          Text(widget.arabic ? '• 3 مجموعات إضافية\\n• خيار إجابة رابع\\n• وصول أسبوعي' : '• +3 deck slots\\n• fourth answer option\\n• weekly access', style: const TextStyle(color: Color(0xFF96A1B1), height: 1.7)),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: widget.player.weeklyPass ? null : () {
              widget.player.weeklyPass = true;
              widget.player.notifyListeners();
              setState(() {});
            },
            child: Text(widget.player.weeklyPass ? (widget.arabic ? 'مفعل' : 'ACTIVE') : (widget.arabic ? 'تجربة محلية' : 'LOCAL DEMO')),
          ),
        ],
      ),
    );
  }
}

class _SimplePage extends StatelessWidget {
  const _SimplePage({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Padding(padding: const EdgeInsets.all(22), child: Text(body, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, height: 1.5, fontWeight: FontWeight.w800)))),
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFF111824), borderRadius: BorderRadius.circular(17), border: Border.all(color: const Color(0x1FFFFFFF))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF78D9D0), size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(color: Color(0xFF8995A7), fontSize: 11, height: 1.4))),
        ],
      ),
    );
  }
}
