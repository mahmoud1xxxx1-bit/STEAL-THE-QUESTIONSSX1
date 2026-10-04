import 'package:flutter_test/flutter_test.dart';
import 'package:steal_the_questions/main.dart';

void main() {
  testWidgets('shows the real home shell without question content', (tester) async {
    await tester.pumpWidget(const StealTheQuestionsApp());

    expect(find.text('STEAL THE QUESTIONS'), findsOneWidget);
    expect(find.textContaining('10 CARDS'), findsOneWidget);
    expect(find.text('COLLECTION'), findsOneWidget);
    expect(find.text('DECKS'), findsOneWidget);
    expect(find.text('BOT TRAINING'), findsOneWidget);
    expect(find.text('Which planet is known as the Red Planet?'), findsNothing);
  });

  testWidgets('navigation exposes collection, decks and play structure', (tester) async {
    await tester.pumpWidget(const StealTheQuestionsApp());

    await tester.tap(find.text('CARDS'));
    await tester.pumpAndSettle();
    expect(find.text('COLLECTION'), findsWidgets);

    await tester.tap(find.text('DECKS'));
    await tester.pumpAndSettle();
    expect(find.text('DECK 1'), findsOneWidget);
    expect(find.text('DECK 5'), findsOneWidget);
    expect(find.text('Every deck contains exactly 10 distinct cards.'), findsOneWidget);

    await tester.tap(find.text('PLAY'));
    await tester.pumpAndSettle();
    expect(find.text('BOT TRAINING'), findsOneWidget);
    expect(find.text('TROLL DUEL'), findsOneWidget);
    expect(find.text('Which planet is known as the Red Planet?'), findsNothing);
  });
}
