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
  final Map<String, List<String>> _answerDrafts = <String, List<String>>{};
  int tab = 0;
  bool arabic = true;

  static const _blue = Color(0xFF2E6BFF);
  static const _purple = Color(0xFF7A48F5);
  static const _gold = Color(0xFFFFC94D);
  static const _coral = Color(0xFFFF6A67);
  static const _green = Color(0xFF21B573);
  static const _ink = Color(0xFF183153);
  static const _muted = Color(0xFF7183A3);
  static const _page = Color(0xFFF5F8FF);
  static const double _maxContentWidth = 1120;

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

  Widget _bounded(Widget child, {EdgeInsets padding = const EdgeInsets.fromLTRB(16, 16, 16, 28)}) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxContentWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }

  PreferredSizeWidget _topBar() {
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 0,
      toolbarHeight: 68,
      titleSpacing: 12,
      title: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxContentWidth),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [_blue, _purple]),
                ),
                child: const Icon(Icons.question_mark_rounded, color: Colors.white),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'STEAL THE QUESTIONS',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: _ink, fontSize: 14, fontWeight: FontWeight.w900),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(color: const Color(0xFFFFF2C8), borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  const Icon(Icons.style_rounded, size: 16, color: Color(0xFFE49C00)),
                  const SizedBox(width: 5),
                  Text('${player.ownedCount}/$kTotalCards', style: const TextStyle(color: _ink, fontSize: 11, fontWeight: FontWeight.w900)),
                ]),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: arabic ? 'English' : 'العربية',
                onPressed: () => setState(() => arabic = !arabic),
                icon: Text(arabic ? 'EN' : 'ع', style: const TextStyle(color: _blue, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bottomBar() {
    return NavigationBar(
      height: 68,
      backgroundColor: Colors.white,
      indicatorColor: const Color(0xFFE9EEFF),
      selectedIndex: tab,
      onDestinationSelected: (value) => setState(() => tab = value),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      destinations: [
        NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home_rounded, color: _blue), label: arabic ? 'الرئيسية' : 'Home'),
        NavigationDestination(icon: const Icon(Icons.style_outlined), selectedIcon: const Icon(Icons.style_rounded, color: _purple), label: arabic ? 'البطاقات' : 'Cards'),
        NavigationDestination(icon: const Icon(Icons.layers_outlined), selectedIcon: const Icon(Icons.layers_rounded, color: Color(0xFFE0A000)), label: arabic ? 'المجموعات' : 'Decks'),
        NavigationDestination(icon: const Icon(Icons.sports_esports_outlined), selectedIcon: const Icon(Icons.sports_esports_rounded, color: _coral), label: arabic ? 'اللعب' : 'Play'),
        NavigationDestination(icon: const Icon(Icons.more_horiz_rounded), selectedIcon: const Icon(Icons.more_horiz_rounded, color: _blue), label: arabic ? 'المزيد' : 'More'),
      ],
    );
  }

  Widget _home() {
    final pvpReady = player.pvpUnlocked;
    final deckCount = player.decks[player.activeDeck].length;
    return SingleChildScrollView(
      child: _bounded(Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF4E8CFF), Color(0xFF8356F6)]),
              boxShadow: const [BoxShadow(color: Color(0x264E79FF), blurRadius: 18, offset: Offset(0, 8))],
            ),
            child: Wrap(
              spacing: 22,
              runSpacing: 16,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 560,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(arabic ? 'جاوب، اجمع، نافس... واسرق بطاقة!' : 'Answer, collect, compete... and steal a card!', style: const TextStyle(color: Colors.white, fontSize: 27, height: 1.12, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    Text(arabic ? 'كل جولة تقرّبك من مجموعة أقوى وترتيب أعلى.' : 'Every round moves you toward a stronger collection and a higher rank.', style: TextStyle(color: Colors.white.withValues(alpha: .9), fontSize: 12, height: 1.45, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => setState(() => tab = 3),
                      style: FilledButton.styleFrom(backgroundColor: _gold, foregroundColor: _ink),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: Text(arabic ? 'ابدأ اللعب الآن' : 'PLAY NOW', style: const TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ]),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: .16), borderRadius: BorderRadius.circular(999)),
                  child: Text(pvpReady ? (arabic ? 'PvP مفتوح' : 'PvP unlocked') : (arabic ? '${player.ownedCount}/10 لفتح PvP' : '${player.ownedCount}/10 to unlock PvP'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(builder: (context, constraints) {
            final horizontal = constraints.maxWidth >= 620;
            final bot = _modeCard(icon: Icons.smart_toy_rounded, color: _blue, title: arabic ? 'ضد البوت' : 'Bot', subtitle: arabic ? 'اجمع بطاقات جديدة حتى تصل إلى 10.' : 'Collect new cards until you reach 10.', onTap: _openLegacy);
            final pvp = _modeCard(icon: Icons.flash_on_rounded, color: _coral, title: arabic ? 'ضد لاعب' : 'PvP', subtitle: arabic ? (pvpReady ? 'نافس واسرق بطاقة من الخصم.' : 'يفتح بعد امتلاك 10 بطاقات.') : (pvpReady ? 'Compete and steal a card.' : 'Unlocks after owning 10 cards.'), onTap: _openLegacy);
            if (horizontal) return Row(children: [Expanded(child: bot), const SizedBox(width: 12), Expanded(child: pvp)]);
            return Column(children: [bot, const SizedBox(height: 10), pvp]);
          }),
          const SizedBox(height: 14),
          _panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _sectionTitle(arabic ? 'تقدم مجموعتك' : 'Collection progress', trailing: '${player.ownedCount}/$kTotalCards'),
            const SizedBox(height: 12),
            ClipRRect(borderRadius: BorderRadius.circular(999), child: LinearProgressIndicator(value: player.ownedCount / kTotalCards, minHeight: 9, color: _blue, backgroundColor: const Color(0xFFE3E9F5))),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _rarityMini('EPIC', _purple, player.ownedCards.where((id) => QuestionBank.byId(id).rarity == CardRarity.epic).length, kEpicCards),
              _rarityMini('GOLD', const Color(0xFFE0A000), player.ownedCards.where((id) => QuestionBank.byId(id).rarity == CardRarity.gold).length, kGoldCards),
              _rarityMini('LEGENDARY', _coral, player.ownedCards.where((id) => QuestionBank.byId(id).rarity == CardRarity.legendary).length, kLegendaryCards),
            ]),
          ])),
          const SizedBox(height: 14),
          _panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _sectionTitle(arabic ? 'المجموعة النشطة' : 'Active deck', trailing: '$deckCount/$kDeckSize'),
            const SizedBox(height: 10),
            SizedBox(height: 58, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: kDeckSize, separatorBuilder: (_, __) => const SizedBox(width: 6), itemBuilder: (_, i) {
              final has = i < deckCount;
              final id = has ? player.decks[player.activeDeck][i] : null;
              final rarity = id == null ? CardRarity.epic : QuestionBank.byId(id).rarity;
              return _miniCard(id: id, rarity: rarity);
            })),
            const SizedBox(height: 12),
            OutlinedButton.icon(onPressed: () => setState(() => tab = 2), icon: const Icon(Icons.edit_rounded), label: Text(arabic ? 'إدارة المجموعات' : 'Manage decks')),
          ])),
        ],
      )),
    );
  }

  Widget _collection() {
    final owned = QuestionBank.all.where((q) => player.ownedCards.contains(q.id)).toList(growable: false);
    final locked = QuestionBank.all.where((q) => !player.ownedCards.contains(q.id)).toList(growable: false);

    return SingleChildScrollView(
      child: _bounded(Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _pageHeading(arabic ? 'بطاقاتك' : 'Your cards', arabic ? 'بطاقاتك المملوكة أولًا. اضغط على أي بطاقة لرؤية السؤال وتخصيص خياراتها.' : 'Owned cards first. Tap a card to see its question and customize its choices.'),
          const SizedBox(height: 12),
          _panel(child: Wrap(spacing: 24, runSpacing: 12, alignment: WrapAlignment.spaceAround, children: [
            _bigNumber('${player.ownedCount}', arabic ? 'مملوكة' : 'Owned', _blue),
            _bigNumber('${kTotalCards - player.ownedCount}', arabic ? 'غير مملوكة' : 'Locked', _muted),
            _bigNumber('$kTotalCards', arabic ? 'الإجمالي' : 'Total', const Color(0xFFE0A000)),
          ])),
          const SizedBox(height: 18),
          _sectionTitle(arabic ? 'البطاقات المملوكة' : 'Owned cards', trailing: '${owned.length}'),
          const SizedBox(height: 6),
          Text(arabic ? 'هذه بطاقاتك القابلة للاستخدام والتعديل.' : 'These are the cards you can use and customize.', style: const TextStyle(color: _muted, fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          if (owned.isEmpty)
            _emptyOwned()
          else
            _compactCardGrid(owned, owned: true),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(child: _sectionTitle(arabic ? 'بطاقات لم تحصل عليها بعد' : 'Cards you have not earned yet')),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: const Color(0xFFEEF2F8), borderRadius: BorderRadius.circular(999)), child: Text('${locked.length}', style: const TextStyle(color: _muted, fontSize: 11, fontWeight: FontWeight.w900))),
          ]),
          const SizedBox(height: 6),
          Text(arabic ? 'تبقى في الأسفل حتى لا تزاحم بطاقاتك. ستظهر معلوماتها بعد الحصول عليها.' : 'Kept below so they never get in the way of your collection. Details unlock when earned.', style: const TextStyle(color: _muted, fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          _compactCardGrid(locked, owned: false),
        ],
      )),
    );
  }

  Widget _compactCardGrid(List<QuestionContent> cards, {required bool owned}) {
    return LayoutBuilder(builder: (context, constraints) {
      const targetWidth = 126.0;
      final columns = (constraints.maxWidth / targetWidth).floor().clamp(2, 8);
      return GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: columns, childAspectRatio: .92, crossAxisSpacing: 9, mainAxisSpacing: 9),
        itemCount: cards.length,
        itemBuilder: (_, i) => _collectionCard(cards[i], owned),
      );
    });
  }

  Widget _emptyOwned() {
    return _panel(child: Row(children: [
      Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0xFFE9EEFF), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.smart_toy_rounded, color: _blue)),
      const SizedBox(width: 12),
      Expanded(child: Text(arabic ? 'ابدأ جولة البوت لتحصل على أول بطاقة.' : 'Start a bot round to earn your first card.', style: const TextStyle(color: _ink, fontWeight: FontWeight.w800))),
      TextButton(onPressed: () => setState(() => tab = 3), child: Text(arabic ? 'العب' : 'Play')),
    ]));
  }

  Widget _collectionCard(QuestionContent q, bool owned) {
    final color = _rarityColor(q.rarity);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: owned ? () => _showCardDetails(q) : null,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: owned ? Colors.white : const Color(0xFFF0F3F8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: owned ? color.withValues(alpha: .55) : const Color(0xFFDCE3EE), width: owned ? 1.4 : 1),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              width: 38,
              height: 46,
              decoration: BoxDecoration(gradient: owned ? LinearGradient(colors: [color.withValues(alpha: .72), color]) : null, color: owned ? null : const Color(0xFFE1E6EE), borderRadius: BorderRadius.circular(10)),
              child: Icon(owned ? Icons.question_mark_rounded : Icons.lock_rounded, color: owned ? Colors.white : _muted, size: 22),
            ),
            const SizedBox(height: 7),
            Text(q.id, style: const TextStyle(color: _ink, fontWeight: FontWeight.w900, fontSize: 10)),
            const SizedBox(height: 2),
            Text(_rarityName(q.rarity), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: owned ? color : _muted, fontWeight: FontWeight.w900, fontSize: 7)),
            if (owned) ...[
              const SizedBox(height: 4),
              const Icon(Icons.touch_app_rounded, color: _muted, size: 13),
            ],
          ]),
        ),
      ),
    );
  }

  Future<void> _showCardDetails(QuestionContent q) async {
    final baseAnswers = List<String>.from(arabic ? q.answersAr : q.answersEn);
    final correct = baseAnswers[q.correctIndex];
    final extra = arabic ? q.passExtraAr : q.passExtraEn;
    final draft = List<String>.from(_answerDrafts[q.id] ?? [...baseAnswers, if (player.weeklyPass) extra]);
    while (draft.length < (player.weeklyPass ? 4 : 3)) {
      draft.add('');
    }
    final controllers = List<TextEditingController>.generate(draft.length, (i) => TextEditingController(text: draft[i]));

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: arabic ? TextDirection.rtl : TextDirection.ltr,
        child: AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
          contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          title: Row(children: [
            Container(width: 40, height: 48, decoration: BoxDecoration(gradient: LinearGradient(colors: [_rarityColor(q.rarity).withValues(alpha: .7), _rarityColor(q.rarity)]), borderRadius: BorderRadius.circular(11)), child: const Icon(Icons.question_mark_rounded, color: Colors.white)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(q.id, style: const TextStyle(color: _ink, fontWeight: FontWeight.w900, fontSize: 18)),
              Text(_rarityName(q.rarity), style: TextStyle(color: _rarityColor(q.rarity), fontWeight: FontWeight.w900, fontSize: 9)),
            ])),
          ]),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(arabic ? 'السؤال' : 'Question', style: const TextStyle(color: _muted, fontSize: 10, fontWeight: FontWeight.w900)),
                const SizedBox(height: 5),
                Text(arabic ? q.questionAr : q.questionEn, style: const TextStyle(color: _ink, fontSize: 18, height: 1.45, fontWeight: FontWeight.w900)),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFFEAF9F2), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFBCEBD6))),
                  child: Row(children: [
                    const Icon(Icons.check_circle_rounded, color: _green),
                    const SizedBox(width: 8),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(arabic ? 'الإجابة الصحيحة' : 'Correct answer', style: const TextStyle(color: _green, fontSize: 10, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 2),
                      Text(correct, style: const TextStyle(color: _ink, fontSize: 14, fontWeight: FontWeight.w900)),
                    ])),
                  ]),
                ),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(child: Text(arabic ? 'خيارات الإجابة' : 'Answer choices', style: const TextStyle(color: _ink, fontSize: 15, fontWeight: FontWeight.w900))),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: const Color(0xFFE9EEFF), borderRadius: BorderRadius.circular(999)), child: Text('${controllers.length} ${arabic ? 'خيارات' : 'choices'}', style: const TextStyle(color: _blue, fontSize: 9, fontWeight: FontWeight.w900))),
                ]),
                const SizedBox(height: 5),
                Text(arabic ? 'يمكنك كتابة الخيارات التي تريدها. الإجابة الصحيحة تبقى واضحة ولا تتغير في مرحلة التصميم.' : 'Write the choices you want. The correct answer stays visible and unchanged during design.', style: const TextStyle(color: _muted, fontSize: 10, height: 1.4)),
                const SizedBox(height: 10),
                ...List.generate(controllers.length, (i) {
                  final isCorrect = i == q.correctIndex;
                  final isFourth = i == 3;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TextField(
                      controller: controllers[i],
                      readOnly: isCorrect,
                      decoration: InputDecoration(
                        labelText: isCorrect ? (arabic ? 'الإجابة الصحيحة' : 'Correct answer') : '${arabic ? 'الخيار' : 'Choice'} ${i + 1}${isFourth ? ' · Weekly Pass' : ''}',
                        prefixIcon: Icon(isCorrect ? Icons.check_circle_rounded : Icons.edit_rounded, color: isCorrect ? _green : _blue),
                        filled: true,
                        fillColor: isCorrect ? const Color(0xFFEAF9F2) : const Color(0xFFF7F9FD),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      ),
                    ),
                  );
                }),
                if (!player.weeklyPass)
                  Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(color: const Color(0xFFFFF7DE), borderRadius: BorderRadius.circular(13)),
                    child: Row(children: [
                      const Icon(Icons.workspace_premium_rounded, color: Color(0xFFE0A000), size: 20),
                      const SizedBox(width: 8),
                      Expanded(child: Text(arabic ? 'الخيار الرابع متاح مع Weekly Pass.' : 'The fourth choice is available with Weekly Pass.', style: const TextStyle(color: _ink, fontSize: 10, fontWeight: FontWeight.w800))),
                    ]),
                  ),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(arabic ? 'إلغاء' : 'Cancel')),
            FilledButton.icon(
              onPressed: () {
                _answerDrafts[q.id] = controllers.map((c) => c.text.trim()).toList(growable: false);
                Navigator.pop(dialogContext);
                setState(() {});
              },
              icon: const Icon(Icons.save_rounded),
              label: Text(arabic ? 'حفظ للمعاينة' : 'Save preview'),
            ),
          ],
        ),
      ),
    );
    for (final c in controllers) {
      c.dispose();
    }
  }

  Widget _decks() {
    return SingleChildScrollView(
      child: _bounded(Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _pageHeading(arabic ? 'مجموعات اللعب' : 'Decks', arabic ? 'اختر المجموعة النشطة وعدّل بطاقاتها بسهولة.' : 'Choose your active deck and edit its cards easily.'),
          const SizedBox(height: 14),
          ...List.generate(kMaxDeckSlots, (i) {
            final unlocked = i < player.deckSlots;
            final count = player.decks[i].length;
            final active = i == player.activeDeck;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _panel(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Container(width: 44, height: 44, decoration: BoxDecoration(color: unlocked ? const Color(0xFFE9EEFF) : const Color(0xFFF1F3F7), borderRadius: BorderRadius.circular(14)), child: Icon(unlocked ? Icons.layers_rounded : Icons.lock_rounded, color: unlocked ? _purple : _muted)),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [Text('${arabic ? 'المجموعة' : 'Deck'} ${i + 1}', style: const TextStyle(color: _ink, fontWeight: FontWeight.w900, fontSize: 15)), if (active) ...[const SizedBox(width: 7), _statusPill(arabic ? 'نشطة' : 'ACTIVE', _green)]]),
                    const SizedBox(height: 2),
                    Text(unlocked ? '$count/$kDeckSize' : 'Weekly Pass', style: const TextStyle(color: _muted, fontSize: 11, fontWeight: FontWeight.w700)),
                  ])),
                  if (unlocked)
                    OutlinedButton(onPressed: () { player.setActiveDeck(i); setState(() {}); }, child: Text(active ? (arabic ? 'مختارة' : 'Selected') : (arabic ? 'اختيار' : 'Select')))
                  else
                    const Icon(Icons.workspace_premium_rounded, color: Color(0xFFE0A000)),
                ]),
                if (unlocked) ...[
                  const SizedBox(height: 10),
                  SizedBox(height: 52, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: kDeckSize, separatorBuilder: (_, __) => const SizedBox(width: 5), itemBuilder: (_, index) {
                    final has = index < count;
                    final id = has ? player.decks[i][index] : null;
                    final rarity = id == null ? CardRarity.epic : QuestionBank.byId(id).rarity;
                    return _miniCard(id: id, rarity: rarity);
                  })),
                  const SizedBox(height: 10),
                  FilledButton.icon(onPressed: _openLegacy, icon: const Icon(Icons.edit_rounded), label: Text(arabic ? 'تعديل بطاقات المجموعة' : 'Edit deck cards')),
                ],
              ])),
            );
          }),
        ],
      )),
    );
  }

  Widget _play() {
    final deckCount = player.decks[player.activeDeck].length;
    return SingleChildScrollView(
      child: _bounded(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _pageHeading(arabic ? 'اللعب' : 'Play', arabic ? 'اعرف ما تحتاجه قبل بدء الجولة، ثم اختر وضع اللعب.' : 'See what you need before starting, then choose a mode.'),
        const SizedBox(height: 14),
        _panel(child: Row(children: [
          Container(width: 46, height: 46, decoration: BoxDecoration(color: const Color(0xFFE9EEFF), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.layers_rounded, color: _purple)),
          const SizedBox(width: 11),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${arabic ? 'المجموعة النشطة' : 'Active deck'} ${player.activeDeck + 1}', style: const TextStyle(color: _ink, fontWeight: FontWeight.w900, fontSize: 14)),
            const SizedBox(height: 2),
            Text('$deckCount/$kDeckSize', style: TextStyle(color: player.activeDeckReady ? _green : _coral, fontWeight: FontWeight.w900, fontSize: 12)),
          ])),
          TextButton(onPressed: () => setState(() => tab = 2), child: Text(arabic ? 'تعديل' : 'Edit')),
        ])),
        const SizedBox(height: 12),
        _playCard(Icons.smart_toy_rounded, const [Color(0xFF46A6FF), Color(0xFF2E6BFF)], arabic ? 'العب ضد البوت' : 'Play vs Bot', arabic ? 'للاعب الذي يملك أقل من 10 بطاقات: إجابة صحيحة = بطاقة جديدة.' : 'For players below 10 cards: a correct answer earns a new card.', _openLegacy),
        const SizedBox(height: 12),
        _playCard(Icons.flash_on_rounded, const [Color(0xFFFF7C73), Color(0xFFFF4F87)], arabic ? 'العب ضد لاعب' : 'Play PvP', player.pvpUnlocked ? (player.activeDeckReady ? (arabic ? 'جاهز: 7 أسئلة ثم الفائز يسرق بطاقة.' : 'Ready: 7 questions, then the winner steals a card.') : (arabic ? 'أكمل المجموعة النشطة إلى 10 بطاقات أولًا.' : 'Complete the active deck to 10 cards first.')) : (arabic ? 'يفتح بعد امتلاك 10 بطاقات.' : 'Unlocks after owning 10 cards.'), _openLegacy),
      ])),
    );
  }

  Widget _more() {
    return SingleChildScrollView(
      child: _bounded(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _pageHeading(arabic ? 'المزيد' : 'More', arabic ? 'الأشياء الثانوية هنا حتى تبقى الصفحات الأساسية بسيطة.' : 'Secondary items live here so the core screens stay simple.'),
        const SizedBox(height: 14),
        _panel(child: Column(children: [
          _menuRow(Icons.person_rounded, arabic ? 'الحساب' : 'Account', player.authenticated ? player.accountLabel : (arabic ? 'وضع المعاينة المحلية' : 'Local preview mode'), _openLegacy),
          const Divider(height: 22),
          _menuRow(Icons.emoji_events_rounded, arabic ? 'التصنيف' : 'Ranking', arabic ? 'ترتيبك حسب عدد البطاقات ثم الانتصارات' : 'Ranked by cards, then wins', _openLegacy),
          const Divider(height: 22),
          _menuRow(Icons.workspace_premium_rounded, 'Weekly Pass', arabic ? '3 مجموعات إضافية + الخيار الرابع' : '3 extra decks + fourth answer choice', _openLegacy),
          const Divider(height: 22),
          _menuRow(Icons.help_outline_rounded, arabic ? 'كيف تعمل اللعبة؟' : 'How it works', arabic ? 'شرح مختصر لمسار اللعب' : 'A short guide to the game flow', _openLegacy),
        ])),
      ])),
    );
  }

  Widget _modeCard({required IconData icon, required Color color, required String title, required String subtitle, required VoidCallback onTap}) => Material(color: Colors.transparent, child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(20), child: Ink(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE7ECF5))), child: Row(children: [Container(width: 44, height: 44, decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: color)), const SizedBox(width: 11), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: _ink, fontWeight: FontWeight.w900, fontSize: 15)), const SizedBox(height: 3), Text(subtitle, style: const TextStyle(color: _muted, fontSize: 10, height: 1.35))])), const Icon(Icons.chevron_right_rounded, color: _muted)]))));

  Widget _panel({required Widget child}) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE7ECF5)), boxShadow: const [BoxShadow(color: Color(0x09183153), blurRadius: 10, offset: Offset(0, 4))]), child: child);

  Widget _sectionTitle(String title, {String? trailing}) => Row(mainAxisSize: MainAxisSize.min, children: [Flexible(child: Text(title, style: const TextStyle(color: _ink, fontSize: 16, fontWeight: FontWeight.w900))), if (trailing != null) ...[const SizedBox(width: 8), Text(trailing, style: const TextStyle(color: _blue, fontSize: 12, fontWeight: FontWeight.w900))]]);

  Widget _rarityMini(String label, Color color, int value, int total) => Container(width: 150, padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10), decoration: BoxDecoration(color: color.withValues(alpha: .1), borderRadius: BorderRadius.circular(14)), child: Row(children: [Expanded(child: Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900))), Text('$value/$total', style: const TextStyle(color: _ink, fontWeight: FontWeight.w900, fontSize: 13))]));

  Widget _miniCard({String? id, required CardRarity rarity}) {
    final color = _rarityColor(rarity);
    return Container(width: 40, decoration: BoxDecoration(gradient: id == null ? null : LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [color.withValues(alpha: .8), color]), color: id == null ? const Color(0xFFEDF1F7) : null, borderRadius: BorderRadius.circular(9), border: Border.all(color: id == null ? const Color(0xFFDCE3EE) : color)), child: Center(child: Text(id == null ? '+' : id.replaceFirst('Q', ''), style: TextStyle(color: id == null ? _muted : Colors.white, fontSize: 8, fontWeight: FontWeight.w900))));
  }

  Widget _pageHeading(String title, String subtitle) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: _ink, fontSize: 25, fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text(subtitle, style: const TextStyle(color: _muted, fontSize: 11, height: 1.4, fontWeight: FontWeight.w600))]);

  Widget _bigNumber(String value, String label, Color color) => SizedBox(width: 120, child: Column(children: [Text(value, style: TextStyle(color: color, fontSize: 21, fontWeight: FontWeight.w900)), const SizedBox(height: 2), Text(label, style: const TextStyle(color: _muted, fontSize: 10, fontWeight: FontWeight.w700))]));

  Widget _statusPill(String label, Color color) => Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3), decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(999)), child: Text(label, style: TextStyle(color: color, fontSize: 7, fontWeight: FontWeight.w900)));

  Widget _playCard(IconData icon, List<Color> colors, String title, String subtitle, VoidCallback onTap) => Material(color: Colors.transparent, child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(22), child: Ink(padding: const EdgeInsets.all(18), decoration: BoxDecoration(gradient: LinearGradient(colors: colors), borderRadius: BorderRadius.circular(22), boxShadow: [BoxShadow(color: colors.last.withValues(alpha: .18), blurRadius: 14, offset: const Offset(0, 6))]), child: Row(children: [Container(width: 52, height: 52, decoration: BoxDecoration(color: Colors.white.withValues(alpha: .2), borderRadius: BorderRadius.circular(16)), child: Icon(icon, color: Colors.white, size: 28)), const SizedBox(width: 13), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: .92), fontSize: 10, height: 1.4, fontWeight: FontWeight.w600))])), const Icon(Icons.chevron_right_rounded, color: Colors.white)]))));

  Widget _menuRow(IconData icon, String title, String subtitle, VoidCallback onTap) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(14), child: Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [Container(width: 40, height: 40, decoration: BoxDecoration(color: const Color(0xFFE9EEFF), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: _blue, size: 21)), const SizedBox(width: 11), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: _ink, fontSize: 13, fontWeight: FontWeight.w900)), const SizedBox(height: 2), Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _muted, fontSize: 9, height: 1.35))])), const Icon(Icons.chevron_right_rounded, color: _muted)])));

  Color _rarityColor(CardRarity rarity) {
    switch (rarity) {
      case CardRarity.epic:
        return _purple;
      case CardRarity.gold:
        return const Color(0xFFE0A000);
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
