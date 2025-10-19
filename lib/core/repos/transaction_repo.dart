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
    String order = 'fecha_desc',
    String? searchTerm,
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

  /// Listar transacciones con filtros múltiples
  Future<List<AppTransaction>> listMultiple({
    List<String>? tipos,
    DateTime? from,
    DateTime? to,
    String order = 'fecha_desc',
    String? searchTerm,
    List<String>? orders, // Agregar parámetro para múltiples órdenes
  }) async {
    final db = await _dbFuture;

    final where = <String>[];
    final args = <dynamic>[];

    if (tipos != null && tipos.isNotEmpty && !tipos.contains('todos')) {
      // Crear condición OR para múltiples tipos
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

    // Manejar múltiples criterios de ordenamiento
    String orderBy;
    if (orders != null && orders.isNotEmpty) {
      List<String> orderCriteria = [];

      // Agregar criterios de fecha si están presentes (usando DATE() para agrupar por día)
      if (orders.contains('fecha_desc')) {
        orderCriteria.add('DATE(fecha) DESC');
      } else if (orders.contains('fecha_asc')) {
        orderCriteria.add('DATE(fecha) ASC');
      }

      // Agregar criterios de monto si están presentes (independientemente de si hay criterios de fecha)
      if (orders.contains('monto_desc')) {
        orderCriteria.add('monto DESC');
      } else if (orders.contains('monto_asc')) {
        orderCriteria.add('monto ASC');
      }

      // Si hay criterios de fecha, agregar también el timestamp como criterio final para consistencia
      if (orders.contains('fecha_desc') || orders.contains('fecha_asc')) {
        if (orders.contains('fecha_desc')) {
          orderCriteria.add('fecha DESC');
        } else {
          orderCriteria.add('fecha ASC');
        }
      }

      // Si no hay criterios específicos, usar fecha DESC como fallback
      if (orderCriteria.isEmpty) {
        orderCriteria.add('fecha DESC');
      }

      orderBy = orderCriteria.join(', ');
    } else {
      // Lógica de ordenamiento simple para compatibilidad
      switch (order) {
        case 'fecha_asc':  orderBy = 'fecha ASC'; break;
        case 'monto_desc': orderBy = 'monto DESC, fecha DESC'; break;
        case 'monto_asc':  orderBy = 'monto ASC, fecha DESC'; break;
        case 'fecha_desc':
        default:           orderBy = 'fecha DESC';
      }
    }

    final rows = await db.query(
      'transaccion',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: orderBy,
    );
    return rows.map(AppTransaction.fromMap).toList();
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
