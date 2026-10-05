import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'backend/firebase_bootstrap.dart';
import 'backend/firebase_game_api.dart';
import 'data/local_player_store.dart';
import 'game/game_rules.dart';
import 'game/question_bank.dart';
import 'services/purchase_service.dart';

class DemoPlayerState extends ChangeNotifier {
  DemoPlayerState();

  final LocalPlayerStore store = LocalPlayerStore();
  final List<List<String>> decks = List<List<String>>.generate(
    kMaxDeckSlots,
    (_) => <String>[],
  );
  final Set<String> ownedCards = <String>{};

  FirebaseGameApi? api;
  bool firebaseAvailable = false;
  bool initialized = false;
  bool loading = true;
  bool tutorialComplete = false;
  bool weeklyPass = false;
  DateTime? weeklyPassExpiresAt;
  int wins = 0;
  int losses = 0;
  int activeDeck = 0;
  StreamSubscription<dynamic>? _authSubscription;

  int get ownedCount => ownedCards.length;
  bool get pvpUnlocked => ownedCount >= kPvpMinimumCollection;
  int get deckSlots => weeklyPass ? kMaxDeckSlots : kFreeDeckSlots;
  bool get activeDeckReady =>
      activeDeck < deckSlots && decks[activeDeck].length == kDeckSize;
  bool get authenticated => api?.currentUser != null;
  String get accountLabel => api?.currentUser?.email ?? '';

  Future<void> initialize() async {
    if (initialized) return;
    final local = await store.load();
    ownedCards
      ..clear()
      ..addAll(local.ownedCards);
    for (int i = 0; i < kMaxDeckSlots; i++) {
      decks[i]
        ..clear()
        ..addAll(i < local.decks.length ? local.decks[i] : const <String>[]);
    }
    weeklyPass = local.weeklyPass;
    weeklyPassExpiresAt = local.weeklyPassExpiresAt;
    wins = local.wins;
    losses = local.losses;
    activeDeck = local.activeDeck.clamp(0, kMaxDeckSlots - 1);
    tutorialComplete = local.tutorialComplete;

    firebaseAvailable = await FirebaseBootstrap.initialize();
    if (firebaseAvailable) {
      api = FirebaseGameApi();
      _authSubscription = api!.auth.authStateChanges().listen((_) async {
        if (api?.currentUser != null) {
          await _loadRemote();
        }
        notifyListeners();
      });
      if (api!.currentUser != null) {
        await _loadRemote();
      }
    }
    initialized = true;
    loading = false;
    notifyListeners();
  }

  Future<void> _loadRemote() async {
    try {
      final data = await api!.loadProfile();
      final owned = List<String>.from(data['ownedCards'] as List? ?? const []);
      ownedCards
        ..clear()
        ..addAll(owned);

      final remoteDecks = data['decks'] as List? ?? const [];
      for (int i = 0; i < kMaxDeckSlots; i++) {
        decks[i]
          ..clear()
          ..addAll(i < remoteDecks.length
              ? List<String>.from(remoteDecks[i] as List? ?? const [])
              : const <String>[]);
      }

      wins = (data['wins'] as num?)?.toInt() ?? wins;
      losses = (data['losses'] as num?)?.toInt() ?? losses;
      activeDeck = ((data['activeDeck'] as num?)?.toInt() ?? activeDeck)
          .clamp(0, kMaxDeckSlots - 1);

      weeklyPassExpiresAt = _readDate(data['weeklyPassExpiresAt']);
      weeklyPass = weeklyPassExpiresAt != null &&
          weeklyPassExpiresAt!.isAfter(DateTime.now());

      await _saveLocal();
    } catch (_) {
      // Local state stays available when the backend is temporarily unreachable.
    }
  }

  DateTime? _readDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  Future<void> _saveLocal() => store.save(
        ownedCards: ownedCards,
        decks: decks,
        weeklyPass: weeklyPass,
        weeklyPassExpiresAt: weeklyPassExpiresAt,
        wins: wins,
        losses: losses,
        activeDeck: activeDeck,
        tutorialComplete: tutorialComplete,
      );

  Future<void> signIn(String email, String password) async {
    if (!firebaseAvailable || api == null) {
      throw StateError('Firebase is not configured in this build.');
    }
    await api!.signIn(email, password);
    await _loadRemote();
    notifyListeners();
  }

  Future<void> signUp(String email, String password) async {
    if (!firebaseAvailable || api == null) {
      throw StateError('Firebase is not configured in this build.');
    }
    await api!.signUp(email, password);
    await _loadRemote();
    notifyListeners();
  }

  Future<void> signOut() async {
    await api?.signOut();
    notifyListeners();
  }

  void completeTutorial() {
    tutorialComplete = true;
    _saveLocal();
    notifyListeners();
  }

  void setActiveDeck(int index) {
    if (index < 0 || index >= deckSlots) return;
    activeDeck = index;
    _saveLocal();
    notifyListeners();
  }

  Future<void> toggleCardInDeck(String cardId) async {
    if (activeDeck >= deckSlots || !ownedCards.contains(cardId)) return;
    final current = decks[activeDeck];
    if (current.contains(cardId)) {
      current.remove(cardId);
    } else if (current.length < kDeckSize) {
      current.add(cardId);
    }
    await _saveLocal();
    notifyListeners();
  }

  Future<void> clearDeck(int index) async {
    if (index < 0 || index >= deckSlots) return;
    decks[index].clear();
    await _saveLocal();
    notifyListeners();
  }

  Future<void> saveDeck(int index) async {
    if (index < 0 || index >= deckSlots) return;
    final deck = decks[index];
    final domainDeck = PlayerDeck(deck);
    domainDeck.validate(PlayerCollection(ownedCards));
    if (authenticated) {
      await api!.saveDeck(deckIndex: index, cardIds: deck);
      await _loadRemote();
    } else {
      await _saveLocal();
      notifyListeners();
    }
  }

  Future<BotRoundData> startBotRound({required bool arabic}) async {
    if (!tutorialComplete) completeTutorial();
    if (pvpUnlocked) {
      throw StateError('Bot onboarding is complete.');
    }
    if (authenticated) {
      return api!.startBotRound(arabic: arabic);
    }

    final normalQuestions = QuestionBank.normal.toList(growable: false);
    final rewardCandidates = normalQuestions
        .where((q) => !ownedCards.contains(q.id))
        .toList(growable: false);
    if (rewardCandidates.isEmpty) {
      throw StateError('No unowned normal reward cards remain.');
    }

    final random = Random();
    final q = normalQuestions[random.nextInt(normalQuestions.length)];
    final reward = rewardCandidates[random.nextInt(rewardCandidates.length)];
    return BotRoundData(
      roundId: 'local-' + DateTime.now().microsecondsSinceEpoch.toString(),
      questionId: q.id,
      questionEn: q.questionEn,
      questionAr: q.questionAr,
      answersEn: q.answersEn,
      answersAr: q.answersAr,
      rewardCardId: reward.id,
    );
  }

  Future<bool> completeBotRound({
    required BotRoundData round,
    required int answerIndex,
  }) async {
    if (authenticated) {
      final result = await api!.submitBotAnswer(
        roundId: round.roundId,
        answerIndex: answerIndex,
      );
      await _loadRemote();
      return result['correct'] == true;
    }

    final q = QuestionBank.byId(round.questionId);
    final correct = answerIndex == q.correctIndex;
    if (correct && ownedCount < kPvpMinimumCollection) {
      ownedCards.add(round.rewardCardId ?? round.questionId);
      await _saveLocal();
      notifyListeners();
    }
    return correct;
  }

  Future<Map<String, dynamic>> findOrCreateDuel() async {
    if (!authenticated) {
      throw StateError('Sign in before entering TROLL DUEL.');
    }
    if (!activeDeckReady) {
      throw StateError('Complete the active 10-card deck first.');
    }
    return api!.findOrCreateDuel(List<String>.from(decks[activeDeck]));
  }

  Future<List<Map<String, dynamic>>> loadRanking() async {
    if (!authenticated) {
      throw StateError('Sign in to load the ranking.');
    }
    return api!.ranking();
  }

  Future<Map<String, dynamic>> claimRankingReward() async {
    if (!authenticated) throw StateError('Sign in first.');
    final result = await api!.claimRankingReward();
    await _loadRemote();
    notifyListeners();
    return result;
  }

  Future<Map<String, dynamic>> verifyWeeklyPass({
    required String productId,
    required String platform,
    required String receipt,
  }) async {
    if (!authenticated) throw StateError('Sign in before purchasing.');
    final result = await api!.verifyWeeklyPassPurchase(
      productId: productId,
      platform: platform,
      receipt: receipt,
    );
    await _loadRemote();
    notifyListeners();
    return result;
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
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
  void initState() {
    super.initState();
    player.initialize();
  }

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
        if (player.loading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
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
                    value: player.ownedCount.toString() + '/' + kTotalCards.toString(),
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
    final progress = (player.ownedCount / kPvpMinimumCollection).clamp(0.0, 1.0);
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
      children: [
        Text(
          arabic ? 'STEAL THE QUESTIONS' : 'STEAL THE QUESTIONS',
          style: const TextStyle(
            color: Color(0xFFF3C86B),
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          player.pvpUnlocked
              ? (arabic ? 'بطاقاتك أصبحت ترسانة للمواجهة.' : 'Your collection is now your arsenal.')
              : (arabic ? 'ابدأ بجمع أول 10 بطاقات.' : 'Start by collecting your first 10 cards.'),
          style: const TextStyle(fontSize: 28, height: 1.05, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 15),
        _ActionCard(
          icon: player.pvpUnlocked ? Icons.sports_mma_rounded : Icons.smart_toy_rounded,
          title: player.pvpUnlocked
              ? 'TROLL DUEL'
              : (arabic ? 'تدريب BOT' : 'BOT TRAINING'),
          body: player.pvpUnlocked
              ? (arabic
                  ? 'اختر مجموعة من 10 بطاقات وادخل مطابقة حقيقية.'
                  : 'Choose a 10-card deck and enter a real match.')
              : (arabic
                  ? 'كل إجابة صحيحة تمنحك بطاقة عادية غير مملوكة حتى تصل إلى 10.'
                  : 'Every correct answer earns an unowned normal card until you reach 10.'),
          action: player.pvpUnlocked
              ? (arabic ? 'ابدأ المواجهة' : 'START DUEL')
              : (arabic ? 'ابدأ التدريب' : 'START TRAINING'),
          onTap: () => open(3),
        ),
        const SizedBox(height: 13),
        Row(
          children: [
            Expanded(
              child: _MiniStat(
                title: arabic ? 'المجموعة' : 'COLLECTION',
                value: player.ownedCount.toString() + '/' + kTotalCards.toString(),
                onTap: () => open(1),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MiniStat(
                title: arabic ? 'المجموعة النشطة' : 'ACTIVE DECK',
                value: player.decks[player.activeDeck].length.toString() + '/' + kDeckSize.toString(),
                onTap: () => open(2),
              ),
            ),
          ],
        ),
        const SizedBox(height: 19),
        _Section(
          title: arabic ? 'بوابة PvP' : 'PVP GATE',
          body: arabic
              ? 'يُفتح PvP عند امتلاك 10 بطاقات كاملة.'
              : 'PvP opens when you own at least 10 cards.',
        ),
        const SizedBox(height: 10),
        _ProgressBox(
          arabic: arabic,
          progress: progress,
          value: player.ownedCount,
          unlocked: player.pvpUnlocked,
        ),
        const SizedBox(height: 19),
        _Section(
          title: arabic ? 'الحساب' : 'ACCOUNT',
          body: player.authenticated
              ? (arabic ? player.accountLabel : player.accountLabel)
              : (arabic ? 'المعاينة المحلية مفعلة' : 'Local preview mode'),
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.action,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String body;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Ink(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF111824),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0x35F3C86B)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3C86B),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: const Color(0xFF0A0F19)),
                ),
                const Spacer(),
                const _Pill(label: 'LIVE SYSTEMS', positive: true),
              ],
            ),
            const SizedBox(height: 18),
            Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(body, style: const TextStyle(color: Color(0xFF919CAC), height: 1.5, fontSize: 11)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: Text(action),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.title, required this.value, required this.onTap});
  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: const Color(0xFF111824),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0x1FFFFFFF)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Color(0xFF7F8B9C), fontSize: 8, fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(body, style: const TextStyle(color: Color(0xFF7F8B9C), fontSize: 10)),
        ],
      );
}

class _ProgressBox extends StatelessWidget {
  const _ProgressBox({
    required this.arabic,
    required this.progress,
    required this.value,
    required this.unlocked,
  });
  final bool arabic;
  final double progress;
  final int value;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111824),
        borderRadius: BorderRadius.circular(20),
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
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  unlocked
                      ? (arabic ? 'PvP مفتوح' : 'PVP UNLOCKED')
                      : (arabic ? 'اجمع 10 بطاقات' : 'COLLECT 10 CARDS'),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              Text(
                value.toString() + '/' + kPvpMinimumCollection.toString(),
                style: const TextStyle(color: Color(0xFFF3C86B), fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 11),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: const Color(0xFF283242),
            ),
          ),
        ],
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
    final cards = catalog.cards;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
      children: [
        _PageHeader(
          eyebrow: arabic ? 'البطاقات' : 'COLLECTION',
          title: arabic ? '222 سؤالًا قابلًا للجمع' : '222 COLLECTIBLE QUESTIONS',
          body: arabic
              ? 'كل سؤال له Card ID ثابت. لا توجد نسخ مكررة داخل حسابك.'
              : 'Every question has a permanent Card ID. No duplicate copy is owned.',
          trailing: player.ownedCount.toString() + '/' + kTotalCards.toString(),
        ),
        const SizedBox(height: 14),
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
            final owned = player.ownedCards.contains(card.id);
            return _CardTile(
              card: card,
              owned: owned,
              arabic: arabic,
              onTap: () => owned ? _showCard(context, card) : null,
            );
          },
        ),
      ],
    );
  }

  void _showCard(BuildContext context, QuestionCard card) {
    final q = QuestionBank.byId(card.id);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        child: Directionality(
          textDirection: arabic ? TextDirection.rtl : TextDirection.ltr,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(card.id, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                  const Spacer(),
                  Text(
                    card.rarity.name.toUpperCase(),
                    style: const TextStyle(color: Color(0xFFF3C86B), fontWeight: FontWeight.w900, fontSize: 9),
                  ),
                ],
              ),
              const SizedBox(height: 13),
              Text(
                arabic ? q.questionAr : q.questionEn,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, height: 1.35),
              ),
              const SizedBox(height: 12),
              ...q.answers(arabic: arabic, weeklyPass: player.weeklyPass).asMap().entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 7),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: const Color(0xFF111824),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          (entry.key + 1).toString() + '. ' + entry.value,
                          style: const TextStyle(fontSize: 11),
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
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: owned ? const Color(0xFF172131) : const Color(0xFF0F151F),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: owned ? accent.withValues(alpha: .45) : const Color(0x171FFFFFFF)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 38,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF202D3C),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                owned ? Icons.style_rounded : Icons.lock_rounded,
                color: owned ? accent : const Color(0xFF566172),
                size: 21,
              ),
            ),
            const SizedBox(height: 8),
            Text(card.id, style: TextStyle(color: owned ? accent : const Color(0xFF5E697A), fontSize: 8, fontWeight: FontWeight.w900)),
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
          eyebrow: arabic ? 'المجموعات' : 'DECK BUILDER',
          title: arabic ? 'اجعل الـ10 بطاقات لها معنى' : 'MAKE YOUR 10 CARDS MATTER',
          body: arabic
              ? 'كل مجموعة يجب أن تحتوي على 10 بطاقات مختلفة ومملوكة.'
              : 'Every deck must contain 10 distinct owned cards.',
          trailing: player.deckSlots.toString() + '/' + kMaxDeckSlots.toString(),
        ),
        const SizedBox(height: 14),
        for (int i = 0; i < kMaxDeckSlots; i++) ...[
          _DeckCard(
            index: i,
            deck: player.decks[i],
            active: i == player.activeDeck,
            unlocked: i < player.deckSlots,
            arabic: arabic,
            onTap: i < player.deckSlots
                ? () => _openBuilder(context, i)
                : () => _openPass(context),
          ),
          const SizedBox(height: 9),
        ],
      ],
    );
  }

  void _openBuilder(BuildContext context, int index) {
    player.setActiveDeck(index);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _DeckBuilderPage(
          arabic: arabic,
          player: player,
          deckIndex: index,
        ),
      ),
    );
  }

  void _openPass(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _PassPage(arabic: arabic, player: player),
      ),
    );
  }
}

class _DeckCard extends StatelessWidget {
  const _DeckCard({
    required this.index,
    required this.deck,
    required this.active,
    required this.unlocked,
    required this.arabic,
    required this.onTap,
  });
  final int index;
  final List<String> deck;
  final bool active;
  final bool unlocked;
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
            Icon(
              unlocked ? Icons.layers_rounded : Icons.lock_rounded,
              color: !unlocked
                  ? const Color(0xFF586273)
                  : ready
                      ? const Color(0xFF78D9D0)
                      : const Color(0xFFF3C86B),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (arabic ? 'مجموعة ' : 'DECK ') + (index + 1).toString(),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    !unlocked
                        ? (arabic ? 'مقفلة مع Weekly Pass' : 'Locked with Weekly Pass')
                        : deck.length.toString() + ' / ' + kDeckSize.toString(),
                    style: const TextStyle(color: Color(0xFF7F8B9C), fontSize: 10),
                  ),
                ],
              ),
            ),
            if (active && unlocked)
              const Icon(Icons.check_circle_rounded, color: Color(0xFF78D9D0))
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
        final owned = CardCatalog.foundation()
            .cards
            .where((c) => player.ownedCards.contains(c.id))
            .toList(growable: false);
        final current = player.decks[deckIndex];
        final ready = current.length == kDeckSize;
        return Directionality(
          textDirection: arabic ? TextDirection.rtl : TextDirection.ltr,
          child: Scaffold(
            appBar: AppBar(
              title: Text((arabic ? 'مجموعة ' : 'DECK ') + (deckIndex + 1).toString()),
              actions: [
                TextButton(
                  onPressed: current.isEmpty ? null : () => player.clearDeck(deckIndex),
                  child: Text(arabic ? 'مسح' : 'CLEAR'),
                ),
              ],
            ),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(18, 15, 18, 28),
              children: [
                _DeckBuilderTop(arabic: arabic, count: current.length, ready: ready),
                const SizedBox(height: 14),
                if (owned.isEmpty)
                  _EmptyDeck(arabic: arabic)
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: owned.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 9,
                      mainAxisSpacing: 9,
                      childAspectRatio: .83,
                    ),
                    itemBuilder: (context, index) {
                      final card = owned[index];
                      final selected = current.contains(card.id);
                      return InkWell(
                        onTap: !selected && current.length >= kDeckSize
                            ? null
                            : () => player.toggleCardInDeck(card.id),
                        borderRadius: BorderRadius.circular(16),
                        child: Ink(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: selected ? const Color(0xFF203346) : const Color(0xFF111824),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: selected ? const Color(0xFF78D9D0) : const Color(0x1FFFFFFF),
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.style_rounded, color: selected ? const Color(0xFF78D9D0) : const Color(0xFFF3C86B)),
                              const SizedBox(height: 8),
                              Text(card.id, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900)),
                              const SizedBox(height: 3),
                              Text(selected ? (arabic ? 'مختارة' : 'SELECTED') : (arabic ? 'اختيار' : 'SELECT')),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
            bottomNavigationBar: SafeArea(
              minimum: const EdgeInsets.all(14),
              child: FilledButton.icon(
                onPressed: ready
                    ? () async {
                        try {
                          await player.saveDeck(deckIndex);
                          if (context.mounted) Navigator.pop(context);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(e.toString().replaceFirst('Bad state: ', ''))),
                            );
                          }
                        }
                      }
                    : null,
                icon: const Icon(Icons.check_rounded),
                label: Text(ready ? (arabic ? 'حفظ المجموعة' : 'SAVE DECK') : (arabic ? 'اختر 10' : 'SELECT 10')),
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF111824),
          borderRadius: BorderRadius.circular(19),
          border: Border.all(color: ready ? const Color(0x3F78D9D0) : const Color(0x1FFFFFFF)),
        ),
        child: Row(
          children: [
            Icon(ready ? Icons.check_circle_rounded : Icons.layers_rounded, color: ready ? const Color(0xFF78D9D0) : const Color(0xFFF3C86B)),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                ready
                    ? (arabic ? 'جاهزة للمبارزة.' : 'Ready for the duel.')
                    : (arabic ? 'اختر 10 بطاقات مختلفة.' : 'Choose 10 distinct cards.'),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            Text(count.toString() + ' / ' + kDeckSize.toString(), style: const TextStyle(color: Color(0xFFF3C86B), fontWeight: FontWeight.w900)),
          ],
        ),
      );
}

class _EmptyDeck extends StatelessWidget {
  const _EmptyDeck({required this.arabic});
  final bool arabic;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF111824),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          arabic
              ? 'اجمع 10 بطاقات من Bot أولاً.'
              : 'Collect 10 cards through Bot onboarding first.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF7F8B9C)),
        ),
      );
}

class _PlayPage extends StatelessWidget {
  const _PlayPage({required this.arabic, required this.player});
  final bool arabic;
  final DemoPlayerState player;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
      children: [
        _PageHeader(
          eyebrow: arabic ? 'اللعب' : 'PLAY',
          title: arabic ? 'الأسئلة ثم المواجهة' : 'QUESTIONS. THEN DUELS.',
          body: arabic
              ? 'Bot يبني مجموعتك. Troll Duel يستخدم Deck حقيقي من 10 بطاقات.'
              : 'Bot builds your collection. Troll Duel uses a real 10-card deck.',
          trailing: player.pvpUnlocked ? 'READY' : 'LOCKED',
        ),
        const SizedBox(height: 14),
        if (!player.pvpUnlocked)
          _ModeCard(
            icon: Icons.smart_toy_rounded,
            title: 'BOT TRAINING',
            status: arabic ? 'متاح الآن' : 'AVAILABLE',
            body: arabic
                ? 'سؤال واحد في كل جولة. الصحيح يعطي بطاقة عادية غير مملوكة.'
                : 'One question per round. Correct answer awards an unowned normal card.',
            button: arabic ? 'ابدأ الجولة' : 'START ROUND',
            enabled: true,
            onTap: () => _openBot(context),
          )
        else ...[
          _ModeCard(
            icon: Icons.sports_mma_rounded,
            title: 'TROLL DUEL',
            status: player.activeDeckReady ? 'READY' : 'DECK NEEDED',
            body: arabic
                ? '1v1 حقيقي عبر Firebase. الخادم يختار 7 بطاقات من مجموعتك.'
                : 'Real 1v1 through Firebase. The server selects 7 cards from your deck.',
            button: player.authenticated ? (arabic ? 'ابدأ المطابقة' : 'FIND MATCH') : (arabic ? 'تسجيل الدخول' : 'SIGN IN'),
            enabled: player.activeDeckReady && player.authenticated,
            onTap: player.authenticated && player.activeDeckReady
                ? () => _openDuel(context)
                : () => _showAuthHint(context),
          ),
          if (!player.authenticated)
            Padding(
              padding: const EdgeInsets.only(top: 9),
              child: OutlinedButton.icon(
                onPressed: () => _openAuth(context),
                icon: const Icon(Icons.lock_open_rounded),
                label: Text(arabic ? 'تسجيل الدخول للـPvP' : 'SIGN IN FOR PVP'),
              ),
            ),
        ],
        const SizedBox(height: 14),
        _RulePanel(
          title: arabic ? 'قواعد المواجهة' : 'DUEL RULES',
          lines: arabic
              ? ['10 بطاقات في الـDeck', 'الخادم يختار 7', '7 أسئلة × 20 ثانية', 'الأكثر صحيحًا يفوز', 'التعادل يُحسم بالوقت', 'الفائز يسرق بطاقة واحدة']
              : ['10 cards in the deck', 'Server selects 7', '7 questions × 20 seconds', 'More correct answers wins', 'Tie goes to lower time', 'Winner steals one card'],
        ),
      ],
    );
  }

  void _openBot(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _BotRoundPage(arabic: arabic, player: player),
      ),
    );
  }

  void _openDuel(BuildContext context) async {
    try {
      final result = await player.findOrCreateDuel();
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _DuelPage(
            arabic: arabic,
            player: player,
            duelId: result['duelId'] as String,
          ),
        ),
      );
    } catch (e) {
      _showError(context, e);
    }
  }

  void _openAuth(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _AuthPage(arabic: arabic, player: player)),
    );
  }

  void _showAuthHint(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _AuthPage(arabic: arabic, player: player)),
    );
  }
}

class _BotRoundPage extends StatefulWidget {
  const _BotRoundPage({required this.arabic, required this.player});
  final bool arabic;
  final DemoPlayerState player;

  @override
  State<_BotRoundPage> createState() => _BotRoundPageState();
}

class _BotRoundPageState extends State<_BotRoundPage> {
  BotRoundData? round;
  Timer? timer;
  int seconds = kSecondsPerQuestion;
  bool loading = true;
  bool answered = false;
  bool correct = false;
  int? selected;
  String message = '';

  @override
  void initState() {
    super.initState();
    _loadRound();
  }

  Future<void> _loadRound() async {
    try {
      final next = await widget.player.startBotRound(arabic: widget.arabic);
      if (!mounted) return;
      setState(() {
        round = next;
        loading = false;
      });
      timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted || answered) return;
        if (seconds <= 1) {
          _answer(-1);
        } else {
          setState(() => seconds--);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        message = e.toString().replaceFirst('Bad state: ', '');
      });
    }
  }

  Future<void> _answer(int index) async {
    if (answered || round == null) return;
    answered = true;
    timer?.cancel();
    try {
      final ok = await widget.player.completeBotRound(
        round: round!,
        answerIndex: index,
      );
      if (!mounted) return;
      setState(() {
        selected = index;
        correct = ok;
        message = ok
            ? (widget.arabic ? 'أحسنت — تمت إضافة بطاقة.' : 'Correct — a card was added.')
            : (widget.arabic ? 'إجابة غير صحيحة — لا توجد بطاقة.' : 'Wrong or timeout — no card awarded.');
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => message = e.toString().replaceFirst('Bad state: ', ''));
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.arabic ? 'تدريب BOT' : 'BOT TRAINING')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (round == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.arabic ? 'تدريب BOT' : 'BOT TRAINING')),
        body: Center(child: Padding(padding: const EdgeInsets.all(30), child: Text(message, textAlign: TextAlign.center))),
      );
    }
    final q = QuestionBank.byId(round!.questionId);
    final answers = q.answers(arabic: widget.arabic, weeklyPass: widget.player.weeklyPass);
    return Directionality(
      textDirection: widget.arabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.arabic ? 'تدريب BOT' : 'BOT TRAINING'),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              child: Text(seconds.toString() + 's', style: const TextStyle(fontWeight: FontWeight.w900)),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
          children: [
            _PageHeader(
              eyebrow: round!.questionId,
              title: widget.arabic ? 'أجب لتحصل على البطاقة' : 'ANSWER TO EARN THE CARD',
              body: widget.arabic ? q.categoryAr : q.categoryEn,
              trailing: q.rarity.name.toUpperCase(),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(19),
              decoration: BoxDecoration(
                color: const Color(0xFF111824),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0x1FFFFFFF)),
              ),
              child: Text(
                widget.arabic ? round!.questionAr : round!.questionEn,
                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, height: 1.35),
              ),
            ),
            const SizedBox(height: 12),
            for (int i = 0; i < answers.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: _AnswerButton(
                  text: answers[i],
                  index: i,
                  selected: selected == i,
                  reveal: answered,
                  correct: i == q.correctIndex,
                  onTap: answered ? null : () => _answer(i),
                ),
              ),
            if (answered) ...[
              const SizedBox(height: 6),
              _ResultBanner(correct: correct, text: message),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: widget.player.pvpUnlocked ? () => Navigator.pop(context) : _loadNext,
                icon: Icon(widget.player.pvpUnlocked ? Icons.arrow_forward_rounded : Icons.refresh_rounded),
                label: Text(
                  widget.player.pvpUnlocked
                      ? (widget.arabic ? 'تم فتح PvP' : 'PVP UNLOCKED')
                      : (widget.arabic ? 'جولة أخرى' : 'NEXT ROUND'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _loadNext() {
    setState(() {
      round = null;
      seconds = kSecondsPerQuestion;
      answered = false;
      selected = null;
      correct = false;
      message = '';
      loading = true;
    });
    _loadRound();
  }
}

class _DuelPage extends StatefulWidget {
  const _DuelPage({
    required this.arabic,
    required this.player,
    required this.duelId,
  });
  final bool arabic;
  final DemoPlayerState player;
  final String duelId;

  @override
  State<_DuelPage> createState() => _DuelPageState();
}

class _DuelPageState extends State<_DuelPage> {
  Timer? poller;
  Map<String, dynamic>? duel;
  bool loading = true;
  bool sending = false;
  int? revealedSlot;
  Map<String, dynamic>? reveal;
  bool stealDone = false;
  bool remoteRefreshed = false;
  int localDeadline = kFullDuelSeconds;

  @override
  void initState() {
    super.initState();
    _poll();
    poller = Timer.periodic(const Duration(seconds: 1), (_) => _poll());
  }

  Future<void> _poll() async {
    try {
      final state = await widget.player.api!.getDuelState(widget.duelId);
      if (!mounted) return;
      setState(() {
        duel = state;
        loading = false;
      });
      if (state['status'] == 'finished' && !remoteRefreshed) {
        remoteRefreshed = true;
        await widget.player._loadRemote();
      }
      final startedAt = _readDate(state['startedAt']);
      if (startedAt != null) {
        final elapsed = DateTime.now().difference(startedAt).inSeconds;
        localDeadline = max(0, kFullDuelSeconds - elapsed);
      }
      if (state['status'] == 'playing') {
        if (DateTime.now().difference(startedAt ?? DateTime.now()).inSeconds >= kQuestionPhaseSeconds) {
          await widget.player.api!.resolveDuel(widget.duelId);
        }
      }
    } catch (_) {
      // Keep polling; transient network failures are normal in live play.
    }
  }

  DateTime? _readDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  String get role {
    final uid = widget.player.api?.currentUser?.uid;
    if (uid == null || duel == null) return 'p1';
    return duel!['p1Uid'] == uid ? 'p1' : 'p2';
  }

  List<Map<String, dynamic>> get questions {
    final raw = duel?[role == 'p1' ? 'questionsP1' : 'questionsP2'] as List? ?? const [];
    return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList(growable: false);
  }

  int get myAnswered => (duel?[role == 'p1' ? 'p1AnsweredCount' : 'p2AnsweredCount'] as num?)?.toInt() ?? 0;
  int get opponentAnswered => (duel?[role == 'p1' ? 'p2AnsweredCount' : 'p1AnsweredCount'] as num?)?.toInt() ?? 0;

  @override
  void dispose() {
    poller?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loading || duel == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('TROLL DUEL')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final status = duel!['status'] as String? ?? 'searching';
    if (status == 'searching') {
      return Scaffold(
        appBar: AppBar(title: const Text('TROLL DUEL')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 18),
                Text(
                  widget.arabic ? 'نبحث عن خصم...' : 'Searching for an opponent...',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 7),
                Text(
                  widget.arabic
                      ? 'ابقَ في الشاشة. عند العثور على خصم تبدأ المواجهة تلقائيًا.'
                      : 'Stay on this screen. The duel starts automatically when matched.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF7F8B9C), fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final result = duel!['result'] as String?;
    if (result != null && result != 'playing') {
      return _buildResult(context, result);
    }

    final qs = questions;
    final index = min(myAnswered, qs.isEmpty ? 0 : qs.length - 1);
    final current = qs.isEmpty ? null : qs[index];

    return Directionality(
      textDirection: widget.arabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('TROLL DUEL'),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 18),
              child: Text(
                localDeadline.toString() + 's',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 30),
          children: [
            Row(
              children: [
                Expanded(child: _DuelProgress(label: widget.arabic ? 'أنت' : 'YOU', value: myAnswered)),
                const SizedBox(width: 10),
                Expanded(child: _DuelProgress(label: widget.arabic ? 'الخصم' : 'OPPONENT', value: opponentAnswered)),
              ],
            ),
            const SizedBox(height: 14),
            _PageHeader(
              eyebrow: 'ROUND ' + (myAnswered + 1).toString() + ' / ' + kDuelQuestions.toString(),
              title: widget.arabic ? 'سؤال من مجموعة خصمك' : 'A QUESTION FROM YOUR OPPONENT\'S DECK',
              body: widget.arabic ? 'الوقت هو معيار التعادل.' : 'Time is the tie-breaker.',
              trailing: '',
            ),
            const SizedBox(height: 14),
            if (current != null)
              _DuelQuestion(
                arabic: widget.arabic,
                weeklyPass: widget.player.weeklyPass,
                question: current,
                disabled: sending,
                onAnswer: _submitAnswer,
              )
            else
              const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }

  Future<void> _submitAnswer(int index) async {
    if (sending) return;
    setState(() => sending = true);
    try {
      await widget.player.api!.submitDuelAnswer(
        duelId: widget.duelId,
        questionIndex: myAnswered,
        answerIndex: index,
      );
      await _poll();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Bad state: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Widget _buildResult(BuildContext context, String result) {
    final uid = widget.player.api?.currentUser?.uid;
    final winner = duel!['winnerUid'] as String?;
    final iWon = winner != null && winner == uid;
    final draw = result == 'draw';
    return Directionality(
      textDirection: widget.arabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(title: Text(widget.arabic ? 'النتيجة' : 'RESULT')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(18, 22, 18, 30),
          children: [
            _ResultBanner(
              correct: iWon,
              text: draw
                  ? (widget.arabic ? 'تعادل — لا توجد سرقة.' : 'DRAW — NO STEAL.')
                  : iWon
                      ? (widget.arabic ? 'فزت. حان وقت السرقة.' : 'YOU WON. STEAL NOW.')
                      : (widget.arabic ? 'خسرت هذه المواجهة.' : 'YOU LOST THIS DUEL.'),
            ),
            const SizedBox(height: 15),
            _ScoreBox(
              arabic: widget.arabic,
              myCorrect: (duel![role == 'p1' ? 'p1CorrectCount' : 'p2CorrectCount'] as num?)?.toInt() ?? 0,
              opponentCorrect: (duel![role == 'p1' ? 'p2CorrectCount' : 'p1CorrectCount'] as num?)?.toInt() ?? 0,
            ),
            const SizedBox(height: 15),
            if (iWon && !stealDone) _StealPanel(
              arabic: widget.arabic,
              revealedSlot: revealedSlot,
              reveal: reveal,
              onReveal: _reveal,
              onConfirm: _confirmSteal,
              onChanged: (v) => setState(() => revealedSlot = v),
            ),
            if (stealDone)
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: Text(widget.arabic ? 'العودة' : 'BACK'),
              ),
            if (!iWon && !draw)
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: Text(widget.arabic ? 'العودة' : 'BACK'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _reveal() async {
    if (revealedSlot == null) return;
    try {
      final value = await widget.player.api!.revealStealTarget(
        duelId: widget.duelId,
        slotIndex: revealedSlot!,
      );
      if (mounted) setState(() => reveal = value);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Bad state: ', ''))),
        );
      }
    }
  }

  Future<void> _confirmSteal() async {
    try {
      await widget.player.api!.confirmSteal(widget.duelId);
      await widget.player._loadRemote();
      if (mounted) setState(() => stealDone = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Bad state: ', ''))),
        );
      }
    }
  }
}

class _DuelQuestion extends StatelessWidget {
  const _DuelQuestion({
    required this.arabic,
    required this.weeklyPass,
    required this.question,
    required this.disabled,
    required this.onAnswer,
  });
  final bool arabic;
  final bool weeklyPass;
  final Map<String, dynamic> question;
  final bool disabled;
  final ValueChanged<int> onAnswer;

  @override
  Widget build(BuildContext context) {
    final text = question[arabic ? 'questionAr' : 'questionEn'] as String? ?? '';
    final answers = List<String>.from(question[arabic ? 'answersAr' : 'answersEn'] as List? ?? const []);
    if (weeklyPass) {
      final fourth = question[arabic ? 'fourthAr' : 'fourthEn'] as String?;
      if (fourth != null && fourth.isNotEmpty) answers.add(fourth);
    }
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF111824),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, height: 1.4)),
        ),
        const SizedBox(height: 12),
        for (int i = 0; i < answers.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: _AnswerButton(
              text: answers[i],
              index: i,
              selected: false,
              reveal: false,
              correct: false,
              onTap: disabled ? null : () => onAnswer(i),
            ),
          ),
      ],
    );
  }
}

class _DuelProgress extends StatelessWidget {
  const _DuelProgress({required this.label, required this.value});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF111824),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900))),
            Text(value.toString() + '/7', style: const TextStyle(color: Color(0xFFF3C86B), fontWeight: FontWeight.w900)),
          ],
        ),
      );
}

class _ScoreBox extends StatelessWidget {
  const _ScoreBox({
    required this.arabic,
    required this.myCorrect,
    required this.opponentCorrect,
  });
  final bool arabic;
  final int myCorrect;
  final int opponentCorrect;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: _ScoreCell(
              label: arabic ? 'أنت' : 'YOU',
              value: myCorrect,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ScoreCell(
              label: arabic ? 'الخصم' : 'OPPONENT',
              value: opponentCorrect,
            ),
          ),
        ],
      );
}

class _ScoreCell extends StatelessWidget {
  const _ScoreCell({required this.label, required this.value});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF111824),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Text(label, style: const TextStyle(color: Color(0xFF7F8B9C), fontSize: 9, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(value.toString(), style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w900)),
          ],
        ),
      );
}

class _StealPanel extends StatelessWidget {
  const _StealPanel({
    required this.arabic,
    required this.revealedSlot,
    required this.reveal,
    required this.onReveal,
    required this.onConfirm,
    required this.onChanged,
  });
  final bool arabic;
  final int? revealedSlot;
  final Map<String, dynamic>? reveal;
  final VoidCallback onReveal;
  final VoidCallback onConfirm;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final cardId = reveal?['cardId'] as String?;
    final rarity = reveal?['rarity'] as String?;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111824),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x35F3C86B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            arabic ? 'اختر بطاقة واحدة' : 'CHOOSE ONE CARD',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (int i = 0; i < 10; i++)
                ChoiceChip(
                  label: Text((i + 1).toString()),
                  selected: revealedSlot == i,
                  onSelected: (_) => onChanged(i),
                ),
            ],
          ),
          const SizedBox(height: 11),
          OutlinedButton(
            onPressed: revealedSlot == null ? null : onReveal,
            child: Text(arabic ? 'كشف البطاقة' : 'REVEAL CARD'),
          ),
          if (cardId != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1C2A38),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                cardId + ' • ' + (rarity ?? '').toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: onConfirm,
              child: Text(arabic ? 'تأكيد السرقة' : 'CONFIRM STEAL'),
            ),
          ],
        ],
      ),
    );
  }
}

class _AuthPage extends StatefulWidget {
  const _AuthPage({required this.arabic, required this.player});
  final bool arabic;
  final DemoPlayerState player;

  @override
  State<_AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<_AuthPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool create = false;
  bool busy = false;
  String error = '';

  Future<void> _submit() async {
    setState(() {
      busy = true;
      error = '';
    });
    try {
      if (create) {
        await widget.player.signUp(email.text, password.text);
      } else {
        await widget.player.signIn(email.text, password.text);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Bad state: ', ''));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: widget.arabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(title: Text(widget.arabic ? 'الحساب' : 'ACCOUNT')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(18, 22, 18, 30),
          children: [
            _PageHeader(
              eyebrow: 'FIREBASE AUTH',
              title: create
                  ? (widget.arabic ? 'أنشئ حسابًا' : 'CREATE ACCOUNT')
                  : (widget.arabic ? 'سجل الدخول' : 'SIGN IN'),
              body: widget.arabic
                  ? 'الحساب مطلوب للوصول إلى PvP وحفظ ملكية البطاقات على الخادم.'
                  : 'An account is required for PvP and server-side card ownership.',
              trailing: '',
            ),
            const SizedBox(height: 18),
            TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: widget.arabic ? 'البريد الإلكتروني' : 'EMAIL',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 11),
            TextField(
              controller: password,
              obscureText: true,
              decoration: InputDecoration(
                labelText: widget.arabic ? 'كلمة المرور' : 'PASSWORD',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            if (error.isNotEmpty)
              Text(error, style: const TextStyle(color: Color(0xFFE38B8B), fontSize: 11)),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: busy ? null : _submit,
              child: Text(busy
                  ? '...'
                  : create
                      ? (widget.arabic ? 'إنشاء' : 'CREATE')
                      : (widget.arabic ? 'دخول' : 'SIGN IN')),
            ),
            TextButton(
              onPressed: busy ? null : () => setState(() => create = !create),
              child: Text(
                create
                    ? (widget.arabic ? 'لديك حساب؟ سجل الدخول' : 'Already have an account? Sign in')
                    : (widget.arabic ? 'حساب جديد' : 'Create a new account'),
              ),
            ),
            if (widget.player.authenticated)
              OutlinedButton(
                onPressed: busy
                    ? null
                    : () async {
                        await widget.player.signOut();
                        if (mounted) setState(() {});
                      },
                child: Text(widget.arabic ? 'تسجيل الخروج' : 'SIGN OUT'),
              ),
          ],
        ),
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
          title: arabic ? 'الترتيب والـPass والحساب' : 'RANKING. PASS. ACCOUNT.',
          body: arabic ? 'كل الأنظمة مرتبطة الآن بطبقات البيانات والخادم.' : 'All systems now have their data/backend layer.',
          trailing: '',
        ),
        const SizedBox(height: 14),
        _MoreTile(
          icon: Icons.emoji_events_rounded,
          title: arabic ? 'الترتيب' : 'RANKING',
          subtitle: arabic ? 'المقياس الأساسي: عدد البطاقات.' : 'Primary metric: cards owned.',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _RankingPage(arabic: arabic, player: player))),
        ),
        _MoreTile(
          icon: Icons.workspace_premium_rounded,
          title: 'WEEKLY PASS',
          subtitle: arabic ? '+3 مجموعات + خيار رابع' : '+3 decks + fourth answer option',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _PassPage(arabic: arabic, player: player))),
        ),
        _MoreTile(
          icon: Icons.person_rounded,
          title: arabic ? 'الحساب' : 'ACCOUNT',
          subtitle: player.authenticated
              ? player.accountLabel
              : (arabic ? 'تسجيل الدخول للـPvP' : 'Sign in for PvP'),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _AuthPage(arabic: arabic, player: player))),
        ),
        _MoreTile(
          icon: Icons.info_outline_rounded,
          title: arabic ? 'كيف تعمل اللعبة؟' : 'HOW IT WORKS',
          subtitle: arabic ? 'من Bot إلى السرقة والترتيب' : 'From Bot to stealing and ranking',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _HowItWorksPage(arabic: arabic))),
        ),
      ],
    );
  }
}

class _RankingPage extends StatefulWidget {
  const _RankingPage({required this.arabic, required this.player});
  final bool arabic;
  final DemoPlayerState player;

  @override
  State<_RankingPage> createState() => _RankingPageState();
}

class _RankingPageState extends State<_RankingPage> {
  bool loading = true;
  String error = '';
  List<Map<String, dynamic>> players = const [];
  Map<String, dynamic>? reward;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final value = await widget.player.loadRanking();
      if (!mounted) return;
      setState(() {
        players = value;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = e.toString().replaceFirst('Bad state: ', '');
      });
    }
  }

  Future<void> _claim() async {
    try {
      final value = await widget.player.claimRankingReward();
      if (mounted) setState(() => reward = value);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Bad state: ', ''))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: widget.arabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(title: Text(widget.arabic ? 'الترتيب' : 'RANKING')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
          children: [
            _PageHeader(
              eyebrow: 'RANKING',
              title: widget.arabic ? 'اجمع أكثر، ترتفع أكثر' : 'COLLECT MORE. RANK HIGHER.',
              body: widget.arabic
                  ? 'المركز يعتمد أساساً على عدد البطاقات. جوائز الأسبوع تُطالب من الخادم.'
                  : 'Rank is driven primarily by cards owned. Weekly rewards are claimed from the server.',
              trailing: '',
            ),
            const SizedBox(height: 14),
            if (loading)
              const Center(child: CircularProgressIndicator())
            else if (error.isNotEmpty)
              _RulePanel(
                title: widget.arabic ? 'يتطلب تسجيل الدخول' : 'SIGN IN REQUIRED',
                lines: [error],
              )
            else ...[
              for (int i = 0; i < players.length; i++)
                _RankRow(
                  rank: i + 1,
                  name: (players[i]['displayName'] as String?) ?? ((players[i]['uid'] as String?) ?? 'PLAYER').substring(0, min(8, ((players[i]['uid'] as String?) ?? 'PLAYER').length)),
                  cards: (players[i]['ownedCount'] as num?)?.toInt() ?? 0,
                ),
              const SizedBox(height: 9),
              FilledButton.icon(
                onPressed: _claim,
                icon: const Icon(Icons.redeem_rounded),
                label: Text(widget.arabic ? 'المطالبة بمكافأة الأسبوع' : 'CLAIM WEEKLY REWARD'),
              ),
              if (reward != null) ...[
                const SizedBox(height: 10),
                _RulePanel(
                  title: widget.arabic ? 'تمت المطالبة' : 'REWARD CLAIMED',
                  lines: [reward.toString()],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({required this.rank, required this.name, required this.cards});
  final int rank;
  final String name;
  final int cards;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF111824),
          borderRadius: BorderRadius.circular(17),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFF202D3C),
              child: Text(rank.toString(), style: const TextStyle(fontWeight: FontWeight.w900)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w900))),
            Text(cards.toString() + ' cards', style: const TextStyle(color: Color(0xFFF3C86B), fontWeight: FontWeight.w900)),
          ],
        ),
      );
}

class _PassPage extends StatefulWidget {
  const _PassPage({required this.arabic, required this.player});
  final bool arabic;
  final DemoPlayerState player;

  @override
  State<_PassPage> createState() => _PassPageState();
}

class _PassPageState extends State<_PassPage> {
  final WeeklyPassPurchaseService purchases = WeeklyPassPurchaseService();
  String storeMessage = '';

  @override
  void initState() {
    super.initState();
    purchases.listen(onPurchase: _handlePurchase);
  }

  Future<void> _handlePurchase(PurchaseDetails purchase) async {
    if (purchase.status != PurchaseStatus.purchased &&
        purchase.status != PurchaseStatus.restored) {
      return;
    }
    final receipt = purchase.verificationData.serverVerificationData;
    if (receipt.isEmpty) return;
    try {
      await widget.player.verifyWeeklyPass(
        productId: WeeklyPassPurchaseService.productId,
        platform: defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
        receipt: receipt,
      );
      if (mounted) {
        setState(() => storeMessage = widget.arabic
            ? 'تم التحقق من الاشتراك.'
            : 'Pass receipt verified.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => storeMessage = e.toString().replaceFirst('Bad state: ', ''));
      }
    }
  }

  Future<void> _buy() async {
    try {
      final started = await purchases.buy();
      if (mounted && !started) {
        setState(() => storeMessage = widget.arabic
            ? 'لم يتوفر منتج Weekly Pass في المتجر.'
            : 'Weekly Pass is not available in the store.');
      }
    } catch (e) {
      if (mounted) setState(() => storeMessage = e.toString());
    }
  }

  @override
  void dispose() {
    purchases.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.player.weeklyPass;
    return Directionality(
      textDirection: widget.arabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(title: const Text('WEEKLY PASS')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
          children: [
            _PageHeader(
              eyebrow: 'WEEKLY PASS',
              title: active
                  ? (widget.arabic ? 'الـPass فعال' : 'PASS ACTIVE')
                  : (widget.arabic ? 'مزايا للاعب الجامع' : 'MORE ROOM TO COLLECT'),
              body: widget.arabic
                  ? 'منتج الدفع الوحيد. الصلاحية أسبوعية ولا توجد عملات مدفوعة أخرى.'
                  : 'The only paid product. Weekly access with no other paid currency.',
              trailing: active ? 'ACTIVE' : 'OPTIONAL',
            ),
            const SizedBox(height: 15),
            _Benefit(icon: Icons.layers_rounded, title: widget.arabic ? '+3 مجموعات' : '+3 DECK SLOTS', body: widget.arabic ? 'المجموع 5.' : 'Five total deck slots.'),
            _Benefit(icon: Icons.looks_4_rounded, title: widget.arabic ? 'خيار رابع للإجابة' : 'FOURTH ANSWER OPTION', body: widget.arabic ? 'مفعل في الأسئلة المدعومة.' : 'Enabled on supported questions.'),
            _Benefit(icon: Icons.calendar_today_rounded, title: widget.arabic ? 'أسبوع كامل' : 'WEEKLY ACCESS', body: widget.arabic ? 'التجديد من المتجر.' : 'Renewal is controlled by the store.'),
            const SizedBox(height: 13),
            FilledButton.icon(
              onPressed: active ? null : _buy,
              icon: const Icon(Icons.shopping_bag_rounded),
              label: Text(active ? (widget.arabic ? 'مفعل' : 'ACTIVE') : (widget.arabic ? 'شراء' : 'PURCHASE')),
            ),
            if (storeMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(storeMessage, style: const TextStyle(color: Color(0xFF7F8B9C), fontSize: 10, height: 1.5)),
              ),
          ],
        ),
      ),
    );
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: const Color(0xFF111824),
          borderRadius: BorderRadius.circular(17),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFFF3C86B)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
                  const SizedBox(height: 3),
                  Text(body, style: const TextStyle(color: Color(0xFF7F8B9C), fontSize: 10)),
                ],
              ),
            ),
          ],
        ),
      );
}

class _HowItWorksPage extends StatelessWidget {
  const _HowItWorksPage({required this.arabic});
  final bool arabic;

  @override
  Widget build(BuildContext context) {
    final steps = arabic
        ? ['ابدأ بـ0 بطاقة وأكمل Bot حتى تصل إلى 10.', 'ابنِ Deck من 10 بطاقات مختلفة.', 'السيرفر يختار 7 من Deckك في كل مواجهة.', 'أجب عن 7 أسئلة مبنية على بطاقات خصمك.', 'الأكثر صحيحًا يفوز، والتعادل يحسمه الوقت.', 'الفائز يكشف ويؤكد بطاقة واحدة للسرقة.']
        : ['Start with 0 cards and use Bot until 10.', 'Build a deck of 10 distinct cards.', 'The server selects 7 from your deck each duel.', 'Answer 7 questions built from your opponent\'s cards.', 'More correct answers wins; lower time breaks ties.', 'Winner reveals and confirms one card to steal.'];
    return Scaffold(
      appBar: AppBar(title: Text(arabic ? 'كيف تعمل اللعبة؟' : 'HOW IT WORKS')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
        children: [
          for (int i = 0; i < steps.length; i++)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF111824),
                borderRadius: BorderRadius.circular(17),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 17,
                    backgroundColor: const Color(0xFF202D3C),
                    child: Text((i + 1).toString()),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(steps[i], style: const TextStyle(fontSize: 11, height: 1.45))),
                ],
              ),
            ),
        ],
      ),
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
              Text(eyebrow, style: const TextStyle(color: Color(0xFFF3C86B), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
              const SizedBox(height: 6),
              Text(title, style: const TextStyle(fontSize: 24, height: 1.06, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(body, style: const TextStyle(color: Color(0xFF7F8B9C), fontSize: 10.5, height: 1.45)),
            ],
          ),
        ),
        if (trailing.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 10),
            child: Text(trailing, style: const TextStyle(color: Color(0xFFF3C86B), fontWeight: FontWeight.w900, fontSize: 9)),
          ),
      ],
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.title,
    required this.status,
    required this.body,
    required this.button,
    required this.enabled,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String status;
  final String body;
  final String button;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF111824),
          borderRadius: BorderRadius.circular(21),
          border: Border.all(color: const Color(0x1FFFFFFF)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFFF3C86B), size: 26),
                const Spacer(),
                _Pill(label: status, positive: enabled),
              ],
            ),
            const SizedBox(height: 15),
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(body, style: const TextStyle(color: Color(0xFF8E99A8), fontSize: 10.5, height: 1.5)),
            const SizedBox(height: 14),
            FilledButton(onPressed: enabled ? onTap : null, child: Text(button)),
          ],
        ),
      );
}

class _AnswerButton extends StatelessWidget {
  const _AnswerButton({
    required this.text,
    required this.index,
    required this.selected,
    required this.reveal,
    required this.correct,
    required this.onTap,
  });
  final String text;
  final int index;
  final bool selected;
  final bool reveal;
  final bool correct;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    var color = const Color(0xFF111824);
    if (reveal && correct) color = const Color(0xFF1B3A32);
    if (reveal && selected && !correct) color = const Color(0xFF3A2424);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: selected ? const Color(0xFFF3C86B) : const Color(0x1FFFFFFF)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 13,
              backgroundColor: const Color(0xFF202D3C),
              child: Text((index + 1).toString(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
          ],
        ),
      ),
    );
  }
}

class _ResultBanner extends StatelessWidget {
  const _ResultBanner({required this.correct, required this.text});
  final bool correct;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: correct ? const Color(0xFF1B3A32) : const Color(0xFF2A2020),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w900)),
      );
}

class _RulePanel extends StatelessWidget {
  const _RulePanel({required this.title, required this.lines});
  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: const Color(0xFF111824),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0x1FFFFFFF)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 9),
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    const Icon(Icons.circle, size: 5, color: Color(0xFFF3C86B)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(line, style: const TextStyle(color: Color(0xFF8792A2), fontSize: 10.5))),
                  ],
                ),
              ),
          ],
        ),
      );
}

class _MoreTile extends StatelessWidget {
  const _MoreTile({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          onTap: onTap,
          tileColor: const Color(0xFF111824),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
          leading: Icon(icon, color: const Color(0xFFF3C86B)),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
          subtitle: Text(subtitle, style: const TextStyle(color: Color(0xFF7F8B9C), fontSize: 9.5)),
          trailing: const Icon(Icons.chevron_right_rounded),
        ),
      );

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.positive});
  final String label;
  final bool positive;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
          color: positive ? const Color(0x1926C9B5) : const Color(0x16F3C86B),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: positive ? const Color(0xFF78D9D0) : const Color(0xFFF3C86B),
            fontSize: 7.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      );

void _showError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(error.toString().replaceFirst('Bad state: ', ''))),
  );
}
