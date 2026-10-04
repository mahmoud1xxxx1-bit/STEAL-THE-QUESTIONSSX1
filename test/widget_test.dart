import 'package:flutter_test/flutter_test.dart';
import 'package:steal_the_questions/main.dart';

void main() {
  testWidgets('first question is visible', (tester) async {
    await tester.pumpWidget(const StealTheQuestionsApp());
    expect(find.text('QUESTION'), findsOneWidget);
    expect(find.text('Which planet is known as the Red Planet?'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);
  });
}
