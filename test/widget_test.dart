import 'package:flutter_test/flutter_test.dart';

import 'package:mype_finanzas/main.dart';

void main() {
  testWidgets('Login screen loads', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('Bienvenido a Numeria'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });
}
