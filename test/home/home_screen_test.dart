import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klura/home/home_screen.dart';

void main() {
  testWidgets('shows the date and the bridges puzzle', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: HomeScreen(today: DateTime(2026, 11, 11))),
    );

    expect(find.text('Klura'), findsOneWidget);
    expect(find.text('Wednesday, November 11, 2026'), findsOneWidget);
    expect(find.text('Bridges'), findsOneWidget);
  });
}
