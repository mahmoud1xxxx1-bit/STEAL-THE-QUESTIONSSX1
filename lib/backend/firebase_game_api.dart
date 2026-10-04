import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../game/question_bank.dart';

class BotRoundData {
  const BotRoundData({
    required this.roundId,
    required this.questionId,
    required this.questionEn,
    required this.questionAr,
    required this.answersEn,
    required this.answersAr,
  });

  final String roundId;
  final String questionId;
  final String questionEn;
  final String questionAr;
  final List<String> answersEn;
  final List<String> answersAr;
}

class DuelStateData {
  const DuelStateData({
    required this.duelId,
    required this.status,
    required this.role,
    required this.questionIndex,
    required this.questions,
    required this.correct,
    required this.responseTimeMs,
    required this.opponentAnswered,
    required this.opponentCorrect,
    required this.result,
    required this.winnerUid,
    required this.loserUid,
    required this.opponentDeckCount,
    required this.stealRevealed,
    required this.stolenCardId,
    required this.stolenRarity,
  });

  final String duelId;
  final String status;
  final String role;
  final int questionIndex;
  final List<Map<String, dynamic>> questions;
  final int correct;
  final int responseTimeMs;
  final bool opponentAnswered;
  final int opponentCorrect;
  final String? result;
  final String? winnerUid;
  final String? loserUid;
  final int opponentDeckCount;
  final bool stealRevealed;
  final String? stolenCardId;
  final String? stolenRarity;
}

class FirebaseGameApi {
  FirebaseGameApi();

  FirebaseAuth get auth => FirebaseAuth.instance;
  FirebaseFirestore get firestore => FirebaseFirestore.instance;
  FirebaseFunctions get functions => FirebaseFunctions.instance;

  User? get currentUser => auth.currentUser;

  Future<Map<String, dynamic>> loadProfile() async {
    final uid = currentUser?.uid;
    if (uid == null) throw StateError('Authentication required.');
    final snap = await firestore.collection('users').doc(uid).get();
    return snap.data() ?? const <String, dynamic>{};
  }

  Future<void> signUp(String email, String password) async {
    await auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
  }

  Future<void> signIn(String email, String password) async {
    await auth.signInWithEmailAndPassword(email: email.trim(), password: password);
  }

  Future<void> signOut() => auth.signOut();

  Future<BotRoundData> startBotRound({required bool arabic}) async {
    final call = functions.httpsCallable('startBotRound');
    final response = await call.call({'language': arabic ? 'ar' : 'en'});
    final data = Map<String, dynamic>.from(response.data as Map);
    return BotRoundData(
      roundId: data['roundId'] as String,
      questionId: data['questionId'] as String,
      questionEn: data['questionEn'] as String,
      questionAr: data['questionAr'] as String,
      answersEn: List<String>.from(data['answersEn'] as List),
      answersAr: List<String>.from(data['answersAr'] as List),
    );
  }

  Future<Map<String, dynamic>> submitBotAnswer({
    required String roundId,
    required int answerIndex,
  }) async {
    final call = functions.httpsCallable('submitBotAnswer');
    final response = await call.call({
      'roundId': roundId,
      'answerIndex': answerIndex,
    });
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<void> saveDeck({required int deckIndex, required List<String> cardIds}) async {
    final call = functions.httpsCallable('saveDeck');
    await call.call({'deckIndex': deckIndex, 'cardIds': cardIds});
  }

  Future<Map<String, dynamic>> findOrCreateDuel(List<String> deck) async {
    final call = functions.httpsCallable('findOrCreateDuel');
    final response = await call.call({'deck': deck});
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<void> submitDuelAnswer({
    required String duelId,
    required int questionIndex,
    required int answerIndex,
  }) async {
    final call = functions.httpsCallable('submitDuelAnswer');
    await call.call({
      'duelId': duelId,
      'questionIndex': questionIndex,
      'answerIndex': answerIndex,
    });
  }

  Future<Map<String, dynamic>> resolveDuel(String duelId) async {
    final call = functions.httpsCallable('resolveDuel');
    final response = await call.call({'duelId': duelId});
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> getDuelState(String duelId) async {
    final snap = await firestore.collection('duels').doc(duelId).get();
    final data = snap.data();
    if (data == null) throw StateError('Duel not found.');
    return data;
  }

  Future<Map<String, dynamic>> revealStealTarget({
    required String duelId,
    required int slotIndex,
  }) async {
    final call = functions.httpsCallable('revealStealTarget');
    final response = await call.call({
      'duelId': duelId,
      'slotIndex': slotIndex,
    });
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> confirmSteal(String duelId) async {
    final call = functions.httpsCallable('confirmSteal');
    final response = await call.call({'duelId': duelId});
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<List<Map<String, dynamic>>> ranking() async {
    final call = functions.httpsCallable('getRanking');
    final response = await call.call();
    final data = Map<String, dynamic>.from(response.data as Map);
    return (data['players'] as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> claimRankingReward() async {
    final call = functions.httpsCallable('claimRankingReward');
    final response = await call.call();
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> verifyWeeklyPassPurchase({
    required String productId,
    required String platform,
    required String receipt,
  }) async {
    final call = functions.httpsCallable('verifyWeeklyPassPurchase');
    final response = await call.call({
      'productId': productId,
      'platform': platform,
      'receipt': receipt,
    });
    return Map<String, dynamic>.from(response.data as Map);
  }

  static Map<String, dynamic> localQuestionPayload(QuestionContent q, {required bool arabic, required bool weeklyPass}) {
    return {
      'questionId': q.id,
      'question': arabic ? q.questionAr : q.questionEn,
      'answers': q.answers(arabic: arabic, weeklyPass: weeklyPass),
    };
  }
}
