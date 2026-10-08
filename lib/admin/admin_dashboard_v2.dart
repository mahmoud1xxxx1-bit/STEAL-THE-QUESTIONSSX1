import 'package:flutter/material.dart';

import '../game/core_engine_v2.dart';
import 'admin_content_v2.dart';

class AdminDashboardV2 extends StatefulWidget {
  const AdminDashboardV2({super.key, required this.arabic});

  final bool arabic;

  @override
  State<AdminDashboardV2> createState() => _AdminDashboardV2State();
}

class _AdminDashboardV2State extends State<AdminDashboardV2> {
  final _repo = AdminContentRepositoryV2();
  bool _loading = true;
  String? _error;
  List<AdminCardV2> _cards = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cards = await _repo.loadCards();
      if (!mounted) return;
      setState(() => _cards = cards);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openCardEditor([AdminCardV2? card]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AdminCardEditor(
        repo: _repo,
        card: card,
        arabic: widget.arabic,
      ),
    );
    if (saved == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final arabic = widget.arabic;
    return Directionality(
      textDirection: arabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F4FF),
        appBar: AppBar(
          title: Text(arabic ? 'إدارة المحتوى' : 'Content admin'),
          actions: [
            IconButton(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openCardEditor(),
          icon: const Icon(Icons.add_rounded),
          label: Text(arabic ? 'بطاقة جديدة' : 'New card'),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!))
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    children: [
                      _AdminHero(arabic: arabic, cards: _cards),
                      const SizedBox(height: 16),
                      ..._cards.map(
                        (card) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _AdminCardTile(
                            card: card,
                            arabic: arabic,
                            edit: () => _openCardEditor(card),
                            questions: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => AdminQuestionsPageV2(
                                  arabic: arabic,
                                  card: card,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}

class _AdminHero extends StatelessWidget {
  const _AdminHero({required this.arabic, required this.cards});

  final bool arabic;
  final List<AdminCardV2> cards;

  @override
  Widget build(BuildContext context) {
    int count(CardRarityV2 rarity) =>
        cards.where((item) => item.rarity == rarity).length;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4A2FCF), Color(0xFF315CF4)],
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            arabic ? 'لوحة إدارة البطاقات' : 'Card control center',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            arabic
                ? 'زد البطاقات والأسئلة مستقبلًا بدون تحديث التطبيق.'
                : 'Grow cards and questions later without an app update.',
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _CountChip(label: 'Epic', value: count(CardRarityV2.epic)),
              _CountChip(label: 'Gold', value: count(CardRarityV2.gold)),
              _CountChip(
                label: 'Legendary',
                value: count(CardRarityV2.legendary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .14),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          '$label  $value',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
}

class _AdminCardTile extends StatelessWidget {
  const _AdminCardTile({
    required this.card,
    required this.arabic,
    required this.edit,
    required this.questions,
  });

  final AdminCardV2 card;
  final bool arabic;
  final VoidCallback edit;
  final VoidCallback questions;

  List<Color> get gradient => switch (card.rarity) {
        CardRarityV2.epic => const [
            Color(0xFF7B3FF2),
            Color(0xFF4D2AB6),
          ],
        CardRarityV2.gold => const [
            Color(0xFFFFD75A),
            Color(0xFFD99A17),
          ],
        CardRarityV2.legendary => const [
            Color(0xFF17102F),
            Color(0xFFFF6A3D),
          ],
      };

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: questions,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: gradient),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: gradient.last.withValues(alpha: .24),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(color: Colors.white54),
                ),
                child: const Icon(
                  Icons.style_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      arabic ? card.titleAr : card.titleEn,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${card.rarity.nameEn} • ${card.questionCount} Q • ${card.availableCopies} copies',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: edit,
                icon: const Icon(Icons.edit_rounded, color: Colors.white),
              ),
            ],
          ),
        ),
      );
}

class _AdminCardEditor extends StatefulWidget {
  const _AdminCardEditor({
    required this.repo,
    required this.card,
    required this.arabic,
  });

  final AdminContentRepositoryV2 repo;
  final AdminCardV2? card;
  final bool arabic;

  @override
  State<_AdminCardEditor> createState() => _AdminCardEditorState();
}

class _AdminCardEditorState extends State<_AdminCardEditor> {
  late final TextEditingController _id;
  late final TextEditingController _ar;
  late final TextEditingController _en;
  late final TextEditingController _copies;
  late GameCategoryId _category;
  late CardRarityV2 _rarity;
  late bool _enabled;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final card = widget.card;
    _id = TextEditingController(text: card?.id ?? '');
    _ar = TextEditingController(text: card?.titleAr ?? '');
    _en = TextEditingController(text: card?.titleEn ?? '');
    _copies = TextEditingController(text: '${card?.availableCopies ?? 0}');
    _category = card?.category ?? GameCategoryId.football;
    _rarity = card?.rarity ?? CardRarityV2.epic;
    _enabled = card?.enabled ?? true;
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
              color: Color(0xFFF8F6FF),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Text(
                    widget.arabic ? 'إعداد البطاقة' : 'Card setup',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _id,
                    enabled: widget.card == null,
                    decoration: const InputDecoration(labelText: 'Card ID'),
                  ),
                  TextField(
                    controller: _ar,
                    decoration: const InputDecoration(labelText: 'الاسم العربي'),
                  ),
                  TextField(
                    controller: _en,
                    decoration: const InputDecoration(labelText: 'English title'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<GameCategoryId>(
                    initialValue: _category,
                    items: GameCategoryId.values
                        .map(
                          (item) => DropdownMenuItem(
                            value: item,
                            child: Text(item.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _category = value ?? _category),
                    decoration: const InputDecoration(labelText: 'Category'),
                  ),
                  DropdownButtonFormField<CardRarityV2>(
                    initialValue: _rarity,
                    items: CardRarityV2.values
                        .map(
                          (item) => DropdownMenuItem(
                            value: item,
                            child: Text(
                              '${item.nameEn} — ${item.difficultyAr}',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _rarity = value ?? _rarity),
                    decoration: const InputDecoration(labelText: 'Rarity'),
                  ),
                  TextField(
                    controller: _copies,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Available copies'),
                  ),
                  SwitchListTile(
                    value: _enabled,
                    onChanged: (value) =>
                        setState(() => _enabled = value),
                    title: Text(
                      widget.arabic ? 'البطاقة مفعلة' : 'Card enabled',
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _saving
                        ? null
                        : () async {
                            setState(() => _saving = true);
                            try {
                              await widget.repo.upsertCard(
                                id: _id.text,
                                category: _category,
                                titleAr: _ar.text,
                                titleEn: _en.text,
                                rarity: _rarity,
                                availableCopies:
                                    int.tryParse(_copies.text) ?? 0,
                                enabled: _enabled,
                              );
                              if (context.mounted) Navigator.pop(context, true);
                            } finally {
                              if (mounted) {
                                setState(() => _saving = false);
                              }
                            }
                          },
                    icon: const Icon(Icons.save_rounded),
                    label: Text(
                      widget.arabic ? 'حفظ البطاقة' : 'Save card',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class AdminQuestionsPageV2 extends StatefulWidget {
  const AdminQuestionsPageV2({
    super.key,
    required this.arabic,
    required this.card,
  });

  final bool arabic;
  final AdminCardV2 card;

  @override
  State<AdminQuestionsPageV2> createState() => _AdminQuestionsPageV2State();
}

class _AdminQuestionsPageV2State extends State<AdminQuestionsPageV2> {
  final _repo = AdminContentRepositoryV2();
  List<AdminQuestionV2> _questions = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await _repo.loadQuestions(widget.card.id);
    if (!mounted) return;
    setState(() {
      _questions = items;
      _loading = false;
    });
  }

  Future<void> _newQuestion() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _QuestionEditor(
        arabic: widget.arabic,
        repo: _repo,
        cardId: widget.card.id,
      ),
    );
    if (saved == true) await _load();
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection:
            widget.arabic ? TextDirection.rtl : TextDirection.ltr,
        child: Scaffold(
          appBar: AppBar(
            title: Text(
              widget.arabic ? widget.card.titleAr : widget.card.titleEn,
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _newQuestion,
            icon: const Icon(Icons.add_rounded),
            label: Text(
              widget.arabic ? 'إضافة سؤال' : 'Add question',
            ),
          ),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  itemCount: _questions.length,
                  itemBuilder: (_, index) {
                    final question = _questions[index];
                    return Card(
                      child: ListTile(
                        title: Text(
                          widget.arabic
                              ? question.questionAr
                              : question.questionEn,
                        ),
                        subtitle: Text(
                          '${question.id} • ${question.enabled ? 'ACTIVE' : 'OFF'}',
                        ),
                        trailing: Switch(
                          value: question.enabled,
                          onChanged: (value) async {
                            await _repo.setQuestionEnabled(
                              cardId: widget.card.id,
                              questionId: question.id,
                              enabled: value,
                            );
                            await _load();
                          },
                        ),
                      ),
                    );
                  },
                ),
        ),
      );
}

class _QuestionEditor extends StatefulWidget {
  const _QuestionEditor({
    required this.arabic,
    required this.repo,
    required this.cardId,
  });

  final bool arabic;
  final AdminContentRepositoryV2 repo;
  final String cardId;

  @override
  State<_QuestionEditor> createState() => _QuestionEditorState();
}

class _QuestionEditorState extends State<_QuestionEditor> {
  final _id = TextEditingController();
  final _qar = TextEditingController();
  final _qen = TextEditingController();
  final _car = TextEditingController();
  final _cen = TextEditingController();
  final _war = TextEditingController();
  final _wen = TextEditingController();
  bool _saving = false;

  List<String> _split(TextEditingController controller) =>
      controller.text
          .split('|')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
              color: Color(0xFFF8F6FF),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Text(
                    widget.arabic
                        ? 'إضافة سؤال للبطاقة'
                        : 'Add card question',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _id,
                    decoration:
                        const InputDecoration(labelText: 'Question ID'),
                  ),
                  TextField(
                    controller: _qar,
                    decoration:
                        const InputDecoration(labelText: 'السؤال العربي'),
                  ),
                  TextField(
                    controller: _qen,
                    decoration:
                        const InputDecoration(labelText: 'English question'),
                  ),
                  TextField(
                    controller: _car,
                    decoration: const InputDecoration(
                      labelText: 'الإجابة الصحيحة بالعربية',
                    ),
                  ),
                  TextField(
                    controller: _cen,
                    decoration: const InputDecoration(
                      labelText: 'Correct answer in English',
                    ),
                  ),
                  TextField(
                    controller: _war,
                    decoration: const InputDecoration(
                      labelText: 'الإجابات الخاطئة بالعربية — افصل بـ |',
                    ),
                  ),
                  TextField(
                    controller: _wen,
                    decoration: const InputDecoration(
                      labelText: 'Wrong answers in English — separate with |',
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: _saving
                        ? null
                        : () async {
                            setState(() => _saving = true);
                            try {
                              await widget.repo.upsertQuestion(
                                cardId: widget.cardId,
                                id: _id.text,
                                questionAr: _qar.text,
                                questionEn: _qen.text,
                                correctAr: _car.text,
                                correctEn: _cen.text,
                                wrongAnswersAr: _split(_war),
                                wrongAnswersEn: _split(_wen),
                                enabled: true,
                              );
                              if (context.mounted) Navigator.pop(context, true);
                            } finally {
                              if (mounted) {
                                setState(() => _saving = false);
                              }
                            }
                          },
                    icon: const Icon(Icons.auto_awesome_rounded),
                    label: Text(
                      widget.arabic ? 'حفظ السؤال' : 'Save question',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
