import 'package:sqflite/sqflite.dart';
import '../../core/database/app_database.dart';
import '../../../data/models/transaction_model.dart';

class TransactionRepo {
  final Future<Database> _dbFuture;
  TransactionRepo({Future<Database>? dbFuture}) : _dbFuture = dbFuture ?? AppDatabase().database;
  TransactionRepo.withDb(Database db) : _dbFuture = Future.value(db);

  Future<int> insert(AppTransaction t) async {
    final db = await _dbFuture;
    return db.insert('transacciones', t.toMap());
  }

  Future<int> insertAndGetId(AppTransaction t) async {
    final db = await _dbFuture;
    return await db.insert('transacciones', t.toMap());
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

  Future<double> total(String tipo, {int? usuarioId}) async {
    final db = await _dbFuture;
    final where = <String>['tipo = ?'];
    final args = <dynamic>[tipo];

    if (usuarioId != null) {
      where.add('usuario_id = ?');
      args.add(usuarioId);
    }

    final rows = await db.rawQuery(
      'SELECT SUM(monto) as total FROM transacciones WHERE ${where.join(' AND ')}',
      args,
    );
    final value = rows.first['total'] as num?;
    return (value ?? 0).toDouble();
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
    final map = t.toMap()..remove('id');
    return db.update('transacciones', map, where: 'id = ?', whereArgs: [t.id]);
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