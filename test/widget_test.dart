import 'package:flutter_test/flutter_test.dart';
import 'package:steal_the_questions/game/core_engine_v2.dart';

void main() {
  test('seven category model is exposed', () {
    expect(kCategoriesV2.length, 7);
    expect(kCategoriesV2.map((c) => c.id).toSet().length, 7);
  });

  test('subscription model keeps free and subscriber limits', () {
    const free = SubscriptionEntitlementV2(active: false);
    const subscriber = SubscriptionEntitlementV2(active: true);

    expect(free.deckSlots, 2);
    expect(free.answerChoices, 3);
    expect(subscriber.deckSlots, 5);
    expect(subscriber.answerChoices, 4);
  });
}
