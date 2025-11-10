import '../../core/database/app_database.dart';
import '../models/category_budget_model.dart';

class CategoryBudgetRepo {
  // Obtener la instancia de AppDatabase sólo cuando se necesita (lazy).
  AppDatabase get _dbProvider => AppDatabase();

  Future<int> insert(CategoryBudget budget) async {
    final db = await _dbProvider.database;
    return db.insert('presupuestos', budget.toMap());
    }

  Future<int> update(CategoryBudget budget) async {
    if (budget.id == null) throw ArgumentError('update requiere id');
    final db = await _dbProvider.database;
    final map = budget.toMap()..remove('id');
    return db.update('presupuestos', map, where: 'id = ?', whereArgs: [budget.id]);
  }

  Future<int> delete(int id) async {
    final db = await _dbProvider.database;
    return db.delete('presupuestos', where: 'id = ?', whereArgs: [id]);
  }

  Future<CategoryBudget?> getActiveFor({
    required int usuarioId,
    required int categoriaId,
    required String periodo, // 'mensual' | 'trimestral'
    required DateTime fechaReferencia,
  }) async {
    final db = await _dbProvider.database;
    final dateStr = fechaReferencia.toIso8601String();
    final rows = await db.query(
      'presupuestos',
      where: 'usuario_id = ? AND categoria_id = ? AND periodo = ? AND activo = 1 AND fecha_inicio <= ? AND fecha_fin >= ?',
      whereArgs: [usuarioId, categoriaId, periodo, dateStr, dateStr],
      orderBy: 'fecha_inicio DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return CategoryBudget.fromMap(rows.first);
  }

  Future<List<CategoryBudget>> listForRange({
    required int usuarioId,
    required int categoriaId,
    required DateTime from,
    required DateTime to,
  }) async {
    final db = await _dbProvider.database;
    final rows = await db.query(
      'presupuestos',
      where: 'usuario_id = ? AND categoria_id = ? AND fecha_fin >= ? AND fecha_inicio <= ? AND activo = 1',
      whereArgs: [usuarioId, categoriaId, from.toIso8601String(), to.toIso8601String()],
      orderBy: 'fecha_inicio ASC',
    );
    return rows.map(CategoryBudget.fromMap).toList();
  }

  Future<int> upsert(CategoryBudget budget) async {
    final existing = await getActiveFor(
      usuarioId: budget.usuarioId,
      categoriaId: budget.categoriaId,
      periodo: budget.periodo,
      fechaReferencia: budget.fechaInicio,
    );
    if (existing != null) {
      return update(budget.copyWith(id: existing.id));
    }
    return insert(budget);
  }

  Future<void> setAlertEmitted({required int id, required int hasta}) async {
    final db = await _dbProvider.database;
    await db.update('presupuestos', {
      'alerta_emitida_hasta': hasta,
      'updated_at': DateTime.now().toIso8601String(),
    }, where: 'id = ?', whereArgs: [id]);
  }
}
