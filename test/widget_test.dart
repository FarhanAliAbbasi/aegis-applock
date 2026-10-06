import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:applock/main.dart';

void main() {
  testWidgets('AegisAppLockApp initializes and displays without crash', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'aegis_onboarding_completed': true});

    await tester.pumpWidget(const AegisAppLockApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
