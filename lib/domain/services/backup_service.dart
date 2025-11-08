import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../../core/database/app_database.dart';

/// Servicio para respaldo y restauración ligera de datos críticos.
/// No pretende ser un dump completo, pero evita pérdida total accidental.
class BackupService {
  static const _backupFileName = 'backup_mype_finanzas.json';
  static const _backupMetaName = 'backup_meta.txt';

  Future<File> _getBackupFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_backupFileName');
  }

  Future<File> _getMetaFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_backupMetaName');
  }

  /// Exporta tablas clave a un archivo JSON.
  /// Se llama tras login/registro y podría llamarse tras operaciones masivas.
  Future<void> exportBackup() async {
    try {
      final db = await AppDatabase().database;

      // Tablas críticas (añade más si hace falta): usuarios, cuentas, categorias, transacciones
      final usuarios = await db.query('usuarios');
      final cuentas = await _safeQuery(db, 'cuentas');
      final categorias = await db.query('categorias', where: 'usuario_id IS NOT NULL');
      final transacciones = await db.query('transacciones');

      final payload = {
        'version': 1,
        'timestamp': DateTime.now().toIso8601String(),
        'usuarios': usuarios,
        'cuentas': cuentas,
        'categorias': categorias,
        'transacciones': transacciones,
      };

      final file = await _getBackupFile();
      await file.writeAsString(jsonEncode(payload));

      final meta = await _getMetaFile();
      await meta.writeAsString('last_backup=${DateTime.now().toIso8601String()}\nrows_usuarios=${usuarios.length}');

      debugPrint('💾 Backup exportado (${usuarios.length} usuarios, ${transacciones.length} transacciones)');
    } catch (e) {
      debugPrint('⚠️ Error exportando backup: $e');
    }
  }

  /// Restaura datos si la BD está vacía (sin usuarios). Evita sobreescribir si ya hay datos.
  Future<bool> restoreIfEmpty() async {
    try {
      final db = await AppDatabase().database;
      final usuarioCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM usuarios')) ?? 0;
      if (usuarioCount > 0) {
        debugPrint('🔁 Restauración omitida (ya hay $usuarioCount usuarios)');
        return false; // no restauró
      }

      final file = await _getBackupFile();
      if (!(await file.exists())) {
        debugPrint('📂 No existe archivo de backup para restaurar');
        return false;
      }

      final content = await file.readAsString();
      final map = jsonDecode(content) as Map<String, dynamic>;

      final batch = db.batch();

      void insertList(String table, List<dynamic>? rows) {
        if (rows == null) return;
        for (final r in rows) {
          final row = Map<String, Object?>.from(r as Map);
          // Eliminar id para permitir autoincrement (excepto si realmente quieres mantenerlo)
          row.remove('id');
          batch.insert(table, row, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      }

      insertList('usuarios', map['usuarios'] as List?);
      insertList('cuentas', map['cuentas'] as List?);
      insertList('categorias', map['categorias'] as List?);
      insertList('transacciones', map['transacciones'] as List?);

      await batch.commit(noResult: true);
      debugPrint('🧩 Restauración desde backup completada');
      return true;
    } catch (e) {
      debugPrint('❌ Error restaurando backup: $e');
      return false;
    }
  }

  Future<List<Map<String, Object?>>> _safeQuery(Database db, String table) async {
    try {
      return await db.query(table);
    } catch (_) {
      return [];
    }
  }
}
