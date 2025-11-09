import 'dart:math';

import '../../core/database/app_database.dart';
import '../../data/models/category_budget_model.dart';
import '../../data/repositories/category_budget_repo.dart';
import '../../data/repositories/transaction_repo.dart';

class CategoryBudgetSummary {
  final CategoryBudget budget;
  final double realAcumulado;
  final double restante;
  final double porcentaje;
  final String semaforo; // 'verde', 'amarillo', 'rojo'
  final int? nuevoUmbralEmitido; // 75, 90, 100 si corresponde
  final double? sugerenciaAjuste; // null si no aplica o autoAjuste=false

  CategoryBudgetSummary({
    required this.budget,
    required this.realAcumulado,
    required this.restante,
    required this.porcentaje,
    required this.semaforo,
    this.nuevoUmbralEmitido,
    this.sugerenciaAjuste,
  });
}

class CategoryBudgetService {
  final CategoryBudgetRepo _repo;
  final TransactionRepo _txRepo;
  final AppDatabase _db = AppDatabase();

  CategoryBudgetService({CategoryBudgetRepo? repo, TransactionRepo? txRepo})
      : _repo = repo ?? CategoryBudgetRepo(),
        _txRepo = txRepo ?? TransactionRepo();

  /// Helpers de período
  DateTimeRange _periodoMensual(DateTime fecha) {
    final start = DateTime(fecha.year, fecha.month, 1);
    final end = DateTime(fecha.year, fecha.month + 1, 0, 23, 59, 59, 999);
    return DateTimeRange(start: start, end: end);
  }

  DateTimeRange _periodoTrimestral(DateTime fecha) {
    final quarterStart = ((fecha.month - 1) ~/ 3) * 3 + 1;
    final start = DateTime(fecha.year, quarterStart, 1);
    final end = DateTime(fecha.year, quarterStart + 3, 0, 23, 59, 59, 999);
    return DateTimeRange(start: start, end: end);
  }

  DateTimeRange computeRange(String periodo, DateTime referencia) {
    switch (periodo) {
      case 'trimestral':
        return _periodoTrimestral(referencia);
      case 'mensual':
      default:
        return _periodoMensual(referencia);
    }
  }

  /// Crea/actualiza presupuesto por categoría para un período dado
  Future<int> saveBudget({
    required int usuarioId,
    required int categoriaId,
    required String nombre,
    required double montoLimite,
    required String periodo, // 'mensual' | 'trimestral'
    required DateTime referencia,
    List<int>? alertaThresholds,
    bool autoAjuste = false,
  }) async {
    final range = computeRange(periodo, referencia);
    final now = DateTime.now();
    final budget = CategoryBudget(
      usuarioId: usuarioId,
      categoriaId: categoriaId,
      nombre: nombre,
      montoLimite: montoLimite,
      periodo: periodo,
      fechaInicio: range.start,
      fechaFin: range.end,
      alertaThresholds: alertaThresholds ?? const [75, 90, 100],
      autoAjuste: autoAjuste,
      createdAt: now,
      updatedAt: now,
    );
    return _repo.upsert(budget);
  }

  Future<List<int>> _subcategoriaIds(int categoriaId) async {
    try {
      final db = await _db.database;
      final rows = await db.query('categorias', columns: ['id'], where: 'categoria_padre_id = ? AND activa = 1', whereArgs: [categoriaId]);
      return rows.map((r) => r['id'] as int).toList();
    } catch (_) {
      return [];
    }
  }

  /// Calcula ejecución real (egresos) para el período del presupuesto
  Future<double> _calcEgresoCategoria({
    required int usuarioId,
    required int categoriaId,
    required DateTime from,
    required DateTime to,
  }) async {
    final list = await _txRepo.list(
      usuarioId: usuarioId,
      tipo: 'egreso',
      from: from,
      to: to,
    );
    final hijos = await _subcategoriaIds(categoriaId);
    final idsAceptados = {categoriaId, ...hijos};
    final total = list
        .where((t) => t.confirmada && t.categoriaId != null && idsAceptados.contains(t.categoriaId))
        .fold<double>(0.0, (sum, t) => sum + t.monto);
    return total;
  }

  String _colorSemaforo(double pct) {
    if (pct >= 100.0) return 'rojo';
    if (pct >= 90.0) return 'amarillo';
    if (pct >= 75.0) return 'amarillo';
    return 'verde';
  }

  /// Retorna el presupuesto activo y su resumen, actualizando alerta_emitida_hasta si corresponde
  Future<CategoryBudgetSummary?> getSummary({
    required int usuarioId,
    required int categoriaId,
    required String periodo,
    required DateTime referencia,
  }) async {
    final budget = await _repo.getActiveFor(
      usuarioId: usuarioId,
      categoriaId: categoriaId,
      periodo: periodo,
      fechaReferencia: referencia,
    );
    if (budget == null) return null;

    final real = await _calcEgresoCategoria(
      usuarioId: usuarioId,
      categoriaId: categoriaId,
      from: budget.fechaInicio,
      to: budget.fechaFin,
    );
    final pct = budget.montoLimite == 0 ? 0.0 : (real / budget.montoLimite) * 100.0;
    final restante = max(0.0, budget.montoLimite - real);

    // determinar nuevo umbral alcanzado
    final reached = budget.alertaThresholds.where((t) => pct >= t).fold<int>(0, (prev, t) => t > prev ? t : prev);
    int? nuevoUmbral;
    if (reached > budget.alertaEmitidaHasta) {
      await _repo.setAlertEmitted(id: budget.id!, hasta: reached);
      nuevoUmbral = reached;
    }

    double? sugerencia;
    if (budget.autoAjuste && pct > 110.0) {
      sugerencia = await _proponerAjuste(
        usuarioId: usuarioId,
        categoriaId: categoriaId,
        periodo: periodo,
        referencia: referencia,
      );
    }

    return CategoryBudgetSummary(
      budget: budget,
      realAcumulado: real,
      restante: restante,
      porcentaje: pct,
      semaforo: _colorSemaforo(pct),
      nuevoUmbralEmitido: nuevoUmbral,
      sugerenciaAjuste: sugerencia,
    );
  }

  Future<double?> _proponerAjuste({
    required int usuarioId,
    required int categoriaId,
    required String periodo,
    required DateTime referencia,
  }) async {
    final valores = <double>[];
    if (periodo == 'mensual') {
      for (int i = 1; i <= 3; i++) {
        final date = DateTime(referencia.year, referencia.month - i, 15);
        final range = computeRange('mensual', date);
        final val = await _calcEgresoCategoria(
          usuarioId: usuarioId,
          categoriaId: categoriaId,
          from: range.start,
          to: range.end,
        );
        valores.add(val);
      }
    } else if (periodo == 'trimestral') {
      for (int i = 1; i <= 3; i++) {
        final date = DateTime(referencia.year, referencia.month - (i * 3), 15);
        final range = computeRange('trimestral', date);
        final val = await _calcEgresoCategoria(
          usuarioId: usuarioId,
          categoriaId: categoriaId,
          from: range.start,
          to: range.end,
        );
        valores.add(val);
      }
    }
    if (valores.isEmpty) return null;
    final promedio = valores.reduce((a, b) => a + b) / valores.length;
    return double.parse((promedio * 1.05).toStringAsFixed(2));
  }
}

class DateTimeRange {
  final DateTime start;
  final DateTime end;
  const DateTimeRange({required this.start, required this.end});
}
