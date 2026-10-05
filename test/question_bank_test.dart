import 'package:flutter_test/flutter_test.dart';
import 'package:steal_the_questions/game/game_rules.dart';
import 'package:steal_the_questions/game/question_bank.dart';

void main() {
  group('question content', () {
    test('catalog has 222 unique bilingual questions', () {
      QuestionBank.validate();
      expect(QuestionBank.all.length, 222);
      expect(QuestionBank.all.map((q) => q.id).toSet().length, 222);
      expect(QuestionBank.all.where((q) => q.rarity == CardRarity.epic).length, 150);
      expect(QuestionBank.all.where((q) => q.rarity == CardRarity.gold).length, 50);
      expect(QuestionBank.all.where((q) => q.rarity == CardRarity.legendary).length, 22);
    });

    test('every question has three base options and a Weekly Pass fourth option', () {
      for (final q in QuestionBank.all) {
        expect(q.answersEn.length, 3);
        expect(q.answersAr.length, 3);
        expect(q.correctIndex, inInclusiveRange(0, 2));
        expect(q.answersEn[q.correctIndex], isNotEmpty);
        expect(q.answersAr[q.correctIndex], isNotEmpty);
        expect(q.answers(arbic: false, weeklyPass: true), hasLength(4), reason: q.id);
      }
    });
  });
}
