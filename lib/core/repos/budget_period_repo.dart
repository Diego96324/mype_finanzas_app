import '../db/app_database.dart';
import '../models/budget_period_model.dart';

/// Repositorio para gestionar presupuestos por período
class BudgetPeriodRepo {
  final _db = AppDatabase();

  Future<int> insert(BudgetPeriod budget) async {
    final db = await _db.database;
    return await db.insert('budget_periods', budget.toMap());
  }

  Future<int> update(BudgetPeriod budget) async {
    final db = await _db.database;
    return await db.update(
      'budget_periods',
      budget.toMap(),
      where: 'id = ?',
      whereArgs: [budget.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await _db.database;
    return await db.delete(
      'budget_periods',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Obtiene el presupuesto para un período específico
  Future<BudgetPeriod?> getForPeriod({
    required int usuarioId,
    required String periodo,
    required int mes,
    required int anio,
  }) async {
    final db = await _db.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'budget_periods',
      where: 'usuario_id = ? AND periodo = ? AND mes = ? AND anio = ?',
      whereArgs: [usuarioId, periodo, mes, anio],
    );
    if (maps.isEmpty) return null;
    return BudgetPeriod.fromMap(maps.first);
  }

  /// Guarda o actualiza un presupuesto
  Future<int> setBudget({
    required int usuarioId,
    required double monto,
    required String periodo,
    required int mes,
    required int anio,
  }) async {
    final existing = await getForPeriod(
      usuarioId: usuarioId,
      periodo: periodo,
      mes: mes,
      anio: anio,
    );

    if (existing != null) {
      return await update(BudgetPeriod(
        id: existing.id,
        usuarioId: usuarioId,
        monto: monto,
        periodo: periodo,
        mes: mes,
        anio: anio,
      ));
    } else {
      return await insert(BudgetPeriod(
        usuarioId: usuarioId,
        monto: monto,
        periodo: periodo,
        mes: mes,
        anio: anio,
      ));
    }
  }

  /// Elimina el presupuesto para un período específico
  Future<int> deleteForPeriod({
    required int usuarioId,
    required String periodo,
    required int mes,
    required int anio,
  }) async {
    final db = await _db.database;
    return await db.delete(
      'budget_periods',
      where: 'usuario_id = ? AND periodo = ? AND mes = ? AND anio = ?',
      whereArgs: [usuarioId, periodo, mes, anio],
    );
  }

  /// Obtiene todos los presupuestos de un usuario para un año específico
  Future<List<BudgetPeriod>> getAllForYear({
    required int usuarioId,
    required int anio,
  }) async {
    final db = await _db.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'budget_periods',
      where: 'usuario_id = ? AND anio = ?',
      whereArgs: [usuarioId, anio],
      orderBy: 'mes ASC, periodo ASC',
    );
    return List.generate(maps.length, (i) => BudgetPeriod.fromMap(maps[i]));
  }
}

