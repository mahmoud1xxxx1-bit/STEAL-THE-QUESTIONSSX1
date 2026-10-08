import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../game/core_engine_v2.dart';

class AdminCardV2 {
  const AdminCardV2({
    required this.id,
    required this.category,
    required this.titleAr,
    required this.titleEn,
    required this.rarity,
    required this.enabled,
    required this.availableCopies,
    required this.questionCount,
  });

  final String id;
  final GameCategoryId category;
  final String titleAr;
  final String titleEn;
  final CardRarityV2 rarity;
  final bool enabled;
  final int availableCopies;
  final int questionCount;
}

class AdminQuestionV2 {
  const AdminQuestionV2({
    required this.id,
    required this.cardId,
    required this.questionAr,
    required this.questionEn,
    required this.correctAr,
    required this.correctEn,
    required this.wrongAnswersAr,
    required this.wrongAnswersEn,
    required this.enabled,
  });

  final String id;
  final String cardId;
  final String questionAr;
  final String questionEn;
  final String correctAr;
  final String correctEn;
  final List<String> wrongAnswersAr;
  final List<String> wrongAnswersEn;
  final bool enabled;
}

class AdminAccessV2 {
  AdminAccessV2({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Future<bool> isCurrentUserAdmin() async {
    final email = _auth.currentUser?.email?.trim().toLowerCase();
    if (email == null || email.isEmpty) return false;
    final doc = await _firestore.collection('adminEmailsV2').doc(email).get();
    return doc.exists && doc.data()?['enabled'] == true;
  }
}

class AdminContentRepositoryV2 {
  AdminContentRepositoryV2({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<List<AdminCardV2>> loadCards() async {
    final snapshot = await _firestore.collection('cardsV2').get();
    final cards = snapshot.docs.map((doc) {
      final data = doc.data();
      return AdminCardV2(
        id: doc.id,
        category: _category(data['category'] as String?),
        titleAr: data['titleAr'] as String? ?? '',
        titleEn: data['titleEn'] as String? ?? '',
        rarity: _rarity(data['rarity'] as String?),
        enabled: data['enabled'] != false,
        availableCopies: (data['availableCopies'] as num?)?.toInt() ?? 0,
        questionCount: (data['questionCount'] as num?)?.toInt() ?? 0,
      );
    }).toList();
    cards.sort((a, b) => a.id.compareTo(b.id));
    return cards;
  }

  Future<void> upsertCard({
    required String id,
    required GameCategoryId category,
    required String titleAr,
    required String titleEn,
    required CardRarityV2 rarity,
    required int availableCopies,
    required bool enabled,
  }) async {
    final cleanId = id.trim();
    if (cleanId.isEmpty) throw StateError('CARD_ID_REQUIRED');
    if (titleAr.trim().isEmpty || titleEn.trim().isEmpty) {
      throw StateError('CARD_TITLE_REQUIRED');
    }
    if (availableCopies < 0) throw StateError('INVALID_COPY_COUNT');

    await _firestore.collection('cardsV2').doc(cleanId).set({
      'category': category.name,
      'titleAr': titleAr.trim(),
      'titleEn': titleEn.trim(),
      'rarity': rarity.name,
      'availableCopies': availableCopies,
      'enabled': enabled,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<List<AdminQuestionV2>> loadQuestions(String cardId) async {
    final snapshot = await _firestore
        .collection('cardsV2')
        .doc(cardId)
        .collection('questions')
        .get();
    final result = snapshot.docs.map((doc) {
      final data = doc.data();
      return AdminQuestionV2(
        id: doc.id,
        cardId: cardId,
        questionAr: data['questionAr'] as String? ?? '',
        questionEn: data['questionEn'] as String? ?? '',
        correctAr: data['correctAr'] as String? ?? '',
        correctEn: data['correctEn'] as String? ?? '',
        wrongAnswersAr:
            List<String>.from(data['wrongAnswersAr'] as List? ?? const []),
        wrongAnswersEn:
            List<String>.from(data['wrongAnswersEn'] as List? ?? const []),
        enabled: data['enabled'] != false,
      );
    }).toList();
    result.sort((a, b) => a.id.compareTo(b.id));
    return result;
  }

  Future<void> upsertQuestion({
    required String cardId,
    required String id,
    required String questionAr,
    required String questionEn,
    required String correctAr,
    required String correctEn,
    required List<String> wrongAnswersAr,
    required List<String> wrongAnswersEn,
    required bool enabled,
  }) async {
    if (id.trim().isEmpty) throw StateError('QUESTION_ID_REQUIRED');
    if (questionAr.trim().isEmpty || correctAr.trim().isEmpty) {
      throw StateError('ARABIC_QUESTION_REQUIRED');
    }
    if (questionEn.trim().isEmpty || correctEn.trim().isEmpty) {
      throw StateError('ENGLISH_QUESTION_REQUIRED');
    }
    if (wrongAnswersAr.length < 2 || wrongAnswersEn.length < 2) {
      throw StateError('AT_LEAST_TWO_WRONG_ANSWERS_REQUIRED');
    }

    final cardRef = _firestore.collection('cardsV2').doc(cardId);
    final questionRef = cardRef.collection('questions').doc(id.trim());
    final batch = _firestore.batch();
    batch.set(questionRef, {
      'questionAr': questionAr.trim(),
      'questionEn': questionEn.trim(),
      'correctAr': correctAr.trim(),
      'correctEn': correctEn.trim(),
      'wrongAnswersAr': wrongAnswersAr.map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
      'wrongAnswersEn': wrongAnswersEn.map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
      'enabled': enabled,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    final count = await questionRef.get();
    if (!count.exists) {
      batch.set(cardRef, {'questionCount': FieldValue.increment(1)}, SetOptions(merge: true));
    }
    await batch.commit();
  }

  Future<void> setQuestionEnabled({
    required String cardId,
    required String questionId,
    required bool enabled,
  }) =>
      _firestore
          .collection('cardsV2')
          .doc(cardId)
          .collection('questions')
          .doc(questionId)
          .update({'enabled': enabled, 'updatedAt': FieldValue.serverTimestamp()});

  GameCategoryId _category(String? value) {
    return GameCategoryId.values.firstWhere(
      (item) => item.name == value,
      orElse: () => GameCategoryId.general,
    );
  }

  CardRarityV2 _rarity(String? value) {
    return CardRarityV2.values.firstWhere(
      (item) => item.name == value,
      orElse: () => CardRarityV2.epic,
    );
  }
}
