import 'dart:async'; // Necesario para Future
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'models/database/app_database.dart';
import 'models/services/auth_service.dart';
import 'models/services/backup_service.dart';
import 'models/services/attachment_cleanup_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Inicializar BD (Esto es rápido, se queda aquí)
  await AppDatabase().database.then(
        (db) => debugPrint('✅ Base de datos inicializada'),
  );

  // 2. Configuración rápida de Auth
  final prefs = await SharedPreferences.getInstance();
  if (prefs.containsKey('auth_token')) {
    await prefs.remove('auth_token');
    debugPrint('🗑️ Token antiguo eliminado');
  }

  final container = ProviderContainer();
  AuthService.setContainer(container);

  // 3. Restauración crítica (Solo si está vacío, necesario antes de iniciar)
  final restored = await BackupService().restoreIfEmpty();
  if (!restored) {
    await AppDatabase().ensureSeedUser();
  }

  // 🚀 4. ¡ARRANCAR LA APP YA! (No esperar más)
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const MyApp(),
    ),
  );

  // 5. TAREAS EN SEGUNDO PLANO (Post-Arranque)
  // Usamos Future.delayed para no competir con la animación de inicio
  Future.delayed(const Duration(seconds: 4), () async {
    debugPrint('⏳ Iniciando tareas de mantenimiento en segundo plano...');

    // Limpieza de adjuntos (Mover aquí para no bloquear inicio)
    await AttachmentCleanupService().removeOrphanAttachments();

    // Backup (Mover aquí para no bloquear inicio)
    // Gracias al arreglo anterior con 'compute', esto ya no congelará la UI
    await BackupService().exportBackup();

    debugPrint('✅ Tareas de mantenimiento completadas');
  });
}