import 'package:sqflite/sqflite.dart';
import '../db/app_database.dart';
import '../models/transaction_model.dart';

class TransactionRepo {
  final _dbFuture = AppDatabase().database;

  /// Insertar una transacción
  Future<int> insert(AppTransaction t) async {
    final db = await _dbFuture;
    return db.insert('transaccion', t.toMap());
  }

  /// Listar transacciones con filtros opcionales
  Future<List<AppTransaction>> list({
    String? tipo,
    DateTime? from,
    DateTime? to,
    String order = 'fecha_desc'
  }) async {
    final db = await _dbFuture;

    final where = <String>[];
    final args = <dynamic>[];

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

    String orderBy;
    switch (order) {
      case 'fecha_asc':  orderBy = 'fecha ASC'; break;
      case 'monto_desc': orderBy = 'monto DESC, fecha DESC'; break;
      case 'monto_asc':  orderBy = 'monto ASC, fecha DESC'; break;
      case 'fecha_desc':
      default:           orderBy = 'fecha DESC';
    }

    final rows = await db.query(
      'transaccion',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: orderBy,
    );
    return rows.map(AppTransaction.fromMap).toList();
  }


  /// Obtener total por tipo (ingreso/egreso)
  Future<double> total(String tipo) async {
    final db = await _dbFuture;
    final rows = await db.rawQuery(
      'SELECT SUM(monto) as total FROM transaccion WHERE tipo = ?',
      [tipo],
    );
    final value = rows.first['total'] as num?;
    return (value ?? 0).toDouble();
  }

  // Funcion Delete
  Future<int> delete(int id) async {
    final db = await _dbFuture;
    return db.delete('transaccion', where: 'id = ?', whereArgs: [id]);
  }

  // Funcion Update
  Future<int> update(AppTransaction t) async {
    if (t.id == null) {
      throw ArgumentError('update() requiere un id');
    }
    final db = await _dbFuture;
    final map = t.toMap()..remove('id');
    return db.update('transaccion', map, where: 'id = ?', whereArgs: [t.id]);
  }

  // Funcion GetById
  Future<AppTransaction?> getById(int id) async {
    final db = await _dbFuture;
    final res = await db.query(
      'transaccion',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (res.isEmpty) return null;
    return AppTransaction.fromMap(res.first);
  }


}
