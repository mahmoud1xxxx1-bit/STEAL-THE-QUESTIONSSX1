import 'package:flutter_test/flutter_test.dart';
import 'package:steal_the_questions/main.dart';

void main() {
  testWidgets('shows the real home shell', (tester) async {
    await tester.pumpWidget(const StealTheQuestionsApp());

    expect(find.text('STEAL THE QUESTIONS'), findsOneWidget);
    expect(find.textContaining('10 CARDS'), findsOneWidget);
    expect(find.text('COLLECTION'), findsOneWidget);
    expect(find.text('DECKS'), findsOneWidget);
    expect(find.text('BOT TRAINING'), findsOneWidget);
  });

  testWidgets('navigation exposes collection and decks', (tester) async {
    await tester.pumpWidget(const StealTheQuestionsApp());

    await tester.tap(find.text('CARDS'));
    await tester.pumpAndSettle();
    expect(find.text('COLLECTION'), findsWidgets);
    expect(
      find.text('222 unique cards. No duplicate Card IDs per player.'),
      findsOneWidget,
    );

    await tester.tap(find.text('DECKS'));
    await tester.pumpAndSettle();
    expect(
      find.text('Every deck contains exactly 10 distinct cards.'),
      findsOneWidget,
    );
    expect(find.text('DECK 1'), findsOneWidget);
    expect(find.text('DECK 5'), findsOneWidget);
  });
}
