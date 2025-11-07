import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/database/app_database.dart';
import 'domain/services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar base de datos
  await AppDatabase().database.then(
    (db) => debugPrint('✅ Base de datos inicializada: $db'),
  );

  // Limpiar tokens antiguos de SharedPreferences (migración)
  final prefs = await SharedPreferences.getInstance();
  if (prefs.containsKey('auth_token')) {
    await prefs.remove('auth_token');
    debugPrint('🗑️ Token antiguo eliminado de SharedPreferences');
  }

  // Crear contenedor de Riverpod
  final container = ProviderContainer();

  // Configurar AuthService con el contenedor
  AuthService.setContainer(container);

  // Ejecutar la aplicación
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const MyApp(),
    ),
  );
}

