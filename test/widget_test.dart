// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mype_finanzas/main.dart';

void main() {
  testWidgets('Login screen loads', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Wait for async initialization
    await tester.pumpAndSettle();

    // Verify that login screen elements are present
    expect(find.text('Bienvenido a Numeria'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });
}
