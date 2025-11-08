import 'package:flutter/material.dart' as flutter;
import 'package:flutter/material.dart' hide ThemeMode;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/providers/providers.dart';

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkMode = ref.watch(themeStateProvider);

    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Numeria',
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      themeMode: isDarkMode ? flutter.ThemeMode.dark : flutter.ThemeMode.light,
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
      routerConfig: router,
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: Colors.greenAccent,
        secondary: Colors.green,
        surface: const Color(0xFF1E1E1E),
        surfaceContainerHighest: Colors.grey[900]!,
        error: Colors.redAccent,
        onPrimary: Colors.black,
        onSecondary: Colors.black,
        onSurface: Colors.white,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: Colors.black,
      cardColor: const Color(0xFF1E1E1E),
      dividerColor: Colors.white.withValues(alpha: 0.05),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
    );
  }

  ThemeData _buildLightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: Colors.green.shade700,
        secondary: Colors.green.shade500,
        surface: Colors.white,
        surfaceContainerHighest: Colors.grey.shade200,
        error: Colors.red.shade700,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Colors.black87,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: Colors.grey[50],
      cardColor: Colors.white,
      dividerColor: Colors.black.withValues(alpha: 0.1),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
      ),
    );
  }
}
