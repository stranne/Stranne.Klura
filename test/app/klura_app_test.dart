import 'package:flutter_test/flutter_test.dart';
import 'package:klura/app/klura_app.dart';
import 'package:klura/puzzles/bridges/bridges_screen.dart';
import 'package:klura/puzzles/bridges/logic/bridges_generator.dart';

void main() {
  final today = DateTime(2026, 11, 11);

  BridgesScreen screen(WidgetTester tester) =>
      tester.widget<BridgesScreen>(find.byType(BridgesScreen));

  testWidgets('opens a daily puzzle from home and keeps it on return', (
    tester,
  ) async {
    await tester.pumpWidget(KluraApp(today: today));

    await tester.tap(find.text('Hard'));
    await tester.pumpAndSettle();

    expect(find.text('Bridges · Hard'), findsOneWidget);
    final controller = screen(tester).controller;
    expect(controller.seedKey, 'bridges-hard:v2:2026-11-11');

    controller.cycleBridges(controller.game.puzzle.connections.first);
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('In progress'), findsOneWidget);

    await tester.tap(find.text('Hard'));
    await tester.pumpAndSettle();

    expect(screen(tester).controller, same(controller));
    expect(controller.game.arrangement.isEmpty, isFalse);
  });

  testWidgets('keeps the start date for the whole session', (tester) async {
    await tester.pumpWidget(KluraApp(today: today));
    await tester.pumpWidget(KluraApp(today: DateTime(2026, 11, 12)));

    expect(find.text('Wednesday, November 11, 2026'), findsOneWidget);

    await tester.tap(find.text('Normal'));
    await tester.pumpAndSettle();

    expect(
      screen(tester).controller.seedKey,
      bridgesDailySeedKey(BridgesLevel.normal, today),
    );
  });
}
