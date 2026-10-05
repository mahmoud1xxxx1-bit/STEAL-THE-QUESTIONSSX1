import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'final_design_app_v2.dart';
import 'game/game_rules.dart';
import 'game/question_bank.dart';
import 'product_app.dart';

class GameCategory {
  const GameCategory({
    required this.id,
    required this.en,
    required this.ar,
    required this.color,
    required this.icon,
  });

  final String id;
  final String en;
  final String ar;
  final Color color;
  final IconData icon;
}

const gameCategories = <GameCategory>[
  GameCategory(id: 'football', en: 'Football', ar: 'كرة القدم', color: Color(0xFF19A55A), icon: Icons.sports_soccer_rounded),
  GameCategory(id: 'animals', en: 'Animals', ar: 'الحيوانات', color: Color(0xFFE34B4B), icon: Icons.pets_rounded),
  GameCategory(id: 'anime', en: 'Anime', ar: 'الأنمي', color: Color(0xFF3478F6), icon: Icons.auto_awesome_rounded),
  GameCategory(id: 'countries', en: 'Countries & Geography', ar: 'الدول والجغرافيا', color: Color(0xFFE5A51A), icon: Icons.public_rounded),
  GameCategory(id: 'movies', en: 'Movies & Series', ar: 'الأفلام والمسلسلات', color: Color(0xFF8A4FE0), icon: Icons.movie_rounded),
  GameCategory(id: 'general', en: 'General Knowledge', ar: 'معلومات عامة', color: Color(0xFF18A7A7), icon: Icons.lightbulb_rounded),
  GameCategory(id: 'science', en: 'Science & Technology', ar: 'العلوم والتقنية', color: Color(0xFFF06B32), icon: Icons.science_rounded),
];

GameCategory categoryFor(QuestionContent q) {
  final category = q.categoryEn.toLowerCase();
  final text = '${q.questionEn} ${q.answersEn.join(' ')}'.toLowerCase();

  if (text.contains('football') || text.contains('fifa') || text.contains('world cup') || text.contains('soccer')) {
    return gameCategories[0];
  }
  if (text.contains('animal') || text.contains('lion') || text.contains('tiger') || text.contains('elephant') || text.contains('bird')) {
    return gameCategories[1];
  }
  if (text.contains('anime') || text.contains('manga')) {
    return gameCategories[2];
  }
  if (category.contains('geography')) return gameCategories[3];
  if (category.contains('culture') && (text.contains('film') || text.contains('movie') || text.contains('cinema'))) {
    return gameCategories[4];
  }
  if (category.contains('science') || category.contains('technology')) return gameCategories[6];
  return gameCategories[5];
}

class SevenCategoriesApp extends StatefulWidget {
  const SevenCategoriesApp({super.key});

  @override
  State<SevenCategoriesApp> createState() => _SevenCategoriesAppState();
}

class _SevenCategoriesAppState extends State<SevenCategoriesApp> {
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

  void push(Widget pageWidget) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => pageWidget));

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: player,
      builder: (_, __) {
        if (player.loading) {
          return const Scaffold(backgroundColor: page, body: Center(child: CircularProgressIndicator()));
        }

        final screens = <Widget>[
          CategoriesHomeScreen(arabic: arabic, player: player, openTab: (value) => setState(() => tab = value), push: push),
          CategoriesCardsScreen(arabic: arabic, player: player, prefs: prefs, savedChoices: savedChoices),
          CategoriesDecksScreen(arabic: arabic, player: player, push: push),
          PlayScreen(arabic: arabic, player: player, push: push),
          CategoriesMoreScreen(arabic: arabic, player: player, push: push),
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
                      child: const Icon(Icons.style_rounded, color: Colors.white),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        Text('STEAL THE QUESTIONS', style: TextStyle(color: ink, fontSize: 14, fontWeight: FontWeight.w900)),
                        Text('7 CATEGORIES', style: TextStyle(color: purple, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1.1)),
                      ]),
                    ),
                    AppPill(text: '${player.ownedCount}', color: purple, bg: const Color(0xFFF1ECFF), icon: Icons.style_rounded),
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: () => setState(() => arabic = !arabic),
                      icon: Text(arabic ? 'EN' : 'ع', style: const TextStyle(color: blue, fontWeight: FontWeight.w900)),
                    ),
                  ]),
                ),
              ),
            ),
            body: IndexedStack(index: tab, children: screens),
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

class CategoriesHomeScreen extends StatelessWidget {
  const CategoriesHomeScreen({
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
    return AppScroll(children: [
      Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: const LinearGradient(colors: [Color(0xFF3E7DF5), Color(0xFF7A48F5)]),
          boxShadow: const [BoxShadow(color: Color(0x224C72FF), blurRadius: 18, offset: Offset(0, 8))],
        ),
        child: Stack(children: [
          PositionedDirectional(
            end: -20,
            top: -22,
            child: Icon(Icons.style_rounded, size: 160, color: Colors.white.withValues(alpha: .10)),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(arabic ? '7 مجالات. Deck واحد. كل مباراة مختلفة.' : '7 categories. One deck. Every match feels different.', style: const TextStyle(color: Colors.white, fontSize: 27, height: 1.15, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text(arabic ? 'اجمع بطاقات من المجالات التي تحبها، امزجها بطريقتك، ونافس على بطاقات خصمك.' : 'Collect categories you like, mix them your way, and compete for your opponent cards.', style: TextStyle(color: Colors.white.withValues(alpha: .9), fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => openTab(3),
                style: FilledButton.styleFrom(backgroundColor: gold, foregroundColor: ink),
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(arabic ? 'ابدأ اللعب' : 'PLAY NOW'),
              ),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 14),
      AppHeading(arabic ? 'الأقسام السبعة' : 'Seven categories', arabic ? 'لون البطاقة يعني مجالها، وليس قوتها أو ندرتها.' : 'A card color shows its category, not power or rarity.'),
      const SizedBox(height: 10),
      LayoutBuilder(builder: (_, constraints) {
        final columns = constraints.maxWidth >= 760 ? 4 : constraints.maxWidth >= 480 ? 3 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: gameCategories.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: columns, childAspectRatio: 1.55, crossAxisSpacing: 9, mainAxisSpacing: 9),
          itemBuilder: (_, index) {
            final cat = gameCategories[index];
            final ownedCount = player.ownedCards.where((id) => categoryFor(QuestionBank.byId(id)).id == cat.id).length;
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: cat.color.withValues(alpha: .35))),
              child: Row(children: [
                Container(width: 42, height: 42, decoration: BoxDecoration(color: cat.color.withValues(alpha: .12), borderRadius: BorderRadius.circular(13)), child: Icon(cat.icon, color: cat.color)),
                const SizedBox(width: 9),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(arabic ? cat.ar : cat.en, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: ink, fontSize: 12, fontWeight: FontWeight.w900)),
                  Text('$ownedCount ${arabic ? 'بطاقة' : 'cards'}', style: TextStyle(color: cat.color, fontSize: 9, fontWeight: FontWeight.w800)),
                ])),
              ]),
            );
          },
        );
      }),
      const SizedBox(height: 14),
      ResponsiveTwo(
        a: ActionTile(icon: Icons.smart_toy_rounded, color: blue, title: arabic ? 'ابدأ من البوت' : 'Start vs Bot', text: arabic ? 'كوّن أول 10 بطاقات.' : 'Build your first 10 cards.', onTap: () => push(BotPage(arabic: arabic, player: player))),
        b: ActionTile(icon: Icons.flash_on_rounded, color: coral, title: arabic ? 'PvP وسرقة البطاقات' : 'PvP & steal', text: player.pvpUnlocked ? (arabic ? 'نافس واربح بطاقة من خصمك.' : 'Compete and win a card from your opponent.') : (arabic ? 'يفتح عند امتلاك 10 بطاقات.' : 'Unlocks at 10 owned cards.'), onTap: () => openTab(3)),
      ),
      const SizedBox(height: 14),
      AppPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TitleRow(arabic ? 'الـDeck النشط' : 'Active deck', '$deckCount/$kDeckSize'),
        const SizedBox(height: 8),
        Text(arabic ? 'يمكنك مزج أي أقسام تريدها داخل 10 بطاقات.' : 'Mix any categories you want inside the 10-card deck.', style: const TextStyle(color: muted, fontSize: 10, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 6, children: player.decks[player.activeDeck].map((id) {
          final q = QuestionBank.byId(id);
          final cat = categoryFor(q);
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
            decoration: BoxDecoration(color: cat.color.withValues(alpha: .12), borderRadius: BorderRadius.circular(10)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(cat.icon, color: cat.color, size: 14), const SizedBox(width: 4), Text(id, style: TextStyle(color: cat.color, fontSize: 9, fontWeight: FontWeight.w900))]),
          );
        }).toList()),
        const SizedBox(height: 10),
        OutlinedButton.icon(onPressed: () => openTab(2), icon: const Icon(Icons.tune_rounded), label: Text(arabic ? 'إدارة الـDecks' : 'Manage decks')),
      ])),
    ]);
  }
}

class CategoriesCardsScreen extends StatelessWidget {
  const CategoriesCardsScreen({
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

  String choiceKey(String cardId) => 'stq_choices_${arabic ? 'ar' : 'en'}_$cardId';

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
    return AppScroll(children: [
      AppHeading(arabic ? 'بطاقاتي وأسئلتي' : 'My cards & questions', arabic ? 'لا توجد ندرة الآن. لون البطاقة يحدد مجال الأسئلة.' : 'There is no rarity now. Card color identifies the question category.'),
      const SizedBox(height: 12),
      ...gameCategories.map((cat) {
        final cards = owned.where((q) => categoryFor(q).id == cat.id).toList(growable: false);
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AppPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Container(width: 40, height: 40, decoration: BoxDecoration(color: cat.color.withValues(alpha: .12), borderRadius: BorderRadius.circular(12)), child: Icon(cat.icon, color: cat.color)),
              const SizedBox(width: 9),
              Expanded(child: Text(arabic ? cat.ar : cat.en, style: const TextStyle(color: ink, fontSize: 16, fontWeight: FontWeight.w900))),
              AppPill(text: '${cards.length}', color: cat.color, bg: cat.color.withValues(alpha: .10)),
            ]),
            if (cards.isEmpty) ...[
              const SizedBox(height: 10),
              Text(arabic ? 'لا تملك بطاقة من هذا القسم بعد.' : 'You do not own a card in this category yet.', style: const TextStyle(color: muted, fontSize: 10, fontWeight: FontWeight.w700)),
            ] else ...[
              const SizedBox(height: 10),
              ...cards.map((q) => Padding(padding: const EdgeInsets.only(bottom: 8), child: _ownedCard(context, q, cat))),
            ],
          ])),
        );
      }),
    ]);
  }

  Widget _ownedCard(BuildContext context, QuestionContent q, GameCategory cat) {
    final base = arabic ? q.answersAr : q.answersEn;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: cat.color.withValues(alpha: .045), borderRadius: BorderRadius.circular(16), border: Border.all(color: cat.color.withValues(alpha: .25))),
      child: FutureBuilder<List<String>>(
        future: choicesFor(q),
        builder: (_, snap) {
          final choices = snap.data ?? List<String>.from(base);
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(width: 40, height: 48, decoration: BoxDecoration(color: cat.color, borderRadius: BorderRadius.circular(11)), child: Icon(cat.icon, color: Colors.white, size: 21)),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${q.id} · ${arabic ? cat.ar : cat.en}', style: TextStyle(color: cat.color, fontSize: 10, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(arabic ? q.questionAr : q.questionEn, style: const TextStyle(color: ink, fontSize: 15, height: 1.4, fontWeight: FontWeight.w900)),
              ])),
            ]),
            const SizedBox(height: 9),
            Wrap(spacing: 6, runSpacing: 6, children: List.generate(choices.length, (i) {
              final correct = i == q.correctIndex;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                decoration: BoxDecoration(color: correct ? const Color(0xFFEAF9F2) : Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: correct ? const Color(0xFFBCE7D2) : line)),
                child: Text(choices[i], style: TextStyle(color: correct ? green : ink, fontSize: 10, fontWeight: FontWeight.w800)),
              );
            })),
            const SizedBox(height: 9),
            FilledButton.icon(
              onPressed: () => _editChoices(context, q),
              icon: const Icon(Icons.edit_rounded),
              label: Text(player.weeklyPass ? (arabic ? 'تعديل 3 خيارات خاطئة' : 'Edit 3 wrong choices') : (arabic ? 'تعديل الخيارين الخاطئين' : 'Edit 2 wrong choices')),
            ),
          ]);
        },
      ),
    );
  }

  Future<void> _editChoices(BuildContext context, QuestionContent q) async {
    final base = List<String>.from(arabic ? q.answersAr : q.answersEn);
    final key = choiceKey(q.id);
    final values = await choicesFor(q);
    final ctrls = values.map((value) => TextEditingController(text: value)).toList(growable: false);
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
                final next = ctrls.map((controller) => controller.text.trim()).toList(growable: false);
                next[q.correctIndex] = base[q.correctIndex];
                final normalized = next.map((value) => value.toLowerCase()).toList(growable: false);
                if (next.any((value) => value.isEmpty) || normalized.toSet().length != normalized.length) {
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

    for (final controller in ctrls) {
      controller.dispose();
    }
  }
}

class CategoriesDecksScreen extends StatelessWidget {
  const CategoriesDecksScreen({super.key, required this.arabic, required this.player, required this.push});

  final bool arabic;
  final DemoPlayerState player;
  final ValueChanged<Widget> push;

  @override
  Widget build(BuildContext context) {
    return AppScroll(children: [
      AppHeading(arabic ? 'بناء الـDeck' : 'Build your deck', arabic ? 'اختر 10 بطاقات من أي خليط من الأقسام السبعة.' : 'Choose 10 cards using any mix of the seven categories.'),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFFF0ECFF), borderRadius: BorderRadius.circular(15)),
        child: Text(arabic ? 'التنوع قرارك: يمكنك التخصص في مجال أو توزيع بطاقاتك بين عدة مجالات.' : 'Diversity is your choice: specialize in one category or spread your cards across several.', style: const TextStyle(color: ink, fontSize: 11, fontWeight: FontWeight.w800)),
      ),
      const SizedBox(height: 14),
      ...List.generate(kMaxDeckSlots, (index) {
        final unlocked = index < player.deckSlots;
        final active = index == player.activeDeck;
        final deck = player.decks[index];
        final categoryIds = deck.map((id) => categoryFor(QuestionBank.byId(id)).id).toSet();
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: AppPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Container(width: 44, height: 44, decoration: BoxDecoration(color: unlocked ? const Color(0xFFEAF0FF) : const Color(0xFFF0F2F6), borderRadius: BorderRadius.circular(13)), child: Icon(unlocked ? Icons.layers_rounded : Icons.lock_rounded, color: unlocked ? purple : muted)),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${arabic ? 'Deck' : 'Deck'} ${index + 1}', style: const TextStyle(color: ink, fontSize: 15, fontWeight: FontWeight.w900)),
                Text(unlocked ? '${deck.length}/$kDeckSize · ${categoryIds.length} ${arabic ? 'أقسام' : 'categories'}${active ? ' · ACTIVE' : ''}' : 'Monthly Pass', style: const TextStyle(color: muted, fontSize: 10, fontWeight: FontWeight.w700)),
              ])),
              if (unlocked)
                OutlinedButton(onPressed: () => player.setActiveDeck(index), child: Text(active ? (arabic ? 'مختار' : 'Selected') : (arabic ? 'اختيار' : 'Select')))
              else
                const Icon(Icons.workspace_premium_rounded, color: Color(0xFFE0A000)),
            ]),
            if (unlocked && deck.isNotEmpty) ...[
              const SizedBox(height: 9),
              Wrap(spacing: 5, runSpacing: 5, children: deck.map((id) {
                final cat = categoryFor(QuestionBank.byId(id));
                return Container(width: 28, height: 28, decoration: BoxDecoration(color: cat.color.withValues(alpha: .12), borderRadius: BorderRadius.circular(8)), child: Icon(cat.icon, color: cat.color, size: 15));
              }).toList()),
            ],
            if (unlocked) ...[
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: () {
                  player.setActiveDeck(index);
                  push(CategoriesDeckBuilderPage(arabic: arabic, player: player, deckIndex: index));
                },
                icon: const Icon(Icons.edit_rounded),
                label: Text(arabic ? 'تعديل البطاقات' : 'Edit cards'),
              ),
            ],
          ])),
        );
      }),
    ]);
  }
}

class CategoriesDeckBuilderPage extends StatelessWidget {
  const CategoriesDeckBuilderPage({super.key, required this.arabic, required this.player, required this.deckIndex});

  final bool arabic;
  final DemoPlayerState player;
  final int deckIndex;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: player,
      builder: (_, __) {
        final deck = player.decks[deckIndex];
        final owned = QuestionBank.all.where((q) => player.ownedCards.contains(q.id)).toList(growable: false);
        return AppShell(
          title: '${arabic ? 'Deck' : 'Deck'} ${deckIndex + 1}',
          arabic: arabic,
          child: AppBody(children: [
            AppPanel(child: Row(children: [
              Icon(deck.length == kDeckSize ? Icons.check_circle_rounded : Icons.layers_rounded, color: deck.length == kDeckSize ? green : purple),
              const SizedBox(width: 9),
              Expanded(child: Text(arabic ? 'اختر 10 بطاقات. ألوانها توضح مجالاتها.' : 'Choose 10 cards. Colors show their categories.', style: const TextStyle(color: ink, fontWeight: FontWeight.w900))),
              Text('${deck.length}/$kDeckSize', style: const TextStyle(color: blue, fontWeight: FontWeight.w900)),
            ])),
            const SizedBox(height: 12),
            ...gameCategories.map((cat) {
              final cards = owned.where((q) => categoryFor(q).id == cat.id).toList(growable: false);
              if (cards.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [Icon(cat.icon, color: cat.color, size: 19), const SizedBox(width: 7), Expanded(child: Text(arabic ? cat.ar : cat.en, style: TextStyle(color: cat.color, fontWeight: FontWeight.w900)))]),
                  const SizedBox(height: 7),
                  Wrap(spacing: 7, runSpacing: 7, children: cards.map((q) {
                    final selected = deck.contains(q.id);
                    return InkWell(
                      onTap: () => player.toggleCardInDeck(q.id),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 86,
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(color: selected ? cat.color.withValues(alpha: .15) : Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: selected ? cat.color : line, width: selected ? 2 : 1)),
                        child: Column(children: [Icon(cat.icon, color: cat.color, size: 22), const SizedBox(height: 4), Text(q.id, style: const TextStyle(color: ink, fontSize: 10, fontWeight: FontWeight.w900)), if (selected) const Icon(Icons.check_circle_rounded, color: green, size: 14)]),
                      ),
                    );
                  }).toList()),
                ]),
              );
            }),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: deck.isEmpty ? null : () => player.clearDeck(deckIndex), child: Text(arabic ? 'مسح' : 'Clear'))),
              const SizedBox(width: 10),
              Expanded(child: FilledButton(onPressed: deck.length == kDeckSize ? () async { await player.saveDeck(deckIndex); if (context.mounted) Navigator.pop(context); } : null, child: Text(arabic ? 'حفظ الـDeck' : 'Save deck'))),
            ]),
          ]),
        );
      },
    );
  }
}

class CategoriesMoreScreen extends StatelessWidget {
  const CategoriesMoreScreen({super.key, required this.arabic, required this.player, required this.push});

  final bool arabic;
  final DemoPlayerState player;
  final ValueChanged<Widget> push;

  @override
  Widget build(BuildContext context) {
    return AppScroll(children: [
      AppHeading(arabic ? 'المزيد' : 'More', arabic ? 'الحساب، الترتيب، الاشتراك وطريقة اللعب.' : 'Account, ranking, subscription and game guide.'),
      const SizedBox(height: 14),
      AppPanel(child: Column(children: [
        MenuRow(icon: Icons.person_rounded, title: arabic ? 'الحساب' : 'Account', subtitle: player.authenticated ? player.accountLabel : (arabic ? 'غير مسجل' : 'Not signed in'), onTap: () => push(AuthPage(arabic: arabic, player: player))),
        const Divider(height: 22),
        MenuRow(icon: Icons.emoji_events_rounded, title: arabic ? 'الترتيب' : 'Ranking', subtitle: arabic ? 'المنافسة بين اللاعبين' : 'Player competition', onTap: () => push(RankingPage(arabic: arabic, player: player))),
        const Divider(height: 22),
        MenuRow(icon: Icons.workspace_premium_rounded, title: r'Monthly Pass · $10', subtitle: arabic ? '5 Decks + 4 خيارات + تعديل 3 خيارات خاطئة' : '5 decks + 4 choices + edit 3 wrong choices', onTap: () => push(CategoriesPassPage(arabic: arabic, player: player))),
        const Divider(height: 22),
        MenuRow(icon: Icons.help_outline_rounded, title: arabic ? 'كيف تعمل اللعبة؟' : 'How it works', subtitle: arabic ? 'جمع، Deck، PvP، سرقة' : 'Collect, deck, PvP, steal', onTap: () => push(HowPage(arabic: arabic))),
      ])),
    ]);
  }
}

class CategoriesPassPage extends StatelessWidget {
  const CategoriesPassPage({super.key, required this.arabic, required this.player});

  final bool arabic;
  final DemoPlayerState player;

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Monthly Pass',
      arabic: arabic,
      child: AppBody(children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFFFD55C), Color(0xFFFFA94D)]), borderRadius: BorderRadius.circular(24)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 44), const Spacer(), Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(999)), child: const Text(r'$10 / MONTH', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)))]),
            const SizedBox(height: 12),
            Text(arabic ? 'مرونة أكبر بدون قوة إضافية' : 'More flexibility, not more power', style: const TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(arabic ? 'المشترك لا يحصل على نقاط أو بطاقات أقوى. يحصل فقط على خيارات وDecks أكثر.' : 'Subscribers do not get stronger cards or extra score. They only get more choices and deck slots.', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ]),
        ),
        const SizedBox(height: 14),
        AppPanel(child: Column(children: [
          FeatureRow(Icons.layers_rounded, arabic ? '5 Decks بدل 2' : '5 decks instead of 2'),
          const Divider(height: 22),
          FeatureRow(Icons.add_circle_outline_rounded, arabic ? '4 خيارات بدل 3' : '4 choices instead of 3'),
          const Divider(height: 22),
          FeatureRow(Icons.edit_rounded, arabic ? 'تعديل 3 خيارات خاطئة بدل خيارين' : 'Edit 3 wrong choices instead of 2'),
        ])),
        const SizedBox(height: 12),
        Text(player.weeklyPass ? (arabic ? 'اشتراكك نشط.' : 'Your subscription is active.') : (arabic ? 'ربط الدفع الفعلي سيتم في مرحلة المتجر.' : 'Real purchase wiring stays for the store phase.'), style: const TextStyle(color: muted, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}
