import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/db/app_database.dart';
import 'core/services/auth_service.dart';
import 'core/services/theme_service.dart';
import 'features/auth/login_screen.dart';
import 'features/personal_finances/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Future.wait([
    AppDatabase().database.then((db) => debugPrint('📦 Base de datos inicializada: $db')),
    AuthService().init(),
    ThemeService().init(),
  ]);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeService(),
      builder: (context, _) {
        final themeService = ThemeService();
        final authService = AuthService();

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'MYPE Finanzas',
          theme: themeService.lightTheme,
          darkTheme: themeService.darkTheme,
          themeMode: themeService.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          locale: const Locale('es', 'PE'),
          supportedLocales: const [
            Locale('es', 'PE'),
            Locale('es'),
            Locale('en'),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: authService.isAuthenticated
              ? const MyHomePage(title: 'Registro de transacciones')
              : const LoginScreen(),
        );
      },
    );
  }
}
