import 'package:flutter_test/flutter_test.dart';
import 'package:steal_the_questions/main.dart';

void main() {
  testWidgets('shows the first card and question', (tester) async {
    await tester.pumpWidget(const StealTheQuestionsApp());
    expect(find.text('STEAL THE'), findsOneWidget);
    expect(find.text('QUESTIONS'), findsOneWidget);
    expect(
      find.text('Which planet is known as the Red Planet?'),
      findsOneWidget,
    );
    expect(find.text('20'), findsOneWidget);
    expect(find.text('YOUR DECK'), findsOneWidget);
  });
}
