import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../../data/models/transaction_model.dart';
import '../../../../data/repositories/transaction_repo.dart';
import '../../../../data/repositories/account_repository.dart';
import '../../../../domain/services/auth_service.dart';
import '../../../../domain/services/transaction_cache_service.dart';

part 'transactions_controller.g.dart';

// Provider para el repositorio de cuentas
final accountRepositoryProvider = Provider<AccountRepository>((ref) => AccountRepository());

class TransactionsState {
  final List<AppTransaction> transactions; // lista de movimientos
  final Map<String, double>? stats; // totales de ingresos/egresos
  final bool isLoading;
  final String? error; // nunca se sabe
  final TransactionFilters filters; // filtros activos (fecha, tipo, etc)

  const TransactionsState({
    this.transactions = const [],
    this.stats,
    this.isLoading = false,
    this.error,
    this.filters = const TransactionFilters(),
  });

  TransactionsState copyWith({
    List<AppTransaction>? transactions,
    Map<String, double>? stats,
    bool? isLoading,
    String? error,
    TransactionFilters? filters,
  }) {
    return TransactionsState(
      transactions: transactions ?? this.transactions,
      stats: stats ?? this.stats,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      filters: filters ?? this.filters,
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

  const TransactionFilters({
    this.tipos,
    this.from,
    this.to,
    this.searchTerm,
    this.order = 'fecha_desc',
  });

  TransactionFilters copyWith({
    List<String>? tipos,
    DateTime? from,
    DateTime? to,
    String? searchTerm,
    String? order,
  }) {
    return TransactionFilters(
      tipos: tipos ?? this.tipos,
      from: from ?? this.from,
      to: to ?? this.to,
      searchTerm: searchTerm ?? this.searchTerm,
      order: order ?? this.order,
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
    Future.microtask(() => loadTransactions());
    return const TransactionsState(isLoading: true);
  }

  Future<void> loadTransactions() async {
    debugPrint('🔵 [TransactionsController] Cargando transacciones...');
    state = state.copyWith(isLoading: true, error: null);

    try {
      final userId = _authService.currentUserId;
      debugPrint('🔵 [TransactionsController] User: $userId');

      if (userId == null) {
        debugPrint('🔴 [TransactionsController] Sin usuario');
        state = state.copyWith(
          isLoading: false,
          error: 'Usuario no autenticado',
        );
        return;
      }

      final filters = state.filters;
      debugPrint('🔵 [TransactionsController] Filtros: tipos=${filters.tipos}, from=${filters.from}, to=${filters.to}, order=${filters.order}');

      final transactions = await _transactionRepo.listMultiple(
        usuarioId: userId,
        tipos: filters.tipos,
        from: filters.from,
        to: filters.to,
        searchTerm: filters.searchTerm,
        orders: [filters.order],
      );

      debugPrint('✅ [TransactionsController] ${transactions.length} transacciones');

      final stats = await _transactionRepo.getStats(usuarioId: userId);
      debugPrint('✅ [TransactionsController] Stats: $stats');

      state = TransactionsState(
        transactions: transactions,
        stats: stats,
        isLoading: false,
        error: null,
        filters: filters,
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

  Future<void> applyFilters(TransactionFilters filters) async {
    state = state.copyWith(filters: filters);
    await loadTransactions();
  }

  // Quita todos los filtros
  Future<void> clearFilters() async {
    state = state.copyWith(filters: const TransactionFilters());
    await loadTransactions();
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

      // Guardamos la transacción con el usuario correcto
      final now = DateTime.now();
      final newTransaction = transaction.copyWith(
        usuarioId: userId,
        createdAt: now,
        updatedAt: now,
      );

      await _transactionRepo.insert(newTransaction);

      _cacheService.invalidateUser(userId);
      await loadTransactions();

      return true;
    } catch (e) {
      state = state.copyWith(error: 'Error al guardar transacción: ${e.toString()}');
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

      // Actualizamos la fecha de modificación
      final updatedTransaction = transaction.copyWith(
        updatedAt: DateTime.now(),
      );

      await _transactionRepo.update(updatedTransaction);

      // Limpiamos caché y recargamos
      _cacheService.invalidateUser(userId);
      await loadTransactions();

      return true;
    } catch (e) {
      state = state.copyWith(error: 'Error al actualizar transacción: ${e.toString()}');
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

      await _transactionRepo.delete(transactionId);

      // Actualizamos después de borrar
      _cacheService.invalidateUser(userId);
      await loadTransactions();

      return true;
    } catch (e) {
      state = state.copyWith(error: 'Error al eliminar transacción: ${e.toString()}');
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
      final success = await accountRepo.deleteAccountFromTransaction(accountId);

      if (success) {
        // Actualizamos la lista de transacciones
        _cacheService.invalidateUser(userId);
        await loadTransactions();
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
      state = state.copyWith(error: 'Error al obtener transacción: ${e.toString()}');
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
    await loadTransactions();
  }

  // Recarga después de editar una cuenta (llamado desde el diálogo de edición)
  Future<void> reloadAfterAccountUpdate() async {
    await loadTransactions();
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
}
