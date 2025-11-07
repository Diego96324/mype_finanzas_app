import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/models/transaction_model.dart';
import '../../../core/repos/transaction_repo.dart';

part 'transaction_detail_controller.g.dart';

// Estado para el detalle de una transacción
class TransactionDetailState {
  final AppTransaction? transaction;
  final bool isLoading;
  final String? error;

  const TransactionDetailState({
    this.transaction,
    this.isLoading = false,
    this.error,
  });

  TransactionDetailState copyWith({
    AppTransaction? transaction,
    bool? isLoading,
    String? error,
  }) {
    return TransactionDetailState(
      transaction: transaction ?? this.transaction,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// Controlador para manejar el detalle de una transacción
@riverpod
class TransactionDetailController extends _$TransactionDetailController {
  final TransactionRepo _transactionRepo = TransactionRepo();

  @override
  TransactionDetailState build(int transactionId) {
    // Cargamos la transacción cuando arranca
    Future.microtask(() => loadTransaction(transactionId));
    return const TransactionDetailState(isLoading: true);
  }

  // Carga los detalles de la transacción
  Future<void> loadTransaction(int id) async {
    print('🔵 [TransactionDetailController] ID: $id');
    state = state.copyWith(isLoading: true, error: null);

    try {
      final transaction = await _transactionRepo.getById(id);

      if (transaction != null) {
        print('✅ [TransactionDetailController] Transacción: ${transaction.etiqueta}');
        state = TransactionDetailState(
          transaction: transaction,
          isLoading: false,
          error: null,
        );
      } else {
        print('🔴 [TransactionDetailController] No encontrada');
        state = TransactionDetailState(
          transaction: null,
          isLoading: false,
          error: 'Transacción no encontrada',
        );
      }
    } catch (e, stackTrace) {
      print('🔴 [TransactionDetailController] Error: $e');
      print('🔴 [TransactionDetailController] StackTrace: $stackTrace');
      state = TransactionDetailState(
        transaction: null,
        isLoading: false,
        error: 'Error al cargar: ${e.toString()}',
      );
    }
  }

  // Recarga la transacción
  Future<void> refresh() async {
    if (state.transaction?.id != null) {
      await loadTransaction(state.transaction!.id!);
    }
  }

  // Elimina la transacción
  Future<bool> delete() async {
    if (state.transaction?.id == null) {
      state = state.copyWith(error: 'No hay transacción para eliminar');
      return false;
    }

    try {
      state = state.copyWith(isLoading: true, error: null);

      await _transactionRepo.delete(state.transaction!.id!);

      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Error al eliminar: ${e.toString()}',
      );
      return false;
    }
  }

  // Actualiza la transacción
  Future<bool> update(AppTransaction updatedTransaction) async {
    if (updatedTransaction.id == null) {
      state = state.copyWith(error: 'Transacción sin ID');
      return false;
    }

    try {
      state = state.copyWith(isLoading: true, error: null);

      final updated = updatedTransaction.copyWith(
        updatedAt: DateTime.now(),
      );

      await _transactionRepo.update(updated);

      // Recargar después de actualizar
      await loadTransaction(updated.id!);

      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Error al actualizar: ${e.toString()}',
      );
      return false;
    }
  }
}

