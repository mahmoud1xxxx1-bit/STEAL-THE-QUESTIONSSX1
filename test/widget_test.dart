import 'package:flutter_test/flutter_test.dart';
import 'package:steal_the_questions/main.dart';

void main() {
  testWidgets('shows the product shell and onboarding gate', (tester) async {
    await tester.pumpWidget(const StealTheQuestionsApp());
    await tester.pumpAndSettle();

    expect(find.text('STEAL THE QUESTIONS'), findsOneWidget);
    expect(find.textContaining('10'), findsWidgets);
    expect(find.text('COLLECTION'), findsWidgets);
    expect(find.text('DECKS'), findsOneWidget);
    expect(find.text('BOT TRAINING'), findsOneWidget);
  });

  testWidgets('navigation exposes collection, decks and play', (tester) async {
    await tester.pumpWidget(const StealTheQuestionsApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('CARDS'));
    await tester.pumpAndSettle();
    expect(find.text('222 COLLECTIBLE QUESTIONS'), findsOneWidget);
    expect(find.text('Q001'), findsOneWidget);
    expect(find.text('Q222'), findsOneWidget);

    await tester.tap(find.text('DECKS'));
    await tester.pumpAndSettle();
    expect(find.text('DECK 1'), findsOneWidget);
    expect(find.text('DECK 5'), findsOneWidget);

    await tester.tap(find.text('PLAY'));
    await tester.pumpAndSettle();
    expect(find.text('BOT TRAINING'), findsOneWidget);
    expect(find.text('START ROUND'), findsOneWidget);
  });
}
