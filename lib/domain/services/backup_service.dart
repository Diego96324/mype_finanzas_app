import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart'; // Para compute
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../../core/database/app_database.dart';

class BackupService {
  static const _backupFileName = 'backup_mype_finanzas.json';
  static const _backupMetaName = 'backup_meta.txt';

  Future<String> get _localPath async {
    final dir = await getApplicationDocumentsDirectory();
    return dir.path;
  }

  /// Exporta TODAS las tablas en SEGUNDO PLANO.
  Future<void> exportBackup() async {
    try {
      final db = await AppDatabase().database;

      // 1. Recolectar datos (Rápido en lectura, pesado en memoria si son miles)
      // He agregado todas las tablas que vi en tu AppDatabase
      final usuarios = await _safeQuery(db, 'usuarios');
      final cuentas = await _safeQuery(db, 'cuentas');
      final categorias = await _safeQuery(db, 'categorias');
      final transacciones = await _safeQuery(db, 'transacciones');
      final presupuestos = await _safeQuery(db, 'presupuestos');
      final metas = await _safeQuery(db, 'metas_financieras');
      final recordatorios = await _safeQuery(db, 'recordatorios');

      // Gamification (Nuevas tablas v14)
      final gamificationProfiles = await _safeQuery(db, 'gamification_profiles');
      final gamificationAchievements = await _safeQuery(db, 'gamification_achievements');
      final gamificationEvents = await _safeQuery(db, 'gamification_events');

      // Construir el objeto gigante
      final Map<String, dynamic> payload = {
        'version': 1,
        'timestamp': DateTime.now().toIso8601String(),
        'usuarios': usuarios,
        'cuentas': cuentas,
        'categorias': categorias,
        'transacciones': transacciones,
        'presupuestos': presupuestos,
        'metas_financieras': metas,
        'recordatorios': recordatorios,
        'gamification_profiles': gamificationProfiles,
        'gamification_achievements': gamificationAchievements,
        'gamification_events': gamificationEvents,
      };

      final path = await _localPath;

      // 2. 🔥 EL SECRETO: Procesar JSON y guardar en otro hilo
      await compute(_writeBackupInBackground, {
        'path': path,
        'payload': payload,
        'fileName': _backupFileName,
        'metaName': _backupMetaName,
        'countTrans': transacciones.length,
      });

      debugPrint('💾 Backup completo exportado en segundo plano');

    } catch (e) {
      debugPrint('⚠️ Error exportando backup: $e');
    }
  }

  // Esta función estática corre en un hilo aislado
  static Future<void> _writeBackupInBackground(Map<String, dynamic> params) async {
    final String path = params['path'];
    final Map<String, dynamic> payload = params['payload'];
    final String fileName = params['fileName'];
    final String metaName = params['metaName'];

    // Esto es lo que mataba tu app: convertir mapas gigantes a texto
    final jsonString = jsonEncode(payload);

    final file = File('$path/$fileName');
    await file.writeAsString(jsonString); // Escribir al disco

    final meta = File('$path/$metaName');
    await meta.writeAsString('last_backup=${DateTime.now().toIso8601String()}');
  }

  Future<bool> restoreIfEmpty() async {
    try {
      final db = await AppDatabase().database;
      final usuarioCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM usuarios')) ?? 0;

      if (usuarioCount > 0) {
        debugPrint('🔁 Restauración omitida (ya hay datos)');
        return false;
      }

      final path = await _localPath;
      final file = File('$path/$_backupFileName');

      if (!(await file.exists())) return false;

      final content = await file.readAsString();
      final map = jsonDecode(content) as Map<String, dynamic>;

      final batch = db.batch();

      void insertList(String table, List<dynamic>? rows) {
        if (rows == null) return;
        for (final r in rows) {
          final row = Map<String, Object?>.from(r as Map);
          row.remove('id'); // Dejar que SQLite asigne nuevos IDs
          batch.insert(table, row, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      }

      // Restaurar en orden de dependencia
      insertList('usuarios', map['usuarios'] as List?);
      insertList('cuentas', map['cuentas'] as List?);
      insertList('categorias', map['categorias'] as List?);
      insertList('transacciones', map['transacciones'] as List?);
      insertList('presupuestos', map['presupuestos'] as List?);
      insertList('metas_financieras', map['metas_financieras'] as List?);
      insertList('recordatorios', map['recordatorios'] as List?);

      // Restaurar Gamification
      insertList('gamification_profiles', map['gamification_profiles'] as List?);
      insertList('gamification_achievements', map['gamification_achievements'] as List?);
      insertList('gamification_events', map['gamification_events'] as List?);

      await batch.commit(noResult: true);
      debugPrint('🧩 Restauración completa exitosa');
      return true;
    } catch (e) {
      debugPrint('❌ Error restaurando: $e');
      return false;
    }
  }

  Future<List<Map<String, Object?>>> _safeQuery(Database db, String table) async {
    try {
      // Verificamos si la tabla existe antes de consultar para evitar crashes en versiones viejas
      return await db.query(table);
    } catch (_) {
      return [];
    }
  }
}