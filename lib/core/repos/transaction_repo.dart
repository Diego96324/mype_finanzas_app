import '../db/app_database.dart';
import '../models/transaction_model.dart';

class TransactionRepo {
  final _dbFuture = AppDatabase().database;

  Future<int> insert(AppTransaction t) async {
    final db = await _dbFuture;
    return db.insert('transacciones', t.toMap());
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
    if (searchTerm != null && searchTerm.isNotEmpty) {
      where.add('(etiqueta LIKE ? OR nota LIKE ?)');
      final searchPattern = '%$searchTerm%';
      args.add(searchPattern);
      args.add(searchPattern);
    }

    String orderBy;
    if (orders != null && orders.isNotEmpty) {
      List<String> orderCriteria = [];

      if (orders.contains('fecha_desc')) {
        orderCriteria.add('DATE(fecha) DESC');
      } else if (orders.contains('fecha_asc')) {
        orderCriteria.add('DATE(fecha) ASC');
      }

      if (orders.contains('monto_desc')) {
        orderCriteria.add('monto DESC');
      } else if (orders.contains('monto_asc')) {
        orderCriteria.add('monto ASC');
      }

      if (orders.contains('fecha_desc') || orders.contains('fecha_asc')) {
        if (orders.contains('fecha_desc')) {
          orderCriteria.add('fecha DESC');
        } else {
          orderCriteria.add('fecha ASC');
        }
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
}
