
import 'package:flutter/material.dart';
import 'game/game_rules.dart';

class DemoPlayerState extends ChangeNotifier {
  final Set<String> ownedCards = <String>{};
  final List<List<String>> decks = List<List<String>>.generate(
    kMaxDeckSlots,
    (_) => <String>[],
  );

  bool weeklyPass = false;
  int wins = 0;
  int losses = 0;
  int activeDeck = 0;

  int get ownedCount => ownedCards.length;
  bool get pvpUnlocked => ownedCount >= kPvpMinimumCollection;
  int get deckSlots => weeklyPass ? kMaxDeckSlots : kFreeDeckSlots;
  bool get activeDeckReady =>
      activeDeck < deckSlots && decks[activeDeck].length == kDeckSize;

  void awardBotCard() {
    if (pvpUnlocked) return;
    final catalog = CardCatalog.foundation();
    final candidates = catalog.normalCards
        .where((c) => !ownedCards.contains(c.id))
        .toList(growable: false);
    if (candidates.isEmpty) return;
    ownedCards.add(candidates.first.id);
    notifyListeners();
  }

  void wrongBotAnswer() => notifyListeners();

  void setActiveDeck(int index) {
    if (index < 0 || index >= deckSlots) return;
    activeDeck = index;
    notifyListeners();
  }

  void toggleCardInDeck(String cardId) {
    if (activeDeck >= deckSlots) return;
    final current = decks[activeDeck];
    if (current.contains(cardId)) {
      current.remove(cardId);
    } else if (current.length < kDeckSize && ownedCards.contains(cardId)) {
      current.add(cardId);
    }
    notifyListeners();
  }

  void clearDeck(int index) {
    if (index < 0 || index >= deckSlots) return;
    decks[index].clear();
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

  void openTab(int index) => setState(() => tab = index);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: player,
      builder: (context, _) {
        final pages = <Widget>[
          _HomePage(arabic: arabic, player: player, open: openTab),
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
              toolbarHeight: 68,
              titleSpacing: 18,
              title: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3C86B),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.question_mark_rounded,
                      color: Color(0xFF0A0F19),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'STEAL THE QUESTIONS',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  _TopCount(
                    value: '${player.ownedCount}/$kTotalCards',
                    label: arabic ? 'بطاقات' : 'CARDS',
                  ),
                ],
              ),
              actions: [
                IconButton(
                  tooltip: arabic ? 'اللغة' : 'Language',
                  onPressed: () => setState(() => arabic = !arabic),
                  icon: Text(
                    arabic ? 'EN' : 'ع',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 6),
              ],
            ),
            body: SafeArea(
              top: false,
              child: IndexedStack(index: tab, children: pages),
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: tab,
              onDestinationSelected: openTab,
              destinations: [
                NavigationDestination(
                  icon: const Icon(Icons.home_outlined),
                  selectedIcon: const Icon(Icons.home_rounded),
                  label: arabic ? 'الرئيسية' : 'HOME',
                ),
                NavigationDestination(
                  icon: const Icon(Icons.style_outlined),
                  selectedIcon: const Icon(Icons.style_rounded),
                  label: arabic ? 'البطاقات' : 'CARDS',
                ),
                NavigationDestination(
                  icon: const Icon(Icons.layers_outlined),
                  selectedIcon: const Icon(Icons.layers_rounded),
                  label: arabic ? 'المجموعات' : 'DECKS',
                ),
                NavigationDestination(
                  icon: const Icon(Icons.sports_mma_outlined),
                  selectedIcon: const Icon(Icons.sports_mma_rounded),
                  label: arabic ? 'اللعب' : 'PLAY',
                ),
                NavigationDestination(
                  icon: const Icon(Icons.menu_rounded),
                  selectedIcon: const Icon(Icons.menu_rounded),
                  label: arabic ? 'المزيد' : 'MORE',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TopCount extends StatelessWidget {
  const _TopCount({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF111824),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x1FFFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF7F8B9C),
              fontSize: 7,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
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
    final unlocked = player.pvpUnlocked;
    final progress = (player.ownedCount / kPvpMinimumCollection).clamp(0.0, 1.0);

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
      children: [
        _Eyebrow(text: arabic ? 'مرحباً بك' : 'WELCOME BACK'),
        const SizedBox(height: 6),
        Text(
          unlocked
              ? (arabic ? 'اختر مجموعتك وابدأ المواجهة.' : 'Choose your deck. Enter the duel.')
              : (arabic ? 'ابنِ أول 10 بطاقات لك.' : 'Build your first 10 cards.'),
          style: const TextStyle(fontSize: 28, height: 1.06, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 14),
        _HeroAction(arabic: arabic, unlocked: unlocked, onTap: () => open(3)),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: arabic ? 'المجموعة' : 'COLLECTION',
                value: '${player.ownedCount}/$kTotalCards',
                icon: Icons.style_rounded,
                onTap: () => open(1),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                label: arabic ? 'المجموعة النشطة' : 'ACTIVE DECK',
                value: '${player.decks[player.activeDeck].length}/$kDeckSize',
                icon: Icons.layers_rounded,
                onTap: () => open(2),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _SectionHeader(
          title: arabic ? 'مسار البداية' : 'START HERE',
          subtitle: arabic ? 'هذه هي الخطوة المطلوبة قبل PvP.' : 'The exact path to PvP.',
        ),
        const SizedBox(height: 10),
        _ProgressCard(
          arabic: arabic,
          progress: progress,
          owned: player.ownedCount,
          open: open,
          unlocked: unlocked,
        ),
        const SizedBox(height: 20),
        _SectionHeader(
          title: arabic ? 'الوصول السريع' : 'QUICK ACCESS',
          subtitle: arabic ? 'الوصول المباشر لأهم أجزاء اللعبة.' : 'Jump directly into the core areas.',
        ),
        const SizedBox(height: 10),
        _QuickTile(
          icon: Icons.style_rounded,
          title: arabic ? 'المجموعة' : 'COLLECTION',
          subtitle: arabic ? '222 بطاقة فريدة' : '222 unique cards',
          onTap: () => open(1),
        ),
        _QuickTile(
          icon: Icons.layers_rounded,
          title: arabic ? 'بناء المجموعة' : 'DECK BUILDER',
          subtitle: arabic ? '10 بطاقات لكل مجموعة' : '10 cards per deck',
          onTap: () => open(2),
        ),
        _QuickTile(
          icon: Icons.emoji_events_rounded,
          title: arabic ? 'الترتيب' : 'RANKING',
          subtitle: arabic ? 'الجوائز مبنية على الملكية' : 'Rewards are card-based',
          onTap: () => open(4),
        ),
        const SizedBox(height: 10),
        _RuleStrip(
          icon: Icons.shield_outlined,
          title: arabic ? 'الهيكل أولاً' : 'STRUCTURE FIRST',
          body: arabic
              ? 'لا توجد أسئلة حقيقية أو مباراة مباشرة في هذه المرحلة.'
              : 'No real question bank or live match is connected yet.',
        ),
      ],
    );
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          color: Color(0xFFF3C86B),
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
        ),
      );
}

class _HeroAction extends StatelessWidget {
  const _HeroAction({required this.arabic, required this.unlocked, required this.onTap});
  final bool arabic;
  final bool unlocked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Ink(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF182436), Color(0xFF101722)],
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0x35F3C86B)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3C86B),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    unlocked ? Icons.sports_mma_rounded : Icons.smart_toy_rounded,
                    color: const Color(0xFF0A0F19),
                    size: 25,
                  ),
                ),
                const Spacer(),
                _Pill(
                  label: unlocked ? 'PVP READY' : (arabic ? 'البداية' : 'ONBOARDING'),
                  positive: unlocked,
                ),
              ],
            ),
            const SizedBox(height: 22),
            Text(
              unlocked ? 'TROLL DUEL' : 'BOT TRAINING',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: .4),
            ),
            const SizedBox(height: 6),
            Text(
              unlocked
                  ? (arabic
                      ? 'اختر مجموعة مكتملة من 10 بطاقات. المطابقة واللعب المباشر ستُربط في مرحلة backend.'
                      : 'Select a complete 10-card deck. Matchmaking and live play will connect in the backend phase.')
                  : (arabic
                      ? 'الإجابات الصحيحة تمنح بطاقة عادية غير مملوكة حتى تصل إلى 10.'
                      : 'Correct answers award an unowned normal card until you reach 10.'),
              style: const TextStyle(color: Color(0xFF9BA6B5), fontSize: 11, height: 1.5),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onTap,
              icon: Icon(unlocked ? Icons.arrow_forward_rounded : Icons.play_arrow_rounded),
              label: Text(unlocked
                  ? (arabic ? 'الدخول إلى اللعب' : 'OPEN PLAY')
                  : (arabic ? 'فتح التدريب' : 'OPEN TRAINING')),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.icon, required this.onTap});
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(19),
      child: Ink(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: const Color(0xFF111824),
          borderRadius: BorderRadius.circular(19),
          border: Border.all(color: const Color(0x1FFFFFFF)),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF78D9D0), size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: Color(0xFF7F8B9C), fontSize: 8, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: Color(0xFF7F8B9C), fontSize: 10)),
        ],
      );
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.arabic,
    required this.progress,
    required this.owned,
    required this.open,
    required this.unlocked,
  });

  final bool arabic;
  final double progress;
  final int owned;
  final ValueChanged<int> open;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xFF111824),
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: const Color(0x1FFFFFFF)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                unlocked ? Icons.check_circle_rounded : Icons.lock_open_rounded,
                color: unlocked ? const Color(0xFF78D9D0) : const Color(0xFFF3C86B),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  unlocked ? (arabic ? 'PvP مفتوح' : 'PVP UNLOCKED') : (arabic ? 'اجمع 10 بطاقات' : 'COLLECT 10 CARDS'),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              Text(
                '$owned/$kPvpMinimumCollection',
                style: const TextStyle(color: Color(0xFFF3C86B), fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: const Color(0xFF283242),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  unlocked
                      ? (arabic ? 'يمكنك الآن تجهيز مجموعة والانتقال للعب.' : 'You can now prepare a deck and move to play.')
                      : (arabic ? 'Bot هو المسار الوحيد حتى تملك 10 بطاقات.' : 'Bot onboarding is the only path until 10 cards.'),
                  style: const TextStyle(color: Color(0xFF7F8B9C), fontSize: 10, height: 1.4),
                ),
              ),
              TextButton(
                onPressed: () => open(unlocked ? 2 : 3),
                child: Text(arabic ? 'فتح' : 'OPEN'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickTile extends StatelessWidget {
  const _QuickTile({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        tileColor: const Color(0xFF111824),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0x1FFFFFFF)),
        ),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: const Color(0xFF182333), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: const Color(0xFF78D9D0), size: 21),
        ),
        title: Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
        subtitle: Text(subtitle, style: const TextStyle(color: Color(0xFF7F8B9C), fontSize: 10)),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

class _RuleStrip extends StatelessWidget {
  const _RuleStrip({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF101722),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0x1FFFFFFF)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFFF3C86B), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(body, style: const TextStyle(color: Color(0xFF7F8B9C), fontSize: 10, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CollectionPage extends StatefulWidget {
  const _CollectionPage({required this.arabic, required this.player});
  final bool arabic;
  final DemoPlayerState player;

  @override
  State<_CollectionPage> createState() => _CollectionPageState();
}

class _CollectionPageState extends State<_CollectionPage> {
  CardRarity? filter;

  @override
  Widget build(BuildContext context) {
    final catalog = CardCatalog.foundation();
    final cards = filter == null
        ? catalog.cards
        : catalog.cards.where((c) => c.rarity == filter).toList();
    final owned = widget.player.ownedCards.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
      children: [
        _PageHeader(
          eyebrow: widget.arabic ? 'المجموعة' : 'COLLECTION',
          title: widget.arabic ? 'كل بطاقاتك في مكان واحد' : 'YOUR CARDS, ONE PLACE',
          body: widget.arabic
              ? '222 بطاقة فريدة. لا يمكن امتلاك نسختين من نفس Card ID.'
              : '222 unique cards. One copy maximum per Card ID.',
          trailing: '${owned}/$kTotalCards',
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: _RarityStat(label: 'EPIC', value: '$kEpicCards', active: filter == CardRarity.epic, onTap: () => setState(() => filter = filter == CardRarity.epic ? null : CardRarity.epic))),
            const SizedBox(width: 8),
            Expanded(child: _RarityStat(label: 'GOLD', value: '$kGoldCards', active: filter == CardRarity.gold, onTap: () => setState(() => filter = filter == CardRarity.gold ? null : CardRarity.gold))),
            const SizedBox(width: 8),
            Expanded(child: _RarityStat(label: 'LEGENDARY', value: '$kLegendaryCards', active: filter == CardRarity.legendary, onTap: () => setState(() => filter = filter == CardRarity.legendary ? null : CardRarity.legendary))),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Text(
                filter == null
                    ? (widget.arabic ? 'كل البطاقات' : 'ALL CARDS')
                    : filter == CardRarity.epic
                        ? 'EPIC'
                        : filter == CardRarity.gold
                            ? 'GOLD'
                            : 'LEGENDARY',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
              ),
            ),
            Text(
              '${cards.length}',
              style: const TextStyle(color: Color(0xFF7F8B9C), fontSize: 11, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cards.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 9,
            mainAxisSpacing: 9,
            childAspectRatio: .83,
          ),
          itemBuilder: (context, index) {
            final card = cards[index];
            final isOwned = widget.player.ownedCards.contains(card.id);
            return _CardTile(
              card: card,
              owned: isOwned,
              arabic: widget.arabic,
              onTap: isOwned ? () => _showCardDetails(context, card) : null,
            );
          },
        ),
      ],
    );
  }

  void _showCardDetails(BuildContext context, QuestionCard card) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(card.id, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(
              card.rarity.name.toUpperCase(),
              style: const TextStyle(color: Color(0xFFF3C86B), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2),
            ),
            const SizedBox(height: 14),
            Text(
              widget.arabic
                  ? 'محتوى السؤال الحقيقي سيُضاف لاحقاً. البطاقة الآن تمثل هوية السؤال وبنيته.'
                  : 'The real question content will be added later. This card currently represents the question identity and structure.',
              style: const TextStyle(color: Color(0xFF8E99A8), height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _RarityStat extends StatelessWidget {
  const _RarityStat({required this.label, required this.value, required this.active, required this.onTap});
  final String label;
  final String value;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF1A2837) : const Color(0xFF111824),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: active ? const Color(0x55F3C86B) : const Color(0x1FFFFFFF)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Color(0xFF7F8B9C), fontSize: 7, fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}

class _CardTile extends StatelessWidget {
  const _CardTile({required this.card, required this.owned, required this.arabic, required this.onTap});
  final QuestionCard card;
  final bool owned;
  final bool arabic;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = card.rarity == CardRarity.legendary
        ? const Color(0xFFF3C86B)
        : card.rarity == CardRarity.gold
            ? const Color(0xFFD1AD5C)
            : const Color(0xFF78D9D0);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(17),
      child: Ink(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: owned ? const Color(0xFF172131) : const Color(0xFF0F151F),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: owned ? accent.withValues(alpha: .48) : const Color(0x171FFFFFFF)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 38,
              height: 48,
              decoration: BoxDecoration(
                color: owned ? const Color(0xFF202D3C) : const Color(0xFF111824),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: owned ? accent.withValues(alpha: .55) : const Color(0x1FFFFFFF)),
              ),
              child: Icon(owned ? Icons.style_rounded : Icons.lock_rounded, color: owned ? accent : const Color(0xFF5E697A), size: 21),
            ),
            const SizedBox(height: 8),
            Text(
              card.id,
              style: TextStyle(color: owned ? accent : const Color(0xFF5E697A), fontSize: 8, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              owned ? (arabic ? 'مملوكة' : 'OWNED') : (arabic ? 'مقفلة' : 'LOCKED'),
              style: const TextStyle(color: Color(0xFF6F7B8A), fontSize: 7, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}

class _DecksPage extends StatelessWidget {
  const _DecksPage({required this.arabic, required this.player});
  final bool arabic;
  final DemoPlayerState player;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
      children: [
        _PageHeader(
          eyebrow: arabic ? 'بناء المجموعة' : 'DECK BUILDER',
          title: arabic ? 'ابنِ مجموعة تخوض بها المبارزة' : 'BUILD THE DECK YOU PLAY',
          body: arabic
              ? 'كل مجموعة 10 بطاقات مختلفة. البطاقة الواحدة يمكن تكرارها في أكثر من مجموعة.'
              : 'Every deck has 10 distinct cards. A card can be reused across decks.',
          trailing: '${player.deckSlots}/$kMaxDeckSlots',
        ),
        const SizedBox(height: 14),
        if (player.ownedCount < kDeckSize)
          _DeckEmptyState(arabic: arabic),
        for (int index = 0; index < kMaxDeckSlots; index++) ...[
          _DeckSlotCard(
            index: index,
            deck: player.decks[index],
            unlocked: index < player.deckSlots,
            active: player.activeDeck == index,
            arabic: arabic,
            onTap: index < player.deckSlots
                ? () => _openBuilder(context, index)
                : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => _PassPage(arabic: arabic, player: player),
                      ),
                    ),
          ),
          const SizedBox(height: 9),
        ],
        _RuleStrip(
          icon: Icons.auto_awesome_outlined,
          title: arabic ? 'الدور الاستراتيجي' : 'WHY DECKS MATTER',
          body: arabic
              ? 'الخادم يختار 7 بطاقات من مجموعتك عند بداية المبارزة، وتحدد هذه البطاقات الأسئلة التي يواجهها خصمك.'
              : 'At duel start, the server selects 7 cards from your deck. Those cards determine the questions your opponent faces.',
        ),
      ],
    );
  }

  void _openBuilder(BuildContext context, int deckIndex) {
    player.setActiveDeck(deckIndex);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _DeckBuilderPage(
          arabic: arabic,
          player: player,
          deckIndex: deckIndex,
        ),
      ),
    );
  }
}

class _DeckEmptyState extends StatelessWidget {
  const _DeckEmptyState({required this.arabic});
  final bool arabic;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF101722),
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: const Color(0x1FFFFFFF)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: Color(0xFFF3C86B)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              arabic
                  ? 'لا يمكن تجهيز مجموعة قبل امتلاك 10 بطاقات.'
                  : 'A complete deck cannot be built before you own 10 cards.',
              style: const TextStyle(color: Color(0xFF8E99A8), fontSize: 10, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeckSlotCard extends StatelessWidget {
  const _DeckSlotCard({
    required this.index,
    required this.deck,
    required this.unlocked,
    required this.active,
    required this.arabic,
    required this.onTap,
  });

  final int index;
  final List<String> deck;
  final bool unlocked;
  final bool active;
  final bool arabic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ready = deck.length == kDeckSize;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(19),
      child: Ink(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF182636) : const Color(0xFF111824),
          borderRadius: BorderRadius.circular(19),
          border: Border.all(color: active ? const Color(0x45F3C86B) : const Color(0x1FFFFFFF)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 52,
              decoration: BoxDecoration(
                color: unlocked ? const Color(0xFF202D3C) : const Color(0xFF0D131C),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                unlocked ? Icons.layers_rounded : Icons.lock_rounded,
                color: unlocked
                    ? (ready ? const Color(0xFF78D9D0) : const Color(0xFFF3C86B))
                    : const Color(0xFF5E697A),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    arabic ? 'مجموعة ${index + 1}' : 'DECK ${index + 1}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    !unlocked
                        ? (arabic ? 'مفتوحة مع Weekly Pass' : 'Unlock with Weekly Pass')
                        : ready
                            ? (arabic ? 'مكتملة 10 / 10' : 'COMPLETE 10 / 10')
                            : (arabic ? '${deck.length} / $kDeckSize بطاقات' : '${deck.length} / $kDeckSize cards'),
                    style: TextStyle(
                      color: ready ? const Color(0xFF78D9D0) : const Color(0xFF7F8B9C),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            if (active && unlocked)
              const Icon(Icons.check_circle_rounded, color: Color(0xFF78D9D0), size: 19)
            else
              const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

class _DeckBuilderPage extends StatelessWidget {
  const _DeckBuilderPage({
    required this.arabic,
    required this.player,
    required this.deckIndex,
  });

  final bool arabic;
  final DemoPlayerState player;
  final int deckIndex;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: player,
      builder: (context, _) {
        final catalog = CardCatalog.foundation();
        final current = player.decks[deckIndex];
        final ownedCards = catalog.cards.where((c) => player.ownedCards.contains(c.id)).toList(growable: false);
        final ready = current.length == kDeckSize;

        return Directionality(
          textDirection: arabic ? TextDirection.rtl : TextDirection.ltr,
          child: Scaffold(
            appBar: AppBar(
              title: Text(arabic ? 'مجموعة ${deckIndex + 1}' : 'DECK ${deckIndex + 1}'),
              actions: [
                TextButton(
                  onPressed: current.isEmpty ? null : () => player.clearDeck(deckIndex),
                  child: Text(arabic ? 'مسح' : 'CLEAR'),
                ),
              ],
            ),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 30),
              children: [
                _DeckBuilderTop(arabic: arabic, count: current.length, ready: ready),
                const SizedBox(height: 14),
                if (ownedCards.isEmpty)
                  _NoCardsBuilderState(arabic: arabic)
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: ownedCards.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 9,
                      mainAxisSpacing: 9,
                      childAspectRatio: .83,
                    ),
                    itemBuilder: (context, index) {
                      final card = ownedCards[index];
                      final isSelected = current.contains(card.id);
                      return _SelectableCard(
                        card: card,
                        selected: isSelected,
                        arabic: arabic,
                        disabled: !isSelected && current.length >= kDeckSize,
                        onTap: () => player.toggleCardInDeck(card.id),
                      );
                    },
                  ),
                const SizedBox(height: 18),
                _RuleStrip(
                  icon: Icons.security_rounded,
                  title: arabic ? 'الملكية ليست من الواجهة' : 'OWNERSHIP IS NOT CLIENT AUTHORITY',
                  body: arabic
                      ? 'هذه واجهة اختيار فقط. عند ربط Firebase، الخادم هو المرجع النهائي للملكية والحفظ.'
                      : 'This is only a selection UI. When Firebase is connected, the server owns the final authority over persistence and ownership.',
                ),
              ],
            ),
            bottomNavigationBar: SafeArea(
              minimum: const EdgeInsets.all(14),
              child: FilledButton.icon(
                onPressed: ready ? () => Navigator.pop(context) : null,
                icon: const Icon(Icons.check_rounded),
                label: Text(ready ? (arabic ? 'حفظ المجموعة' : 'SAVE DECK') : (arabic ? 'اختر 10 بطاقات' : 'SELECT 10 CARDS')),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DeckBuilderTop extends StatelessWidget {
  const _DeckBuilderTop({required this.arabic, required this.count, required this.ready});
  final bool arabic;
  final int count;
  final bool ready;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: const Color(0xFF111824),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: ready ? const Color(0x3F78D9D0) : const Color(0x1FFFFFFF)),
        ),
        child: Row(
          children: [
            Icon(ready ? Icons.check_circle_rounded : Icons.layers_rounded, color: ready ? const Color(0xFF78D9D0) : const Color(0xFFF3C86B)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                ready ? (arabic ? 'المجموعة جاهزة للمواجهة.' : 'This deck is ready for a duel.') : (arabic ? 'اختر بطاقاتك بعناية.' : 'Choose your cards carefully.'),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            Text('$count / $kDeckSize', style: const TextStyle(color: Color(0xFFF3C86B), fontWeight: FontWeight.w900)),
          ],
        ),
      );
}

class _SelectableCard extends StatelessWidget {
  const _SelectableCard({
    required this.card,
    required this.selected,
    required this.arabic,
    required this.disabled,
    required this.onTap,
  });

  final QuestionCard card;
  final bool selected;
  final bool arabic;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = card.rarity == CardRarity.legendary
        ? const Color(0xFFF3C86B)
        : card.rarity == CardRarity.gold
            ? const Color(0xFFD1AD5C)
            : const Color(0xFF78D9D0);

    return InkWell(
      onTap: disabled ? null : onTap,
      borderRadius: BorderRadius.circular(17),
      child: Ink(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF203346) : const Color(0xFF111824),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: selected ? const Color(0xFF78D9D0) : const Color(0x1FFFFFFF),
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 38,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF1B2634),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(Icons.style_rounded, color: accent),
            ),
            const SizedBox(height: 8),
            Text(card.id, style: TextStyle(color: accent, fontSize: 8, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(
              selected ? (arabic ? 'مختارة' : 'SELECTED') : (arabic ? 'اختيار' : 'SELECT'),
              style: TextStyle(
                color: selected ? const Color(0xFF78D9D0) : const Color(0xFF6F7B8A),
                fontSize: 7,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoCardsBuilderState extends StatelessWidget {
  const _NoCardsBuilderState({required this.arabic});
  final bool arabic;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF111824),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0x1FFFFFFF)),
        ),
        child: Column(
          children: [
            const Icon(Icons.style_outlined, size: 46, color: Color(0xFF5E697A)),
            const SizedBox(height: 12),
            Text(
              arabic ? 'المجموعة فارغة الآن' : 'YOUR BUILDER IS EMPTY',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              arabic
                  ? 'اجمع أول 10 بطاقات من Bot Training ثم عد لبناء أول مجموعة.'
                  : 'Collect your first 10 cards from Bot Training, then return to build your deck.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF7F8B9C), fontSize: 10, height: 1.5),
            ),
          ],
        ),
      );
}

class _PlayPage extends StatefulWidget {
  const _PlayPage({required this.arabic, required this.player});
  final bool arabic;
  final DemoPlayerState player;

  @override
  State<_PlayPage> createState() => _PlayPageState();
}

class _PlayPageState extends State<_PlayPage> {
  int mode = 0;

  @override
  Widget build(BuildContext context) {
    final pvp = widget.player.pvpUnlocked;
    final deckReady = widget.player.activeDeckReady;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
      children: [
        _PageHeader(
          eyebrow: widget.arabic ? 'اللعب' : 'PLAY',
          title: widget.arabic ? 'اختر كيف تريد أن تلعب' : 'CHOOSE HOW YOU PLAY',
          body: widget.arabic
              ? 'نحدد الوضع الآن. الأسئلة والمطابقة المباشرة ستأتي في طبقات التنفيذ التالية.'
              : 'Choose the mode now. Questions and live matchmaking connect in later implementation layers.',
          trailing: pvp ? 'READY' : 'LOCKED',
        ),
        const SizedBox(height: 14),
        SegmentedButton<int>(
          segments: [
            ButtonSegment(
              value: 0,
              icon: const Icon(Icons.smart_toy_rounded),
              label: Text(widget.arabic ? 'Bot' : 'BOT'),
            ),
            const ButtonSegment(
              value: 1,
              icon: Icon(Icons.sports_mma_rounded),
              label: Text('TROLL DUEL'),
            ),
          ],
          selected: {mode},
          onSelectionChanged: (value) => setState(() => mode = value.first),
        ),
        const SizedBox(height: 14),
        if (mode == 0)
          _PlayModeCard(
            icon: Icons.smart_toy_rounded,
            title: widget.arabic ? 'تدريب Bot' : 'BOT TRAINING',
            status: widget.player.pvpUnlocked ? (widget.arabic ? 'مكتمل' : 'COMPLETE') : (widget.arabic ? 'متاح' : 'AVAILABLE'),
            body: widget.arabic
                ? 'الهدف: الوصول إلى 10 بطاقات. الصحيح يمنح بطاقة عادية غير مملوكة، والخطأ أو انتهاء الوقت لا يمنح شيئاً.'
                : 'Goal: reach 10 cards. Correct answers award an unowned normal card; wrong or timeout awards nothing.',
            primary: !widget.player.pvpUnlocked,
            actionLabel: widget.arabic ? 'تدريب لاحقاً' : 'TRAINING UI LATER',
            onTap: () => _showPending(context),
          )
        else
          _PlayModeCard(
            icon: Icons.sports_mma_rounded,
            title: 'TROLL DUEL',
            status: pvp && deckReady ? 'READY' : pvp ? 'DECK NEEDED' : 'LOCKED',
            body: pvp
                ? (widget.arabic
                    ? '1v1 تنافسي. تختار مجموعة من 10، والخادم يحدد 7 بطاقات للمواجهة.'
                    : 'Competitive 1v1. Choose a 10-card deck, then the server selects 7 duel cards.')
                : (widget.arabic ? 'مغلق حتى تملك 10 بطاقات.' : 'Locked until you own 10 cards.'),
            primary: pvp && deckReady,
            actionLabel: pvp && deckReady
                ? (widget.arabic ? 'تجهيز المطابقة' : 'PREP MATCH')
                : pvp
                    ? (widget.arabic ? 'اذهب للمجموعات' : 'OPEN DECKS')
                    : (widget.arabic ? 'مغلق' : 'LOCKED'),
            onTap: pvp && deckReady
                ? () => _showPending(context)
                : pvp
                    ? () => _showDeckHint(context)
                    : null,
          ),
        const SizedBox(height: 14),
        _DuelFlowCard(arabic: widget.arabic),
        const SizedBox(height: 12),
        _RuleStrip(
          icon: Icons.lock_outline_rounded,
          title: widget.arabic ? 'المباراة الحقيقية غير مفعلة بعد' : 'LIVE MATCH IS NOT CONNECTED',
          body: widget.arabic
              ? 'هذه المرحلة تثبت تجربة المستخدم ومسارات الشاشة بدون اختلاق مباراة وهمية.'
              : 'This phase locks the UX and screen flow without pretending a fake live match exists.',
        ),
      ],
    );
  }

  void _showPending(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.arabic
              ? 'تم تثبيت المسار. سنربطه بالمحتوى والbackend لاحقاً.'
              : 'The flow is ready. Content and backend will connect later.',
        ),
      ),
    );
  }

  void _showDeckHint(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.arabic ? 'أكمل مجموعة نشطة من 10 بطاقات أولاً.' : 'Complete an active 10-card deck first.',
        ),
      ),
    );
  }
}

class _PlayModeCard extends StatelessWidget {
  const _PlayModeCard({
    required this.icon,
    required this.title,
    required this.status,
    required this.body,
    required this.primary,
    required this.actionLabel,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String status;
  final String body;
  final bool primary;
  final String actionLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF121C29),
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: const Color(0x1FFFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(color: const Color(0xFF1D2A3A), borderRadius: BorderRadius.circular(15)),
                child: Icon(icon, color: const Color(0xFF78D9D0)),
              ),
              const Spacer(),
              _Pill(label: status, positive: primary),
            ],
          ),
          const SizedBox(height: 19),
          Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 7),
          Text(body, style: const TextStyle(color: Color(0xFF929EAE), height: 1.5, fontSize: 11)),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onTap,
            icon: Icon(primary ? Icons.arrow_forward_rounded : Icons.info_outline_rounded),
            label: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

class _DuelFlowCard extends StatelessWidget {
  const _DuelFlowCard({required this.arabic});
  final bool arabic;

  @override
  Widget build(BuildContext context) {
    final items = arabic
        ? ['مجموعة 10', 'الخادم يختار 7', '7 أسئلة × 20 ثانية', 'نتيجة ثم سرقة']
        : ['10-card deck', 'Server selects 7', '7 questions × 20s', 'Result then steal'];

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xFF111824),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x1FFFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            arabic ? 'المواجهة في أربع خطوات' : 'THE DUEL IN FOUR STEPS',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          for (int i = 0; i < items.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 11,
                    backgroundColor: const Color(0xFF202D3C),
                    child: Text('${i + 1}'),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      items[i],
                      style: const TextStyle(color: Color(0xFF8995A5), fontSize: 10),
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

class _MorePage extends StatelessWidget {
  const _MorePage({required this.arabic, required this.player});
  final bool arabic;
  final DemoPlayerState player;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
      children: [
        _PageHeader(
          eyebrow: arabic ? 'المزيد' : 'MORE',
          title: arabic ? 'كل أدوات المنتج هنا' : 'ALL PRODUCT TOOLS',
          body: arabic ? 'الترتيب وWeekly Pass والإعدادات الأساسية.' : 'Ranking, Weekly Pass and essential settings.',
          trailing: '',
        ),
        const SizedBox(height: 14),
        _MoreTile(
          icon: Icons.emoji_events_rounded,
          title: arabic ? 'الترتيب' : 'RANKING',
          subtitle: arabic ? 'الأولوية الأساسية لعدد البطاقات المملوكة.' : 'Primary ranking metric: cards owned.',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _RankingPage(arabic: arabic))),
        ),
        _MoreTile(
          icon: Icons.workspace_premium_rounded,
          title: 'WEEKLY PASS',
          subtitle: arabic ? '+3 مجموعات + خيار إجابة رابع' : '+3 deck slots + fourth answer option',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _PassPage(arabic: arabic, player: player))),
        ),
        _MoreTile(
          icon: Icons.settings_rounded,
          title: arabic ? 'الإعدادات' : 'SETTINGS',
          subtitle: arabic ? 'اللغة وتفضيلات المنتج' : 'Language and product preferences',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _SettingsPage(arabic: arabic))),
        ),
        _MoreTile(
          icon: Icons.menu_book_rounded,
          title: arabic ? 'كيف تعمل اللعبة؟' : 'HOW IT WORKS',
          subtitle: arabic ? 'المسار الكامل من البطاقة إلى السرقة' : 'The full path from card to steal',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _HowItWorksPage(arabic: arabic))),
        ),
      ],
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.trailing,
  });

  final String eyebrow;
  final String title;
  final String body;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(eyebrow, style: const TextStyle(color: Color(0xFFF3C86B), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.4)),
              const SizedBox(height: 6),
              Text(title, style: const TextStyle(fontSize: 25, height: 1.05, fontWeight: FontWeight.w900)),
              const SizedBox(height: 7),
              Text(body, style: const TextStyle(color: Color(0xFF7F8B9C), fontSize: 11, height: 1.45)),
            ],
          ),
        ),
        if (trailing.isNotEmpty) ...[
          const SizedBox(width: 14),
          Text(trailing, style: const TextStyle(color: Color(0xFFF3C86B), fontWeight: FontWeight.w900)),
        ],
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.positive});
  final String label;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: positive ? const Color(0x1926C9B5) : const Color(0x16F3C86B),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: positive ? const Color(0x3A78D9D0) : const Color(0x35F3C86B)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: positive ? const Color(0xFF78D9D0) : const Color(0xFFF3C86B),
          fontSize: 8,
          fontWeight: FontWeight.w900,
          letterSpacing: .8,
        ),
      ),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: ListTile(
        onTap: onTap,
        tileColor: const Color(0xFF111824),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0x1FFFFFFF)),
        ),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: const Color(0xFF182333), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: const Color(0xFFF3C86B), size: 21),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
        subtitle: Text(subtitle, style: const TextStyle(color: Color(0xFF7F8B9C), fontSize: 10)),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

class _RankingPage extends StatelessWidget {
  const _RankingPage({required this.arabic});
  final bool arabic;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(arabic ? 'الترتيب' : 'RANKING')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
        children: [
          _PageHeader(
            eyebrow: 'RANKING',
            title: arabic ? 'اجمع أكثر، ارتقِ أعلى' : 'COLLECT MORE. RANK HIGHER.',
            body: arabic ? 'الترتيب يعتمد أساساً على عدد البطاقات المملوكة.' : 'Ranking is primarily driven by cards owned.',
            trailing: '',
          ),
          const SizedBox(height: 16),
          const _RankReward(rank: '1', reward: '1 LEGENDARY'),
          const _RankReward(rank: '2', reward: '3 GOLD'),
          const _RankReward(rank: '3', reward: '2 GOLD'),
          const SizedBox(height: 12),
          _RuleStrip(
            icon: Icons.info_outline_rounded,
            title: arabic ? 'الجوائز النهائية' : 'END-OF-RANK REWARDS',
            body: arabic
                ? 'الجوائز ستصبح server-authoritative عند ربط Firebase ودورة الترتيب.'
                : 'Rewards become server-authoritative when Firebase and ranking cycles are connected.',
          ),
        ],
      ),
    );
  }
}

class _RankReward extends StatelessWidget {
  const _RankReward({required this.rank, required this.reward});
  final String rank;
  final String reward;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 15),
      decoration: BoxDecoration(
        color: const Color(0xFF111824),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x1FFFFFFF)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 19,
            backgroundColor: const Color(0xFF202D3C),
            child: Text(rank, style: const TextStyle(fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 12),
          const Icon(Icons.card_giftcard_rounded, color: Color(0xFFF3C86B)),
          const SizedBox(width: 9),
          Text(reward, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
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
    final active = widget.player.weeklyPass;
    return Scaffold(
      appBar: AppBar(title: const Text('WEEKLY PASS')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
        children: [
          _PageHeader(
            eyebrow: 'WEEKLY PASS',
            title: active ? (widget.arabic ? 'الـPass فعال' : 'PASS ACTIVE') : (widget.arabic ? 'مزايا إضافية للجامع' : 'MORE ROOM TO COLLECT'),
            body: widget.arabic ? 'منتج الدفع الوحيد في الإصدار الأول.' : 'The only paid product planned for the initial release.',
            trailing: active ? 'ACTIVE' : 'OPTIONAL',
          ),
          const SizedBox(height: 16),
          _PassBenefit(
            icon: Icons.layers_rounded,
            title: widget.arabic ? '+3 مجموعات' : '+3 DECK SLOTS',
            body: widget.arabic ? 'إجمالي 5 مجموعات بدلاً من مجموعتين.' : 'Five total deck slots instead of two.',
          ),
          _PassBenefit(
            icon: Icons.looks_4_rounded,
            title: widget.arabic ? 'خيار إجابة رابع' : 'FOURTH ANSWER OPTION',
            body: widget.arabic ? 'يظهر حيث يدعم السؤال ذلك.' : 'Available where the question format supports it.',
          ),
          _PassBenefit(
            icon: Icons.calendar_today_rounded,
            title: widget.arabic ? 'وصول أسبوعي' : 'WEEKLY ACCESS',
            body: widget.arabic ? 'التسعير وSKU والتجديد ستضاف في مرحلة billing.' : 'Price, SKU and renewal belong to the billing implementation.',
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: active
                ? null
                : () {
                    widget.player.weeklyPass = true;
                    widget.player.notifyListeners();
                    setState(() {});
                  },
            child: Text(active ? (widget.arabic ? 'مفعل' : 'ACTIVE') : (widget.arabic ? 'تجربة محلية' : 'LOCAL DEMO')),
          ),
        ],
      ),
    );
  }
}

class _PassBenefit extends StatelessWidget {
  const _PassBenefit({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111824),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x1FFFFFFF)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFFF3C86B)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
                const SizedBox(height: 4),
                Text(body, style: const TextStyle(color: Color(0xFF7F8B9C), fontSize: 10, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsPage extends StatefulWidget {
  const _SettingsPage({required this.arabic});
  final bool arabic;

  @override
  State<_SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<_SettingsPage> {
  late bool arabic;

  @override
  void initState() {
    super.initState();
    arabic = widget.arabic;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: arabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(title: Text(arabic ? 'الإعدادات' : 'SETTINGS')),
        body: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            _SettingsGroup(
              title: arabic ? 'اللغة' : 'LANGUAGE',
              children: [
                SwitchListTile(
                  value: arabic,
                  onChanged: (value) => setState(() => arabic = value),
                  title: Text(arabic ? 'العربية' : 'Arabic'),
                  subtitle: Text(arabic ? 'تخطيط RTL مفعّل' : 'RTL layout support'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _SettingsGroup(
              title: arabic ? 'الحساب' : 'ACCOUNT',
              children: [
                ListTile(
                  leading: const Icon(Icons.lock_outline_rounded),
                  title: Text(arabic ? 'تسجيل الدخول' : 'SIGN IN'),
                  subtitle: Text(
                    arabic
                        ? 'Firebase Authentication سيضاف لاحقاً.'
                        : 'Firebase Authentication will be connected later.',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _RuleStrip(
              icon: Icons.palette_outlined,
              title: arabic ? 'التصميم النهائي غير مقفل' : 'FINAL ART IS NOT LOCKED',
              body: arabic
                  ? 'هذه المرحلة تثبت الهيكل وتجربة الاستخدام فقط، وليست اعتماداً نهائياً للهوية البصرية.'
                  : 'This phase locks structure and UX only, not the final visual identity.',
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111824),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x1FFFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 14, 15, 5),
            child: Text(
              title,
              style: const TextStyle(color: Color(0xFFF3C86B), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.1),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _HowItWorksPage extends StatelessWidget {
  const _HowItWorksPage({required this.arabic});
  final bool arabic;

  @override
  Widget build(BuildContext context) {
    final steps = arabic
        ? [
            'ابدأ بـ0 بطاقة ثم أكمل Bot حتى تملك 10.',
            'ابنِ مجموعة من 10 بطاقات مختلفة.',
            'عند PvP يختار الخادم 7 بطاقات من مجموعتك.',
            'خصمك يواجه الأسئلة المبنية على بطاقاتك.',
            'الأفضل في الإجابات يفوز، والتعادل يُحسم بالوقت.',
            'الفائز يختار بطاقة واحدة من مجموعة خصمه للسرقة.',
          ]
        : [
            'Start with 0 cards, then use Bot onboarding until 10.',
            'Build a deck of 10 distinct cards.',
            'In PvP, the server selects 7 cards from your deck.',
            'Your opponent faces questions generated from your cards.',
            'More correct answers wins; ties are decided by total time.',
            'The winner selects one card from the opponent deck to steal.',
          ];

    return Scaffold(
      appBar: AppBar(title: Text(arabic ? 'كيف تعمل اللعبة؟' : 'HOW IT WORKS')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
        children: [
          _PageHeader(
            eyebrow: 'CORE LOOP',
            title: arabic ? 'البطاقة هي جوهر اللعبة' : 'THE CARD IS THE GAME',
            body: arabic
                ? 'كل جزء من المنتج يعود إلى الجمع والبناء والمواجهة والسرقة.'
                : 'Every part of the product feeds collection, deck building, dueling and stealing.',
            trailing: '',
          ),
          const SizedBox(height: 16),
          for (int i = 0; i < steps.length; i++)
            Container(
              margin: const EdgeInsets.only(bottom: 9),
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: const Color(0xFF111824),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0x1FFFFFFF)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 17,
                    backgroundColor: const Color(0xFF202D3C),
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      steps[i],
                      style: const TextStyle(fontSize: 11, height: 1.45),
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
