import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/repositories/account_repository.dart';
import '../../models/dtos/account_model.dart';
import '../../controllers/transactions/transactions_controller.dart';

part 'account_providers.g.dart';

// Repositorio de cuentas
@riverpod
AccountRepository accountRepository(Ref ref) {
  return AccountRepository();
}

// Estado de las cuentas que ve el usuario
@riverpod
class AccountsState extends _$AccountsState {
  @override
  Future<List<Account>> build() async {
    return await _loadAccounts();
  }

  Future<List<Account>> _loadAccounts() async {
    try {
      final repo = ref.read(accountRepositoryProvider);
      return await repo.getUserAccounts();
    } catch (e) {
      return [];
    }
  }

  // Crear nueva cuenta más para la lista
  Future<bool> createAccount({
    required String nombre,
    required String tipo,
    required double saldoInicial,
    String? numeroFin,
    String? institucion,
    String? color,
    String? icono,
    String moneda = 'PEN',
  }) async {
    try {
      final repo = ref.read(accountRepositoryProvider);
      final account = await repo.createAccount(
        nombre: nombre,
        tipo: tipo,
        saldoInicial: saldoInicial,
        numeroFin: numeroFin,
        institucion: institucion,
        color: color,
        icono: icono,
        moneda: moneda,
      );

      if (account != null) {
        await refresh();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Actualizar cuenta sin drama
  Future<bool> updateAccount({
    required int accountId,
    String? nombre,
    String? tipo,
    double? saldo,
    String? numeroFin,
    String? institucion,
    String? color,
    String? icono,
    bool? incluirEnTotal,
    String? moneda,
  }) async {
    try {
      final repo = ref.read(accountRepositoryProvider);
      final success = await repo.updateAccount(
        accountId: accountId,
        nombre: nombre,
        tipo: tipo,
        saldo: saldo,
        numeroFin: numeroFin,
        institucion: institucion,
        color: color,
        icono: icono,
        incluirEnTotal: incluirEnTotal,
        moneda: moneda,
      );

      if (success) {
        await refresh();
      }
      return success;
    } catch (e) {
      return false;
    }
  }

  // Borrar la cuenta
  Future<bool> deleteAccount(int accountId) async {
    try {
      final repo = ref.read(accountRepositoryProvider);
      final success = await repo.deleteAccount(accountId);

      if (success) {
        await refresh();
        // Recargar transacciones para que no quede basura fantasma en la lista
        try {
          ref.invalidate(transactionsControllerProvider);
        } catch (_) {}
      }
      return success;
    } catch (e) {
      return false;
    }
  }

  // Pasar plata entre cuentas
  Future<bool> transfer({
    required int fromAccountId,
    required int toAccountId,
    required double amount,
    String? descripcion,
  }) async {
    try {
      final repo = ref.read(accountRepositoryProvider);
      final success = await repo.transferBetweenAccounts(
        fromAccountId: fromAccountId,
        toAccountId: toAccountId,
        amount: amount,
        descripcion: descripcion,
      );

      if (success) {
        await refresh();
      }
      return success;
    } catch (e) {
      return false;
    }
  }

  // Cambiar el orden pq si
  Future<bool> reorderAccounts(List<int> accountIds) async {
    try {
      final repo = ref.read(accountRepositoryProvider);
      final success = await repo.reorderAccounts(accountIds);

      if (success) {
        await refresh();
      }
      return success;
    } catch (e) {
      return false;
    }
  }

  // Refrescar la lista de cuentas
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _loadAccounts());
  }
}

// Resumen rápido de cuentas
@riverpod
Future<Map<String, dynamic>> accountsSummary(Ref ref) async {
  // Si cambias las cuentas esto se mueve.
  ref.watch(accountsStateProvider);

  final repo = ref.read(accountRepositoryProvider);
  return await repo.getAccountsSummary();
}

// Buscar una cuenta por id
@riverpod
Future<Account?> accountById(Ref ref, int accountId) async {
  final accounts = await ref.watch(accountsStateProvider.future);
  for (final account in accounts) {
    if (account.id == accountId) return account;
  }
  // Si no aparece, devolver null y ya
  return null;
}

// Total de saldos
@riverpod
Future<double> totalBalance(Ref ref) async {
  final summary = await ref.watch(accountsSummaryProvider.future);
  return summary['total'] as double? ?? 0.0;
}

// Filtrar cuentas por tipo
@riverpod
Future<List<Account>> accountsByType(Ref ref, String tipo) async {
  final accounts = await ref.watch(accountsStateProvider.future);
  return accounts.where((account) => account.tipo == tipo).toList();
}