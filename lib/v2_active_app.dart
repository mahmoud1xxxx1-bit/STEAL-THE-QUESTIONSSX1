import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'backend/bot_api_v2.dart';
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
                    '${_arabic ? 'مجموعة' : 'Deck'} ${index + 1} · ${selected.length}/$kDeckSizeV2',
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
      barrierColor: _ink.withValues(alpha: .72),
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          timer ??= Timer.periodic(const Duration(seconds: 1), (value) {
            if (!dialogContext.mounted) {
              value.cancel();
              return;
            }
            if (secondsLeft <= 1) {
              value.cancel();
              Navigator.of(dialogContext).pop();
              return;
            }
            setDialogState(() => secondsLeft -= 1);
          });

          final danger = secondsLeft <= 5;
          return Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            backgroundColor: Colors.transparent,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: _page,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .18),
                      blurRadius: 30,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: _purple,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.help_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              color: _ink,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: danger
                                ? _coral.withValues(alpha: .13)
                                : _softPurple,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.timer_rounded,
                                size: 16,
                                color: danger ? _coral : _purple,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$secondsLeft',
                                style: TextStyle(
                                  color: danger ? _coral : _purple,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        minHeight: 7,
                        value: secondsLeft / kSecondsPerQuestionV2,
                        backgroundColor: _softPurple,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          danger ? _coral : _purple,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: _cardSurface,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: _softPurple),
                      ),
                      child: Text(
                        prompt,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 20,
                          height: 1.4,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...List.generate(
                      choices.length,
                      (index) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 54),
                          child: SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                            onPressed: () {
                              timer?.cancel();
                              Navigator.pop(context, index);
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _ink,
                              backgroundColor: _cardSurface,
                              side: BorderSide(
                                color: _purple.withValues(alpha: .18),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              alignment: AlignmentDirectional.centerStart,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 15,
                                vertical: 13,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 30,
                                  height: 30,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: _softPurple,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    String.fromCharCode(65 + index),
                                    style: const TextStyle(
                                      color: _purple,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 11),
                                Expanded(
                                  child: Text(
                                    choices[index],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
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
        title:
            '${_arabic ? 'السؤال' : 'Question'} ${question.questionIndex + 1}/$kDuelCardsV2',
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
    if (!mounted) return;
    if (options.alreadyConfirmed || options.packIds.isEmpty) {
      setState(() => _notice = _arabic
          ? 'تم إنهاء نقل البطاقة.'
          : 'Card transfer is already settled.');
      return;
    }

    final selected = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      barrierColor: _ink.withValues(alpha: .74),
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _page,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _StealVictoryMark(),
                const SizedBox(height: 14),
                Text(
                  _arabic ? 'اختر بطاقة لسرقتها' : 'Choose a card to steal',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _arabic
                      ? 'فزت بالمواجهة. اختر بطاقة واحدة من خيارات خصمك.'
                      : 'You won the duel. Pick one card from your opponent.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _muted,
                    height: 1.4,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 18),
                Flexible(
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.center,
                      children: options.packIds
                          .map(
                            (id) => _StealOptionCard(
                              id: id,
                              onTap: () => Navigator.pop(context, id),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ),
                ),
              ],
            ),
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
                        const Text(
                          'STEAL THE\nQUESTIONS',
                          textAlign: TextAlign.center,
                          style: TextStyle(
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
        const SizedBox(height: 14),
        _JourneyStrip(arabic: arabic, ownedCount: profile.ownedCount),
        const SizedBox(height: 12),
        _PlayerMissionCard(
          arabic: arabic,
          ownedCount: profile.ownedCount,
          deckCount: activeDeck.length,
          ready: ready,
          onTap: () => openTab(ready ? 3 : (profile.ownedCount < kDeckSizeV2 ? 3 : 2)),
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
                category: category.id,
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
  Widget build(BuildContext context) {
    final owned = profile.ownedPackIds.toList()..sort();

    return _Scroll(
      children: [
        _CollectionHeader(
          arabic: arabic,
          ownedCount: profile.ownedCount,
          deckReady: profile.activeDeckReady,
        ),
        const SizedBox(height: 18),
        _SectionRow(
          title: arabic ? 'الفئات' : 'Categories',
          action: arabic ? '7 فئات' : '7 worlds',
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 92,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: kCategoriesV2.length,
            separatorBuilder: (_, __) => const SizedBox(width: 9),
            itemBuilder: (context, index) {
              final category = kCategoriesV2[index];
              return _CategoryPillCard(
                title: arabic ? category.nameAr : category.nameEn,
                color: Color(category.colorHex),
                category: category.id,
              );
            },
          ),
        ),
        const SizedBox(height: 22),
        _SectionRow(
          title: arabic ? 'مجموعتي' : 'My collection',
          action: '${profile.ownedCount}',
        ),
        const SizedBox(height: 10),
        if (owned.isEmpty)
          _EmptyCollectionCard(arabic: arabic)
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final width = (constraints.maxWidth - 12) / 2;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: List.generate(owned.length, (index) {
                  final color = Color(
                    kCategoriesV2[index % kCategoriesV2.length].colorHex,
                  );
                  return SizedBox(
                    width: width,
                    child: _OwnedCardTile(
                      id: owned[index],
                      color: color,
                      arabic: arabic,
                    ),
                  );
                }),
              );
            },
          ),
        const SizedBox(height: 18),
      ],
    );
  }
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
  Widget build(BuildContext context) {
    final activeDeck = profile.decks[profile.activeDeckIndex];

    return _Scroll(
      children: [
        _DeckBuilderHero(
          arabic: arabic,
          filled: activeDeck.length,
          ready: profile.activeDeckReady,
        ),
        const SizedBox(height: 18),
        _SectionRow(
          title: arabic ? 'مجموعاتك' : 'Your decks',
          action: '${profile.entitlement.deckSlots}',
        ),
        const SizedBox(height: 10),
        ...List.generate(profile.entitlement.deckSlots, (index) {
          final deck = profile.decks[index];
          final active = index == profile.activeDeckIndex;
          final valid = PlayerDeckV2(deck).isValid(profile.ownedPackIds);

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _DeckSlotCard(
              arabic: arabic,
              index: index,
              count: deck.length,
              active: active,
              valid: valid,
              busy: busy,
              onEdit: () => editDeck(index),
              onActivate: active || !valid
                  ? null
                  : () => setActiveDeck(index),
            ),
          );
        }),
        const SizedBox(height: 6),
        _DeckRuleStrip(arabic: arabic),
        const SizedBox(height: 18),
      ],
    );
  }
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

    return _Scroll(
      children: [
        _PlayHero(
          arabic: arabic,
          needsBot: needsBot,
          searching: searching,
        ),
        const SizedBox(height: 12),
        _DuelArenaStrip(
          arabic: arabic,
          unlocked: profile.activeDeckReady,
          searching: searching,
        ),
        const SizedBox(height: 18),
        _ModeCard(
          arabic: arabic,
          icon: Icons.smart_toy_rounded,
          title: arabic ? 'تحدي البوت' : 'Bot challenge',
          subtitle: arabic
              ? 'مرحلة البداية لجمع أول 10 بطاقات.'
              : 'Your path to the first 10 cards.',
          accent: _mint,
          badge: needsBot
              ? (arabic ? 'متاح' : 'AVAILABLE')
              : (arabic ? 'مكتمل' : 'COMPLETE'),
          enabled: needsBot && !busy,
          buttonText: arabic ? 'ابدأ جولة' : 'Start round',
          onTap: startBot,
        ),
        const SizedBox(height: 12),
        _ModeCard(
          arabic: arabic,
          icon: Icons.flash_on_rounded,
          title: arabic ? 'مواجهة PvP' : 'PvP duel',
          subtitle: profile.activeDeckReady
              ? (arabic
                  ? 'Deck جاهزة. واجه لاعبًا واسرق بطاقة عند الفوز.'
                  : 'Deck ready. Face a player and steal a card if you win.')
              : (arabic
                  ? 'جهّز Deck من 10 بطاقات مختلفة لفتح المواجهة.'
                  : 'Build a 10-card deck to unlock duels.'),
          accent: _coral,
          badge: searching
              ? (arabic ? 'جاري البحث' : 'SEARCHING')
              : profile.activeDeckReady
                  ? (arabic ? 'جاهز' : 'READY')
                  : (arabic ? 'مغلق' : 'LOCKED'),
          enabled: !busy && profile.activeDeckReady,
          buttonText: searching
              ? (arabic ? 'تحقق من الخصم' : 'Check opponent')
              : (arabic ? 'ابحث عن خصم' : 'Find opponent'),
          onTap: startOrCheckMatchmaking,
          secondaryText:
              searching ? (arabic ? 'إلغاء البحث' : 'Cancel search') : null,
          onSecondary: searching ? cancelMatchmaking : null,
        ),
        const SizedBox(height: 18),
        _BattleRulesCard(
          arabic: arabic,
          recentCount: profile.recentQuestionIds.length,
        ),
        if (botStatus != null) ...[
          const SizedBox(height: 12),
          _ProgressStrip(
            label: arabic ? 'تقدم البطاقات' : 'Card progress',
            value: botStatus!.ownedCount,
            total: botStatus!.targetCount,
          ),
        ],
        const SizedBox(height: 18),
      ],
    );
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
    final top = ranking?.players.take(10).toList(growable: false) ??
        const <WeeklyRankingPlayerV2>[];

    return _Scroll(
      children: [
        _ProfileHero(
          arabic: arabic,
          weeklyPoints: profile.weeklyPoints,
          wins: profile.totalWins,
          owned: profile.ownedCount,
          titleKey: profile.currentTitleKey,
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _QuickStatCard(
                icon: Icons.emoji_events_rounded,
                label: arabic ? 'فوز' : 'Wins',
                value: '${profile.totalWins}',
                color: _gold,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _QuickStatCard(
                icon: Icons.close_rounded,
                label: arabic ? 'خسارة' : 'Losses',
                value: '${profile.totalLosses}',
                color: _coral,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _QuickStatCard(
                icon: Icons.handshake_rounded,
                label: arabic ? 'تعادل' : 'Draws',
                value: '${profile.totalDraws}',
                color: _blue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _PrestigeCard(
          arabic: arabic,
          first: profile.prestige.first,
          second: profile.prestige.second,
          third: profile.prestige.third,
          titleKey: profile.currentTitleKey,
          frameKey: profile.currentFrameKey,
          onEquip: busy ? null : equipPrestige,
        ),
        const SizedBox(height: 18),
        _SectionRow(
          title: arabic ? 'الترتيب الأسبوعي' : 'Weekly ranking',
          action: ranking?.weekKey,
        ),
        const SizedBox(height: 10),
        _WeeklyPodium(arabic: arabic, players: top),
        const SizedBox(height: 10),
        _RankingCard(arabic: arabic, players: top),
        const SizedBox(height: 18),
        _SubscriptionCard(
          arabic: arabic,
          active: subscription?.active == true,
          deckSlots: subscription?.deckSlots ?? profile.entitlement.deckSlots,
          answerChoices:
              subscription?.answerChoices ?? profile.entitlement.answerChoices,
          price: subscriptionPrice,
          storeReady: storeReady,
          busy: busy,
          buy: buySubscription,
          restore: restoreSubscription,
          verify: refreshSubscription,
        ),
        const SizedBox(height: 14),
        _ProfileActionsCard(
          arabic: arabic,
          totalMatches: total,
          refresh: busy ? null : refresh,
          signOut: busy ? null : signOut,
        ),
        const SizedBox(height: 18),
      ],
    );
  }
}

class _PlayerMissionCard extends StatelessWidget {
  const _PlayerMissionCard({
    required this.arabic,
    required this.ownedCount,
    required this.deckCount,
    required this.ready,
    required this.onTap,
  });

  final bool arabic;
  final int ownedCount;
  final int deckCount;
  final bool ready;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final collecting = ownedCount < kDeckSizeV2;
    final building = !collecting && !ready;
    final accent = collecting ? _mint : building ? _blue : _coral;
    final icon = collecting
        ? Icons.style_rounded
        : building
            ? Icons.layers_rounded
            : Icons.flash_on_rounded;
    final title = collecting
        ? (arabic ? 'هدفك الآن: اجمع 10 بطاقات' : 'Next goal: collect 10 cards')
        : building
            ? (arabic ? 'هدفك الآن: أكمل Deck' : 'Next goal: finish your deck')
            : (arabic ? 'هدفك الآن: ادخل مواجهة' : 'Next goal: enter a duel');
    final progress = collecting ? ownedCount : building ? deckCount : kDeckSizeV2;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Ink(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: .09),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: accent.withValues(alpha: .2)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 7),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      minHeight: 7,
                      value: (progress / kDeckSizeV2).clamp(0.0, 1.0).toDouble(),
                      backgroundColor: Colors.white,
                      valueColor: AlwaysStoppedAnimation<Color>(accent),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, color: accent),
          ],
        ),
      ),
    );
  }
}

class _DuelArenaStrip extends StatelessWidget {
  const _DuelArenaStrip({
    required this.arabic,
    required this.unlocked,
    required this.searching,
  });

  final bool arabic;
  final bool unlocked;
  final bool searching;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _cardSurface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _softPurple),
        ),
        child: Row(
          children: [
            _ArenaPlayer(
              icon: Icons.person_rounded,
              label: arabic ? 'أنت' : 'YOU',
              color: _blue,
            ),
            const Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: _VersusMark(),
              ),
            ),
            _ArenaPlayer(
              icon: searching
                  ? Icons.radar_rounded
                  : unlocked
                      ? Icons.person_search_rounded
                      : Icons.lock_rounded,
              label: searching
                  ? (arabic ? 'نبحث...' : 'SEARCHING')
                  : unlocked
                      ? (arabic ? 'خصم' : 'RIVAL')
                      : (arabic ? 'مغلق' : 'LOCKED'),
              color: _coral,
            ),
          ],
        ),
      );
}

class _ArenaPlayer extends StatelessWidget {
  const _ArenaPlayer({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: .28), width: 2),
            ),
            child: Icon(icon, color: color, size: 25),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      );
}

class _VersusMark extends StatelessWidget {
  const _VersusMark();

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(child: Divider(color: _purple.withValues(alpha: .18))),
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: _ink,
              shape: BoxShape.circle,
            ),
            child: const Text(
              'VS',
              style: TextStyle(
                color: _gold,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Expanded(child: Divider(color: _purple.withValues(alpha: .18))),
        ],
      );
}

class _WeeklyPodium extends StatelessWidget {
  const _WeeklyPodium({
    required this.arabic,
    required this.players,
  });

  final bool arabic;
  final List<WeeklyRankingPlayerV2> players;

  @override
  Widget build(BuildContext context) {
    if (players.isEmpty) {
      return Container(
        height: 126,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF251C45), Color(0xFF4A2F90)],
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Center(
          child: Text(
            arabic ? 'المنصة تنتظر أول أبطال الأسبوع' : 'The weekly podium is waiting',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: .82),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      );
    }

    WeeklyRankingPlayerV2? atRank(int rank) {
      for (final player in players) {
        if (player.rank == rank) return player;
      }
      return null;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF251C45), Color(0xFF4A2F90)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: _PodiumPlayer(
              player: atRank(2),
              medal: '🥈',
              height: 76,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _PodiumPlayer(
              player: atRank(1),
              medal: '🥇',
              height: 98,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _PodiumPlayer(
              player: atRank(3),
              medal: '🥉',
              height: 66,
            ),
          ),
        ],
      ),
    );
  }
}

class _PodiumPlayer extends StatelessWidget {
  const _PodiumPlayer({
    required this.player,
    required this.medal,
    required this.height,
  });

  final WeeklyRankingPlayerV2? player;
  final String medal;
  final double height;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(medal, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 4),
          Text(
            player?.displayName ?? '—',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            player == null ? '—' : '${player!.weeklyPoints}',
            style: const TextStyle(
              color: _gold,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: height,
            width: double.infinity,
            alignment: Alignment.topCenter,
            padding: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .09),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
            ),
            child: const _StealLogoMark(size: 34),
          ),
        ],
      );
}

class _StealVictoryMark extends StatelessWidget {
  const _StealVictoryMark();

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 118,
        height: 104,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 98,
              height: 98,
              decoration: BoxDecoration(
                color: _gold.withValues(alpha: .16),
                shape: BoxShape.circle,
              ),
            ),
            const _StealLogoMark(size: 82, showGlow: true),
            PositionedDirectional(
              top: 1,
              end: 5,
              child: Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: _gold,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  color: _ink,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      );
}

class _StealOptionCard extends StatelessWidget {
  const _StealOptionCard({required this.id, required this.onTap});
  final String id;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          width: 112,
          height: 148,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_purple, _violet],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: _purple.withValues(alpha: .18),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _CardCornerMark(color: Colors.white),
                  Icon(Icons.auto_awesome_rounded,
                      color: Colors.white70, size: 16),
                ],
              ),
              const Spacer(),
              const _StealLogoMark(size: 46),
              const Spacer(),
              Text(
                id,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      );
}

class _PlayHero extends StatelessWidget {
  const _PlayHero({
    required this.arabic,
    required this.needsBot,
    required this.searching,
  });

  final bool arabic;
  final bool needsBot;
  final bool searching;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF241B46), Color(0xFF6C3BEA)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    searching
                        ? (arabic ? 'نبحث عن خصم...' : 'Finding opponent...')
                        : needsBot
                            ? (arabic ? 'ابدأ رحلتك' : 'Start your journey')
                            : (arabic ? 'وقت المواجهة' : 'Time to duel'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 23,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    needsBot
                        ? (arabic
                            ? 'اجمع بطاقاتك الأولى ثم افتح مواجهات اللاعبين.'
                            : 'Collect your first cards, then unlock player duels.')
                        : (arabic
                            ? '7 أسئلة. 20 ثانية لكل سؤال. والفائز يسرق بطاقة.'
                            : '7 questions. 20 seconds each. Winner steals a card.'),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .76),
                      height: 1.4,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Container(
              width: 70,
              height: 88,
              decoration: BoxDecoration(
                color: _coral,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white, width: 3),
              ),
              child: const Icon(Icons.flash_on_rounded,
                  color: Colors.white, size: 32),
            ),
          ],
        ),
      );
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.arabic,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.badge,
    required this.enabled,
    required this.buttonText,
    required this.onTap,
    this.secondaryText,
    this.onSecondary,
  });

  final bool arabic;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final String badge;
  final bool enabled;
  final String buttonText;
  final VoidCallback onTap;
  final String? secondaryText;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _cardSurface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: accent.withValues(alpha: .16)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: .13),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(icon, color: accent, size: 25),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: _muted,
                          height: 1.35,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                _GameStatusBadge(text: badge, color: accent),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: enabled ? onTap : null,
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                icon: Icon(icon, size: 18),
                label: Text(
                  buttonText,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
            if (secondaryText != null && onSecondary != null)
              TextButton(
                onPressed: onSecondary,
                child: Text(secondaryText!),
              ),
          ],
        ),
      );
}

class _BattleRulesCard extends StatelessWidget {
  const _BattleRulesCard({
    required this.arabic,
    required this.recentCount,
  });

  final bool arabic;
  final int recentCount;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: _softPurple,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          children: [
            _BattleRuleRow(
              icon: Icons.quiz_rounded,
              label: arabic ? 'أسئلة المواجهة' : 'Duel questions',
              value: '$kDuelCardsV2',
            ),
            _BattleRuleRow(
              icon: Icons.timer_rounded,
              label: arabic ? 'وقت كل سؤال' : 'Time per question',
              value: '$kSecondsPerQuestionV2 s',
            ),
            _BattleRuleRow(
              icon: Icons.history_rounded,
              label: arabic ? 'ذاكرة التكرار' : 'Repeat memory',
              value: '$recentCount/$kRecentQuestionLimitV2',
            ),
          ],
        ),
      );
}

class _BattleRuleRow extends StatelessWidget {
  const _BattleRuleRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Icon(icon, size: 19, color: _purple),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: _muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                color: _ink,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      );
}

class _ProgressStrip extends StatelessWidget {
  const _ProgressStrip({
    required this.label,
    required this.value,
    required this.total,
  });
  final String label;
  final int value;
  final int total;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _cardSurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _softPurple),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: _ink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  '$value/$total',
                  style: const TextStyle(
                    color: _purple,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                minHeight: 7,
                value: total == 0
                    ? 0
                    : (value / total).clamp(0.0, 1.0).toDouble(),
                backgroundColor: _softPurple,
                valueColor: const AlwaysStoppedAnimation<Color>(_purple),
              ),
            ),
          ],
        ),
      );
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.arabic,
    required this.weeklyPoints,
    required this.wins,
    required this.owned,
    required this.titleKey,
  });

  final bool arabic;
  final int weeklyPoints;
  final int wins;
  final int owned;
  final String? titleKey;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF241B46), Color(0xFF5B36C5), _blue],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: _purple.withValues(alpha: .18),
              blurRadius: 22,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Stack(
          children: [
            PositionedDirectional(
              top: -36,
              end: -22,
              child: Container(
                width: 126,
                height: 126,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: .06),
                ),
              ),
            ),
            Row(
              children: [
                _PlayerIdentityFrame(titleKey: titleKey),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        arabic ? 'هوية اللاعب' : 'Player identity',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _TitleRibbon(
                        text: titleKey ??
                            (arabic ? 'المنافس الجديد' : 'New challenger'),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          _DarkBadge(
                            icon: Icons.emoji_events_rounded,
                            text: '$weeklyPoints',
                          ),
                          _DarkBadge(
                            icon: Icons.bolt_rounded,
                            text: '$wins',
                          ),
                          _DarkBadge(
                            icon: Icons.style_rounded,
                            text: '$owned',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      );
}

class _PlayerIdentityFrame extends StatelessWidget {
  const _PlayerIdentityFrame({required this.titleKey});
  final String? titleKey;

  @override
  Widget build(BuildContext context) => Container(
        width: 82,
        height: 92,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_gold, Color(0xFFFFE79B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: _gold.withValues(alpha: .22),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.all(3),
        child: Container(
          decoration: BoxDecoration(
            color: _ink,
            borderRadius: BorderRadius.circular(21),
          ),
          child: const Center(
            child: _StealLogoMark(size: 58),
          ),
        ),
      );
}

class _TitleRibbon extends StatelessWidget {
  const _TitleRibbon({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: _gold.withValues(alpha: .16),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: _gold.withValues(alpha: .28)),
        ),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _gold,
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
}

class _PrestigeCard extends StatelessWidget {
  const _PrestigeCard({
    required this.arabic,
    required this.first,
    required this.second,
    required this.third,
    required this.titleKey,
    required this.frameKey,
    required this.onEquip,
  });

  final bool arabic;
  final int first;
  final int second;
  final int third;
  final String? titleKey;
  final String? frameKey;
  final VoidCallback? onEquip;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              _gold.withValues(alpha: .15),
              _cardSurface,
            ],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _gold.withValues(alpha: .28)),
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
                    color: _gold,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.workspace_premium_rounded,
                    color: _ink,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        arabic ? 'قاعة الـPrestige' : 'Prestige hall',
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        arabic
                            ? 'مراكزك تبني هوية دائمة لحسابك.'
                            : 'Your podium finishes build a permanent identity.',
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _PrestigeMedal(
                    medal: '🥇',
                    value: first,
                    label: arabic ? 'أول' : 'First',
                    tone: _gold,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _PrestigeMedal(
                    medal: '🥈',
                    value: second,
                    label: arabic ? 'ثاني' : 'Second',
                    tone: const Color(0xFFBFC7D6),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _PrestigeMedal(
                    medal: '🥉',
                    value: third,
                    label: arabic ? 'ثالث' : 'Third',
                    tone: const Color(0xFFC98A52),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _IdentityEquipRow(
              icon: Icons.workspace_premium_rounded,
              label: arabic ? 'اللقب الحالي' : 'Current title',
              value: titleKey ?? '—',
            ),
            _IdentityEquipRow(
              icon: Icons.crop_square_rounded,
              label: arabic ? 'الإطار الحالي' : 'Current frame',
              value: frameKey ?? '—',
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onEquip,
                style: FilledButton.styleFrom(
                  backgroundColor: _ink,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.auto_awesome_rounded),
                label: Text(
                  arabic ? 'جهز أفضل هوية Prestige' : 'Equip best prestige identity',
                ),
              ),
            ),
          ],
        ),
      );
}

class _PrestigeMedal extends StatelessWidget {
  const _PrestigeMedal({
    required this.medal,
    required this.value,
    required this.label,
    required this.tone,
  });

  final String medal;
  final int value;
  final String label;
  final Color tone;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: tone.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: tone.withValues(alpha: .20)),
        ),
        child: Column(
          children: [
            Text(medal, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 4),
            Text(
              '$value',
              style: const TextStyle(
                color: _ink,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                color: _muted,
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
}

class _IdentityEquipRow extends StatelessWidget {
  const _IdentityEquipRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Icon(icon, size: 18, color: _purple),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: _muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                color: _ink,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      );
}

class _RankingCard extends StatelessWidget {
  const _RankingCard({required this.arabic, required this.players});
  final bool arabic;
  final List<WeeklyRankingPlayerV2> players;

  @override
  Widget build(BuildContext context) {
    if (players.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _cardSurface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _softPurple),
        ),
        child: Text(
          arabic ? 'لا توجد نتائج أسبوعية بعد.' : 'No weekly results yet.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _muted,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _cardSurface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _softPurple),
      ),
      child: Column(
        children: players.map((p) {
          final medal = p.rank == 1
              ? '🥇'
              : p.rank == 2
                  ? '🥈'
                  : p.rank == 3
                      ? '🥉'
                      : '#${p.rank}';
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            margin: const EdgeInsets.only(bottom: 5),
            decoration: BoxDecoration(
              color: p.rank <= 3
                  ? _gold.withValues(alpha: .08)
                  : _page,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 36,
                  child: Text(
                    medal,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                Expanded(
                  child: Text(
                    p.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _ink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  '${p.weeklyPoints}',
                  style: const TextStyle(
                    color: _purple,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          );
        }).toList(growable: false),
      ),
    );
  }
}

class _SubscriptionCard extends StatelessWidget {
  const _SubscriptionCard({
    required this.arabic,
    required this.active,
    required this.deckSlots,
    required this.answerChoices,
    required this.price,
    required this.storeReady,
    required this.busy,
    required this.buy,
    required this.restore,
    required this.verify,
  });

  final bool arabic;
  final bool active;
  final int deckSlots;
  final int answerChoices;
  final String? price;
  final bool storeReady;
  final bool busy;
  final VoidCallback buy;
  final VoidCallback restore;
  final VoidCallback verify;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: active
                ? [const Color(0xFF20183C), const Color(0xFF5A3ACB)]
                : [const Color(0xFFF0EBFF), _cardSurface],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: active
                ? _gold.withValues(alpha: .45)
                : _purple.withValues(alpha: .14),
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: active ? _gold : _purple,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    active
                        ? Icons.workspace_premium_rounded
                        : Icons.star_rounded,
                    color: active ? _ink : Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        active
                            ? (arabic ? 'نادي المنافسين' : 'Challenger club')
                            : (arabic ? 'عضوية المنافسين' : 'Challenger membership'),
                        style: TextStyle(
                          color: active ? Colors.white : _ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        active
                            ? (arabic ? 'عضويتك فعالة' : 'Membership active')
                            : (arabic
                                ? 'خيارات أكثر لبناء مجموعتك.'
                                : 'More options to build your collection.'),
                        style: TextStyle(
                          color: active
                              ? Colors.white.withValues(alpha: .68)
                              : _muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                if (price != null)
                  _GameStatusBadge(
                    text: price!,
                    color: active ? _gold : _purple,
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _EntitlementMini(
                    icon: Icons.layers_rounded,
                    value: '$deckSlots',
                    label: arabic ? 'مجموعات' : 'Decks',
                    inverted: active,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _EntitlementMini(
                    icon: Icons.checklist_rounded,
                    value: '$answerChoices',
                    label: arabic ? 'خيارات' : 'Choices',
                    inverted: active,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (!active)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: busy || !storeReady ? null : buy,
                  icon: const Icon(Icons.star_rounded),
                  label: Text(arabic ? 'انضم للعضوية' : 'Join membership'),
                ),
              ),
            Wrap(
              spacing: 8,
              alignment: WrapAlignment.center,
              children: [
                TextButton(
                  onPressed: busy || !storeReady ? null : restore,
                  style: TextButton.styleFrom(
                    foregroundColor: active ? Colors.white70 : _purple,
                  ),
                  child: Text(arabic ? 'استعادة الشراء' : 'Restore'),
                ),
                TextButton(
                  onPressed: busy ? null : verify,
                  style: TextButton.styleFrom(
                    foregroundColor: active ? Colors.white70 : _purple,
                  ),
                  child: Text(arabic ? 'تحقق' : 'Verify'),
                ),
              ],
            ),
          ],
        ),
      );
}

class _EntitlementMini extends StatelessWidget {
  const _EntitlementMini({
    required this.icon,
    required this.value,
    required this.label,
    this.inverted = false,
  });
  final IconData icon;
  final String value;
  final String label;
  final bool inverted;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: inverted
              ? Colors.white.withValues(alpha: .10)
              : Colors.white.withValues(alpha: .72),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: inverted ? _gold : _purple, size: 20),
            const SizedBox(height: 5),
            Text(
              value,
              style: const TextStyle(
                color: inverted ? Colors.white : _ink,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                color: inverted ? Colors.white70 : _muted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
}

class _ProfileActionsCard extends StatelessWidget {
  const _ProfileActionsCard({
    required this.arabic,
    required this.totalMatches,
    required this.refresh,
    required this.signOut,
  });

  final bool arabic;
  final int totalMatches;
  final VoidCallback? refresh;
  final VoidCallback? signOut;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: _cardSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _softPurple),
        ),
        child: Column(
          children: [
            _StatRow(
              label: arabic ? 'إجمالي المباريات' : 'Total matches',
              value: '$totalMatches',
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: refresh,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(arabic ? 'تحديث' : 'Refresh'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: signOut,
                    icon: const Icon(Icons.logout_rounded),
                    label: Text(arabic ? 'خروج' : 'Sign out'),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
}

class _CollectionHeader extends StatelessWidget {
  const _CollectionHeader({
    required this.arabic,
    required this.ownedCount,
    required this.deckReady,
  });

  final bool arabic;
  final int ownedCount;
  final bool deckReady;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF20183C), Color(0xFF5030A8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(26),
        ),
        child: Row(
          children: [
            Container(
              width: 68,
              height: 84,
              decoration: BoxDecoration(
                color: _purple,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .18),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Center(
                child: _StealLogoMark(size: 54),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    arabic ? 'مجموعة بطاقاتك' : 'Your card collection',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    arabic
                        ? 'اجمع مواضيع جديدة وابنِ Deck جاهزة للمواجهة.'
                        : 'Collect new topics and build a duel-ready deck.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .76),
                      height: 1.35,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      _DarkBadge(
                        icon: Icons.style_rounded,
                        text: '$ownedCount',
                      ),
                      _DarkBadge(
                        icon: deckReady
                            ? Icons.check_circle_rounded
                            : Icons.lock_outline_rounded,
                        text: deckReady
                            ? (arabic ? 'Deck جاهزة' : 'Deck ready')
                            : (arabic ? 'تحتاج 10' : 'Need 10'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _DarkBadge extends StatelessWidget {
  const _DarkBadge({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: Colors.white),
            const SizedBox(width: 4),
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      );
}

class _CategoryPillCard extends StatelessWidget {
  const _CategoryPillCard({
    required this.title,
    required this.color,
    required this.category,
  });
  final String title;
  final Color color;
  final GameCategoryId category;

  @override
  Widget build(BuildContext context) => Container(
        width: 116,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _cardSurface,
          borderRadius: BorderRadius.circular(19),
          border: Border.all(color: color.withValues(alpha: .18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(_categoryIcon(category), color: color, size: 18),
            ),
            const Spacer(),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _ink,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      );
}

class _EmptyCollectionCard extends StatelessWidget {
  const _EmptyCollectionCard({required this.arabic});
  final bool arabic;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: _cardSurface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _softPurple),
        ),
        child: Column(
          children: [
            SizedBox(
              height: 108,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Transform.translate(
                    offset: const Offset(-30, 7),
                    child: Transform.rotate(
                      angle: -.12,
                      child: const _GhostCard(color: _blue),
                    ),
                  ),
                  Transform.translate(
                    offset: const Offset(30, 7),
                    child: Transform.rotate(
                      angle: .12,
                      child: const _GhostCard(color: _coral),
                    ),
                  ),
                  const _GhostCard(color: _purple),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              arabic ? 'مجموعتك تنتظر أول بطاقة' : 'Your collection awaits',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _ink,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              arabic
                  ? 'شكل المجموعة جاهز. ستظهر البطاقات الحقيقية هنا بعد إضافة المحتوى.'
                  : 'The collection is ready. Real cards will appear here when content is added.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _muted,
                height: 1.45,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
}

class _GhostCard extends StatelessWidget {
  const _GhostCard({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 68,
        height: 92,
        decoration: BoxDecoration(
          color: color.withValues(alpha: .14),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: color.withValues(alpha: .34), width: 2),
        ),
        child: Icon(Icons.lock_outline_rounded, color: color, size: 25),
      );
}

class _OwnedCardTile extends StatelessWidget {
  const _OwnedCardTile({
    required this.id,
    required this.color,
    required this.arabic,
  });

  final String id;
  final Color color;
  final bool arabic;

  @override
  Widget build(BuildContext context) => Container(
        height: 202,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, Color.lerp(color, _ink, .30)!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withValues(alpha: .72),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: .22),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            const PositionedDirectional(
              top: 12,
              start: 12,
              child: _CardCornerMark(color: Colors.white),
            ),
            PositionedDirectional(
              top: 11,
              end: 11,
              child: _CardOwnedRibbon(
                text: arabic ? 'مملوكة' : 'OWNED',
              ),
            ),
            PositionedDirectional(
              bottom: 14,
              end: 13,
              child: Icon(
                Icons.north_west_rounded,
                color: Colors.white.withValues(alpha: .36),
                size: 22,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 48, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(),
                  Container(
                    width: 52,
                    height: 62,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: .22),
                      ),
                    ),
                    child: const Center(
                      child: _StealLogoMark(size: 42),
                    ),
                  ),
                  const SizedBox(height: 13),
                  Text(
                    id,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      height: 1.15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    arabic ? 'بطاقة من مجموعتك' : 'YOUR COLLECTION',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .68),
                      fontSize: 9,
                      letterSpacing: .7,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _CardCornerMark extends StatelessWidget {
  const _CardCornerMark({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.help_rounded, color: color, size: 16),
          const SizedBox(width: 2),
          Icon(Icons.bolt_rounded, color: color, size: 13),
        ],
      );
}

class _CardOwnedRibbon extends StatelessWidget {
  const _CardOwnedRibbon({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .16),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: Colors.white.withValues(alpha: .22)),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 8,
            letterSpacing: .5,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
}

class _DeckBuilderHero extends StatelessWidget {
  const _DeckBuilderHero({
    required this.arabic,
    required this.filled,
    required this.ready,
  });

  final bool arabic;
  final int filled;
  final bool ready;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _ink,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _purple,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(Icons.layers_rounded,
                      color: Colors.white, size: 25),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        arabic ? 'ابنِ Deck المواجهة' : 'Build your duel deck',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        ready
                            ? (arabic
                                ? 'Deck النشطة جاهزة للمواجهة'
                                : 'Your active deck is duel-ready')
                            : (arabic
                                ? 'اختر 10 بطاقات مختلفة'
                                : 'Choose 10 different cards'),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .68),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '$filled/$kDeckSizeV2',
                  style: const TextStyle(
                    color: _gold,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                minHeight: 8,
                value: (filled / kDeckSizeV2).clamp(0.0, 1.0).toDouble(),
                backgroundColor: Colors.white.withValues(alpha: .1),
                valueColor: AlwaysStoppedAnimation<Color>(
                  ready ? _mint : _gold,
                ),
              ),
            ),
          ],
        ),
      );
}

class _DeckSlotCard extends StatelessWidget {
  const _DeckSlotCard({
    required this.arabic,
    required this.index,
    required this.count,
    required this.active,
    required this.valid,
    required this.busy,
    required this.onEdit,
    required this.onActivate,
  });

  final bool arabic;
  final int index;
  final int count;
  final bool active;
  final bool valid;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback? onActivate;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: _cardSurface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: active ? _purple : _softPurple,
            width: active ? 1.6 : 1,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: _purple.withValues(alpha: .08),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 43,
                  height: 43,
                  decoration: BoxDecoration(
                    color: active ? _purple : _softPurple,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    active ? Icons.bolt_rounded : Icons.layers_outlined,
                    color: active ? Colors.white : _purple,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${arabic ? 'مجموعة' : 'Deck'} ${index + 1}',
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      _GameStatusBadge(
                        text: active
                            ? (arabic ? 'المجموعة النشطة' : 'ACTIVE DECK')
                            : valid
                                ? (arabic ? 'جاهزة للتفعيل' : 'READY')
                                : (arabic ? 'غير مكتملة' : 'INCOMPLETE'),
                        color: active
                            ? _purple
                            : valid
                                ? _mint
                                : _muted,
                      ),
                    ],
                  ),
                ),
                Text(
                  '$count/$kDeckSizeV2',
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            Row(
              children: List.generate(
                kDeckSizeV2,
                (slot) => Expanded(
                  child: Padding(
                    padding: EdgeInsetsDirectional.only(
                      end: slot == kDeckSizeV2 - 1 ? 0 : 3,
                    ),
                    child: _DeckMiniSlot(
                      filled: slot < count,
                      active: active,
                      index: slot + 1,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 13),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : onEdit,
                    icon: const Icon(Icons.edit_rounded, size: 18),
                    label: Text(arabic ? 'تعديل' : 'Edit'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: busy ? null : onActivate,
                    style: FilledButton.styleFrom(
                      backgroundColor: active ? _softPurple : _purple,
                      foregroundColor: active ? _purple : Colors.white,
                    ),
                    icon: Icon(
                      active
                          ? Icons.check_circle_rounded
                          : Icons.bolt_rounded,
                      size: 18,
                    ),
                    label: Text(
                      active
                          ? (arabic ? 'نشطة' : 'Active')
                          : (arabic ? 'تفعيل' : 'Activate'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
}

class _DeckMiniSlot extends StatelessWidget {
  const _DeckMiniSlot({
    required this.filled,
    required this.active,
    required this.index,
  });

  final bool filled;
  final bool active;
  final int index;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 38,
        decoration: BoxDecoration(
          color: filled
              ? (active ? _purple : _blue)
              : _softPurple,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: filled
                ? Colors.white.withValues(alpha: .35)
                : _purple.withValues(alpha: .08),
          ),
        ),
        child: Center(
          child: filled
              ? const Icon(
                  Icons.help_rounded,
                  color: Colors.white,
                  size: 13,
                )
              : Text(
                  '$index',
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                  ),
                ),
        ),
      );
}

class _GameStatusBadge extends StatelessWidget {
  const _GameStatusBadge({
    required this.text,
    required this.color,
  });

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .11),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 8,
            letterSpacing: .45,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
}

class _DeckRuleStrip extends StatelessWidget {
  const _DeckRuleStrip({required this.arabic});
  final bool arabic;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _gold.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _gold.withValues(alpha: .26)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: _ink, size: 21),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                arabic
                    ? 'كل Deck صالحة تحتاج 10 بطاقات مختلفة تملكها.'
                    : 'A valid deck needs 10 different cards you own.',
                style: const TextStyle(
                  color: _ink,
                  height: 1.4,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      );
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
        ),
      );
}

class _CardFanMark extends StatelessWidget {
  const _CardFanMark();

  @override
  Widget build(BuildContext context) => const SizedBox(
        width: 152,
        height: 122,
        child: Center(
          child: _StealLogoMark(size: 110, showGlow: true),
        ),
      );
}

class _StealLogoMark extends StatelessWidget {
  const _StealLogoMark({
    this.size = 48,
    this.showGlow = false,
  });

  final double size;
  final bool showGlow;

  @override
  Widget build(BuildContext context) {
    final cardW = size * .54;
    final cardH = size * .72;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          if (showGlow)
            Container(
              width: size * .95,
              height: size * .95,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _purple.withValues(alpha: .08),
              ),
            ),
          Transform.translate(
            offset: Offset(-size * .13, size * .04),
            child: Transform.rotate(
              angle: -.20,
              child: _BrandCard(
                width: cardW,
                height: cardH,
                color: _blue,
                child: const Icon(
                  Icons.help_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),
          Transform.translate(
            offset: Offset(size * .12, -size * .03),
            child: Transform.rotate(
              angle: .12,
              child: _BrandCard(
                width: cardW,
                height: cardH,
                color: _purple,
                child: const Icon(
                  Icons.question_mark_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ),
          ),
          PositionedDirectional(
            top: size * .03,
            end: size * .01,
            child: Container(
              width: size * .28,
              height: size * .28,
              decoration: const BoxDecoration(
                color: _gold,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.north_west_rounded,
                color: _ink,
                size: size * .16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandCard extends StatelessWidget {
  const _BrandCard({
    required this.width,
    required this.height,
    required this.color,
    required this.child,
  });

  final double width;
  final double height;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(width * .22),
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: .28),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: child,
      );
}

IconData _categoryIcon(GameCategoryId category) => switch (category) {
      GameCategoryId.football => Icons.sports_soccer_rounded,
      GameCategoryId.anime => Icons.auto_awesome_rounded,
      GameCategoryId.movies => Icons.movie_creation_rounded,
      GameCategoryId.geography => Icons.public_rounded,
      GameCategoryId.animals => Icons.pets_rounded,
      GameCategoryId.science => Icons.science_rounded,
      GameCategoryId.general => Icons.psychology_alt_rounded,
    };

class _MiniFeature extends StatelessWidget {
  const _MiniFeature({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 7),
          Text(
            label,
            style: const TextStyle(
              color: _ink,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      );
}

class _GameHeader extends StatelessWidget {
  const _GameHeader({
    required this.arabic,
    required this.ownedCount,
    required this.weeklyPoints,
    required this.onLanguage,
  });

  final bool arabic;
  final int ownedCount;
  final int weeklyPoints;
  final VoidCallback onLanguage;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 12, 8),
        child: Row(
          children: [
            const _StealLogoMark(size: 48),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'STEAL THE QUESTIONS',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    'CARD DUEL',
                    style: TextStyle(
                      color: _purple,
                      fontSize: 10,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            _HeaderCounter(
              icon: Icons.style_rounded,
              value: '$ownedCount',
              color: _purple,
            ),
            const SizedBox(width: 4),
            _HeaderCounter(
              icon: Icons.emoji_events_rounded,
              value: '$weeklyPoints',
              color: _gold,
            ),
            const SizedBox(width: 2),
            IconButton(
              onPressed: onLanguage,
              visualDensity: VisualDensity.compact,
              icon: Text(
                arabic ? 'EN' : 'ع',
                style: const TextStyle(
                  color: _ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      );
}

class _HeaderCounter extends StatelessWidget {
  const _HeaderCounter({
    required this.icon,
    required this.value,
    required this.color,
  });
  final IconData icon;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 3),
            Text(
              value,
              style: const TextStyle(
                color: _ink,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      );
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({required this.text, required this.dismiss});
  final String text;
  final VoidCallback dismiss;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 6, 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF4D8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _gold.withValues(alpha: .35)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: _ink, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 12,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              onPressed: dismiss,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close_rounded, size: 18),
            ),
          ],
        ),
      );
}

class _GameBottomNav extends StatelessWidget {
  const _GameBottomNav({
    required this.arabic,
    required this.index,
    required this.onSelected,
  });

  final bool arabic;
  final int index;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.home_rounded, arabic ? 'الرئيسية' : 'Home'),
      (Icons.style_rounded, arabic ? 'البطاقات' : 'Cards'),
      (Icons.layers_rounded, arabic ? 'Decks' : 'Decks'),
      (Icons.flash_on_rounded, arabic ? 'اللعب' : 'Play'),
      (Icons.person_rounded, arabic ? 'الملف' : 'Profile'),
    ];

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 7),
        decoration: BoxDecoration(
          color: _ink,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: _ink.withValues(alpha: .18),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: List.generate(items.length, (i) {
            final selected = i == index;
            final item = items[i];
            return Expanded(
              child: InkWell(
                onTap: () => onSelected(i),
                borderRadius: BorderRadius.circular(18),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item.$1,
                        color: selected ? _purple : Colors.white70,
                        size: 22,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.$2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected ? _ink : Colors.white70,
                          fontSize: 9,
                          fontWeight:
                              selected ? FontWeight.w900 : FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _GameHeroCard extends StatelessWidget {
  const _GameHeroCard({
    required this.arabic,
    required this.ready,
    required this.onPlay,
  });

  final bool arabic;
  final bool ready;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_violet, _blue],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: _purple.withValues(alpha: .24),
              blurRadius: 24,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              top: -36,
              right: -26,
              child: Container(
                width: 116,
                height: 116,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: .08),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    ready
                        ? (arabic ? 'جاهز للمواجهة' : 'READY TO DUEL')
                        : (arabic ? 'ابنِ مجموعتك' : 'BUILD YOUR DECK'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      letterSpacing: .5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  arabic
                      ? 'اجمع. نافس.\nواسرق البطاقة.'
                      : 'Collect. Compete.\nSteal the card.',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 27,
                    height: 1.05,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  arabic
                      ? 'كل بطاقة تقرّبك من Deck أقوى ومواجهة جديدة.'
                      : 'Every card brings you closer to a stronger deck and a new duel.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .82),
                    height: 1.4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: onPlay,
                    style: FilledButton.styleFrom(
                      backgroundColor: _gold,
                      foregroundColor: _ink,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(
                      arabic ? 'ابدأ اللعب' : 'PLAY NOW',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
}

class _JourneyStrip extends StatelessWidget {
  const _JourneyStrip({
    required this.arabic,
    required this.ownedCount,
  });

  final bool arabic;
  final int ownedCount;

  @override
  Widget build(BuildContext context) {
    final steps = [
      (Icons.style_rounded, arabic ? 'اجمع' : 'Collect'),
      (Icons.layers_rounded, arabic ? 'كوّن' : 'Build'),
      (Icons.flash_on_rounded, arabic ? 'نافس' : 'Duel'),
      (Icons.north_west_rounded, arabic ? 'اسرق' : 'Steal'),
    ];
    final reached = ownedCount >= kDeckSizeV2 ? 2 : ownedCount > 0 ? 1 : 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: _cardSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _softPurple),
      ),
      child: Row(
        children: List.generate(steps.length, (index) {
          final active = index <= reached;
          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: active ? _purple : _softPurple,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(
                          steps[index].$1,
                          size: 17,
                          color: active ? Colors.white : _muted,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        steps[index].$2,
                        style: TextStyle(
                          color: active ? _ink : _muted,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                if (index < steps.length - 1)
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 14,
                    color: _purple.withValues(alpha: .35),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _QuickStatCard extends StatelessWidget {
  const _QuickStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
        decoration: BoxDecoration(
          color: _cardSurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: .13)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                color: _ink,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _muted,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
}

class _SectionRow extends StatelessWidget {
  const _SectionRow({
    required this.title,
    this.action,
    this.onAction,
  });

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: _ink,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          if (action != null)
            onAction == null
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: _softPurple,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      action!,
                      style: const TextStyle(
                        color: _purple,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  )
                : TextButton(
                    onPressed: onAction,
                    child: Text(
                      action!,
                      style: const TextStyle(
                        color: _purple,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
        ],
      );
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: _cardSurface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: color.withValues(alpha: .16)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .13),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _muted,
                  fontSize: 11,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.title,
    required this.color,
    required this.category,
  });
  final String title;
  final Color color;
  final GameCategoryId category;

  @override
  Widget build(BuildContext context) => Container(
        width: 126,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .11),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: .23)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                _categoryIcon(category),
                color: Colors.white,
                size: 18,
              ),
            ),
            const Spacer(),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _ink,
                fontSize: 12,
                height: 1.15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      );
}

class _Scroll extends StatelessWidget {
  const _Scroll({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
        children: [Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children)))],
      );
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
