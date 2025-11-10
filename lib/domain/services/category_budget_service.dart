import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    // Buscamos recursivamente todas las subcategorías (hijas, nietas, etc.)
    try {
      final db = await _db.database;
      final result = <int>{};
      final queue = <int>[categoriaId];

      while (queue.isNotEmpty) {
        final current = queue.removeLast();
        // Buscar hijos directos del nodo actual
        final rows = await db.query(
          'categorias',
          columns: ['id'],
          where: 'categoria_padre_id = ? AND activa = 1',
          whereArgs: [current],
        );
        for (final r in rows) {
          final id = r['id'] as int?;
          if (id != null && !result.contains(id)) {
            result.add(id);
            queue.add(id);
          }
        }
      }

      return result.toList();
    } catch (e) {
      debugPrint('⚠️ Error al obtener subcategorías recursivas para $categoriaId: $e');
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
    String _normalize(String s) {
      final map = {
        'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u',
        'Á': 'A', 'É': 'E', 'Í': 'I', 'Ó': 'O', 'Ú': 'U', 'Ü': 'U',
        'ñ': 'n', 'Ñ': 'N'
      };
      var out = s.toLowerCase().trim();
      map.forEach((k, v) { out = out.replaceAll(k, v); });
      out = out.replaceAll(RegExp(r'[^a-z0-9]'), '');
      return out;
    }

    // Obtener recursivamente subcategorías
    final hijos = await _subcategoriaIds(categoriaId);
    final idsAceptados = <int>[categoriaId, ...hijos];

    debugPrint('🔍 [CategoryBudgetService] Calculando egresos para categoria $categoriaId (incluye ${hijos.length} subcats): ids=$idsAceptados, range=$from - $to');

    // Obtener nombres de las categorias buscadas (para logs y validación)
    try {
      final db = await _db.database;
      final catRows = await db.query('categorias', columns: ['id', 'nombre'], where: 'id IN (${List.filled(idsAceptados.length, '?').join(',')})', whereArgs: idsAceptados);
      final names = catRows.map((r) => '${r['id']}:${r['nombre']}').toList();
      debugPrint('🔍 [CategoryBudgetService] nombres categorias buscadas: $names');
    } catch (e) {
      debugPrint('⚠️ [CategoryBudgetService] no se pudieron obtener nombres de categorias: $e');
    }

    // Usar listMultiple con filtro de categorias para que la consulta sea ejecutada en la DB
    final list = await _txRepo.listMultiple(
      usuarioId: usuarioId,
      tipos: ['egreso'],
      from: from,
      to: to,
      categoriaIds: idsAceptados,
      order: 'fecha_desc',
    );

    debugPrint('🔎 [CategoryBudgetService] transacciones encontradas=${list.length} para categorias=$idsAceptados');
    for (final tx in list) {
      debugPrint('   - tx id=${tx.id} categoria=${tx.categoriaId} monto=${tx.monto} fecha=${tx.fecha.toIso8601String()} confirmada=${tx.confirmada}');
    }

    // Asegurarnos de contar solo transacciones confirmadas
    final total = list.where((t) => t.confirmada).fold<double>(0.0, (sum, t) => sum + t.monto);
    debugPrint('   → total calculado (confirmadas) = $total');

    // Si no se encontró nada, imprimir un fallback de todas las transacciones egreso en el rango
    if (list.isEmpty || total == 0.0) {
      try {
        final allEgresos = await _txRepo.listMultiple(
          usuarioId: usuarioId,
          tipos: ['egreso'],
          from: from,
          to: to,
          order: 'fecha_desc',
          limit: 50,
        );
        debugPrint('⚠️ [CategoryBudgetService] fallback: total egresos en rango (sin filtrar por categoria) = ${allEgresos.length}');
        for (final tx in allEgresos) {
          debugPrint('   * fallback tx id=${tx.id} categoria=${tx.categoriaId} monto=${tx.monto} fecha=${tx.fecha.toIso8601String()} confirmada=${tx.confirmada}');
        }

        // Agrupar y sumar montos por categoria para ver claramente dónde está el dinero
        final Map<int, double> sumsByCat = {};
        for (final tx in allEgresos) {
          final cid = tx.categoriaId;
          if (cid == null) continue;
          sumsByCat[cid] = (sumsByCat[cid] ?? 0) + tx.monto;
        }
        if (sumsByCat.isNotEmpty) {
          debugPrint('⚠️ [CategoryBudgetService] Sumas por categoria en rango:');
          sumsByCat.forEach((cid, amt) async {
            try {
              final db = await _db.database;
              final rows = await db.query('categorias', columns: ['nombre'], where: 'id = ?', whereArgs: [cid]);
              final name = rows.isNotEmpty ? (rows.first['nombre'] as String) : 'id_$cid';
              debugPrint('   - categoria $cid ($name): S/ ${amt.toStringAsFixed(2)}');
            } catch (_) {
              debugPrint('   - categoria $cid: S/ ${amt.toStringAsFixed(2)}');
            }
          });
        }

        // Mapear ids de fallback a nombres para facilitar diagnóstico
        try {
          final db = await _db.database;
          final fallbackIds = allEgresos.map((e) => e.categoriaId).whereType<int>().toSet().toList();
          if (fallbackIds.isNotEmpty) {
            final rows = await db.query('categorias', columns: ['id', 'nombre'], where: 'id IN (${List.filled(fallbackIds.length, '?').join(',')})', whereArgs: fallbackIds);
            final mapped = rows.map((r) => '${r['id']}:${r['nombre']}').toList();
            debugPrint('⚠️ [CategoryBudgetService] categorias en fallback: $mapped');
          }
        } catch (e) {
          debugPrint('⚠️ [CategoryBudgetService] no se pudieron obtener nombres de categorias para fallback: $e');
        }

        // Intento heurístico: buscar por nombre de la categoría objetivo (case-insensitive)
        try {
          final db = await _db.database;
          final catRow = await db.query('categorias', columns: ['id', 'nombre'], where: 'id = ?', whereArgs: [categoriaId]);
          if (catRow.isNotEmpty) {
            final targetNameRaw = (catRow.first['nombre'] as String);
            final targetName = _normalize(targetNameRaw);
            debugPrint('⚠️ [CategoryBudgetService] nombre de categoria objetivo: $targetNameRaw (normalized=$targetName) id=$categoriaId');

            // Cargar todas las categorias y normalizar nombres para comparación más robusta
            final allCatRows = await db.query('categorias', columns: ['id', 'nombre']);
            final similarIds = <int>[];
            for (final r in allCatRows) {
              final id = r['id'] as int?;
              final name = (r['nombre'] as String?) ?? '';
              if (id == null) continue;
              final n = _normalize(name);
              if (n == targetName || n.contains(targetName) || targetName.contains(n)) {
                similarIds.add(id);
              }
            }

            if (similarIds.isNotEmpty) {
              final similar = similarIds.map((i) => i.toString()).toList();
              debugPrint('⚠️ [CategoryBudgetService] categorias similares por normalización encontradas ids: $similar');
              final mergedIds = <int>[...idsAceptados, ...similarIds].toSet().toList();
              debugPrint('⚠️ [CategoryBudgetService] reintentando consulta con ids extendidos: $mergedIds');
              final retryList = await _txRepo.listMultiple(
                usuarioId: usuarioId,
                tipos: ['egreso'],
                from: from,
                to: to,
                categoriaIds: mergedIds,
                order: 'fecha_desc',
              );
              debugPrint('⚠️ [CategoryBudgetService] reintento transacciones encontradas=${retryList.length}');
              for (final tx in retryList) {
                debugPrint('   - retry tx id=${tx.id} categoria=${tx.categoriaId} monto=${tx.monto} fecha=${tx.fecha.toIso8601String()} confirmada=${tx.confirmada}');
              }
              final retryTotal = retryList.where((t) => t.confirmada).fold<double>(0.0, (s, t) => s + t.monto);
              debugPrint('   → total calculado en reintento (confirmadas) = $retryTotal');
              if (retryTotal > 0) return retryTotal;
            }
          }
        } catch (e) {
          debugPrint('⚠️ [CategoryBudgetService] error heurística por nombre: $e');
        }
      } catch (e) {
        debugPrint('⚠️ [CategoryBudgetService] error en fallback listMultiple: $e');
      }
    }
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
    bool persistAlertChange = true,
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
      // Se superó un umbral nuevo: si se permite persistir, marcar y notificar.
      if (persistAlertChange) {
        await _repo.setAlertEmitted(id: budget.id!, hasta: reached);
      }
      nuevoUmbral = reached;
    } else if (reached < budget.alertaEmitidaHasta) {
      // El uso bajó por debajo del último umbral mostrado: resetear el estado
      // para permitir que, si se supera de nuevo, vuelva a emitir notificaciones.
      if (persistAlertChange) {
        try {
          await _repo.setAlertEmitted(id: budget.id!, hasta: reached);
          // También actualizar la preferencia que utiliza GlobalAlertService
          try {
            final prefs = await SharedPreferences.getInstance();
            final key = 'budget_alert_${budget.fechaInicio.year}_${budget.fechaInicio.month}_${budget.periodo}_${budget.categoriaId}';
            await prefs.setInt(key, reached);
            debugPrint('\u2139\ufe0f [CategoryBudgetService] SharedPreferences $key actualizado a $reached');

            // Además: si existe la notificación marcada como mostrada, eliminarla
            // para permitir que vuelva a mostrarse en futuras verificaciones.
            final shownKey = 'budget_shown_notifications';
            final shownIds = prefs.getStringList(shownKey) ?? [];
            final notifId = 'category_${budget.periodo}_${budget.categoriaId}_${budget.fechaInicio.year}_${budget.fechaInicio.month}';
            if (shownIds.contains(notifId)) {
              shownIds.remove(notifId);
              await prefs.setStringList(shownKey, shownIds);
              debugPrint('\u2139\ufe0f [CategoryBudgetService] Removida notificación $notifId de $shownKey para permitir re-notificación');
            }
          } catch (e) {
            debugPrint('\u26a0\ufe0f [CategoryBudgetService] No se pudo actualizar SharedPreferences: $e');
          }
          debugPrint('\u2139\ufe0f [CategoryBudgetService] alertaEmitidaHasta reducida para budget.id=${budget.id} de ${budget.alertaEmitidaHasta} a $reached');
        } catch (_) {
          // no bloquear el flujo por errores de persistencia
        }
      }
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

  /// Devuelve los montos totales por categoria (categoriaId + nombre + monto) en el rango dado
  Future<List<Map<String, dynamic>>> getCategorySumsInRange({
    required int usuarioId,
    required DateTime from,
    required DateTime to,
    int limit = 50,
    int? rootCategoryId, // si se provee, filtrar sólo la rama de esta categoría
  }) async {
    // Obtener transacciones confirmadas en el rango
    final txList = await _txRepo.listMultiple(
      usuarioId: usuarioId,
      tipos: ['egreso'],
      from: from,
      to: to,
      order: 'fecha_desc',
      limit: limit,
    );
    final confirmed = txList.where((t) => t.confirmada).toList();
    if (confirmed.isEmpty) return [];

    // Cargar todas las categorías para poder construir la jerarquía (padre) y el tipo
    final db = await _db.database;
    final allCats = await db.query('categorias', columns: ['id', 'categoria_padre_id', 'nombre', 'tipo']);
    final Map<int, int?> parent = {};
    final Map<int, String> names = {};
    final Map<int, String> types = {};
    for (final r in allCats) {
      final id = r['id'] as int?;
      if (id == null) continue;
      parent[id] = r['categoria_padre_id'] as int?;
      names[id] = (r['nombre'] as String?) ?? 'id_$id';
      types[id] = (r['tipo'] as String?) ?? '';
    }

    // Acumular montos por categoría y por todos sus ancestros
    final Map<int, double> sums = {};
    for (final tx in confirmed) {
      final cid = tx.categoriaId;
      if (cid == null) continue;
      int? cur = cid;
      // propagar hacia arriba (incluye la categoría misma)
      while (cur != null) {
        sums[cur] = (sums[cur] ?? 0) + tx.monto;
        cur = parent[cur];
      }
    }

    if (sums.isEmpty) return [];

    // Si se proporciona rootCategoryId, construir el conjunto de descendientes (ramo)
    Set<int>? descendants;
    if (rootCategoryId != null) {
      final Map<int, List<int>> children = {};
      for (final entry in parent.entries) {
        final pid = entry.value;
        final id = entry.key;
        if (pid != null) {
          children.putIfAbsent(pid, () => []).add(id);
        }
      }

      descendants = <int>{};
      final queue = <int>[rootCategoryId];
      while (queue.isNotEmpty) {
        final cur = queue.removeLast();
        if (descendants.contains(cur)) continue;
        descendants.add(cur);
        final ch = children[cur];
        if (ch != null) queue.addAll(ch);
      }

      // Log de depuración de la rama
      try {
        final namesList = descendants.map((i) => '${i}:${names[i] ?? 'id_$i'}').toList();
        debugPrint('🔍 [CategoryBudgetService] rama para root=$rootCategoryId -> $namesList');
        // mostrar tipos de las categorias en la rama para detectar 'ingreso' vs 'egreso'
        final typesList = descendants.map((i) => '${i}:${types[i] ?? ''}').toList();
        debugPrint('🔍 [CategoryBudgetService] tipos en rama para root=$rootCategoryId -> $typesList');
      } catch (_) {}
    }

    // Filtrar: solo incluir categorías cuyo tipo sea 'egreso' y que pertenezcan a la rama si aplica
    final filtered = sums.entries
        .where((e) => types[e.key] == 'egreso' && (descendants == null || descendants.contains(e.key)))
        .map((e) => {
              'categoriaId': e.key,
              'nombre': names[e.key] ?? 'id_${e.key}',
              'monto': e.value,
            })
        .toList();
    if (filtered.isEmpty && descendants != null) {
      try {
        debugPrint('⚠️ [CategoryBudgetService] filtered vacío para root=$rootCategoryId; diagnosticando entradas en sums:');
        for (final e in sums.entries) {
          final id = e.key;
          final nm = names[id] ?? 'id_$id';
          final tp = types[id] ?? '';
          final amt = e.value;
          debugPrint('   - id=$id nombre=$nm tipo=$tp monto=$amt inDesc=${descendants.contains(id)}');
        }
      } catch (_) {}
    }
    filtered.sort((a, b) => (b['monto'] as double).compareTo(a['monto'] as double));
    return filtered;
  }
}

class DateTimeRange {
  final DateTime start;
  final DateTime end;
  const DateTimeRange({required this.start, required this.end});
}
