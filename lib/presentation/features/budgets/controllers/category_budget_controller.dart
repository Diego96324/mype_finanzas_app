import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/services/category_budget_service.dart';
import '../../../../domain/services/auth_service.dart';

class CategoryBudgetState {
  final CategoryBudgetSummary? summary;
  final bool isLoading;
  final String? error;
  const CategoryBudgetState({this.summary, this.isLoading = false, this.error});

  CategoryBudgetState copyWith({CategoryBudgetSummary? summary, bool? isLoading, String? error, bool clear = false}) =>
      CategoryBudgetState(
        summary: clear ? null : (summary ?? this.summary),
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

class CategoryBudgetKey {
  final int categoriaId;
  final String periodo; // 'mensual' | 'trimestral'
  final DateTime referencia;
  const CategoryBudgetKey({required this.categoriaId, required this.periodo, required this.referencia});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CategoryBudgetKey &&
          categoriaId == other.categoriaId &&
          periodo == other.periodo &&
          referencia.year == other.referencia.year &&
          referencia.month == other.referencia.month; // comparar período lógico

  @override
  int get hashCode => categoriaId.hashCode ^ periodo.hashCode ^ referencia.year.hashCode ^ referencia.month.hashCode;

  @override
  String toString() => 'CategoryBudgetKey(cat=$categoriaId, periodo=$periodo, ${referencia.year}-${referencia.month})';
}

class CategoryBudgetController extends StateNotifier<CategoryBudgetState> {
  final AuthService _auth = AuthService();
  final CategoryBudgetService _service = CategoryBudgetService();
  final CategoryBudgetKey key;

  CategoryBudgetController(this.key) : super(const CategoryBudgetState(isLoading: true)) {
    Future.microtask(() => load());
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final uid = _auth.currentUserId;
      if (uid == null) {
        state = state.copyWith(isLoading: false, error: 'Usuario no autenticado');
        return;
      }
      final summary = await _service.getSummary(
        usuarioId: uid,
        categoriaId: key.categoriaId,
        periodo: key.periodo,
        referencia: key.referencia,
      );
      state = state.copyWith(summary: summary, isLoading: false);
    } catch (e, st) {
      debugPrint('Error load CategoryBudget: $e\n$st');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> save({
    required String nombre,
    required double montoLimite,
    List<int>? thresholds,
    bool autoAjuste = false,
  }) async {
    try {
      final uid = _auth.currentUserId;
      if (uid == null) {
        state = state.copyWith(error: 'Usuario no autenticado');
        return false;
      }
      if (montoLimite <= 0) {
        state = state.copyWith(error: 'El monto debe ser mayor a cero');
        return false;
      }
      await _service.saveBudget(
        usuarioId: uid,
        categoriaId: key.categoriaId,
        nombre: nombre,
        montoLimite: montoLimite,
        periodo: key.periodo,
        referencia: key.referencia,
        alertaThresholds: thresholds,
        autoAjuste: autoAjuste,
      );
      await load();
      return true;
    } catch (e) {
      state = state.copyWith(error: 'Error al guardar: ${e.toString()}');
      return false;
    }
  }
}

final categoryBudgetControllerProvider = StateNotifierProvider.family<CategoryBudgetController, CategoryBudgetState, CategoryBudgetKey>((ref, key) {
  return CategoryBudgetController(key);
});
