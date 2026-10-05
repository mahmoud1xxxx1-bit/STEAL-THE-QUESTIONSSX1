import 'package:cloud_firestore/cloud_firestore.dart';

import '../game/core_engine_v2.dart';

class CardSummaryV2 {
  const CardSummaryV2({
    required this.id,
    required this.category,
    required this.titleAr,
    required this.titleEn,
    required this.questionCount,
    required this.enabled,
  });

  final String id;
  final GameCategoryId category;
  final String titleAr;
  final String titleEn;
  final int questionCount;
  final bool enabled;
}

class CardCatalogRepositoryV2 {
  CardCatalogRepositoryV2({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<List<CardSummaryV2>> loadEnabledCards() async {
    final snapshot = await _firestore
        .collection('cardsV2')
        .where('enabled', isEqualTo: true)
        .get();

    final cards = <CardSummaryV2>[];
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final category = _categoryFromString(data['category'] as String?);
      if (category == null) continue;
      cards.add(CardSummaryV2(
        id: doc.id,
        category: category,
        titleAr: data['titleAr'] as String? ?? '',
        titleEn: data['titleEn'] as String? ?? '',
        questionCount: (data['questionCount'] as num?)?.toInt() ?? 0,
        enabled: data['enabled'] == true,
      ));
    }
    cards.sort((a, b) => a.id.compareTo(b.id));
    return List<CardSummaryV2>.unmodifiable(cards);
  }

  GameCategoryId? _categoryFromString(String? value) {
    if (value == null) return null;
    for (final category in GameCategoryId.values) {
      if (category.name == value) return category;
    }
    return null;
  }
}
