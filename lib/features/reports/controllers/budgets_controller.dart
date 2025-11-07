import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/budget_model.dart';
import '../../../core/repos/budget_repo.dart';
import '../../../core/services/auth_service.dart';

// El estado del presupuesto mensual
class BudgetsState {
  final Budget? currentBudget; // el presupuesto del mes que estamos viendo
  final bool isLoading; // para mostrar el loading
  final String? error; // si algo sale mal

  const BudgetsState({
    this.currentBudget,
    this.isLoading = false,
    this.error,
  });

  BudgetsState copyWith({
    Budget? currentBudget,
    bool? isLoading,
    String? error,
  }) {
    return BudgetsState(
      currentBudget: currentBudget ?? this.currentBudget,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// Controlador para manejar los presupuestos mensuales
class BudgetsController extends StateNotifier<BudgetsState> {
  final BudgetRepo _budgetRepo = BudgetRepo();
  final AuthService _authService = AuthService();

  BudgetsController() : super(const BudgetsState(isLoading: true)) {
    // Al arrancar, cargamos el presupuesto del mes actual
    Future.microtask(() => loadCurrentMonthBudget());
  }

  // Carga el presupuesto del mes actual
  Future<void> loadCurrentMonthBudget() async {
    debugPrint('🔵 [BudgetsController] Cargando presupuesto...');
    final now = DateTime.now();
    await loadBudgetForMonth(now.month, now.year);
  }

  // Trae el presupuesto de un mes específico
  Future<void> loadBudgetForMonth(int mes, int anio) async {
    debugPrint('🔵 [BudgetsController] Mes: $mes/$anio');
    state = state.copyWith(isLoading: true, error: null);

    try {
      final userId = _authService.currentUserId;
      debugPrint('🔵 [BudgetsController] User: $userId');

      if (userId == null) {
        debugPrint('🔴 [BudgetsController] No hay usuario');
        state = state.copyWith(
          isLoading: false,
          error: 'Usuario no autenticado',
        );
        return;
      }

      final budget = await _budgetRepo.getForMonth(
        usuarioId: userId,
        mes: mes,
        anio: anio,
      );

      debugPrint('✅ [BudgetsController] Presupuesto: ${budget?.monto ?? "ninguno"}');

      state = BudgetsState(
        currentBudget: budget,
        isLoading: false,
        error: null,
      );

      debugPrint('✅ [BudgetsController] Listo');
    } catch (e, stackTrace) {
      debugPrint('🔴 [BudgetsController] Error: $e');
      debugPrint('🔴 [BudgetsController] StackTrace: $stackTrace');
      state = state.copyWith(
        isLoading: false,
        error: 'Error al cargar presupuesto: ${e.toString()}',
      );
    }
  }

  // Guarda un presupuesto para un mes
  Future<bool> setMonthlyBudget({
    required double monto,
    required int mes,
    required int anio,
  }) async {
    try {
      final userId = _authService.currentUserId;

      if (userId == null) {
        state = state.copyWith(error: 'Usuario no autenticado');
        return false;
      }

      if (monto <= 0) {
        state = state.copyWith(error: 'El monto debe ser mayor a cero');
        return false;
      }

      await _budgetRepo.setMonthlyBudget(
        usuarioId: userId,
        monto: monto,
        mes: mes,
        anio: anio,
      );

      // Recargamos para ver el cambio
      await loadBudgetForMonth(mes, anio);

      return true;
    } catch (e) {
      state = state.copyWith(error: 'Error al guardar presupuesto: ${e.toString()}');
      return false;
    }
  }

  // Actualiza un presupuesto que ya existe
  Future<bool> updateBudget(Budget budget) async {
    try {
      if (budget.monto <= 0) {
        state = state.copyWith(error: 'El monto debe ser mayor a cero');
        return false;
      }

      await _budgetRepo.update(budget);

      // Recargamos después de editar
      await loadBudgetForMonth(budget.mes, budget.anio);

      return true;
    } catch (e) {
      state = state.copyWith(error: 'Error al actualizar presupuesto: ${e.toString()}');
      return false;
    }
  }

  // Borra un presupuesto
  Future<bool> deleteBudget(int budgetId) async {
    try {
      await _budgetRepo.delete(budgetId);

      // Volvemos a cargar el presupuesto actual
      await loadCurrentMonthBudget();

      return true;
    } catch (e) {
      state = state.copyWith(error: 'Error al eliminar presupuesto: ${e.toString()}');
      return false;
    }
  }

  // Elimina el presupuesto de un mes en específico
  Future<bool> deleteBudgetForMonth(int mes, int anio) async {
    try {
      final userId = _authService.currentUserId;

      if (userId == null) {
        state = state.copyWith(error: 'Usuario no autenticado');
        return false;
      }

      await _budgetRepo.deleteForMonth(
        usuarioId: userId,
        mes: mes,
        anio: anio,
      );

      // Recargamos después de borrar
      await loadBudgetForMonth(mes, anio);

      return true;
    } catch (e) {
      state = state.copyWith(error: 'Error al eliminar presupuesto: ${e.toString()}');
      return false;
    }
  }
}

// El provider para usar el controlador en la app
final budgetsControllerProvider = StateNotifierProvider<BudgetsController, BudgetsState>((ref) {
  return BudgetsController();
});
