import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/dtos/budget_period_model.dart';
import '../../models/services/budget_period_service.dart';
import '../../core/providers/providers.dart';

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

class BudgetPeriodController extends StateNotifier<BudgetPeriodState> {
  final BudgetPeriodService _budgetService = BudgetPeriodService();
  final Ref _ref;

  BudgetPeriodController(this._ref) : super(const BudgetPeriodState(isLoading: false));

  Future<void> loadBudgetForPeriod({
    required String periodo,
    required int mes,
    required int anio,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final userId = _ref.read(currentUserIdProvider);

      if (userId == null) {
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

      state = BudgetPeriodState(
        currentBudget: budget,
        isLoading: false,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Error al cargar presupuesto: ${e.toString()}',
      );
    }
  }

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

      await loadBudgetForPeriod(
        periodo: periodo,
        mes: mes,
        anio: anio,
      );

      _invalidateRelatedPeriods(periodo, mes, anio);

      return true;
    } catch (e) {
      state = state.copyWith(
        error: 'Error al guardar presupuesto: ${e.toString()}',
      );
      return false;
    }
  }

  void _invalidateRelatedPeriods(String periodo, int mes, int anio) {
    if (periodo == 'mensual') {
      final quarterStartMonth = _budgetService.getQuarterStartMonth(mes);
      _ref.invalidate(budgetPeriodControllerProvider(
        BudgetPeriodKey(periodo: 'trimestral', mes: quarterStartMonth, anio: anio),
      ));
      _ref.invalidate(budgetPeriodControllerProvider(
        BudgetPeriodKey(periodo: 'anual', mes: 1, anio: anio),
      ));
    } else if (periodo == 'trimestral') {
      final quarterStartMonth = _budgetService.getQuarterStartMonth(mes);
      for (int i = 0; i < 3; i++) {
        _ref.invalidate(budgetPeriodControllerProvider(
          BudgetPeriodKey(periodo: 'mensual', mes: quarterStartMonth + i, anio: anio),
        ));
      }
      _ref.invalidate(budgetPeriodControllerProvider(
        BudgetPeriodKey(periodo: 'anual', mes: 1, anio: anio),
      ));
    } else if (periodo == 'anual') {
      for (int month = 1; month <= 12; month++) {
        _ref.invalidate(budgetPeriodControllerProvider(
          BudgetPeriodKey(periodo: 'mensual', mes: month, anio: anio),
        ));
      }
      for (int quarter = 0; quarter < 4; quarter++) {
        final quarterStartMonth = (quarter * 3) + 1;
        _ref.invalidate(budgetPeriodControllerProvider(
          BudgetPeriodKey(periodo: 'trimestral', mes: quarterStartMonth, anio: anio),
        ));
      }
    }
  }

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

      await loadBudgetForPeriod(
        periodo: periodo,
        mes: mes,
        anio: anio,
      );

      _invalidateRelatedPeriods(periodo, mes, anio);

      return true;
    } catch (e) {
      state = state.copyWith(
        error: 'Error al eliminar presupuesto: ${e.toString()}',
      );
      return false;
    }
  }

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

final budgetPeriodControllerProvider = StateNotifierProvider.family<
    BudgetPeriodController,
    BudgetPeriodState,
    BudgetPeriodKey>((ref, key) {
  final controller = BudgetPeriodController(ref);

  Future.microtask(() {
    controller.loadBudgetForPeriod(
      periodo: key.periodo,
      mes: key.mes,
      anio: key.anio,
    );
  });

  return controller;
});

