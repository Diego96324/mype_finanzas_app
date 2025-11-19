import 'dart:async';

import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:mype_finanzas/presentation/providers/gamification/gamification_providers.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/utils/attachments_helper.dart';
import '../../../../core/utils/recurrence_helper.dart';
import '../../../../data/models/transaction_model.dart';
import '../../../../data/repositories/account_repository.dart';
import '../../../../data/repositories/transaction_repo.dart';
import '../../../../domain/services/auth_service.dart';
import '../../../../domain/services/category_budget_service.dart' as budget_service;
import '../../../../domain/services/transaction_cache_service.dart';
import '../../../features/budgets/controllers/category_budget_controller.dart';
import '../../../../core/providers/budget_notifications_provider.dart';

part 'transactions_controller.g.dart';

// Provider para el repositorio de cuentas
final accountRepositoryProvider = Provider<AccountRepository>((ref) => AccountRepository());

class TransactionsState {
  final List<AppTransaction> transactions;
  final Map<String, double>? stats;
  final bool isLoading;
  final String? error;
  final TransactionFilters filters;
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

class TransactionFilters {
  final List<String>? tipos;
  final DateTime? from;
  final DateTime? to;
  final String? searchTerm;
  final String order;
  final List<int>? categoriaIds;
  final double? minAmount;
  final double? maxAmount;
  final bool tagOnly;
  final bool? onlyRecurrent;
  final bool? hasAttachment;
  final String? frecuencia;
  final bool noteOnly;

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

@riverpod
class TransactionsController extends _$TransactionsController {
  final TransactionRepo _transactionRepo = TransactionRepo();
  final TransactionCacheService _cacheService = TransactionCacheService();
  final AuthService _authService = AuthService();

  @override
  TransactionsState build() {
    // Restauramos la forma correcta de iniciar la carga asíncrona.
    Future.microtask(() => loadTransactions(reset: true));
    return const TransactionsState(isLoading: true, hasMore: true, loadedCount: 0);
  }

  Future<void> loadTransactions({bool reset = false}) async {
    if (state.isLoading && !reset) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final userId = await _getEffectiveUserId();
      if (userId == null) return;

      if (reset) {
        state = state.copyWith(transactions: [], loadedCount: 0, hasMore: true);
      }

      // 1. Procesar recurrencias ANTES de cargar la lista.
      await _processDueRecurrences(userId);

      // 2. Ahora cargamos la lista, que ya incluirá las transacciones nuevas.
      final filters = state.filters;
      const pageSize = 50;
      final offset = state.loadedCount;

      final newPage = await _transactionRepo.listMultiple(
        usuarioId: userId,
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

      final stats = await _transactionRepo.getStats(usuarioId: userId);

      state = state.copyWith(
        transactions: reset ? newPage : [...state.transactions, ...newPage],
        stats: stats,
        isLoading: false,
        error: null,
        loadedCount: (reset ? 0 : state.loadedCount) + newPage.length,
        hasMore: newPage.length == pageSize,
      );

    } catch (e) {
      debugPrint('🔴 Error cargando transacciones: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'No se pudieron cargar los movimientos.',
      );
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoading) return;
    await loadTransactions();
  }

  Future<bool> saveTransaction(AppTransaction transaction) async {
    try {
      final userId = _authService.currentUserId;
      if (userId == null) {
        state = state.copyWith(error: 'Sesión expirada. Vuelve a ingresar.');
        return false;
      }

      if (transaction.monto <= 0) {
        state = state.copyWith(error: 'El monto debe ser positivo.');
        return false;
      }

      final now = DateTime.now();
      final newTransaction = _prepareTransactionForSave(transaction, userId, now);

      await _transactionRepo.insertAndGetId(newTransaction);
      debugPrint('💾 Transacción guardada correctamente');

      _cacheService.invalidateUser(userId);
      await _refreshAll();

      _handleGamification(userId, 'transaction_created', newTransaction);

      if (newTransaction.tipo == 'egreso' && newTransaction.categoriaId != null) {
        _handleBudgetCheck(newTransaction.categoriaId!, newTransaction.fecha);
      }

      return true;
    } catch (e) {
      state = state.copyWith(error: 'Error al guardar: ${e.toString()}');
      return false;
    }
  }

  Future<bool> updateTransaction(AppTransaction transaction) async {
    try {
      if (transaction.id == null) {
        state = state.copyWith(error: 'Error interno: ID no encontrado.');
        return false;
      }

      final userId = _authService.currentUserId;
      if (userId == null) {
        state = state.copyWith(error: 'Sesión expirada.');
        return false;
      }

      final updatedTransaction = transaction.copyWith(updatedAt: DateTime.now());

      await _transactionRepo.update(updatedTransaction);

      final updatedList = state.transactions
          .map((t) => t.id == updatedTransaction.id ? updatedTransaction : t)
          .toList();
      state = state.copyWith(transactions: updatedList);

      _cacheService.invalidateUser(userId);

      _handleGamification(userId, 'transaction_updated', updatedTransaction);

      if (updatedTransaction.tipo == 'egreso' && updatedTransaction.categoriaId != null) {
        _handleBudgetCheck(updatedTransaction.categoriaId!, updatedTransaction.fecha);
      }

      _refreshAll();

      return true;
    } catch (e) {
      state = state.copyWith(error: 'No se pudo actualizar: ${e.toString()}');
      return false;
    }
  }

  Future<bool> deleteTransaction(int transactionId) async {
    final previousList = state.transactions;
    try {
      final userId = _authService.currentUserId;
      if (userId == null) return false;

      final tx = await _transactionRepo.getById(transactionId);

      state = state.copyWith(
          transactions: previousList.where((t) => t.id != transactionId).toList()
      );

      await _transactionRepo.delete(transactionId);

      if (tx?.comprobanteUri != null && tx!.comprobanteUri!.isNotEmpty) {
        _deleteAttachmentInBackground(tx.comprobanteUri!);
      }

      _cacheService.invalidateUser(userId);
      _refreshAll();

      if (tx != null && tx.tipo == 'egreso' && tx.categoriaId != null) {
        _handleBudgetCheck(tx.categoriaId!, tx.fecha);
      }

      return true;
    } catch (e) {
      state = state.copyWith(transactions: previousList, error: 'Error al eliminar.');
      return false;
    }
  }

  void _handleGamification(int userId, String eventType, AppTransaction tx) {
    Future.microtask(() async {
      try {
        final service = ref.read(gamificationServiceProvider);
        await service.recordEvent(
            usuarioId: userId,
            tipoEvento: eventType,
            transactionType: tx.tipo,
            fecha: tx.fecha,
            descripcion: eventType == 'transaction_created'
                ? 'Nuevo registro: ${tx.tipo}'
                : 'Actualización de registro'
        );
      } catch (e) {
        debugPrint('🎮 Gamification skip: $e');
      }
    });
  }

  void _handleBudgetCheck(int categoriaId, DateTime fecha) {
    Future.microtask(() async {
      try {
        _invalidateCategoryBudget(categoriaId, fecha);
        await _notifyCategoryBudget(categoriaId, fecha);
        final notifier = ref.read(budgetNotificationsProvider.notifier);
        await notifier.onTransactionChanged();
        notifier.checkBudgets();
      } catch (e) {
        debugPrint('💰 Budget check skip: $e');
      }
    });
  }

  AppTransaction _prepareTransactionForSave(AppTransaction tx, int userId, DateTime now) {
    final frecuencia = tx.frecuenciaRecurrencia;
    final isRecurrent = tx.recurrente && frecuencia != null && frecuencia != 'una_vez';

    final next = tx.nextOccurrence ?? (isRecurrent
        ? RecurrenceHelper.computeNextOccurrence(
      base: tx.fecha,
      frecuencia: frecuencia,
      intervalDays: tx.recurrenceIntervalDays,
    )
        : null);

    return tx.copyWith(
      usuarioId: userId,
      nextOccurrence: next,
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<int?> _getEffectiveUserId() async {
    var userId = _authService.currentUserId;
    if (userId == null) {
      await AppDatabase().ensureSeedUser();
      userId = _authService.currentUserId;
      if (userId == null) {
        state = state.copyWith(isLoading: false, error: 'Usuario no identificado');
        return null;
      }
    }
    return userId;
  }

  Future<void> _processDueRecurrences(int userId) async {
    try {
      final now = DateTime.now();
      final recurrentList = await _transactionRepo.listMultiple(
        usuarioId: userId,
        tipos: null, from: null, to: null, order: 'fecha_desc', onlyRecurrent: true,
      );

      for (final tx in recurrentList) {
        if (!tx.recurrente || tx.frecuenciaRecurrencia == null || tx.frecuenciaRecurrencia == 'una_vez') continue;

        DateTime? next = tx.nextOccurrence;
        if (next == null) continue;

        int safety = 0;
        DateTime? lastNext = next;

        while (lastNext != null && !lastNext.isAfter(now) && RecurrenceHelper.isRecurrenceActive(tx.recurrenceEndDate, lastNext)) {
          final alreadyExists = await _transactionRepo.existsChildAtDate(usuarioId: userId, fecha: lastNext);

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

          lastNext = RecurrenceHelper.computeNextOccurrence(
            base: lastNext,
            frecuencia: tx.frecuenciaRecurrencia,
            intervalDays: tx.recurrenceIntervalDays,
          );

          safety++;
          if (safety > 36) break;
        }

        if (lastNext != next) {
          await _transactionRepo.update(tx.copyWith(nextOccurrence: lastNext, updatedAt: now));
        }
      }
      // No llamamos a refreshAll para evitar el bucle. La carga principal se encargará.
    } catch (e) {
      debugPrint('⚠️ Recurrence error: $e');
    }
  }

  void _deleteAttachmentInBackground(String uri) {
    Future(() async {
      try {
        await AttachmentsHelper.deleteAttachment(uri);
      } catch (_) {}
    });
  }

  Future<void> _refreshAll() async {
    await loadTransactions(reset: true);
  }

  Future<bool> deleteAccountWithTransaction(int accountId) async {
    try {
      final userId = _authService.currentUserId;
      if (userId == null) return false;

      final success = await ref.read(accountRepositoryProvider).deleteAccountFromTransaction(accountId);
      if (success) {
        _cacheService.invalidateUser(userId);
        await _refreshAll();
      }
      return success;
    } catch (e) {
      state = state.copyWith(error: 'Error al eliminar cuenta: $e');
      return false;
    }
  }

  Future<AppTransaction?> getTransactionById(int transactionId) async {
    try {
      return await _transactionRepo.getById(transactionId);
    } catch (e) {
      return null;
    }
  }

  Future<double> getTotalByType(String tipo) async {
    try {
      final userId = _authService.currentUserId;
      if (userId == null) return 0;
      return await _transactionRepo.total(tipo, usuarioId: userId);
    } catch (e) {
      return 0;
    }
  }

  Future<void> searchTransactions(String searchTerm) async {
    await applyFilters(state.filters.copyWith(searchTerm: searchTerm));
  }

  Future<void> sortTransactions(String order) async {
    await applyFilters(state.filters.copyWith(order: order));
  }

  Future<void> applyFilters(TransactionFilters filters) async {
    state = state.copyWith(filters: filters);
    await loadTransactions(reset: true);
  }

  Future<void> clearFilters() async {
    state = state.copyWith(filters: const TransactionFilters());
    await loadTransactions(reset: true);
  }

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
      categoriaIds: (filtersMap['categoriaIds'] as List?)?.map((e) => e as int).toList(),
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

  Future<void> selectDateRange(DateTime? start, DateTime? end) async {
    await applyFilters(state.filters.copyWith(from: start, to: end));
  }

  Future<void> clearDateRange() async {
    await applyFilters(state.filters.copyWith(from: null, to: null));
  }

  Future<void> reloadAfterCreate() async => await loadTransactions(reset: true);
  Future<void> reloadAfterAccountUpdate() async => await loadTransactions(reset: true);

  DateTimeRange? get currentDateRange => (state.filters.from != null && state.filters.to != null)
      ? DateTimeRange(start: state.filters.from!, end: state.filters.to!)
      : null;

  String get currentTypeFilter => state.filters.tipos?.first ?? 'todos';
  String get currentOrder => state.filters.order;
  String? get currentSearchTerm => state.filters.searchTerm;

  void _invalidateCategoryBudget(int categoriaId, DateTime fecha) {
    final keyMensual = CategoryBudgetKey(
        categoriaId: categoriaId, periodo: 'mensual', referencia: DateTime(fecha.year, fecha.month, 1));
    final keyTrimestral = CategoryBudgetKey(
        categoriaId: categoriaId, periodo: 'trimestral', referencia: DateTime(fecha.year, fecha.month, 1));
    try {
      ref.invalidate(categoryBudgetControllerProvider(keyMensual));
      ref.invalidate(categoryBudgetControllerProvider(keyTrimestral));
    } catch (_) {}
  }

  Future<void> _notifyCategoryBudget(int categoriaId, DateTime fecha) async {
    try {
      final uid = _authService.currentUserId;
      if (uid == null) return;
      final service = budget_service.CategoryBudgetService();
      final refDate = DateTime(fecha.year, fecha.month, 1);

      for (final periodo in ['mensual', 'trimestral']) {
        await service.getSummary(
          usuarioId: uid, categoriaId: categoriaId, periodo: periodo, referencia: refDate, persistAlertChange: false,
        );
      }
    } catch (_) {}
  }
}