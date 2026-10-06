import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'backend/bot_api_v2.dart';
import 'backend/firebase_bootstrap.dart';
import 'backend/firebase_game_api_v2.dart';
import 'backend/google_auth_v2.dart';
import 'backend/online_runtime_v2.dart';
import 'backend/profile_features_api_v2.dart';
import 'data/player_profile_store_v2.dart';
import 'game/core_engine_v2.dart';
import 'game/online_player_session_v2.dart';
import 'game/player_profile_v2.dart';
import 'services/purchase_service.dart';

const _blue = Color(0xFF3559F5);
const _purple = Color(0xFF7B3FF2);
const _violet = Color(0xFF5E2BE0);
const _gold = Color(0xFFFFC83D);
const _coral = Color(0xFFFF6464);
const _mint = Color(0xFF45D6A8);
const _ink = Color(0xFF221B3B);
const _muted = Color(0xFF7B7691);
const _page = Color(0xFFF8F6FF);
const _cardSurface = Color(0xFFFFFFFF);
const _softPurple = Color(0xFFF0EBFF);

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
  bool _backendAvailable = false;
  bool _requiresGoogleSignIn = false;
  String? _notice;
  final MonthlySubscriptionPurchaseServiceV2 _purchaseService =
      MonthlySubscriptionPurchaseServiceV2();
  String? _subscriptionPrice;
  bool _storeReady = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final store = SharedPreferencesPlayerProfileStoreV2();
    try {
      final ready = await OnlineRuntimeV2.ensureReady();
      if (!ready) {
        final cached = await store.load();
        if (!mounted) return;
        setState(() {
          _profile = cached;
          _backendAvailable = false;
          _requiresGoogleSignIn = false;
          _loadError = null;
          _notice = _arabic
              ? 'تعذر تهيئة Firebase على هذا الجهاز.'
              : 'Firebase could not be initialized on this device.';
        });
        return;
      }

      if (FirebaseAuth.instance.currentUser == null) {
        if (!mounted) return;
        setState(() {
          _profile = null;
          _session = null;
          _backendAvailable = false;
          _requiresGoogleSignIn = true;
          _loadError = null;
          _notice = null;
        });
        return;
      }

      final session = OnlinePlayerSessionV2(
        store: store,
        api: FirebaseGameApiV2(),
        botApi: BotApiV2(),
      );
      final profile = await session.initialize();
      final online = session.remoteConnected;
      if (!mounted) return;
      setState(() {
        _session = session;
        _profile = profile;
        _backendAvailable = online;
        _requiresGoogleSignIn = false;
        _loadError = null;
        if (!online) {
          _notice = _arabic
              ? 'تم تسجيل الدخول، لكن الاتصال بخدمات اللعبة غير متاح حاليًا.'
              : 'Signed in, but game services are currently unavailable.';
        }
      });

      if (online) {
        await _refreshRemote();
        await _configurePurchases();
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadError = error);
    }
  }

  Future<void> _signInWithGoogle() => _run(() async {
        final credential = await GoogleAuthV2.instance.signIn();
        if (credential.user == null) {
          throw StateError('GOOGLE_SIGN_IN_FAILED');
        }
        await _load();
      });

  Future<void> _signOutGoogle() => _run(() async {
        await GoogleAuthV2.instance.signOut();
        if (!mounted) return;
        setState(() {
          _session = null;
          _profile = null;
          _ranking = null;
          _subscription = null;
          _botStatus = null;
          _matchmaking = null;
          _backendAvailable = false;
          _requiresGoogleSignIn = true;
          _notice = null;
          _tab = 0;
        });
      });

  Future<void> _configurePurchases() async {
    final session = _session;
    if (session == null || !_backendAvailable) return;

    _purchaseService.listen(
      onVerifiedByServer: (payload) async {
        final verified = await session.verifySubscriptionPurchase(
          productId: payload.productId,
          source: payload.source,
          serverVerificationData: payload.serverVerificationData,
          purchaseId: payload.purchaseId,
        );
        if (!verified) return false;

        final status = await session.refreshSubscription();
        if (mounted) {
          setState(() {
            _subscription = status;
            _profile = session.profile;
            _notice = _arabic
                ? 'تم التحقق من الاشتراك وتفعيله من السيرفر.'
                : 'Subscription verified and activated by the server.';
          });
        }
        return true;
      },
    );

    final product = await _purchaseService.loadProduct();
    if (!mounted) return;
    setState(() {
      _storeReady = product != null;
      _subscriptionPrice = product?.price;
    });
  }

  Future<void> _buySubscription() => _run(() async {
        final started = await _purchaseService.buy();
        if (!mounted) return;
        if (!started) {
          setState(() {
            _notice = _arabic
                ? 'تعذر بدء الشراء. تأكد من إعداد المنتج في المتجر.'
                : 'Could not start purchase. Check the store product configuration.';
          });
        }
      });

  Future<void> _restoreSubscription() => _run(() async {
        final started = await _purchaseService.restorePurchases();
        if (!mounted) return;
        if (!started) {
          setState(() {
            _notice = _arabic
                ? 'تعذر استعادة المشتريات على هذا الجهاز.'
                : 'Purchases could not be restored on this device.';
          });
        }
      });

  Future<void> _refreshRemote() async {
    final session = _session;
    if (session == null || !_backendAvailable) return;
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
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      await action();
    } catch (error) {
      if (!mounted) return;
      setState(() => _notice = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _friendlyError(Object error) {
    final value = error.toString();
    if (value.contains('Question content has not been loaded') ||
        value.contains('CONTENT_NOT_AVAILABLE')) {
      return _arabic
          ? 'المسار جاهز، لكنه ينتظر البطاقات والأسئلة التي سنضيفها في آخر مرحلة.'
          : 'This flow is ready and only waits for cards/questions in the final content phase.';
    }
    if (value.contains('unauthenticated')) {
      return _arabic
          ? 'جلسة Firebase غير صالحة. أعد فتح التطبيق.'
          : 'Firebase session is invalid. Reopen the app.';
    }
    return _arabic
        ? 'تعذر تنفيذ العملية الآن.'
        : 'The operation could not be completed.';
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

  Future<void> _saveDeck(int index, List<String> packIds) => _run(() async {
        final profile = await _session!.saveDeck(index, packIds);
        if (!mounted) return;
        setState(() => _profile = profile);
      });

  Future<void> _editDeck(int index) async {
    final profile = _profile;
    if (profile == null) return;
    final owned = profile.ownedPackIds.toList()..sort();
    final selected = <String>{...profile.decks[index]};

    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * .68,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    (_arabic ? 'مجموعة ' : 'Deck ') +
                        '${index + 1} · ${selected.length}/$kDeckSizeV2',
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: owned.isEmpty
                        ? Center(
                            child: Text(
                              _arabic
                                  ? 'لا توجد بطاقات بعد. سنضيف المحتوى في آخر مرحلة.'
                                  : 'No cards yet. Content will be added last.',
                              textAlign: TextAlign.center,
                            ),
                          )
                        : ListView(
                            children: owned.map((id) {
                              final checked = selected.contains(id);
                              return CheckboxListTile(
                                value: checked,
                                title: Text(id),
                                onChanged: (value) {
                                  setSheetState(() {
                                    if (value == true &&
                                        selected.length < kDeckSizeV2) {
                                      selected.add(id);
                                    } else if (value != true) {
                                      selected.remove(id);
                                    }
                                  });
                                },
                              );
                            }).toList(growable: false),
                          ),
                  ),
                  FilledButton(
                    onPressed: selected.length == kDeckSizeV2
                        ? () => Navigator.pop(
                              context,
                              selected.toList(growable: false),
                            )
                        : null,
                    child: Text(_arabic ? 'حفظ المجموعة' : 'Save deck'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (result != null) await _saveDeck(index, result);
  }

  Future<void> _refreshSubscription() => _run(() async {
        final status = await _session!.refreshSubscription();
        if (!mounted) return;
        setState(() {
          _subscription = status;
          _profile = _session!.profile;
          _notice = status.active
              ? (_arabic
                  ? 'تم تأكيد الاشتراك من السيرفر.'
                  : 'Subscription verified by the server.')
              : (_arabic
                  ? 'لا يوجد اشتراك فعال موثق.'
                  : 'No verified active subscription.');
        });
      });

  Future<void> _startBotRound() => _run(() async {
        final session = _session!;
        final status = await session.botStatus();
        if (!mounted) return;
        setState(() => _botStatus = status);

        if (!status.botUnlocked) {
          setState(() => _notice = _arabic
              ? 'وصلت إلى 10 بطاقات. مسار البوت مغلق الآن.'
              : 'You reached 10 cards. Bot onboarding is locked.');
          return;
        }
        if (!status.contentAvailable) {
          setState(() => _notice = _arabic
              ? 'البوت جاهز بالكامل وينتظر المحتوى فقط.'
              : 'Bot onboarding is fully ready and only waits for content.');
          return;
        }

        final round = await session.startBotRound(arabic: _arabic);
        if (!mounted) return;
        final answer = await _answerDialog(
          title: _arabic ? 'سؤال البوت' : 'Bot question',
          prompt: round.prompt ?? '',
          choices: round.choices,
        );
        if (answer == null) return;

        final result = await session.submitBotAnswer(
          roundId: round.roundId,
          selectedIndex: answer,
        );
        if (!mounted) return;
        setState(() {
          _profile = result.profile;
          _notice = result.correct
              ? (result.awarded
                  ? (_arabic
                      ? 'إجابة صحيحة وتمت إضافة بطاقة جديدة.'
                      : 'Correct. A new card was awarded.')
                  : (_arabic ? 'إجابة صحيحة.' : 'Correct.'))
              : (_arabic ? 'إجابة غير صحيحة.' : 'Incorrect.');
        });
        await _refreshRemote();
      });

  Future<int?> _answerDialog({
    required String title,
    required String prompt,
    required List<String> choices,
  }) async {
    Timer? timer;
    var secondsLeft = kSecondsPerQuestionV2;

    final result = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          timer ??= Timer.periodic(const Duration(seconds: 1), (value) {
            if (!dialogContext.mounted) {
              value.cancel();
              return;
            }
            if (secondsLeft <= 1) {
              value.cancel();
              Navigator.of(dialogContext).pop(
                choices.isEmpty ? null : 0,
              );
              return;
            }
            setDialogState(() => secondsLeft -= 1);
          });

          return AlertDialog(
            title: Row(
              children: [
                Expanded(child: Text(title)),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: secondsLeft <= 5
                        ? const Color(0xFFFFE8E7)
                        : const Color(0xFFEAF0FF),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '${secondsLeft}s',
                    style: TextStyle(
                      color: secondsLeft <= 5 ? _coral : _blue,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LinearProgressIndicator(
                    value: secondsLeft / kSecondsPerQuestionV2,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    prompt,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...List.generate(
                    choices.length,
                    (index) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: FilledButton.tonal(
                        onPressed: () {
                          timer?.cancel();
                          Navigator.pop(context, index);
                        },
                        child: Text(choices[index]),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    timer?.cancel();
    return result;
  }

  Future<void> _startOrCheckMatchmaking() => _run(() async {
        final profile = _profile!;
        if (!profile.pvpUnlocked || !profile.activeDeckReady) {
          setState(() => _notice = _arabic
              ? 'تحتاج 10 بطاقات وDeck نشطة صالحة قبل PvP.'
              : 'You need 10 cards and a valid active deck before PvP.');
          return;
        }

        var status = _matchmaking;
        if (status == null || status.status == 'idle') {
          status = await _session!.startMatchmaking();
        } else if (status.searching) {
          status = await _session!.matchStatus();
        }
        if (!mounted) return;
        setState(() => _matchmaking = status);

        if (status.matched && status.duelId != null) {
          await _continueDuel(status.duelId!);
        } else {
          setState(() => _notice = _arabic
              ? 'جاري البحث عن خصم. اضغط مرة أخرى للتحقق.'
              : 'Searching for an opponent. Tap again to check.');
        }
      });

  Future<void> _cancelMatchmaking() => _run(() async {
        await _session!.cancelMatchmaking();
        if (!mounted) return;
        setState(() {
          _matchmaking =
              const MatchmakingStatusV2(status: 'idle', duelId: null);
          _notice = _arabic ? 'تم إلغاء البحث.' : 'Search cancelled.';
        });
      });

  Future<void> _continueDuel(String duelId) async {
    final session = _session!;
    var state = await session.prepareDuelQuestions(
      duelId: duelId,
      arabic: _arabic,
    );
    if (!mounted) return;

    if (!state.questionPlanReady) {
      setState(() => _notice = _arabic
          ? 'تم تجهيز أسئلتك وننتظر تجهيز الخصم.'
          : 'Your questions are ready. Waiting for the opponent.');
      return;
    }

    while (true) {
      final question = await session.startNextQuestion(duelId);
      if (question.complete) break;
      final publicQuestion =
          question.publicQuestion ?? const <String, dynamic>{};
      final choices = List<String>.from(
        publicQuestion['choices'] as List? ?? const <dynamic>[],
      );
      final answer = await _answerDialog(
        title: (_arabic ? 'السؤال ' : 'Question ') +
            '${question.questionIndex + 1}/$kDuelCardsV2',
        prompt: publicQuestion['prompt'] as String? ?? '',
        choices: choices,
      );
      if (answer == null) {
        setState(() => _notice = _arabic
            ? 'المباراة محفوظة ويمكن متابعتها لاحقًا.'
            : 'The duel is saved and can be resumed later.');
        return;
      }
      await session.submitAnswer(
        duelId: duelId,
        questionIndex: question.questionIndex,
        selectedIndex: answer,
      );
    }

    state = await session.finalizeDuel(duelId);
    if (!mounted) return;
    setState(() => _profile = session.profile);

    if (!state.finished) {
      setState(() => _notice = _arabic
          ? 'انتهت إجاباتك وننتظر الخصم.'
          : 'Your answers are complete. Waiting for the opponent.');
      return;
    }

    if (state.result == 'draw') {
      setState(() => _notice = _arabic
          ? 'تعادل. لا تتم سرقة أي بطاقة.'
          : 'Draw. No card is stolen.');
      await _refreshRemote();
      return;
    }

    if (state.winnerUid == FirebaseAuth.instance.currentUser?.uid) {
      await _chooseSteal(duelId);
    } else {
      setState(() => _notice = _arabic
          ? 'انتهت المباراة بفوز الخصم.'
          : 'The opponent won the duel.');
    }
    await _refreshRemote();
  }

  Future<void> _chooseSteal(String duelId) async {
    final options = await _session!.stealOptions(duelId);
    if (options.alreadyConfirmed || options.packIds.isEmpty) {
      setState(() => _notice = _arabic
          ? 'تم إنهاء نقل البطاقة.'
          : 'Card transfer is already settled.');
      return;
    }

    final selected = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(
          _arabic ? 'اختر بطاقة لسرقتها' : 'Choose a card to steal',
        ),
        content: SizedBox(
          width: 420,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.packIds
                .map(
                  (id) => ActionChip(
                    label: Text(id),
                    onPressed: () => Navigator.pop(context, id),
                  ),
                )
                .toList(growable: false),
          ),
        ),
      ),
    );
    if (selected == null) return;

    final result = await _session!.confirmSteal(
      duelId: duelId,
      packId: selected,
    );
    if (!mounted) return;
    setState(() {
      _profile = _session!.profile;
      _notice = (_arabic ? 'تمت سرقة البطاقة: ' : 'Stolen card: ') +
          (result.packId ?? selected);
    });
  }

  Future<void> _equipPrestige() => _run(() async {
        final profile = _profile!;
        String? title;
        String? frame;
        if (profile.prestige.first > 0) {
          title = 'champion_of_the_week';
          frame = 'weekly_gold_frame';
        } else if (profile.prestige.second > 0) {
          title = 'weekly_runner_up';
          frame = 'weekly_silver_frame';
        } else if (profile.prestige.third > 0) {
          title = 'weekly_third_place';
          frame = 'weekly_bronze_frame';
        } else {
          setState(() => _notice = _arabic
              ? 'لم تُفتح جائزة Prestige بعد.'
              : 'No prestige reward is unlocked yet.');
          return;
        }

        final next = await _session!.equipPrestige(
          titleKey: title,
          frameKey: frame,
        );
        if (!mounted) return;
        setState(() {
          _profile = next;
          _notice = _arabic
              ? 'تم تجهيز أفضل لقب وإطار متاحين.'
              : 'Best unlocked title and frame equipped.';
        });
      });

  @override
  void dispose() {
    _purchaseService.dispose();
    super.dispose();
  }

  Widget _googleSignInScreen() {
    return Directionality(
      textDirection: _arabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: _page,
        body: SafeArea(
          child: Stack(
            children: [
              Positioned(
                top: -90,
                right: -70,
                child: _GlowOrb(
                  size: 220,
                  color: _purple.withValues(alpha: .16),
                ),
              ),
              Positioned(
                bottom: 40,
                left: -80,
                child: _GlowOrb(
                  size: 190,
                  color: _blue.withValues(alpha: .12),
                ),
              ),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 28,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      children: [
                        const _CardFanMark(),
                        const SizedBox(height: 28),
                        Text(
                          'STEAL THE\nQUESTIONS',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: _ink,
                            fontSize: 31,
                            height: .98,
                            letterSpacing: .4,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _arabic
                              ? 'اجمع بطاقاتك، ابنِ مجموعتك، نافس واسرق بطاقة الفوز.'
                              : 'Collect cards, build your deck, compete, and steal the winning card.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: _muted,
                            height: 1.55,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 28),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: _cardSurface,
                            borderRadius: BorderRadius.circular(26),
                            boxShadow: [
                              BoxShadow(
                                color: _purple.withValues(alpha: .09),
                                blurRadius: 28,
                                offset: const Offset(0, 14),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  _MiniFeature(
                                    icon: Icons.style_rounded,
                                    label: _arabic ? 'اجمع' : 'Collect',
                                    color: _purple,
                                  ),
                                  _MiniFeature(
                                    icon: Icons.layers_rounded,
                                    label: _arabic ? 'كوّن' : 'Build',
                                    color: _blue,
                                  ),
                                  _MiniFeature(
                                    icon: Icons.flash_on_rounded,
                                    label: _arabic ? 'نافس' : 'Compete',
                                    color: _coral,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: FilledButton.icon(
                                  onPressed:
                                      _busy ? null : _signInWithGoogle,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: _ink,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                  ),
                                  icon: const Icon(Icons.login_rounded),
                                  label: Text(
                                    _arabic
                                        ? 'المتابعة باستخدام Google'
                                        : 'Continue with Google',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ),
                              if (_busy) ...[
                                const SizedBox(height: 14),
                                const LinearProgressIndicator(
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(99)),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextButton(
                          onPressed: () =>
                              setState(() => _arabic = !_arabic),
                          child: Text(
                            _arabic ? 'English' : 'العربية',
                            style: const TextStyle(
                              color: _purple,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
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

  @override
  Widget build(BuildContext context) {
    if (_requiresGoogleSignIn) {
      return _googleSignInScreen();
    }

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
        editDeck: _editDeck,
        setActiveDeck: _setActiveDeck,
      ),
      _PlayV2(
        arabic: _arabic,
        profile: profile,
        busy: _busy,
        botStatus: _botStatus,
        matchmaking: _matchmaking,
        startBot: _startBotRound,
        startOrCheckMatchmaking: _startOrCheckMatchmaking,
        cancelMatchmaking: _cancelMatchmaking,
      ),
      _ProfileV2(
        arabic: _arabic,
        profile: profile,
        ranking: _ranking,
        subscription: _subscription,
        busy: _busy,
        refresh: _refreshProfile,
        refreshSubscription: _refreshSubscription,
        buySubscription: _buySubscription,
        restoreSubscription: _restoreSubscription,
        storeReady: _storeReady,
        subscriptionPrice: _subscriptionPrice,
        equipPrestige: _equipPrestige,
        signOut: _signOutGoogle,
      ),
    ];

    return Directionality(
      textDirection: _arabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: _page,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _GameHeader(
                arabic: _arabic,
                ownedCount: profile.ownedCount,
                weeklyPoints: profile.weeklyPoints,
                onLanguage: () => setState(() => _arabic = !_arabic),
              ),
              if (_notice != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
                  child: _InlineNotice(
                    text: _notice!,
                    dismiss: () => setState(() => _notice = null),
                  ),
                ),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 18),
                  child: LinearProgressIndicator(
                    minHeight: 3,
                    borderRadius: BorderRadius.all(Radius.circular(99)),
                  ),
                ),
              Expanded(
                child: IgnorePointer(
                  ignoring: !_backendAvailable,
                  child: IndexedStack(index: _tab, children: screens),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: _GameBottomNav(
          arabic: _arabic,
          index: _tab,
          onSelected: (value) => setState(() => _tab = value),
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
    final ready = profile.pvpUnlocked && profile.activeDeckReady;

    return _Scroll(
      children: [
        _GameHeroCard(
          arabic: arabic,
          ready: ready,
          onPlay: () => openTab(3),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _QuickStatCard(
                icon: Icons.style_rounded,
                label: arabic ? 'بطاقاتي' : 'Cards',
                value: '${profile.ownedCount}',
                color: _purple,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _QuickStatCard(
                icon: Icons.layers_rounded,
                label: arabic ? 'الـDeck' : 'Deck',
                value: '${activeDeck.length}/$kDeckSizeV2',
                color: _blue,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _QuickStatCard(
                icon: Icons.emoji_events_rounded,
                label: arabic ? 'الأسبوع' : 'Weekly',
                value: '${profile.weeklyPoints}',
                color: _gold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        _SectionRow(
          title: arabic ? 'اختر طريقك' : 'Choose your path',
          action: arabic ? 'تحديث' : 'Refresh',
          onAction: refresh,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _ActionTile(
                icon: Icons.smart_toy_rounded,
                title: arabic ? 'تحدي البوت' : 'Bot challenge',
                subtitle: arabic
                    ? 'اجمع أول 10 بطاقات'
                    : 'Collect your first 10 cards',
                color: _mint,
                onTap: () => openTab(3),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionTile(
                icon: Icons.flash_on_rounded,
                title: 'PvP',
                subtitle: ready
                    ? (arabic ? 'جاهز للمواجهة' : 'Ready to duel')
                    : (arabic ? 'جهز Deck من 10' : 'Build a 10-card deck'),
                color: _coral,
                onTap: () => openTab(3),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        _SectionRow(
          title: arabic ? 'عالم البطاقات' : 'Card worlds',
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 102,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: kCategoriesV2.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final category = kCategoriesV2[index];
              return _CategoryTile(
                title: arabic ? category.nameAr : category.nameEn,
                color: Color(category.colorHex),
              );
            },
          ),
        ),
        const SizedBox(height: 18),
      ],
    );
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
    required this.editDeck,
    required this.setActiveDeck,
  });
  final bool arabic;
  final PlayerProfileV2 profile;
  final bool busy;
  final Future<void> Function(int index) editDeck;
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
                  tooltip: arabic ? 'تعديل المجموعة' : 'Edit deck',
                  onPressed: busy ? null : () => editDeck(index),
                  icon: const Icon(Icons.edit_outlined),
                ),
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
  const _PlayV2({
    required this.arabic,
    required this.profile,
    required this.busy,
    required this.botStatus,
    required this.matchmaking,
    required this.startBot,
    required this.startOrCheckMatchmaking,
    required this.cancelMatchmaking,
  });
  final bool arabic;
  final PlayerProfileV2 profile;
  final bool busy;
  final BotStatusV2? botStatus;
  final MatchmakingStatusV2? matchmaking;
  final VoidCallback startBot;
  final VoidCallback startOrCheckMatchmaking;
  final VoidCallback cancelMatchmaking;

  @override
  Widget build(BuildContext context) {
    final needsBot = profile.ownedCount < kDeckSizeV2;
    final searching = matchmaking?.searching == true;
    return _Scroll(children: [
      _Section(title: arabic ? 'اللعب' : 'Play'),
      const SizedBox(height: 10),
      _Panel(
        child: Column(children: [
          _Empty(
            icon: needsBot ? Icons.smart_toy_rounded : Icons.flash_on_rounded,
            title: needsBot ? (arabic ? 'مسار البوت' : 'Bot onboarding') : (arabic ? 'مسار PvP' : 'PvP path'),
            text: needsBot
                ? (arabic ? 'البوت مربوط الآن بالسيرفر وسيعمل فور إضافة المحتوى.' : 'Bot onboarding is now wired to the server and will run as soon as content is added.')
                : (profile.activeDeckReady
                    ? (arabic ? 'الـDeck جاهزة وMatchmaking مربوط بالسيرفر.' : 'The active deck is ready and matchmaking is wired to the server.')
                    : (arabic ? 'تحتاج Deck صالحة من 10 بطاقات مختلفة قبل PvP.' : 'A valid 10-card deck is required before PvP.')),
          ),
          const SizedBox(height: 12),
          if (needsBot)
            FilledButton.icon(
              onPressed: busy ? null : startBot,
              icon: const Icon(Icons.smart_toy_rounded),
              label: Text(arabic ? 'ابدأ جولة البوت' : 'Start bot round'),
            )
          else
            FilledButton.icon(
              onPressed: busy || !profile.activeDeckReady ? null : startOrCheckMatchmaking,
              icon: Icon(searching ? Icons.refresh_rounded : Icons.sports_esports_rounded),
              label: Text(searching
                  ? (arabic ? 'تحقق من الخصم' : 'Check opponent')
                  : (arabic ? 'ابدأ البحث' : 'Find opponent')),
            ),
          if (searching)
            TextButton(
              onPressed: busy ? null : cancelMatchmaking,
              child: Text(arabic ? 'إلغاء البحث' : 'Cancel search'),
            ),
          if (botStatus != null) ...[
            const SizedBox(height: 8),
            Text('${botStatus!.ownedCount}/${botStatus!.targetCount}', style: const TextStyle(color: _purple, fontWeight: FontWeight.w900)),
          ],
        ]),
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
  const _ProfileV2({
    required this.arabic,
    required this.profile,
    required this.ranking,
    required this.subscription,
    required this.busy,
    required this.refresh,
    required this.refreshSubscription,
    required this.buySubscription,
    required this.restoreSubscription,
    required this.storeReady,
    required this.subscriptionPrice,
    required this.equipPrestige,
    required this.signOut,
  });
  final bool arabic;
  final PlayerProfileV2 profile;
  final WeeklyRankingV2? ranking;
  final SubscriptionStatusV2? subscription;
  final bool busy;
  final VoidCallback refresh;
  final VoidCallback refreshSubscription;
  final VoidCallback buySubscription;
  final VoidCallback restoreSubscription;
  final bool storeReady;
  final String? subscriptionPrice;
  final VoidCallback equipPrestige;
  final VoidCallback signOut;

  @override
  Widget build(BuildContext context) {
    final total = profile.totalWins + profile.totalLosses + profile.totalDraws;
    final top = ranking?.players.take(10).toList(growable: false) ?? const <WeeklyRankingPlayerV2>[];
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
          _StatRow(label: arabic ? 'اللقب الحالي' : 'Current title', value: profile.currentTitleKey ?? '—'),
          _StatRow(label: arabic ? 'الإطار الحالي' : 'Current frame', value: profile.currentFrameKey ?? '—'),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              TextButton.icon(onPressed: busy ? null : refresh, icon: const Icon(Icons.refresh_rounded), label: Text(arabic ? 'تحديث الملف' : 'Refresh profile')),
              OutlinedButton(onPressed: busy ? null : equipPrestige, child: Text(arabic ? 'جهز أفضل Prestige' : 'Equip best prestige')),
              OutlinedButton(onPressed: busy ? null : signOut, child: Text(arabic ? 'تسجيل الخروج' : 'Sign out')),
            ],
          ),
        ]),
      ),
      const SizedBox(height: 12),
      _Section(title: arabic ? 'الاشتراك' : 'Subscription'),
      const SizedBox(height: 8),
      _Panel(
        child: Column(children: [
          _StatRow(label: arabic ? 'الحالة' : 'Status', value: subscription?.active == true ? (arabic ? 'فعال' : 'Active') : (arabic ? 'مجاني' : 'Free')),
          _StatRow(label: arabic ? 'Decks المتاحة' : 'Deck slots', value: '${subscription?.deckSlots ?? profile.entitlement.deckSlots}'),
          _StatRow(label: arabic ? 'خيارات الإجابة' : 'Answer choices', value: '${subscription?.answerChoices ?? profile.entitlement.answerChoices}'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              FilledButton(
                onPressed: busy || !storeReady ? null : buySubscription,
                child: Text(
                  subscriptionPrice == null
                      ? (arabic ? 'اشترك شهريًا' : 'Subscribe monthly')
                      : '${arabic ? 'اشترك' : 'Subscribe'} · $subscriptionPrice',
                ),
              ),
              OutlinedButton(
                onPressed: busy || !storeReady ? null : restoreSubscription,
                child: Text(arabic ? 'استعادة الشراء' : 'Restore purchase'),
              ),
              FilledButton.tonal(
                onPressed: busy ? null : refreshSubscription,
                child: Text(arabic ? 'تحقق من الاشتراك عبر السيرفر' : 'Verify subscription'),
              ),
            ],
          ),
        ]),
      ),
      const SizedBox(height: 12),
      _Section(title: arabic ? 'الترتيب الأسبوعي' : 'Weekly ranking'),
      const SizedBox(height: 8),
      _Panel(
        child: top.isEmpty
            ? Text(arabic ? 'لا توجد نتائج بعد.' : 'No ranking results yet.', style: const TextStyle(color: _muted))
            : Column(children: top.map((p) => _StatRow(label: '#${p.rank} ${p.displayName}', value: '${p.weeklyPoints} · ${p.weeklyWins}W')).toList(growable: false)),
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
