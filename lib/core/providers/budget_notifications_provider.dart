import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../../models/services/budget_notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Estado de las notificaciones de presupuesto
class BudgetNotificationsState {
  final List<BudgetNotification> notifications;
  final bool isLoading;
  final String? error;

  const BudgetNotificationsState({
    this.notifications = const [],
    this.isLoading = false,
    this.error,
  });

  BudgetNotificationsState copyWith({
    List<BudgetNotification>? notifications,
    bool? isLoading,
    String? error,
  }) {
    return BudgetNotificationsState(
      notifications: notifications ?? this.notifications,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Controlador de notificaciones de presupuesto
class BudgetNotificationsController extends StateNotifier<BudgetNotificationsState> {
  final BudgetNotificationService _service;

  // runCheck: permite evitar checkBudgets en tests o contextos donde no queramos
  // ejecutar la verificación inicial (evita llamadas a DB/plataformas).
  BudgetNotificationsController({BudgetNotificationService? service, bool runCheck = true})
      : _service = service ?? BudgetNotificationService(),
        super(const BudgetNotificationsState()) {
    if (runCheck) {
      checkBudgets();
    }
  }

  /// Verificar presupuestos y actualizar notificaciones
  Future<void> checkBudgets() async {
    state = state.copyWith(isLoading: true);

    try {
      await _service.checkAllBudgets();
      state = BudgetNotificationsState(
        notifications: _service.activeNotifications,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Descartar notificación
  Future<void> dismissNotification(String notificationId) async {
    await _service.dismissNotification(notificationId);
    state = state.copyWith(
      notifications: _service.activeNotifications,
    );
  }

  /// Marcar notificación como mostrada sin interacción del usuario.
  /// Esto delega al servicio para añadir la notificación a la lista de mostradas
  /// y actualizar el estado interno.
  ///
  /// Para preservar exactamente el comportamiento histórico (evitar duplicados
  /// inmediatos), acepta parámetros opcionales que permiten actualizar la clave
  /// por categoría en SharedPreferences cuando esté disponible.
  Future<void> markNotificationAsShown(String notificationId, {int? categoriaId, double? porcentaje, String? periodo, DateTime? referencia}) async {
    try {
      if (categoriaId != null && porcentaje != null && periodo != null && referencia != null) {
        try {
          final prefs = await SharedPreferences.getInstance();
          final key = 'budget_alert_${referencia.year}_${referencia.month}_${periodo}_$categoriaId';
          final pctInt = porcentaje.round();
          final lastPct = prefs.getInt(key) ?? 0;
          if (pctInt > lastPct) {
            await prefs.setInt(key, pctInt);
          }
          debugPrint('ℹ️ [BudgetNotificationsController] SharedPreferences $key actualizado a $pctInt');
        } catch (e) {
          debugPrint('⚠️ [BudgetNotificationsController] No se pudo actualizar SharedPreferences: $e');
        }
      }

      await _service.dismissNotification(notificationId);
      state = state.copyWith(
        notifications: _service.activeNotifications,
      );
    } catch (e) {
      debugPrint('❌ [BudgetNotificationsController] Error en markNotificationAsShown: $e');
    }
  }

  /// Llamar después de crear/editar/eliminar transacción
  Future<void> onTransactionChanged() async {
    await _service.onTransactionChanged();
    state = state.copyWith(
      notifications: _service.activeNotifications,
    );
  }

  /// Limpiar notificaciones antiguas
  Future<void> cleanOldNotifications() async {
    await _service.cleanOldNotifications();
  }
}

/// Provider global de notificaciones de presupuesto
final budgetNotificationsProvider =
StateNotifierProvider<BudgetNotificationsController, BudgetNotificationsState>(
      (ref) => BudgetNotificationsController(),
);