import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../repositories/budget_period_repository.dart';
import '../repositories/transaction_repository.dart';
import 'auth_service.dart';
import 'package:mype_finanzas/models/services/category_budget_service.dart';
import '../repositories/category_repository.dart';

/// Tipo de alerta de presupuesto
enum BudgetAlertType {
  generalMonthly,      // Presupuesto general mensual alcanzado
  generalQuarterly,    // Presupuesto general trimestral alcanzado
  generalYearly,       // Presupuesto general anual alcanzado
  categoryMonthly,     // Presupuesto de categoría mensual alcanzado
  categoryQuarterly,   // Presupuesto de categoría trimestral alcanzado
}

/// Modelo de notificación de presupuesto
class BudgetNotification {
  final String id;
  final BudgetAlertType type;
  final String title;
  final String message;
  final double percentage;
  final double limit;
  final double spent;
  final DateTime timestamp;
  final int? categoryId;
  final String? categoryName;
  final String periodo;
  final DateTime referencia;

  BudgetNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.percentage,
    required this.limit,
    required this.spent,
    required this.timestamp,
    this.categoryId,
    this.categoryName,
    required this.periodo,
    required this.referencia,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'title': title,
    'message': message,
    'percentage': percentage,
    'limit': limit,
    'spent': spent,
    'timestamp': timestamp.toIso8601String(),
    'categoryId': categoryId,
    'categoryName': categoryName,
    'periodo': periodo,
    'referencia': referencia.toIso8601String(),
  };

  factory BudgetNotification.fromJson(Map<String, dynamic> json) {
    return BudgetNotification(
      id: json['id'] as String,
      type: BudgetAlertType.values.firstWhere((e) => e.name == json['type']),
      title: json['title'] as String,
      message: json['message'] as String,
      percentage: (json['percentage'] as num).toDouble(),
      limit: (json['limit'] as num).toDouble(),
      spent: (json['spent'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
      categoryId: json['categoryId'] as int?,
      categoryName: json['categoryName'] as String?,
      periodo: json['periodo'] as String,
      referencia: DateTime.parse(json['referencia'] as String),
    );
  }
}

/// Servicio centralizado para gestionar notificaciones de presupuesto
class BudgetNotificationService {
  static final BudgetNotificationService _instance = BudgetNotificationService._();
  factory BudgetNotificationService() => _instance;
  BudgetNotificationService._();

  final _budgetPeriodRepo = BudgetPeriodRepo();
  final _transactionRepo = TransactionRepo();
  final _categoryRepo = CategoryRepository();
  final _categoryBudgetService = CategoryBudgetService();
  final _authService = AuthService();

  static const String _kActiveNotifications = 'budget_active_notifications';
  static const String _kShownNotifications = 'budget_shown_notifications';
  static const double _alertThreshold = 90.0; // 90% umbral para alertar

  /// Lista de notificaciones activas (se actualiza cuando se verifica)
  List<BudgetNotification> _activeNotifications = [];

  /// Si es true, la próxima verificación ignorará la lista de mostradas y
  /// permitirá emitir todas las notificaciones detectadas (usado después
  /// de crear/editar/borrar transacciones para asegurar que la UI reciba
  /// la alerta inmediatamente).
  bool _ignoreShownOnce = false;

  /// Obtener notificaciones activas
  List<BudgetNotification> get activeNotifications => List.unmodifiable(_activeNotifications);

  /// Verificar todos los presupuestos y generar notificaciones
  Future<void> checkAllBudgets() async {
    try {
      final userId = _authService.currentUserId;
      if (userId == null) return;

      final now = DateTime.now();
      final newNotifications = <BudgetNotification>[];

      // Verificar presupuesto general mensual
      await _checkGeneralBudget(
        userId: userId,
        periodo: 'mensual',
        mes: now.month,
        anio: now.year,
        notifications: newNotifications,
      );

      // Verificar presupuesto general trimestral
      final quarterStartMonth = ((now.month - 1) ~/ 3) * 3 + 1;
      await _checkGeneralBudget(
        userId: userId,
        periodo: 'trimestral',
        mes: quarterStartMonth,
        anio: now.year,
        notifications: newNotifications,
      );

      // Verificar presupuesto general anual
      await _checkGeneralBudget(
        userId: userId,
        periodo: 'anual',
        mes: 1,
        anio: now.year,
        notifications: newNotifications,
      );

      // Verificar presupuestos de categorías
      await _checkCategoryBudgets(
        userId: userId,
        notifications: newNotifications,
      );

      // Filtrar notificaciones que ya fueron mostradas (a menos que estemos
      // forzando un ignore temporal tras un cambio de transacciones).
      final filteredNotifications = _ignoreShownOnce
          ? (newNotifications)
          : await _filterShownNotifications(newNotifications);

      // Si habíamos activado ignoreOnce, resetearlo ahora.
      if (_ignoreShownOnce) _ignoreShownOnce = false;

      // Actualizar lista activa
      _activeNotifications = filteredNotifications;

      // Guardar en preferencias
      await _saveActiveNotifications();

      debugPrint('✅ [BudgetNotificationService] Verificación completa: ${_activeNotifications.length} notificaciones activas');
    } catch (e) {
      debugPrint('❌ [BudgetNotificationService] Error al verificar presupuestos: $e');
    }
  }

  /// Verificar presupuesto general (mensual/trimestral/anual)
  Future<void> _checkGeneralBudget({
    required int userId,
    required String periodo,
    required int mes,
    required int anio,
    required List<BudgetNotification> notifications,
  }) async {
    try {
      final budget = await _budgetPeriodRepo.getForPeriod(
        usuarioId: userId,
        periodo: periodo,
        mes: mes,
        anio: anio,
      );

      if (budget == null || budget.monto <= 0) return;

      // Calcular gasto real
      final spent = await _calculateSpentForPeriod(
        userId: userId,
        periodo: periodo,
        mes: mes,
        anio: anio,
      );

      final percentage = (spent / budget.monto) * 100;

      if (percentage >= _alertThreshold) {
        final type = periodo == 'mensual'
            ? BudgetAlertType.generalMonthly
            : periodo == 'trimestral'
            ? BudgetAlertType.generalQuarterly
            : BudgetAlertType.generalYearly;

        final referencia = DateTime(anio, mes, 1);
        final id = 'general_${periodo}_${referencia.year}_${referencia.month}';

        notifications.add(BudgetNotification(
          id: id,
          type: type,
          title: 'Presupuesto ${_getPeriodoDisplay(periodo)} Alcanzado',
          message:
          'Has usado S/ ${spent.toStringAsFixed(2)} de S/ ${budget.monto.toStringAsFixed(2)} (${percentage.toStringAsFixed(1)}%)',
          percentage: percentage,
          limit: budget.monto,
          spent: spent,
          timestamp: DateTime.now(),
          periodo: periodo,
          referencia: referencia,
        ));
      }
    } catch (e) {
      debugPrint('❌ Error verificando presupuesto general $periodo: $e');
    }
  }

  /// Verificar presupuestos de categorías
  Future<void> _checkCategoryBudgets({
    required int userId,
    required List<BudgetNotification> notifications,
  }) async {
    try {
      final now = DateTime.now();
      final categories = await _categoryRepo.getCategoriesByType('egreso');

      for (final category in categories) {
        if (category.id == null) continue;

        // Preferir una única notificación por categoría en este ciclo: comprobar
        // primero mensual y si se añadió no comprobar trimestral para evitar duplicados.
        final addedMonthly = await _checkCategoryBudget(
          userId: userId,
          categoryId: category.id!,
          categoryName: category.nombre,
          periodo: 'mensual',
          referencia: DateTime(now.year, now.month, 1),
          notifications: notifications,
        );

        if (!addedMonthly) {
          final quarterStartMonth = ((now.month - 1) ~/ 3) * 3 + 1;
          await _checkCategoryBudget(
            userId: userId,
            categoryId: category.id!,
            categoryName: category.nombre,
            periodo: 'trimestral',
            referencia: DateTime(now.year, quarterStartMonth, 1),
            notifications: notifications,
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error verificando presupuestos de categorías: $e');
    }
  }

  /// Verificar presupuesto de una categoría específica
  Future<bool> _checkCategoryBudget({
    required int userId,
    required int categoryId,
    required String categoryName,
    required String periodo,
    required DateTime referencia,
    required List<BudgetNotification> notifications,
  }) async {
    try {
      final summary = await _categoryBudgetService.getSummary(
        usuarioId: userId,
        categoriaId: categoryId,
        periodo: periodo,
        referencia: referencia,
      );

      if (summary == null || summary.budget.montoLimite <= 0) return false;

      if (summary.porcentaje >= _alertThreshold) {
        final type = periodo == 'mensual'
            ? BudgetAlertType.categoryMonthly
            : BudgetAlertType.categoryQuarterly;

        final id = 'category_${periodo}_${categoryId}_${referencia.year}_${referencia.month}';

        notifications.add(BudgetNotification(
          id: id,
          type: type,
          title: 'Presupuesto de "$categoryName"',
          message:
          'Has usado S/ ${summary.realAcumulado.toStringAsFixed(2)} de S/ ${summary.budget.montoLimite.toStringAsFixed(2)} (${summary.porcentaje.toStringAsFixed(1)}%)',
          percentage: summary.porcentaje,
          limit: summary.budget.montoLimite,
          spent: summary.realAcumulado,
          timestamp: DateTime.now(),
          categoryId: categoryId,
          categoryName: categoryName,
          periodo: periodo,
          referencia: referencia,
        ));
        return true;
      }
    } catch (e) {
      debugPrint('❌ Error verificando presupuesto de categoría $categoryId: $e');
    }
    return false;
  }

  /// Calcular gasto real para un período
  Future<double> _calculateSpentForPeriod({
    required int userId,
    required String periodo,
    required int mes,
    required int anio,
  }) async {
    DateTime startDate;
    DateTime endDate;

    if (periodo == 'mensual') {
      startDate = DateTime(anio, mes, 1);
      endDate = DateTime(anio, mes + 1, 0, 23, 59, 59);
    } else if (periodo == 'trimestral') {
      startDate = DateTime(anio, mes, 1);
      endDate = DateTime(anio, mes + 3, 0, 23, 59, 59);
    } else {
      // anual
      startDate = DateTime(anio, 1, 1);
      endDate = DateTime(anio, 12, 31, 23, 59, 59);
    }

    final transactions = await _transactionRepo.list(
      usuarioId: userId,
      from: startDate,
      to: endDate,
      tipo: 'egreso',
    );

    return transactions.fold<double>(0, (sum, tx) => sum + tx.monto);
  }

  /// Filtrar notificaciones que ya fueron mostradas
  Future<List<BudgetNotification>> _filterShownNotifications(
      List<BudgetNotification> notifications) async {
    final prefs = await SharedPreferences.getInstance();
    final shownIds = prefs.getStringList(_kShownNotifications) ?? [];

    final result = <BudgetNotification>[];

    for (final notif in notifications) {
      try {
        final id = notif.id;
        if (!shownIds.contains(id)) {
          // Nunca vista: incluir
          result.add(notif);
          continue;
        }

        // Si ya fue marcada como vista, permitir re-mostrar sólo si el
        // porcentaje actual es mayor al último porcentaje guardado para
        // esta alerta (esto permite notificar cuando el uso aumenta).
        // La clave histórica sigue el formato:
        // 'budget_alert_<year>_<month>_<periodo>_<categoriaId>'
        try {
          final ref = notif.referencia;
          final periodo = notif.periodo;
          final categoriaId = notif.categoryId;
          if (categoriaId != null) {
            final key = 'budget_alert_${ref.year}_${ref.month}_${periodo}_$categoriaId';
            final lastPct = prefs.getInt(key) ?? 0;
            final currentPct = notif.percentage.round();
            if (currentPct > lastPct) {
              // Actualizar el porcentaje guardado para evitar re-emisiones sin cambio
              await prefs.setInt(key, currentPct);
              result.add(notif);
              continue;
            }
          } else {
            // Para notificaciones generales (sin categoría) usar una clave similar
            final key = 'budget_alert_${notif.referencia.year}_${notif.referencia.month}_${notif.periodo}_general';
            final lastPct = prefs.getInt(key) ?? 0;
            final currentPct = notif.percentage.round();
            if (currentPct > lastPct) {
              await prefs.setInt(key, currentPct);
              result.add(notif);
              continue;
            }
          }
        } catch (e) {
          // En caso de cualquier error de prefs, no bloquear la notificación.
          result.add(notif);
          continue;
        }
      } catch (e) {
        // Por seguridad, si algo falla, incluir la notificación.
        result.add(notif);
      }
    }

    return result;
  }

  /// Marcar notificación como vista
  Future<void> dismissNotification(String notificationId) async {
    try {
      // Remover de la lista activa
      _activeNotifications.removeWhere((n) => n.id == notificationId);
      await _saveActiveNotifications();

      // Agregar a la lista de mostradas
      final prefs = await SharedPreferences.getInstance();
      final shownIds = prefs.getStringList(_kShownNotifications) ?? [];
      if (!shownIds.contains(notificationId)) {
        shownIds.add(notificationId);
        await prefs.setStringList(_kShownNotifications, shownIds);
      }

      debugPrint('✅ Notificación $notificationId marcada como vista');
    } catch (e) {
      debugPrint('❌ Error al descartar notificación: $e');
    }
  }

  /// Limpiar notificaciones antiguas (más de 30 días)
  Future<void> cleanOldNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final shownIds = prefs.getStringList(_kShownNotifications) ?? [];
      final now = DateTime.now();

      // Filtrar IDs que contengan fechas antiguas
      final recentIds = shownIds.where((id) {
        // Extraer fecha del ID (formato: tipo_periodo_año_mes)
        final parts = id.split('_');
        if (parts.length >= 4) {
          try {
            final year = int.parse(parts[parts.length - 2]);
            final month = int.parse(parts[parts.length - 1]);
            final date = DateTime(year, month);
            return now.difference(date).inDays <= 30;
          } catch (e) {
            return false;
          }
        }
        return false;
      }).toList();

      await prefs.setStringList(_kShownNotifications, recentIds);
      debugPrint('✅ Notificaciones antiguas limpiadas');
    } catch (e) {
      debugPrint('❌ Error al limpiar notificaciones antiguas: $e');
    }
  }

  /// Guardar notificaciones activas
  Future<void> _saveActiveNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _activeNotifications.map((n) => n.toJson()).toList();
      // Convertir a string para guardar
      await prefs.setStringList(
        _kActiveNotifications,
        jsonList.map((json) => json.toString()).toList(),
      );
    } catch (e) {
      debugPrint('❌ Error al guardar notificaciones activas: $e');
    }
  }

  /// Cargar notificaciones activas desde preferencias
  Future<void> loadActiveNotifications() async {
    try {
      // Por simplicidad, volvemos a verificar en lugar de parsear JSON
      await checkAllBudgets();
    } catch (e) {
      debugPrint('❌ Error al cargar notificaciones activas: $e');
    }
  }

  /// Reiniciar verificación después de editar/eliminar transacción
  Future<void> onTransactionChanged() async {
    debugPrint('🔄 Transacción modificada, reverificando presupuestos...');
    // Forzar que la próxima verificación incluya notificaciones aun si ya
    // habían sido marcadas como mostradas (evitar depender de visitar la
    // pantalla de presupuestos para reactivar alertas).
    _ignoreShownOnce = true;
    await checkAllBudgets();
  }

  String _getPeriodoDisplay(String periodo) {
    switch (periodo) {
      case 'mensual':
        return 'Mensual';
      case 'trimestral':
        return 'Trimestral';
      case 'anual':
        return 'Anual';
      default:
        return periodo;
    }
  }
}