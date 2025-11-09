import 'dart:async';

import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/services/global_alert_service.dart';
import '../../../../core/utils/attachments_helper.dart';
import '../../../../core/utils/recurrence_helper.dart';
import '../../../../data/models/transaction_model.dart';
import '../../../../data/repositories/account_repository.dart';
import '../../../../data/repositories/transaction_repo.dart';
import '../../../../domain/services/auth_service.dart';
import '../../../../domain/services/category_budget_service.dart' as budget_service;
import '../../../../domain/services/transaction_cache_service.dart';
import '../../../features/budgets/controllers/category_budget_controller.dart';

part 'transactions_controller.g.dart';

// Provider para el repositorio de cuentas
final accountRepositoryProvider =
    Provider<AccountRepository>((ref) => AccountRepository());

class TransactionsState {
  final List<AppTransaction> transactions; // lista de movimientos
  final Map<String, double>? stats; // totales de ingresos/egresos
  final bool isLoading;
  final String? error; // nunca se sabe
  final TransactionFilters filters; // filtros activos (fecha, tipo, etc)
  final bool hasMore;
  final int loadedCount;

  const TransactionsState({
    this.transactions = const [],
    this.stats,
    this.isLoading = false,
    this.error,
    this.filters = const TransactionFilters(),
    this.hasMore = true,
    this.loadedCount = 0,
  });

  TransactionsState copyWith({
    List<AppTransaction>? transactions,
    Map<String, double>? stats,
    bool? isLoading,
    String? error,
    TransactionFilters? filters,
    bool? hasMore,
    int? loadedCount,
  }) {
    return TransactionsState(
      transactions: transactions ?? this.transactions,
      stats: stats ?? this.stats,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      filters: filters ?? this.filters,
      hasMore: hasMore ?? this.hasMore,
      loadedCount: loadedCount ?? this.loadedCount,
    );
  }
}

// Para filtrar las transacciones por fecha, tipo, búsqueda, etc
class TransactionFilters {
  final List<String>? tipos; // ingreso, egreso
  final DateTime? from; // desde qué fecha
  final DateTime? to; // hasta qué fecha
  final String? searchTerm; // texto para buscar
  final String order; // cómo ordenar (fecha, monto)
  final List<int>? categoriaIds; // nuevas: categorías
  final double? minAmount; // monto mínimo
  final double? maxAmount; // monto máximo
  final bool tagOnly; // buscar solo en etiqueta
  final bool? onlyRecurrent; // solo transacciones recurrentes/no recurrentes
  final bool? hasAttachment; // con o sin comprobante
  final String? frecuencia; // frecuencia_recurrencia específica
  final bool noteOnly; // buscar sólo en nota

  const TransactionFilters({
    this.tipos,
    this.from,
    this.to,
    this.searchTerm,
    this.order = 'fecha_desc',
    this.categoriaIds,
    this.minAmount,
    this.maxAmount,
    this.tagOnly = false,
    this.onlyRecurrent,
    this.hasAttachment,
    this.frecuencia,
    this.noteOnly = false,
  });

  TransactionFilters copyWith({
    List<String>? tipos,
    DateTime? from,
    DateTime? to,
    String? searchTerm,
    String? order,
    List<int>? categoriaIds,
    double? minAmount,
    double? maxAmount,
    bool? tagOnly,
    bool? onlyRecurrent,
    bool? hasAttachment,
    String? frecuencia,
    bool? noteOnly,
  }) {
    return TransactionFilters(
      tipos: tipos ?? this.tipos,
      from: from ?? this.from,
      to: to ?? this.to,
      searchTerm: searchTerm ?? this.searchTerm,
      order: order ?? this.order,
      categoriaIds: categoriaIds ?? this.categoriaIds,
      minAmount: minAmount ?? this.minAmount,
      maxAmount: maxAmount ?? this.maxAmount,
      tagOnly: tagOnly ?? this.tagOnly,
      onlyRecurrent: onlyRecurrent ?? this.onlyRecurrent,
      hasAttachment: hasAttachment ?? this.hasAttachment,
      frecuencia: frecuencia ?? this.frecuencia,
      noteOnly: noteOnly ?? this.noteOnly,
    );
  }
}

// Controlador que maneja todos los movimientos de efectivo
@riverpod
class TransactionsController extends _$TransactionsController {
  final TransactionRepo _transactionRepo = TransactionRepo();
  final TransactionCacheService _cacheService = TransactionCacheService();
  final AuthService _authService = AuthService();

  @override
  TransactionsState build() {
    Future.microtask(() => loadTransactions(reset: true));
    return const TransactionsState(
        isLoading: true, hasMore: true, loadedCount: 0);
  }

  Future<void> loadTransactions({bool reset = false}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final userId = _authService.currentUserId;
      if (userId == null) {
        // intentar crear usuario seed si la DB está vacía
        await AppDatabase().ensureSeedUser();
        final retryUser = _authService.currentUserId;
        if (retryUser == null) {
          state =
              state.copyWith(isLoading: false, error: 'Usuario no autenticado');
          return;
        }
      }
      final effectiveUserId = _authService.currentUserId!;
      if (reset) {
        state =
            state.copyWith(transactions: [], loadedCount: 0, hasMore: true);
      }
      // Procesar ocurrencias recurrentes vencidas antes de listar
      await _processDueRecurrences(effectiveUserId);

      final filters = state.filters;
      debugPrint(
          '🔵 [TransactionsController] Filtros: tipos=${filters.tipos}, from=${filters.from}, to=${filters.to}, order=${filters.order}');

      const pageSize = 50;
      final offset = state.loadedCount;
      final newPage = await _transactionRepo.listMultiple(
        usuarioId: effectiveUserId,
        tipos: filters.tipos,
        from: filters.from,
        to: filters.to,
        order: filters.order,
        searchTerm: filters.searchTerm,
        categoriaIds: filters.categoriaIds,
        minAmount: filters.minAmount,
        maxAmount: filters.maxAmount,
        tagOnly: filters.tagOnly && !filters.noteOnly,
        noteOnly: filters.noteOnly,
        onlyRecurrent: filters.onlyRecurrent,
        hasAttachment: filters.hasAttachment,
        frecuencia: filters.frecuencia,
        limit: pageSize,
        offset: offset,
      );

      final stats =
          await _transactionRepo.getStats(usuarioId: effectiveUserId);
      debugPrint('✅ [TransactionsController] Stats: $stats');

      state = state.copyWith(
        transactions: [...state.transactions, ...newPage],
        stats: stats,
        isLoading: false,
        error: null,
        loadedCount: state.loadedCount + newPage.length,
        hasMore: newPage.length == pageSize,
      );

      debugPrint('✅ [TransactionsController] Ya está');
    } catch (e, stackTrace) {
      debugPrint('🔴 [TransactionsController] Error: $e');
      debugPrint('🔴 [TransactionsController] StackTrace: $stackTrace');
      state = state.copyWith(
        isLoading: false,
        error: 'Error al cargar transacciones: ${e.toString()}',
      );
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoading) return;
    await loadTransactions();
  }

  Future<void> _processDueRecurrences(int userId) async {
    try {
      final now = DateTime.now();
      final recurrentList = await _transactionRepo.listMultiple(
        usuarioId: userId,
        tipos: null,
        from: null,
        to: null,
        order: 'fecha_desc',
        onlyRecurrent: true,
      );

      for (final tx in recurrentList) {
        if (!(tx.recurrente &&
            tx.frecuenciaRecurrencia != null &&
            tx.frecuenciaRecurrencia != 'una_vez')) continue;
        DateTime? next = tx.nextOccurrence;
        if (next == null) continue;

        int safety = 0;
        DateTime? lastNext = next;
        while (lastNext != null &&
            !lastNext.isAfter(now) &&
            RecurrenceHelper.isRecurrenceActive(
                tx.recurrenceEndDate, lastNext)) {
          // Evitar duplicados si ya existe una hija en esa fecha exacta
          final userId = _authService.currentUserId!;
          final alreadyExists = await _transactionRepo.existsChildAtDate(
              usuarioId: userId, fecha: lastNext);
          if (!alreadyExists) {
            final child = tx.copyWith(
              id: null,
              fecha: lastNext,
              esRecurrente: true,
              comprobanteUri: null,
              createdAt: now,
              updatedAt: now,
            );
            await _transactionRepo.insert(child);
          }

          // Calcular siguiente
          lastNext = RecurrenceHelper.computeNextOccurrence(
            base: lastNext,
            frecuencia: tx.frecuenciaRecurrencia,
            intervalDays: tx.recurrenceIntervalDays,
          );

          safety++;
          if (safety > 36) break; // límite de seguridad (3 años si mensual)
        }

        // Actualizar nextOccurrence de la madre si cambió
        if (lastNext != next) {
          final motherUpdated = tx.copyWith(
            nextOccurrence: lastNext,
            updatedAt: now,
          );
          await _transactionRepo.update(motherUpdated);
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error procesando recurrencias: $e');
    }
  }

  Future<void> applyFilters(TransactionFilters filters) async {
    state = state.copyWith(filters: filters);
    await loadTransactions(reset: true);
  }

  // Quita todos los filtros
  Future<void> clearFilters() async {
    state = state.copyWith(filters: const TransactionFilters());
    await loadTransactions(reset: true);
  }

  // Guarda un ingreso o egreso nuevo
  Future<bool> saveTransaction(AppTransaction transaction) async {
    try {
      final userId = _authService.currentUserId;

      if (userId == null) {
        state = state.copyWith(error: 'Usuario no autenticado');
        return false;
      }

      if (transaction.monto <= 0) {
        state = state.copyWith(error: 'El monto debe ser mayor a cero');
        return false;
      }

      final frecuencia = transaction.frecuenciaRecurrencia;
      final isRecurrent = transaction.recurrente &&
          frecuencia != null &&
          frecuencia != 'una_vez';
      final next = transaction.nextOccurrence ??
          (isRecurrent
              ? RecurrenceHelper.computeNextOccurrence(
                  base: transaction.fecha,
                  frecuencia: frecuencia,
                  intervalDays: transaction.recurrenceIntervalDays,
                )
              : null);

      final now = DateTime.now();
      final newTransaction = transaction.copyWith(
        usuarioId: userId,
        nextOccurrence: next,
        createdAt: now,
        updatedAt: now,
      );

      await _transactionRepo.insertAndGetId(newTransaction);
      _cacheService.invalidateUser(userId);
      await _refreshAll();
      // invalidar presupuesto categoría si egreso
      if (newTransaction.tipo == 'egreso' &&
          newTransaction.categoriaId != null) {
        _invalidateCategoryBudget(
            newTransaction.categoriaId!, newTransaction.fecha);
        // Notificar si se cruzó umbral
        unawaited(_notifyCategoryBudget(
            newTransaction.categoriaId!, newTransaction.fecha));
      }
      return true;
    } catch (e) {
      state = state.copyWith(
          error: 'Error al guardar transacción: ${e.toString()}');
      return false;
    }
  }

  // Actualiza una transacción que ya existe
  Future<bool> updateTransaction(AppTransaction transaction) async {
    try {
      if (transaction.id == null) {
        state = state.copyWith(error: 'La transacción no tiene ID');
        return false;
      }

      final userId = _authService.currentUserId;

      if (userId == null) {
        state = state.copyWith(error: 'Usuario no autenticado');
        return false;
      }

      final updatedTransaction = transaction.copyWith(
        updatedAt: DateTime.now(),
      );

      await _transactionRepo.update(updatedTransaction);
      // Actualización optimista
      final updatedList = state.transactions
          .map((t) =>
              t.id == updatedTransaction.id ? updatedTransaction : t)
          .toList();
      state = state.copyWith(transactions: updatedList);
      _cacheService.invalidateUser(userId);
      await _refreshAll();
      if (updatedTransaction.tipo == 'egreso' &&
          updatedTransaction.categoriaId != null) {
        _invalidateCategoryBudget(
            updatedTransaction.categoriaId!, updatedTransaction.fecha);
        // Notificar si se cruzó umbral
        unawaited(_notifyCategoryBudget(
            updatedTransaction.categoriaId!, updatedTransaction.fecha));
      }
      return true;
    } catch (e) {
      state = state.copyWith(
          error: 'Error al actualizar transacción: ${e.toString()}');
      return false;
    }
  }

  // Borra una transacción
  Future<bool> deleteTransaction(int transactionId) async {
    try {
      final userId = _authService.currentUserId;

      if (userId == null) {
        state = state.copyWith(error: 'Usuario no autenticado');
        return false;
      }

      // obtener el comprobante antes de borrar
      final tx = await _transactionRepo.getById(transactionId);
      await _transactionRepo.delete(transactionId);

      // eliminar comprobante físico si existía
      if (tx?.comprobanteUri != null && tx!.comprobanteUri!.isNotEmpty) {
        await AttachmentsHelper.deleteAttachment(tx.comprobanteUri);
      }

      _cacheService.invalidateUser(userId);
      // Optimista: remover de la lista antes de recargar
      final filtered =
          state.transactions.where((t) => t.id != transactionId).toList();
      state = state.copyWith(transactions: filtered);
      await _refreshAll();
      if (tx != null && tx.tipo == 'egreso' && tx.categoriaId != null) {
        _invalidateCategoryBudget(tx.categoriaId!, tx.fecha);
      }
      return true;
    } catch (e) {
      state = state.copyWith(
          error: 'Error al eliminar transacción: ${e.toString()}');
      return false;
    }
  }

  // Borra una cuenta desde una transacción de apertura
  Future<bool> deleteAccountWithTransaction(int accountId) async {
    try {
      final userId = _authService.currentUserId;

      if (userId == null) {
        state = state.copyWith(error: 'Usuario no autenticado');
        return false;
      }

      // Importar el repositorio de cuentas
      final accountRepo = ref.read(accountRepositoryProvider);
      final success =
          await accountRepo.deleteAccountFromTransaction(accountId);

      if (success) {
        _cacheService.invalidateUser(userId);
        await _refreshAll();
      }

      return success;
    } catch (e) {
      state = state.copyWith(error: 'Error al eliminar cuenta: ${e.toString()}');
      return false;
    }
  }

  // Busca una transacción específica por ID
  Future<AppTransaction?> getTransactionById(int transactionId) async {
    try {
      return await _transactionRepo.getById(transactionId);
    } catch (e) {
      state = state.copyWith(
          error: 'Error al obtener transacción: ${e.toString()}');
      return null;
    }
  }

  // Calcula el total de ingresos o egresos
  Future<double> getTotalByType(String tipo) async {
    try {
      final userId = _authService.currentUserId;

      if (userId == null) {
        return 0;
      }

      return await _transactionRepo.total(tipo, usuarioId: userId);
    } catch (e) {
      return 0;
    }
  }

  // Busca transacciones por texto (etiqueta o nota)
  Future<void> searchTransactions(String searchTerm) async {
    final filters = state.filters.copyWith(searchTerm: searchTerm);
    await applyFilters(filters);
  }

  // Cambia el orden de las transacciones (por fecha o monto)
  Future<void> sortTransactions(String order) async {
    final filters = state.filters.copyWith(order: order);
    await applyFilters(filters);
  }

  // Filtro para actualizar filtros desde un mapa (compatibilidad con SearchFilterScreen)
  Future<void> updateFiltersFromMap(Map<String, dynamic> filtersMap) async {
    List<String>? tipos;
    if (filtersMap.containsKey('tipos')) {
      tipos = List<String>.from(filtersMap['tipos']);
    } else if (filtersMap.containsKey('tipo')) {
      final tipo = filtersMap['tipo'] as String;
      tipos = tipo == 'todos' ? null : [tipo];
    }

    String order = state.filters.order;
    if (filtersMap.containsKey('orders')) {
      final orders = List<String>.from(filtersMap['orders']);
      if (orders.isNotEmpty) order = orders.first;
    } else if (filtersMap.containsKey('order')) {
      order = filtersMap['order'] as String;
    }

    final newFilters = TransactionFilters(
      tipos: tipos,
      from: state.filters.from,
      to: state.filters.to,
      searchTerm: filtersMap['searchTerm'] as String?,
      order: order,
      categoriaIds:
          (filtersMap['categoriaIds'] as List?)?.map((e) => e as int).toList(),
      minAmount: filtersMap['minAmount'] as double?,
      maxAmount: filtersMap['maxAmount'] as double?,
      tagOnly: (filtersMap['tagOnly'] as bool?) ?? false,
      onlyRecurrent: filtersMap['onlyRecurrent'] as bool?,
      hasAttachment: filtersMap['hasAttachment'] as bool?,
      frecuencia: filtersMap['frecuencia'] as String?,
      noteOnly: (filtersMap['noteOnly'] as bool?) ?? false,
    );

    await applyFilters(newFilters);
  }

  // Filtro para seleccionar rango de fechas
  Future<void> selectDateRange(DateTime? start, DateTime? end) async {
    final newFilters = state.filters.copyWith(
      from: start,
      to: end,
    );
    await applyFilters(newFilters);
  }

  // Filtro para limpiar el rango de fechas
  Future<void> clearDateRange() async {
    final newFilters = state.filters.copyWith(
      from: null,
      to: null,
    );
    await applyFilters(newFilters);
  }

  // Recarga después de crear una transacción (llamado desde el FAB)
  Future<void> reloadAfterCreate() async {
    await loadTransactions(reset: true);
  }

  // Recarga después de editar una cuenta (llamado desde el diálogo de edición)
  Future<void> reloadAfterAccountUpdate() async {
    await loadTransactions(reset: true);
  }

  // Obtiene el rango de fechas actual
  DateTimeRange? get currentDateRange {
    if (state.filters.from != null && state.filters.to != null) {
      return DateTimeRange(
        start: state.filters.from!,
        end: state.filters.to!,
      );
    }
    return null;
  }

  // Obtiene el tipo de filtro actual
  String get currentTypeFilter {
    final tipos = state.filters.tipos;
    if (tipos == null || tipos.isEmpty) return 'todos';
    return tipos.first;
  }

  // Obtiene el orden actual
  String get currentOrder {
    return state.filters.order;
  }

  // Obtiene el término de búsqueda actual
  String? get currentSearchTerm {
    return state.filters.searchTerm;
  }

  void _invalidateCategoryBudget(int categoriaId, DateTime fecha) {
    final keyMensual = CategoryBudgetKey(
        categoriaId: categoriaId,
        periodo: 'mensual',
        referencia: DateTime(fecha.year, fecha.month, 1));
    final keyTrimestral = CategoryBudgetKey(
        categoriaId: categoriaId,
        periodo: 'trimestral',
        referencia: DateTime(fecha.year, fecha.month, 1));
    try {
      ref.invalidate(categoryBudgetControllerProvider(keyMensual));
      ref.invalidate(categoryBudgetControllerProvider(keyTrimestral));
    } catch (e) {
      debugPrint('⚠️ Error invalidando presupuesto categoría: $e');
    }
  }

  Future<void> _notifyCategoryBudget(int categoriaId, DateTime fecha) async {
    try {
      final uid = _authService.currentUserId;
      if (uid == null) return;
      final service = budget_service.CategoryBudgetService();
      final refDate = DateTime(fecha.year, fecha.month, 1);
      for (final periodo in ['mensual', 'trimestral']) {
        final summary = await service.getSummary(
          usuarioId: uid,
          categoriaId: categoriaId,
          periodo: periodo,
          referencia: refDate,
        );
        final umbral = summary?.nuevoUmbralEmitido;
        if (summary != null && umbral != null) {
          await GlobalAlertService().showBudgetThresholdAlert(
            categoriaId: categoriaId,
            categoriaNombre: summary.budget.nombre,
            porcentaje: umbral.toDouble(),
            limite: summary.budget.montoLimite,
            periodo: periodo,
            referencia: refDate,
          );
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error notificando alerta presupuesto: $e');
    }
  }

  Future<void> _refreshAll() async {
    await loadTransactions(reset: true);
  }
}
