import 'package:flutter_test/flutter_test.dart';

import 'package:steal_the_questions/main.dart';

void main() {
  testWidgets('shows the bilingual card duel core', (tester) async {
    await tester.pumpWidget(const StealTheQuestionsApp());

    expect(find.textContaining('STEAL THE'), findsOneWidget);
    expect(
      find.text('Which planet is known as the Red Planet?'),
      findsOneWidget,
    );
    expect(find.text('20'), findsOneWidget);
    expect(find.text('MY DECK'), findsOneWidget);
  });
}
