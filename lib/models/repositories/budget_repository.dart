import '../dtos/budget_model.dart';
import '../database/app_database.dart';

class BudgetRepo {
  final _db = AppDatabase();

  Future<int> insert(Budget budget) async {
    final db = await _db.database;
    return await db.insert('budgets', budget.toMap());
  }

  Future<int> update(Budget budget) async {
    final db = await _db.database;
    return await db.update(
      'budgets',
      budget.toMap(),
      where: 'id = ?',
      whereArgs: [budget.id],
    );
  }

  Future<Budget?> getForMonth({
    required int usuarioId,
    required int mes,
    required int anio,
  }) async {
    final db = await _db.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'budgets',
      where: 'usuario_id = ? AND mes = ? AND anio = ?',
      whereArgs: [usuarioId, mes, anio],
    );
    if (maps.isEmpty) return null;
    return Budget.fromMap(maps.first);
  }

  Future<int> setMonthlyBudget({
    required int usuarioId,
    required double monto,
    required int mes,
    required int anio,
  }) async {
    final existing = await getForMonth(
      usuarioId: usuarioId,
      mes: mes,
      anio: anio,
    );

    if (existing != null) {
      return await update(Budget(
        id: existing.id,
        usuarioId: usuarioId,
        monto: monto,
        mes: mes,
        anio: anio,
      ));
    } else {
      return await insert(Budget(
        usuarioId: usuarioId,
        monto: monto,
        mes: mes,
        anio: anio,
      ));
    }
  }

  Future<int> delete(int id) async {
    final db = await _db.database;
    return await db.delete(
      'budgets',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteForMonth({
    required int usuarioId,
    required int mes,
    required int anio,
  }) async {
    final db = await _db.database;
    return await db.delete(
      'budgets',
      where: 'usuario_id = ? AND mes = ? AND anio = ?',
      whereArgs: [usuarioId, mes, anio],
    );
  }
}

