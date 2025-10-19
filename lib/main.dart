import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/db/app_database.dart';
import 'features/auth/login_screen.dart';
import 'features/personal_finances/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = await AppDatabase().database;
  debugPrint('📦 Base de datos inicializada: $db');

  final prefs = await SharedPreferences.getInstance();
  final stayLogged = prefs.getBool('stay_logged_in') ?? false;

  runApp(MyApp(stayLoggedIn: stayLogged));
}

class MyApp extends StatelessWidget {
  final bool stayLoggedIn;
  const MyApp({super.key, required this.stayLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MYPE Finanzas',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
      ),
      // Localización
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
      home: stayLoggedIn
          ? const MyHomePage(title: 'Registro de transacciones')
          : const LoginScreen(),
    );
  }
}
