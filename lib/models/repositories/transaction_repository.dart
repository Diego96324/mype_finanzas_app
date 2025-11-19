import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';
import '../dtos/transaction_model.dart';
import 'gamification_repository.dart';
import '../../controllers/services/gamification_service.dart';

class TransactionRepo {
  final Future<Database>? _overrideDbFuture;
  TransactionRepo({Future<Database>? dbFuture}) : _overrideDbFuture = dbFuture;
  TransactionRepo.withDb(Database db) : _overrideDbFuture = Future.value(db);

  Future<Database> get _dbFuture async => _overrideDbFuture ?? AppDatabase().database;

  // Cache simple de columnas por tabla para evitar múltiples PRAGMA
  final Map<String, Set<String>> _tableColumnsCache = {};

  // Servicio de gamificación (lazy initialization)
  GamificationService? _gamificationService;
  GamificationService get _gamification {
    _gamificationService ??= GamificationService(GamificationRepository());
    return _gamificationService!;
  }

  Future<Set<String>> _getTableColumns(Database db, String tableName) async {
    if (_tableColumnsCache.containsKey(tableName)) return _tableColumnsCache[tableName]!;
    try {
      final info = await db.rawQuery('PRAGMA table_info($tableName)');
      final cols = <String>{};
      for (final row in info) {
        final name = row['name'] as String?;
        if (name != null) cols.add(name);
      }
      _tableColumnsCache[tableName] = cols;
      return cols;
    } catch (e) {
      return <String>{};
    }
  }

  Future<Map<String, dynamic>> _filterMapForTable(Database db, String tableName, Map<String, dynamic> input) async {
    final cols = await _getTableColumns(db, tableName);
    if (cols.isEmpty) return input; // si no conocemos columnas, devolver original (fall-back)
    final out = <String, dynamic>{};
    input.forEach((k, v) {
      if (cols.contains(k)) out[k] = v;
    });
    return out;
  }

  /// Registra evento de gamificación según el tipo de transacción
  Future<void> _recordGamificationEvent(AppTransaction t) async {
    try {
      // No registrar gamificación para transacciones de apertura de cuenta
      if (t.esAperturaCuenta) return;

      final usuarioId = t.usuarioId;
      final monto = t.monto;
      // IMPORTANTE: No usamos `etiqueta` como descripción del evento de gamificación
      // porque la etiqueta es metadata y no debe aparecer como motivo para otorgar puntos.
      String? descripcion;
      if (t.descripcion != null && t.descripcion!.trim().isNotEmpty) {
        descripcion = t.descripcion!.trim();
      } else if (t.nota != null && t.nota!.trim().isNotEmpty) {
        descripcion = t.nota!.trim();
      } else {
        descripcion = null;
      }

      switch (t.tipo) {
        case 'ingreso':
          await _gamification.recordIncome(usuarioId, monto, descripcion: descripcion);
          break;
        case 'egreso':
          await _gamification.recordExpense(usuarioId, monto, descripcion: descripcion);
          break;
        case 'transferencia':
          await _gamification.recordTransfer(usuarioId, monto, descripcion: descripcion);
          break;
      }
    } catch (e) {
      // No bloquear la transacción si falla la gamificación
      // debugPrint('⚠️ Error registrando gamificación: $e');
    }
  }

  Future<int> insert(AppTransaction t) async {
    final db = await _dbFuture;
    final raw = t.toMap();
    final filtered = await _filterMapForTable(db, 'transacciones', raw);
    // Ensure we don't pass an explicit id to SQLite insert; let AUTOINCREMENT assign it
    filtered.remove('id');
    final id = await db.insert('transacciones', filtered);

    // 🎮 Registrar evento de gamificación
    await _recordGamificationEvent(t);

    return id;
  }

  Future<int> insertAndGetId(AppTransaction t) async {
    final db = await _dbFuture;
    final raw = t.toMap();
    final filtered = await _filterMapForTable(db, 'transacciones', raw);
    // Ensure we don't pass an explicit id to SQLite insert; let AUTOINCREMENT assign it
    filtered.remove('id');
    final id = await db.insert('transacciones', filtered);

    // 🎮 Registrar evento de gamificación
    await _recordGamificationEvent(t);

    return id;
  }

  Future<List<AppTransaction>> list({
    int? usuarioId,
    String? tipo,
    DateTime? from,
    DateTime? to,
    String order = 'fecha_desc',
    String? searchTerm,
  }) async {
    final db = await _dbFuture;

    final where = <String>[];
    final args = <dynamic>[];

    if (usuarioId != null) {
      where.add('usuario_id = ?');
      args.add(usuarioId);
    }
    if (tipo != null) {
      where.add('tipo = ?');
      args.add(tipo);
    }
    if (from != null) {
      where.add('fecha >= ?');
      args.add(from.toIso8601String());
    }
    if (to != null) {
      final inclusive = DateTime(to.year, to.month, to.day, 23, 59, 59, 999);
      where.add('fecha <= ?');
      args.add(inclusive.toIso8601String());
    }
    if (searchTerm != null && searchTerm.isNotEmpty) {
      where.add('(etiqueta LIKE ? OR nota LIKE ?)');
      final searchPattern = '%$searchTerm%';
      args.add(searchPattern);
      args.add(searchPattern);
    }

    String orderBy;
    switch (order) {
      case 'fecha_asc':  orderBy = 'fecha ASC'; break;
      case 'monto_desc': orderBy = 'monto DESC, fecha DESC'; break;
      case 'monto_asc':  orderBy = 'monto ASC, fecha DESC'; break;
      case 'fecha_desc':
      default:           orderBy = 'fecha DESC';
    }

    final rows = await db.query(
      'transacciones',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: orderBy,
    );
    return rows.map(AppTransaction.fromMap).toList();
  }

  // Helper: comprobar si la tabla contiene una columna (para compatibilidad con DB antiguas)
  Future<bool> _tableHasColumn(Database db, String tableName, String columnName) async {
    try {
      final info = await db.rawQuery('PRAGMA table_info($tableName)');
      for (final row in info) {
        final name = row['name'] as String?;
        if (name == columnName) return true;
      }
      return false;
    } catch (e) {
      // En caso de error asumimos que no existe para evitar excepciones en consultas
      return false;
    }
  }

  Future<double> total(String tipo, {int? usuarioId}) async {
    final db = await _dbFuture;
    final where = <String>['tipo = ?'];
    final args = <dynamic>[tipo];

    // Añadir filtro por afecta_saldo solo si la columna existe en la tabla
    final hasAfecta = await _tableHasColumn(db, 'transacciones', 'afecta_saldo');
    if (hasAfecta) {
      where.add('afecta_saldo = 1');
    }

    if (usuarioId != null) {
      where.add('usuario_id = ?');
      args.add(usuarioId);
    }

    try {
      final rows = await db.rawQuery(
        'SELECT SUM(monto) as total FROM transacciones WHERE ${where.join(' AND ')}',
        args,
      );
      final value = rows.first['total'] as num?;
      return (value ?? 0).toDouble();
    } catch (e) {
      // Si hubo un error SQL (ej. columna no existente), reintentar sin el filtro afecta_saldo
      try {
        final fallbackWhere = <String>['tipo = ?'];
        final fallbackArgs = <dynamic>[tipo];
        if (usuarioId != null) {
          fallbackWhere.add('usuario_id = ?');
          fallbackArgs.add(usuarioId);
        }
        final rows = await db.rawQuery(
          'SELECT SUM(monto) as total FROM transacciones WHERE ${fallbackWhere.join(' AND ')}',
          fallbackArgs,
        );
        final value = rows.first['total'] as num?;
        return (value ?? 0).toDouble();
      } catch (e2) {
        // En caso extremo devolvemos 0 y logueamos
        // debugPrint('Error calculando total: $e / $e2');
        return 0.0;
      }
    }
  }

  Future<List<AppTransaction>> listMultiple({
    int? usuarioId,
    List<String>? tipos,
    DateTime? from,
    DateTime? to,
    String order = 'fecha_desc',
    String? searchTerm,
    List<String>? orders,
    List<int>? categoriaIds,
    double? minAmount,
    double? maxAmount,
    bool tagOnly = false,
    bool? onlyRecurrent,
    bool? hasAttachment,
    String? frecuencia,
    bool noteOnly = false,
    int? limit,
    int? offset,
  }) async {
    final db = await _dbFuture;

    final where = <String>[];
    final args = <dynamic>[];

    if (usuarioId != null) {
      where.add('usuario_id = ?');
      args.add(usuarioId);
    }
    if (tipos != null && tipos.isNotEmpty && !tipos.contains('todos')) {
      final tipoConditions = tipos.map((_) => 'tipo = ?').join(' OR ');
      where.add('($tipoConditions)');
      args.addAll(tipos);
    }
    if (from != null) {
      where.add('fecha >= ?');
      args.add(from.toIso8601String());
    }
    if (to != null) {
      final inclusive = DateTime(to.year, to.month, to.day, 23, 59, 59, 999);
      where.add('fecha <= ?');
      args.add(inclusive.toIso8601String());
    }
    if (categoriaIds != null && categoriaIds.isNotEmpty) {
      if (categoriaIds.length == 1) {
        where.add('categoria_id = ?');
        args.add(categoriaIds.first);
      } else {
        final placeholders = List.filled(categoriaIds.length, '?').join(',');
        where.add('categoria_id IN ($placeholders)');
        args.addAll(categoriaIds);
      }
    }
    if (minAmount != null) {
      where.add('monto >= ?');
      args.add(minAmount);
    }
    if (maxAmount != null) {
      where.add('monto <= ?');
      args.add(maxAmount);
    }
    if (searchTerm != null && searchTerm.isNotEmpty) {
      final searchPattern = '%$searchTerm%';
      if (tagOnly) {
        where.add('etiqueta LIKE ?');
        args.add(searchPattern);
      } else if (noteOnly) {
        where.add('nota LIKE ?');
        args.add(searchPattern);
      } else {
        where.add('(etiqueta LIKE ? OR nota LIKE ?)');
        args.add(searchPattern);
        args.add(searchPattern);
      }
    }
    if (frecuencia != null && frecuencia.isNotEmpty) {
      where.add('frecuencia_recurrencia = ?');
      args.add(frecuencia);
    }
    if (onlyRecurrent != null) {
      if (onlyRecurrent) {
        where.add('recurrente = 1 AND frecuencia_recurrencia IS NOT NULL AND frecuencia_recurrencia != "una_vez"');
      } else {
        where.add('(recurrente = 0 OR frecuencia_recurrencia IS NULL OR frecuencia_recurrencia = "una_vez")');
      }
    }
    if (hasAttachment != null) {
      if (hasAttachment) {
        where.add('comprobante_uri IS NOT NULL AND comprobante_uri != ""');
      } else {
        where.add('(comprobante_uri IS NULL OR comprobante_uri = "")');
      }
    }

    String orderBy;
    if (orders != null && orders.isNotEmpty) {
      List<String> orderCriteria = [];
      if (orders.contains('fecha_desc')) {
        orderCriteria.add('fecha DESC');
      } else if (orders.contains('fecha_asc')) {
        orderCriteria.add('fecha ASC');
      }
      if (orders.contains('monto_desc')) {
        orderCriteria.add('monto DESC');
      } else if (orders.contains('monto_asc')) {
        orderCriteria.add('monto ASC');
      }
      if (orderCriteria.isEmpty) {
        orderCriteria.add('fecha DESC');
      }
      orderBy = orderCriteria.join(', ');
    } else {
      switch (order) {
        case 'fecha_asc':  orderBy = 'fecha ASC'; break;
        case 'monto_desc': orderBy = 'monto DESC, fecha DESC'; break;
        case 'monto_asc':  orderBy = 'monto ASC, fecha DESC'; break;
        case 'fecha_desc':
        default:           orderBy = 'fecha DESC';
      }
    }

    final rows = await db.query(
      'transacciones',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
    return rows.map(AppTransaction.fromMap).toList();
  }

  Future<int> delete(int id) async {
    final db = await _dbFuture;
    return db.delete('transacciones', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> update(AppTransaction t) async {
    if (t.id == null) {
      throw ArgumentError('update() requiere un id');
    }
    final db = await _dbFuture;
    final raw = t.toMap()..remove('id');
    final filtered = await _filterMapForTable(db, 'transacciones', raw);
    return db.update('transacciones', filtered, where: 'id = ?', whereArgs: [t.id]);
  }

  Future<AppTransaction?> getById(int id) async {
    final db = await _dbFuture;
    final res = await db.query(
      'transacciones',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (res.isEmpty) return null;
    return AppTransaction.fromMap(res.first);
  }

  Future<Map<String, double>> getStats({int? usuarioId}) async {
    final ingresos = await total('ingreso', usuarioId: usuarioId);
    final egresos = await total('egreso', usuarioId: usuarioId);
    final saldo = ingresos - egresos;

    return {
      'ingresos': ingresos,
      'egresos': egresos,
      'saldo': saldo,
    };
  }

  Future<bool> existsChildAtDate({required int usuarioId, required DateTime fecha}) async {
    final db = await _dbFuture;
    final rows = await db.query(
      'transacciones',
      columns: ['id'],
      where: 'usuario_id = ? AND fecha = ? AND es_recurrente = 1',
      whereArgs: [usuarioId, fecha.toIso8601String()],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<List<String?>> getAllAttachmentPaths() async {
    final db = await _dbFuture;
    final rows = await db.query('transacciones', columns: ['comprobante_uri'], where: 'comprobante_uri IS NOT NULL AND comprobante_uri != ""');
    return rows.map((r) => r['comprobante_uri'] as String?).toList();
  }
}