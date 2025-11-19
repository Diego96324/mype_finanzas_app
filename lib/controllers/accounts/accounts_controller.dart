import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../models/dtos/account_model.dart';
import '../../models/services/account_service.dart';
import '../../models/services/auth_service.dart';

part 'accounts_controller.g.dart';

// Aquí guardamos toda la info de las cuentas del usuario
class AccountsState {
  final List<Account> accounts; // todas las cuentas
  final Map<String, List<Account>> groupedAccounts; // separadas por activos/pasivos
  final PatrimonioSummary? patrimonioSummary; // el resumen de plata
  final bool isLoading; // para mostrar el loading
  final String? error; // por si algo sale mal

  const AccountsState({
    this.accounts = const [],
    this.groupedAccounts = const {},
    this.patrimonioSummary,
    this.isLoading = false,
    this.error,
  });

  AccountsState copyWith({
    List<Account>? accounts,
    Map<String, List<Account>>? groupedAccounts,
    PatrimonioSummary? patrimonioSummary,
    bool? isLoading,
    String? error,
  }) {
    return AccountsState(
      accounts: accounts ?? this.accounts,
      groupedAccounts: groupedAccounts ?? this.groupedAccounts,
      patrimonioSummary: patrimonioSummary ?? this.patrimonioSummary,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// Este controlador maneja lo relacionado con las cuentas bancarias
@riverpod
class AccountsController extends _$AccountsController {
  final AccountService _accountService = AccountService();
  final AuthService _authService = AuthService();

  @override
  AccountsState build() {
    // Apenas arranca el controlador, traemos las cuentas
    Future.microtask(() => loadAccounts());
    return const AccountsState(isLoading: true);
  }

  // Trae todas las cuentas desde la BD
  Future<void> loadAccounts() async {
    debugPrint('🔵 [AccountsController] Cargando cuentas...');
    state = state.copyWith(isLoading: true, error: null);

    try {
      final userId = _authService.currentUserId;
      debugPrint('🔵 [AccountsController] User: $userId');

      if (userId == null) {
        debugPrint('🔴 [AccountsController] No hay usuario logueado');
        state = state.copyWith(
          isLoading: false,
          error: 'Usuario no autenticado',
        );
        return;
      }

      debugPrint('🔵 [AccountsController] Trayendo cuentas de la BD...');
      // Traemos todas las cuentas junto para que sea más rápido
      final results = await Future.wait([
        _accountService.listAccounts(userId),
        _accountService.getGroupedAccounts(userId),
        _accountService.calculatePatrimonio(userId),
      ]);

      final accounts = results[0] as List<Account>;
      final grouped = results[1] as Map<String, List<Account>>;
      final patrimonio = results[2] as PatrimonioSummary;

      debugPrint('✅ [AccountsController] Listo! ${accounts.length} cuentas');
      debugPrint('✅ [AccountsController] Patrimonio: activos=${patrimonio.activos}, pasivos=${patrimonio.pasivos}');

      state = AccountsState(
        accounts: accounts,
        groupedAccounts: grouped,
        patrimonioSummary: patrimonio,
        isLoading: false,
        error: null,
      );

      debugPrint('✅ [AccountsController] Ya está');
    } catch (e, stackTrace) {
      debugPrint('🔴 [AccountsController] Error: $e');
      debugPrint('🔴 [AccountsController] StackTrace: $stackTrace');
      state = state.copyWith(
        isLoading: false,
        error: 'Error al cargar cuentas: ${e.toString()}',
      );
    }
  }

  // Crea una cuenta nueva
  Future<AccountOperationResult> createAccount({
    required String nombre,
    required String tipo,
    required double saldo,
    required String moneda,
    String? institucion,
    String? numeroFin,
    String? color,
    String? icono,
  }) async {
    final userId = _authService.currentUserId;

    if (userId == null) {
      return AccountOperationResult(
        success: false,
        message: 'Usuario no autenticado',
      );
    }

    final result = await _accountService.createAccount(
      usuarioId: userId,
      nombre: nombre,
      tipo: tipo,
      saldo: saldo,
      moneda: moneda,
      institucion: institucion,
      numeroFin: numeroFin,
      color: color,
      icono: icono,
    );

    // Si salió bien, actualizamos la lista
    if (result.success) {
      await loadAccounts();
    }

    return result;
  }

  // Edita una cuenta que ya existe
  Future<AccountOperationResult> updateAccount(Account account) async {
    if (account.id == null) {
      return AccountOperationResult(
        success: false,
        message: 'Cuenta sin ID',
      );
    }

    final result = await _accountService.updateAccount(
      accountId: account.id!,
      nombre: account.nombre,
      tipo: account.tipo,
      saldo: account.saldo,
      moneda: account.moneda,
      institucion: account.institucion,
      numeroFin: account.numeroFin,
      color: account.color,
      icono: account.icono,
      incluirEnTotal: account.incluirEnTotal,
    );

    // Recargamos para ver los cambios
    if (result.success) {
      await loadAccounts();
    }

    return result;
  }

  // Borra una cuenta (en realidad solo la marca como inactiva)
  Future<AccountOperationResult> deleteAccount(int accountId) async {
    final result = await _accountService.deleteAccount(accountId);

    // Actualizamos la lista después de borrar
    if (result.success) {
      await loadAccounts();
    }

    return result;
  }

  // Busca una cuenta específica por su ID
  Future<Account?> getAccountById(int accountId) async {
    return await _accountService.getAccountById(accountId);
  }

  // Ajusta el saldo de una cuenta (usado cuando hay transacciones)
  Future<bool> adjustAccountBalance({
    required int accountId,
    required double amount,
  }) async {
    final success = await _accountService.adjustAccountBalance(
      accountId: accountId,
      amount: amount,
    );

    // Si cambió el saldo, lo recargamos
    if (success) {
      await loadAccounts();
    }

    return success;
  }

  // Revisa que los datos de la cuenta estén bien antes de guardar
  AccountValidationResult validateAccount({
    required String nombre,
    required String tipo,
    required double saldo,
    required String moneda,
  }) {
    return _accountService.validateAccount(
      nombre: nombre,
      tipo: tipo,
      saldo: saldo,
      moneda: moneda,
    );
  }
}

