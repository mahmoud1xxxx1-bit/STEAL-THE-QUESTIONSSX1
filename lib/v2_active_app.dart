import 'package:flutter/material.dart';

import 'backend/bot_api_v2.dart';
import 'backend/firebase_game_api_v2.dart';
import 'backend/online_runtime_v2.dart';
import 'backend/profile_features_api_v2.dart';
import 'data/player_profile_store_v2.dart';
import 'game/core_engine_v2.dart';
import 'game/online_player_session_v2.dart';
import 'game/player_profile_v2.dart';

const _blue = Color(0xFF2E6BFF);
const _purple = Color(0xFF7A48F5);
const _gold = Color(0xFFFFC94D);
const _coral = Color(0xFFFF6A67);
const _ink = Color(0xFF183153);
const _muted = Color(0xFF7183A3);
const _page = Color(0xFFF5F8FF);

class StealQuestionsV2App extends StatefulWidget {
  const StealQuestionsV2App({super.key});

  @override
  State<StealQuestionsV2App> createState() => _StealQuestionsV2AppState();
}

class _StealQuestionsV2AppState extends State<StealQuestionsV2App> {
  OnlinePlayerSessionV2? _session;
  PlayerProfileV2? _profile;
  WeeklyRankingV2? _ranking;
  SubscriptionStatusV2? _subscription;
  BotStatusV2? _botStatus;
  MatchmakingStatusV2? _matchmaking;
  Object? _loadError;
  int _tab = 0;
  bool _arabic = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final ready = await OnlineRuntimeV2.ensureReady();
      if (!ready) throw StateError('Firebase V2 is unavailable.');
      final session = OnlinePlayerSessionV2(
        store: SharedPreferencesPlayerProfileStoreV2(),
        api: FirebaseGameApiV2(),
        botApi: BotApiV2(),
      );
      final profile = await session.initialize();
      if (!mounted) return;
      setState(() {
        _session = session;
        _profile = profile;
      });
      await _refreshRemote();
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadError = error);
    }
  }

  Future<void> _refreshRemote() async {
    final session = _session;
    if (session == null) return;
    try {
      final values = await Future.wait<dynamic>([
        session.weeklyRanking(),
        session.subscriptionStatus(),
        session.botStatus(),
        session.matchStatus(),
      ]);
      if (!mounted) return;
      setState(() {
        _ranking = values[0] as WeeklyRankingV2;
        _subscription = values[1] as SubscriptionStatusV2;
        _botStatus = values[2] as BotStatusV2;
        _matchmaking = values[3] as MatchmakingStatusV2;
      });
    } catch (_) {
      // The cached profile remains usable while a secondary panel refresh fails.
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refreshProfile() => _run(() async {
        final session = _session!;
        final profile = await session.refreshProfile();
        if (!mounted) return;
        setState(() => _profile = profile);
        await _refreshRemote();
      });

  Future<void> _setActiveDeck(int index) => _run(() async {
        final profile = await _session!.setActiveDeck(index);
        if (!mounted) return;
        setState(() => _profile = profile);
      });

  Future<void> _refreshSubscription() => _run(() async {
        final status = await _session!.refreshSubscription();
        if (!mounted) return;
        setState(() {
          _subscription = status;
          _profile = _session!.profile;
        });
      });

  Future<void> _startBotStatus() => _run(() async {
        final status = await _session!.botStatus();
        if (!mounted) return;
        setState(() => _botStatus = status);
      });

  Future<void> _startOrCheckMatchmaking() => _run(() async {
        var status = _matchmaking;
        if (status == null || status.status == 'idle') {
          status = await _session!.startMatchmaking();
        } else if (status.searching) {
          status = await _session!.matchStatus();
        }
        if (!mounted) return;
        setState(() => _matchmaking = status);
      });

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    if (_loadError != null) {
      return Scaffold(
        backgroundColor: _page,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _arabic ? 'تعذر تحميل ملف اللاعب.' : 'Could not load the player profile.',
              style: const TextStyle(color: _ink, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      );
    }
    if (profile == null) {
      return const Scaffold(
        backgroundColor: _page,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final screens = <Widget>[
      _HomeV2(
        arabic: _arabic,
        profile: profile,
        openTab: (value) => setState(() => _tab = value),
        refresh: _refreshProfile,
      ),
      _CardsV2(arabic: _arabic, profile: profile),
      _DecksV2(
        arabic: _arabic,
        profile: profile,
        busy: _busy,
        setActiveDeck: _setActiveDeck,
      ),
      _PlayV2(
        arabic: _arabic,
        profile: profile,
        busy: _busy,
        botStatus: _botStatus,
        matchmaking: _matchmaking,
        refreshBot: _startBotStatus,
        startOrCheckMatchmaking: _startOrCheckMatchmaking,
      ),
      _ProfileV2(
        arabic: _arabic,
        profile: profile,
        ranking: _ranking,
        subscription: _subscription,
        busy: _busy,
        refresh: _refreshProfile,
        refreshSubscription: _refreshSubscription,
      ),
    ];

    return Directionality(
      textDirection: _arabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: _page,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          title: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [_blue, _purple]),
                ),
                child: const Icon(Icons.style_rounded, color: Colors.white),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'STEAL THE QUESTIONS',
                  style: TextStyle(color: _ink, fontSize: 14, fontWeight: FontWeight.w900),
                ),
              ),
              _Pill(text: '${profile.ownedCount}', icon: Icons.style_rounded),
              IconButton(
                onPressed: () => setState(() => _arabic = !_arabic),
                icon: Text(_arabic ? 'EN' : 'ع', style: const TextStyle(color: _blue, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
        ),
        body: IndexedStack(index: _tab, children: screens),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (value) => setState(() => _tab = value),
          destinations: [
            NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home_rounded), label: _arabic ? 'الرئيسية' : 'Home'),
            NavigationDestination(icon: const Icon(Icons.style_outlined), selectedIcon: const Icon(Icons.style_rounded), label: _arabic ? 'البطاقات' : 'Cards'),
            NavigationDestination(icon: const Icon(Icons.layers_outlined), selectedIcon: const Icon(Icons.layers_rounded), label: _arabic ? 'المجموعات' : 'Decks'),
            NavigationDestination(icon: const Icon(Icons.sports_esports_outlined), selectedIcon: const Icon(Icons.sports_esports_rounded), label: _arabic ? 'اللعب' : 'Play'),
            NavigationDestination(icon: const Icon(Icons.person_outline), selectedIcon: const Icon(Icons.person_rounded), label: _arabic ? 'الملف' : 'Profile'),
          ],
        ),
      ),
    );
  }
}

class _HomeV2 extends StatelessWidget {
  const _HomeV2({
    required this.arabic,
    required this.profile,
    required this.openTab,
    required this.refresh,
  });
  final bool arabic;
  final PlayerProfileV2 profile;
  final ValueChanged<int> openTab;
  final VoidCallback refresh;

  @override
  Widget build(BuildContext context) {
    final activeDeck = profile.decks[profile.activeDeckIndex];
    return _Scroll(children: [
      _Hero(
        title: arabic ? 'اجمع بطاقاتك ثم نافس واسرق بطاقة.' : 'Collect cards, compete, then steal a card.',
        subtitle: arabic ? 'المحرك النشط الآن هو V2 فقط، بدون نظام الندرة أو حد 222.' : 'The active runtime is V2 only, with no rarity system or 222-card cap.',
        action: () => openTab(3),
        actionText: arabic ? 'ابدأ اللعب' : 'PLAY',
      ),
      const SizedBox(height: 16),
      _Section(title: arabic ? 'الأقسام السبعة' : 'Seven categories'),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: kCategoriesV2.map((category) {
          return Chip(
            avatar: CircleAvatar(backgroundColor: Color(category.colorHex)),
            label: Text(arabic ? category.nameAr : category.nameEn),
            backgroundColor: Colors.white,
            side: BorderSide(color: Color(category.colorHex).withValues(alpha: .28)),
          );
        }).toList(growable: false),
      ),
      const SizedBox(height: 18),
      _Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _StatRow(label: arabic ? 'البطاقات المملوكة' : 'Owned cards', value: '${profile.ownedCount}'),
          _StatRow(label: arabic ? 'الـDeck النشط' : 'Active deck', value: '${activeDeck.length}/$kDeckSizeV2'),
          _StatRow(label: arabic ? 'نقاط الأسبوع' : 'Weekly points', value: '${profile.weeklyPoints}'),
          _StatRow(label: arabic ? 'حالة PvP' : 'PvP', value: profile.pvpUnlocked && profile.activeDeckReady ? (arabic ? 'جاهز' : 'Ready') : (arabic ? 'غير جاهز' : 'Locked')),
          const SizedBox(height: 6),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              onPressed: refresh,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(arabic ? 'تحديث من السيرفر' : 'Refresh from server'),
            ),
          ),
        ]),
      ),
    ]);
  }
}

class _CardsV2 extends StatelessWidget {
  const _CardsV2({required this.arabic, required this.profile});
  final bool arabic;
  final PlayerProfileV2 profile;

  @override
  Widget build(BuildContext context) => _Scroll(children: [
        _Section(title: arabic ? 'بطاقاتي' : 'My cards'),
        const SizedBox(height: 10),
        _Panel(
          child: profile.ownedPackIds.isEmpty
              ? _Empty(
                  icon: Icons.inventory_2_outlined,
                  title: arabic ? 'لا توجد بطاقات V2 بعد' : 'No V2 cards yet',
                  text: arabic
                      ? 'هذا متعمد. سنضيف أسماء البطاقات وبنك الأسئلة في مرحلة المحتوى الأخيرة فقط.'
                      : 'This is intentional. Card topics and the question bank will be added only in the final content phase.',
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: profile.ownedPackIds.map((id) => Chip(label: Text(id))).toList(growable: false),
                ),
        ),
      ]);
}

class _DecksV2 extends StatelessWidget {
  const _DecksV2({
    required this.arabic,
    required this.profile,
    required this.busy,
    required this.setActiveDeck,
  });
  final bool arabic;
  final PlayerProfileV2 profile;
  final bool busy;
  final Future<void> Function(int index) setActiveDeck;

  @override
  Widget build(BuildContext context) => _Scroll(children: [
        _Section(title: arabic ? 'المجموعات' : 'Decks'),
        const SizedBox(height: 10),
        ...List.generate(profile.entitlement.deckSlots, (index) {
          final deck = profile.decks[index];
          final active = index == profile.activeDeckIndex;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _Panel(
              child: Row(children: [
                Icon(active ? Icons.radio_button_checked : Icons.radio_button_off, color: active ? _blue : _muted),
                const SizedBox(width: 10),
                Expanded(child: Text('${arabic ? 'مجموعة' : 'Deck'} ${index + 1}', style: const TextStyle(color: _ink, fontWeight: FontWeight.w900))),
                Text('${deck.length}/$kDeckSizeV2', style: const TextStyle(color: _purple, fontWeight: FontWeight.w900)),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: arabic ? 'تفعيل المجموعة' : 'Set active deck',
                  onPressed: busy || active || !PlayerDeckV2(deck).isValid(profile.ownedPackIds)
                      ? null
                      : () => setActiveDeck(index),
                  icon: const Icon(Icons.check_circle_outline),
                ),
              ]),
            ),
          );
        }),
        _Panel(
          child: Text(
            arabic ? 'لا يمكن بناء Deck صالحة قبل وصول بطاقات المحتوى. التحقق النهائي يبقى 10 بطاقات مختلفة ومملوكة.' : 'A valid deck cannot be built before content cards arrive. Final validation remains 10 distinct owned cards.',
            style: const TextStyle(color: _muted, height: 1.5, fontWeight: FontWeight.w700),
          ),
        ),
      ]);
}

class _PlayV2 extends StatelessWidget {
  const _PlayV2({required this.arabic, required this.profile});
  final bool arabic;
  final PlayerProfileV2 profile;

  @override
  Widget build(BuildContext context) {
    final needsBot = profile.ownedCount < kDeckSizeV2;
    return _Scroll(children: [
      _Section(title: arabic ? 'اللعب' : 'Play'),
      const SizedBox(height: 10),
      _Panel(
        child: _Empty(
          icon: needsBot ? Icons.smart_toy_rounded : Icons.flash_on_rounded,
          title: needsBot ? (arabic ? 'مسار البوت' : 'Bot onboarding') : (arabic ? 'مسار PvP' : 'PvP path'),
          text: needsBot
              ? (arabic ? 'البوت هو المسار الصحيح حتى 10 بطاقات. التنفيذ Server-authoritative جاهز، لكن المحتوى لم يُدخل بعد.' : 'Bot is the correct path until 10 cards. The server-authoritative flow is ready, but content is intentionally not loaded yet.')
              : (profile.activeDeckReady
                  ? (arabic ? 'الملف والـDeck جاهزان لبدء Matchmaking V2.' : 'Profile and active deck are ready for V2 matchmaking.')
                  : (arabic ? 'تحتاج Deck صالحة من 10 بطاقات مختلفة قبل PvP.' : 'A valid 10-card deck is required before PvP.')),
        ),
      ),
      const SizedBox(height: 12),
      _Panel(
        child: Column(children: [
          _StatRow(label: arabic ? 'مدة السؤال' : 'Question timer', value: '${kSecondsPerQuestionV2}s'),
          _StatRow(label: arabic ? 'أسئلة المواجهة' : 'Duel questions', value: '$kDuelCardsV2'),
          _StatRow(label: arabic ? 'آخر أسئلة محفوظة' : 'Recent history', value: '${profile.recentQuestionIds.length}/$kRecentQuestionLimitV2'),
        ]),
      ),
    ]);
  }
}

class _ProfileV2 extends StatelessWidget {
  const _ProfileV2({required this.arabic, required this.profile});
  final bool arabic;
  final PlayerProfileV2 profile;

  @override
  Widget build(BuildContext context) {
    final total = profile.totalWins + profile.totalLosses + profile.totalDraws;
    return _Scroll(children: [
      _Section(title: arabic ? 'الملف الشخصي' : 'Profile'),
      const SizedBox(height: 10),
      _Panel(
        child: Column(children: [
          _StatRow(label: arabic ? 'نقاط هذا الأسبوع' : 'Weekly points', value: '${profile.weeklyPoints}'),
          _StatRow(label: arabic ? 'فوز' : 'Wins', value: '${profile.totalWins}'),
          _StatRow(label: arabic ? 'خسارة' : 'Losses', value: '${profile.totalLosses}'),
          _StatRow(label: arabic ? 'تعادل' : 'Draws', value: '${profile.totalDraws}'),
          _StatRow(label: arabic ? 'إجمالي المباريات' : 'Total matches', value: '$total'),
          _StatRow(label: '🥇 / 🥈 / 🥉', value: '${profile.prestige.first} / ${profile.prestige.second} / ${profile.prestige.third}'),
          _StatRow(label: arabic ? 'Decks المتاحة' : 'Deck slots', value: '${profile.entitlement.deckSlots}'),
          _StatRow(label: arabic ? 'خيارات الإجابة' : 'Answer choices', value: '${profile.entitlement.answerChoices}'),
        ]),
      ),
    ]);
  }
}

class _Scroll extends StatelessWidget {
  const _Scroll({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
        children: [Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 960), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children)))],
      );
}

class _Hero extends StatelessWidget {
  const _Hero({required this.title, required this.subtitle, required this.action, required this.actionText});
  final String title;
  final String subtitle;
  final VoidCallback action;
  final String actionText;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(colors: [_blue, _purple]),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 26, height: 1.2, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: .9), height: 1.45, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          FilledButton(onPressed: action, style: FilledButton.styleFrom(backgroundColor: _gold, foregroundColor: _ink), child: Text(actionText)),
        ]),
      );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE5EBF5))),
        child: child,
      );
}

class _Section extends StatelessWidget {
  const _Section({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) => Text(title, style: const TextStyle(color: _ink, fontSize: 20, fontWeight: FontWeight.w900));
}

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.title, required this.text});
  final IconData icon;
  final String title;
  final String text;
  @override
  Widget build(BuildContext context) => Column(children: [
        Icon(icon, size: 42, color: _blue),
        const SizedBox(height: 10),
        Text(title, textAlign: TextAlign.center, style: const TextStyle(color: _ink, fontSize: 16, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text(text, textAlign: TextAlign.center, style: const TextStyle(color: _muted, height: 1.5, fontWeight: FontWeight.w600)),
      ]);
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [
          Expanded(child: Text(label, style: const TextStyle(color: _muted, fontWeight: FontWeight.w700))),
          Text(value, style: const TextStyle(color: _ink, fontWeight: FontWeight.w900)),
        ]),
      );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.icon});
  final String text;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(color: const Color(0xFFF1ECFF), borderRadius: BorderRadius.circular(99)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 15, color: _purple), const SizedBox(width: 4), Text(text, style: const TextStyle(color: _purple, fontWeight: FontWeight.w900))]),
      );
}
