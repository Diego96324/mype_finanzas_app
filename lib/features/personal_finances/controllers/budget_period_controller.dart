import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/budget_period_model.dart';
import '../../../core/services/budget_period_service.dart';
import '../../../core/providers/providers.dart';

// Estado para presupuestos por período
class BudgetPeriodState {
  final BudgetPeriod? currentBudget;
  final bool isLoading;
  final String? error;

  const BudgetPeriodState({
    this.currentBudget,
    this.isLoading = false,
    this.error,
  });

  BudgetPeriodState copyWith({
    BudgetPeriod? currentBudget,
    bool? isLoading,
    String? error,
    bool clearBudget = false,
    bool clearError = false,
  }) {
    return BudgetPeriodState(
      currentBudget: clearBudget ? null : (currentBudget ?? this.currentBudget),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// Controlador para presupuestos dinámicos (mes/trimestre/año)
class BudgetPeriodController extends StateNotifier<BudgetPeriodState> {
  final BudgetPeriodService _budgetService = BudgetPeriodService();
  final Ref _ref;

  BudgetPeriodController(this._ref) : super(const BudgetPeriodState(isLoading: false));

  // Carga presupuesto para un período específico
  Future<void> loadBudgetForPeriod({
    required String periodo,
    required int mes,
    required int anio,
  }) async {
    print('🔵 [BudgetPeriodController] Cargando presupuesto para periodo=$periodo, mes=$mes, anio=$anio');
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final userId = _ref.read(currentUserIdProvider);
      print('🔵 [BudgetPeriodController] userId: $userId');

      if (userId == null) {
        print('🔴 [BudgetPeriodController] Usuario no autenticado');
        state = state.copyWith(
          isLoading: false,
          error: 'Usuario no autenticado',
        );
        return;
      }

      final budget = await _budgetService.getBudgetForPeriod(
        usuarioId: userId,
        periodo: periodo,
        mes: mes,
        anio: anio,
      );

      print('✅ [BudgetPeriodController] Presupuesto cargado: ${budget?.monto ?? "null"}');

      state = BudgetPeriodState(
        currentBudget: budget,
        isLoading: false,
        error: null,
      );
    } catch (e) {
      print('🔴 [BudgetPeriodController] Error: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Error al cargar presupuesto: ${e.toString()}',
      );
    }
  }

  // Guarda un presupuesto para el período
  Future<bool> saveBudget({
    required double monto,
    required String periodo,
    required int mes,
    required int anio,
  }) async {
    try {
      final userId = _ref.read(currentUserIdProvider);

      if (userId == null) {
        state = state.copyWith(error: 'Usuario no autenticado');
        return false;
      }

      if (monto <= 0) {
        state = state.copyWith(error: 'El monto debe ser mayor a cero');
        return false;
      }

      // Guardamos según el tipo de período
      if (periodo == 'mensual') {
        await _budgetService.saveMonthlyBudget(
          usuarioId: userId,
          monto: monto,
          mes: mes,
          anio: anio,
        );
      } else if (periodo == 'trimestral') {
        await _budgetService.saveQuarterlyBudget(
          usuarioId: userId,
          monto: monto,
          mes: mes,
          anio: anio,
        );
      } else if (periodo == 'anual') {
        await _budgetService.saveYearlyBudget(
          usuarioId: userId,
          monto: monto,
          anio: anio,
        );
      }

      // Recargamos para ver el cambio
      await loadBudgetForPeriod(
        periodo: periodo,
        mes: mes,
        anio: anio,
      );

      return true;
    } catch (e) {
      state = state.copyWith(
        error: 'Error al guardar presupuesto: ${e.toString()}',
      );
      return false;
    }
  }

  // Elimina el presupuesto del período
  Future<bool> deleteBudget({
    required String periodo,
    required int mes,
    required int anio,
  }) async {
    try {
      final userId = _ref.read(currentUserIdProvider);

      if (userId == null) {
        state = state.copyWith(error: 'Usuario no autenticado');
        return false;
      }

      await _budgetService.deleteBudget(
        usuarioId: userId,
        periodo: periodo,
        mes: mes,
        anio: anio,
        syncToOthers: true,
      );

      // Recargamos para actualizar el estado
      await loadBudgetForPeriod(
        periodo: periodo,
        mes: mes,
        anio: anio,
      );

      return true;
    } catch (e) {
      state = state.copyWith(
        error: 'Error al eliminar presupuesto: ${e.toString()}',
      );
      return false;
    }
  }

  // Obtiene el tipo de período según el string
  String getPeriodType(String selectedPeriod) {
    switch (selectedPeriod) {
      case 'trimestre':
        return 'trimestral';
      case 'año':
        return 'anual';
      default:
        return 'mensual';
    }
  }
}

// Clase para identificar un presupuesto único
class BudgetPeriodKey {
  final String periodo;
  final int mes;
  final int anio;

  const BudgetPeriodKey({
    required this.periodo,
    required this.mes,
    required this.anio,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BudgetPeriodKey &&
          runtimeType == other.runtimeType &&
          periodo == other.periodo &&
          mes == other.mes &&
          anio == other.anio;

  @override
  int get hashCode => periodo.hashCode ^ mes.hashCode ^ anio.hashCode;

  @override
  String toString() => 'BudgetPeriodKey($periodo, $mes/$anio)';
}

// Provider con familia para crear instancias separadas por período
final budgetPeriodControllerProvider = StateNotifierProvider.family<
    BudgetPeriodController,
    BudgetPeriodState,
    BudgetPeriodKey>((ref, key) {
  print('🆕 [Provider] Creando controlador para $key');
  final controller = BudgetPeriodController(ref);

  // Cargamos automáticamente cuando se crea el provider
  Future.microtask(() {
    controller.loadBudgetForPeriod(
      periodo: key.periodo,
      mes: key.mes,
      anio: key.anio,
    );
  });

  return controller;
});

