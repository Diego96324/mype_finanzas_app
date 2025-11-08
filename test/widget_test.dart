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
    // Evita esperar a que se asiente porque hay animaciones infinitas
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Bienvenido a Numeria'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });
}
