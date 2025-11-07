import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mype_finanzas/app.dart';

void main() {
  testWidgets('Login screen loads', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MyApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bienvenido a Numeria'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });
}
