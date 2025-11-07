import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/models/transaction_model.dart';
import '../../../core/repos/transaction_repo.dart';
import '../../../core/services/auth_service.dart';

part 'reports_controller.g.dart';

// Estado para la pantalla de informes
class ReportsState {
  final List<AppTransaction> transactions;
  final DateTimeRange dateRange;
  final String selectedPeriod;
  final bool isLoading;
  final String? error;

  const ReportsState({
    this.transactions = const [],
    required this.dateRange,
    this.selectedPeriod = 'mes',
    this.isLoading = false,
    this.error,
  });

  ReportsState copyWith({
    List<AppTransaction>? transactions,
    DateTimeRange? dateRange,
    String? selectedPeriod,
    bool? isLoading,
    String? error,
  }) {
    return ReportsState(
      transactions: transactions ?? this.transactions,
      dateRange: dateRange ?? this.dateRange,
      selectedPeriod: selectedPeriod ?? this.selectedPeriod,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// Controlador para la pantalla de informes
@riverpod
class ReportsController extends _$ReportsController {
  final TransactionRepo _transactionRepo = TransactionRepo();
  final AuthService _authService = AuthService();

  @override
  ReportsState build() {
    // Inicializar con el mes actual
    final now = DateTime.now();
    final initialRange = DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: DateTime(now.year, now.month + 1, 0, 23, 59, 59),
    );

    Future.microtask(() => loadTransactions());

    return ReportsState(
      dateRange: initialRange,
      selectedPeriod: 'mes',
      isLoading: true,
    );
  }

  // Carga las transacciones del rango actual
  Future<void> loadTransactions() async {
    debugPrint('🔵 [ReportsController] Cargando transacciones...');
    state = state.copyWith(isLoading: true, error: null);

    try {
      final userId = _authService.currentUserId;
      debugPrint('🔵 [ReportsController] User: $userId');

      if (userId == null) {
        debugPrint('🔴 [ReportsController] Sin usuario');
        state = state.copyWith(
          isLoading: false,
          error: 'Usuario no autenticado',
        );
        return;
      }

      final transactions = await _transactionRepo.list(
        usuarioId: userId,
        from: state.dateRange.start,
        to: state.dateRange.end,
      );

      debugPrint('✅ [ReportsController] ${transactions.length} transacciones');

      state = state.copyWith(
        transactions: transactions,
        isLoading: false,
        error: null,
      );

      debugPrint('✅ [ReportsController] Listo');
    } catch (e, stackTrace) {
      debugPrint('🔴 [ReportsController] Error: $e');
      debugPrint('🔴 [ReportsController] StackTrace: $stackTrace');
      state = state.copyWith(
        isLoading: false,
        error: 'Error al cargar: ${e.toString()}',
      );
    }
  }

  // Cambia el período (mes, trimestre, año, personalizado)
  Future<void> changePeriod(String period, {DateTimeRange? customRange}) async {
    final now = DateTime.now();
    DateTimeRange newRange;

    switch (period) {
      case 'mes':
        newRange = DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month + 1, 0, 23, 59, 59),
        );
        break;

      case 'trimestre':
        final quarterStart = ((now.month - 1) ~/ 3) * 3 + 1;
        newRange = DateTimeRange(
          start: DateTime(now.year, quarterStart, 1),
          end: DateTime(now.year, quarterStart + 3, 0, 23, 59, 59),
        );
        break;

      case 'año':
        newRange = DateTimeRange(
          start: DateTime(now.year, 1, 1),
          end: DateTime(now.year, 12, 31, 23, 59, 59),
        );
        break;

      case 'personalizado':
        if (customRange == null) return;
        newRange = customRange;
        break;

      default:
        return;
    }

    state = state.copyWith(
      selectedPeriod: period,
      dateRange: newRange,
    );

    await loadTransactions();
  }

  // Recarga los datos
  Future<void> refresh() async {
    await loadTransactions();
  }

  // Obtiene transacciones por tipo
  List<AppTransaction> getTransactionsByType(String tipo) {
    return state.transactions.where((t) => t.tipo == tipo).toList();
  }

  // Calcula el total por tipo
  double getTotalByType(String tipo) {
    return state.transactions
        .where((t) => t.tipo == tipo)
        .fold(0.0, (sum, t) => sum + t.monto);
  }

  // Agrupa transacciones por categoría
  Map<String, List<AppTransaction>> groupByCategory() {
    final Map<String, List<AppTransaction>> grouped = {};

    for (var tx in state.transactions) {
      final category = tx.etiqueta ?? 'Sin categoría';
      if (!grouped.containsKey(category)) {
        grouped[category] = [];
      }
      grouped[category]!.add(tx);
    }

    return grouped;
  }

  // Calcula totales por categoría
  Map<String, double> getTotalsByCategory() {
    final grouped = groupByCategory();
    final Map<String, double> totals = {};

    grouped.forEach((category, transactions) {
      totals[category] = transactions.fold(0.0, (sum, t) => sum + t.monto);
    });

    return totals;
  }
}

