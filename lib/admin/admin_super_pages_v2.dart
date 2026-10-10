
import 'package:flutter/material.dart';

import 'admin_api_v2.dart';

class AdminPlayersPageV2 extends StatefulWidget {
  const AdminPlayersPageV2({super.key, required this.arabic});
  final bool arabic;

  @override
  State<AdminPlayersPageV2> createState() => _AdminPlayersPageV2State();
}

class _AdminPlayersPageV2State extends State<AdminPlayersPageV2> {
  final _api = AdminApiV2();
  bool _loading = true;
  String? _error;
  List<AdminPlayerRowV2> _players = const [];

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
      final rows = await _api.loadPlayers();
      if (!mounted) return;
      setState(() => _players = rows);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit(AdminPlayerRowV2 player) async {
    final points = TextEditingController(text: '${player.weeklyPoints}');
    final weeklySteals = TextEditingController(text: '${player.weeklySteals}');
    final totalSteals = TextEditingController(text: '${player.totalSteals}');
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.arabic ? 'دعم اللاعب' : 'Player support'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(player.displayName),
            const SizedBox(height: 12),
            TextField(
              controller: points,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: widget.arabic ? 'نقاط الأسبوع' : 'Weekly points',
              ),
            ),
            TextField(
              controller: weeklySteals,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: widget.arabic ? 'سرقات الأسبوع' : 'Weekly steals',
              ),
            ),
            TextField(
              controller: totalSteals,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: widget.arabic ? 'إجمالي السرقات' : 'Total steals',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(widget.arabic ? 'إلغاء' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(widget.arabic ? 'حفظ' : 'Save'),
          ),
        ],
      ),
    );
    if (save != true) return;

    await _api.updatePlayerStats(
      uid: player.uid,
      weeklyPoints: int.tryParse(points.text),
      weeklySteals: int.tryParse(weeklySteals.text),
      totalSteals: int.tryParse(totalSteals.text),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: widget.arabic ? TextDirection.rtl : TextDirection.ltr,
        child: Scaffold(
          appBar: AppBar(
            title: Text(widget.arabic ? 'اللاعبون' : 'Players'),
            actions: [
              IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
            ],
          ),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text(_error!))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _players.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, index) {
                        final p = _players[index];
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              child: Text(
                                p.displayName.isEmpty
                                    ? '?'
                                    : p.displayName.characters.first,
                              ),
                            ),
                            title: Text(p.displayName),
                            subtitle: Text(
                              [
                                if (p.email != null) p.email!,
                                '${p.weeklyPoints} pts',
                                '${p.weeklySteals} steals',
                                '${p.ownedCount} cards',
                                if (p.subscriptionActive) 'SUB',
                                if (p.activeDuelV2 != null) 'DUEL',
                              ].join(' • '),
                            ),
                            trailing: IconButton(
                              onPressed: () => _edit(p),
                              icon: const Icon(Icons.manage_accounts_rounded),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      );
}

class AdminDuelsPageV2 extends StatefulWidget {
  const AdminDuelsPageV2({super.key, required this.arabic});
  final bool arabic;

  @override
  State<AdminDuelsPageV2> createState() => _AdminDuelsPageV2State();
}

class _AdminDuelsPageV2State extends State<AdminDuelsPageV2> {
  final _api = AdminApiV2();
  bool _loading = true;
  String? _error;
  List<AdminDuelRowV2> _duels = const [];

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
      final rows = await _api.loadDuels();
      if (!mounted) return;
      setState(() => _duels = rows);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _cancel(AdminDuelRowV2 duel) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.arabic ? 'إلغاء المواجهة؟' : 'Cancel duel?'),
        content: Text(
          widget.arabic
              ? 'سيتم تحرير اللاعبين من المواجهة وحذف حالة الانتظار. لا يمكن إلغاء مواجهة منتهية.'
              : 'Players will be released from this duel and queue state will be cleared. Finished duels cannot be cancelled.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(widget.arabic ? 'رجوع' : 'Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(widget.arabic ? 'إلغاء المواجهة' : 'Cancel duel'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _api.cancelDuel(duel.duelId);
    await _load();
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: widget.arabic ? TextDirection.rtl : TextDirection.ltr,
        child: Scaffold(
          appBar: AppBar(
            title: Text(widget.arabic ? 'المواجهات' : 'Duels'),
            actions: [
              IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
            ],
          ),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text(_error!))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _duels.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, index) {
                        final duel = _duels[index];
                        final cancellable = duel.status != 'finished' &&
                            duel.status != 'cancelled_by_admin';
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.sports_esports_rounded),
                            title: Text(duel.duelId),
                            subtitle: Text(
                              [
                                duel.status,
                                'P1 ${duel.p1Uid ?? '-'}',
                                'P2 ${duel.p2Uid ?? '-'}',
                                if (duel.winnerUid != null)
                                  'WIN ${duel.winnerUid}',
                                if (duel.stolenPackId != null)
                                  'STEAL ${duel.stolenPackId}',
                              ].join(' • '),
                            ),
                            trailing: cancellable
                                ? IconButton(
                                    onPressed: () => _cancel(duel),
                                    icon: const Icon(
                                      Icons.cancel_rounded,
                                      color: Colors.redAccent,
                                    ),
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
        ),
      );
}

class AdminRankingPageV2 extends StatefulWidget {
  const AdminRankingPageV2({super.key, required this.arabic});
  final bool arabic;

  @override
  State<AdminRankingPageV2> createState() => _AdminRankingPageV2State();
}

class _AdminRankingPageV2State extends State<AdminRankingPageV2> {
  final _api = AdminApiV2();
  bool _loading = true;
  String? _error;
  List<AdminRankingRowV2> _rows = const [];

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
      final rows = await _api.loadRanking();
      if (!mounted) return;
      setState(() => _rows = rows);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: widget.arabic ? TextDirection.rtl : TextDirection.ltr,
        child: Scaffold(
          appBar: AppBar(
            title: Text(widget.arabic ? 'الترتيب والسمعة' : 'Ranking & reputation'),
            actions: [
              IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
            ],
          ),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text(_error!))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _rows.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, index) {
                        final row = _rows[index];
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              child: Text('#${row.rank}'),
                            ),
                            title: Text(row.displayName),
                            subtitle: Text(
                              [
                                '${row.weeklyPoints} pts',
                                '${row.weeklySteals} steals',
                                '${row.weeklyWins}W',
                                '${row.weeklyLosses}L',
                                '${row.weeklyDraws}D',
                              ].join(' • '),
                            ),
                            trailing: Text(
                              row.uid,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 9,
                                color: Colors.black45,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      );
}

class AdminSubscriptionsPageV2 extends StatefulWidget {
  const AdminSubscriptionsPageV2({super.key, required this.arabic});
  final bool arabic;

  @override
  State<AdminSubscriptionsPageV2> createState() =>
      _AdminSubscriptionsPageV2State();
}

class _AdminSubscriptionsPageV2State extends State<AdminSubscriptionsPageV2> {
  final _api = AdminApiV2();
  bool _loading = true;
  String? _error;
  List<AdminSubscriptionRowV2> _rows = const [];

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
      final rows = await _api.loadSubscriptions();
      if (!mounted) return;
      setState(() => _rows = rows);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: widget.arabic ? TextDirection.rtl : TextDirection.ltr,
        child: Scaffold(
          appBar: AppBar(
            title: Text(widget.arabic ? 'الاشتراكات' : 'Subscriptions'),
            actions: [
              IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
            ],
          ),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text(_error!))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _rows.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, index) {
                        final item = _rows[index];
                        return Card(
                          child: ListTile(
                            leading: Icon(
                              item.active
                                  ? Icons.verified_rounded
                                  : Icons.history_rounded,
                              color: item.active ? Colors.green : Colors.grey,
                            ),
                            title: Text(item.uid),
                            subtitle: Text(
                              [
                                item.productId ?? '-',
                                item.source ?? '-',
                                if (item.expiresAt != null)
                                  item.expiresAt!.toLocal().toString(),
                              ].join(' • '),
                            ),
                            trailing: Text(
                              item.active ? 'ACTIVE' : 'OFF',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: item.active ? Colors.green : Colors.grey,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      );
}

class AdminAuditPageV2 extends StatefulWidget {
  const AdminAuditPageV2({super.key, required this.arabic});
  final bool arabic;

  @override
  State<AdminAuditPageV2> createState() => _AdminAuditPageV2State();
}

class _AdminAuditPageV2State extends State<AdminAuditPageV2> {
  final _api = AdminApiV2();
  bool _loading = true;
  String? _error;
  List<AdminAuditRowV2> _rows = const [];

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
      final rows = await _api.loadAudit();
      if (!mounted) return;
      setState(() => _rows = rows);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: widget.arabic ? TextDirection.rtl : TextDirection.ltr,
        child: Scaffold(
          appBar: AppBar(
            title: Text(widget.arabic ? 'سجل الإدارة' : 'Admin audit'),
            actions: [
              IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
            ],
          ),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text(_error!))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _rows.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, index) {
                        final item = _rows[index];
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.fact_check_rounded),
                            title: Text(item.action ?? '-'),
                            subtitle: Text(
                              [
                                item.actorEmail ?? '-',
                                item.target ?? '-',
                                if (item.createdAt != null)
                                  item.createdAt!.toLocal().toString(),
                              ].join(' • '),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      );
}
