import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/models/transaction_model.dart';
import '../../../core/repos/transaction_repo.dart';
import '../../../core/services/auth_service.dart';

part 'analytics_controller.g.dart';

// Estado para la pantalla de analytics
class AnalyticsState {
  final List<AppTransaction> transactions;
  final DateTimeRange? dateRange;
  final Map<String, double>? stats;
  final bool isLoading;
  final String? error;

  const AnalyticsState({
    this.transactions = const [],
    this.dateRange,
    this.stats,
    this.isLoading = false,
    this.error,
  });

  AnalyticsState copyWith({
    List<AppTransaction>? transactions,
    DateTimeRange? dateRange,
    Map<String, double>? stats,
    bool? isLoading,
    String? error,
  }) {
    return AnalyticsState(
      transactions: transactions ?? this.transactions,
      dateRange: dateRange ?? this.dateRange,
      stats: stats ?? this.stats,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// Controlador para la pantalla de analytics
@riverpod
class AnalyticsController extends _$AnalyticsController {
  final TransactionRepo _transactionRepo = TransactionRepo();
  final AuthService _authService = AuthService();

  @override
  AnalyticsState build() {
    // Cargar datos del mes actual por defecto
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    final lastDay = DateTime(now.year, now.month + 1, 0);

    final initialRange = DateTimeRange(start: firstDay, end: lastDay);

    Future.microtask(() => loadTransactions(initialRange));

    return AnalyticsState(
      dateRange: initialRange,
      isLoading: true,
    );
  }

  // Carga las transacciones para un rango de fechas
  Future<void> loadTransactions(DateTimeRange range) async {
    print('🔵 [AnalyticsController] Rango: ${range.start} - ${range.end}');
    state = state.copyWith(
      isLoading: true,
      error: null,
      dateRange: range,
    );

    try {
      final userId = _authService.currentUserId;
      print('🔵 [AnalyticsController] User: $userId');

      if (userId == null) {
        print('🔴 [AnalyticsController] Sin usuario');
        state = state.copyWith(
          isLoading: false,
          error: 'Usuario no autenticado',
        );
        return;
      }

      // Traemos las transacciones del rango
      final transactions = await _transactionRepo.listMultiple(
        usuarioId: userId,
        from: range.start,
        to: range.end,
        order: 'fecha_desc',
      );

      print('✅ [AnalyticsController] ${transactions.length} transacciones');

      // Calculamos stats
      final stats = await _transactionRepo.getStats(usuarioId: userId);
      print('✅ [AnalyticsController] Stats: $stats');

      state = AnalyticsState(
        transactions: transactions,
        dateRange: range,
        stats: stats,
        isLoading: false,
        error: null,
      );

      print('✅ [AnalyticsController] Listo');
    } catch (e, stackTrace) {
      print('🔴 [AnalyticsController] Error: $e');
      print('🔴 [AnalyticsController] StackTrace: $stackTrace');
      state = state.copyWith(
        isLoading: false,
        error: 'Error al cargar: ${e.toString()}',
      );
    }
  }

  // Cambia el rango de fechas
  Future<void> setDateRange(DateTimeRange range) async {
    await loadTransactions(range);
  }

  // Recarga los datos
  Future<void> refresh() async {
    if (state.dateRange != null) {
      await loadTransactions(state.dateRange!);
    }
  }

  // Cambia al mes anterior
  Future<void> previousMonth() async {
    if (state.dateRange == null) return;

    final currentStart = state.dateRange!.start;
    final previousMonth = DateTime(currentStart.year, currentStart.month - 1, 1);
    final lastDay = DateTime(previousMonth.year, previousMonth.month + 1, 0);

    await loadTransactions(DateTimeRange(start: previousMonth, end: lastDay));
  }

  // Cambia al mes siguiente
  Future<void> nextMonth() async {
    if (state.dateRange == null) return;

    final currentStart = state.dateRange!.start;
    final nextMonth = DateTime(currentStart.year, currentStart.month + 1, 1);
    final lastDay = DateTime(nextMonth.year, nextMonth.month + 1, 0);

    await loadTransactions(DateTimeRange(start: nextMonth, end: lastDay));
  }

  // Cambia el período (mes, trimestre, año, personalizado)
  Future<void> changePeriod(String period, {DateTimeRange? customRange}) async {
    final now = DateTime.now();
    DateTimeRange range;

    switch (period) {
      case 'mes':
        final firstDay = DateTime(now.year, now.month, 1);
        final lastDay = DateTime(now.year, now.month + 1, 0);
        range = DateTimeRange(start: firstDay, end: lastDay);
        break;

      case 'trimestre':
        final quarter = ((now.month - 1) ~/ 3) + 1;
        final firstMonth = (quarter - 1) * 3 + 1;
        final firstDay = DateTime(now.year, firstMonth, 1);
        final lastDay = DateTime(now.year, firstMonth + 3, 0);
        range = DateTimeRange(start: firstDay, end: lastDay);
        break;

      case 'año':
        final firstDay = DateTime(now.year, 1, 1);
        final lastDay = DateTime(now.year, 12, 31);
        range = DateTimeRange(start: firstDay, end: lastDay);
        break;

      case 'personalizado':
        if (customRange == null) return;
        range = customRange;
        break;

      default:
        return;
    }

    await loadTransactions(range);
  }

  // Mueve el rango de tiempo (siguiente/anterior)
  Future<void> moveTimeRange(bool forward) async {
    if (state.dateRange == null) return;

    final currentStart = state.dateRange!.start;
    final currentEnd = state.dateRange!.end;

    // Calculamos la diferencia en días para saber el tipo de período
    final difference = currentEnd.difference(currentStart).inDays;

    DateTime newStart;
    DateTime newEnd;

    if (difference <= 31) {
      // Es un mes
      if (forward) {
        newStart = DateTime(currentStart.year, currentStart.month + 1, 1);
        newEnd = DateTime(newStart.year, newStart.month + 1, 0);
      } else {
        newStart = DateTime(currentStart.year, currentStart.month - 1, 1);
        newEnd = DateTime(newStart.year, newStart.month + 1, 0);
      }
    } else if (difference <= 92) {
      // Es un trimestre
      if (forward) {
        newStart = DateTime(currentStart.year, currentStart.month + 3, 1);
        newEnd = DateTime(newStart.year, newStart.month + 3, 0);
      } else {
        newStart = DateTime(currentStart.year, currentStart.month - 3, 1);
        newEnd = DateTime(newStart.year, newStart.month + 3, 0);
      }
    } else {
      // Es un año
      if (forward) {
        newStart = DateTime(currentStart.year + 1, 1, 1);
        newEnd = DateTime(currentStart.year + 1, 12, 31);
      } else {
        newStart = DateTime(currentStart.year - 1, 1, 1);
        newEnd = DateTime(currentStart.year - 1, 12, 31);
      }
    }

    await loadTransactions(DateTimeRange(start: newStart, end: newEnd));
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

  // Agrupa transacciones por categoría/etiqueta
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

  // Obtiene el período actual como texto
  String getCurrentPeriodText() {
    if (state.dateRange == null) return 'Sin período';

    final start = state.dateRange!.start;
    final end = state.dateRange!.end;
    final difference = end.difference(start).inDays;

    if (difference <= 31) {
      // Mes
      final months = [
        'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
        'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
      ];
      return '${months[start.month - 1]} ${start.year}';
    } else if (difference <= 92) {
      // Trimestre
      final quarter = ((start.month - 1) ~/ 3) + 1;
      return 'Q$quarter ${start.year}';
    } else {
      // Año
      return '${start.year}';
    }
  }
}

