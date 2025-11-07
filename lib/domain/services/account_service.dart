import '../../../data/models/account_model.dart';
import '../../data/repositories/account_repo.dart';

/// Servicio que maneja la lógica de negocio para las cuentas
class AccountService {
  final AccountRepo _accountRepo = AccountRepo();

  /// Valida los datos de una cuenta antes de crear o actualizar
  AccountValidationResult validateAccount({
    required String nombre,
    required String tipo,
    required double saldo,
    required String moneda,
  }) {
    final errors = <String>[];

    // Validar nombre
    if (nombre.trim().isEmpty) {
      errors.add('El nombre de la cuenta es obligatorio');
    } else if (nombre.length > 100) {
      errors.add('El nombre no puede exceder 100 caracteres');
    }

    // Validar tipo
    final tiposValidos = [
      'efectivo',
      'debito',
      'credito',
      'virtual',
      'inversion',
      'por_cobrar',
      'por_pagar'
    ];
    if (!tiposValidos.contains(tipo)) {
      errors.add('Tipo de cuenta no válido');
    }

    // Validar saldo según tipo de cuenta
    final esPasivo = tipo == 'credito' || tipo == 'por_pagar';
    if (!esPasivo && saldo < 0) {
      errors.add('Las cuentas de activo no pueden tener saldo negativo');
    }

    // Validar moneda
    final monedasValidas = ['PEN', 'USD', 'EUR'];
    if (!monedasValidas.contains(moneda)) {
      errors.add('Moneda no válida');
    }

    return AccountValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
    );
  }

  /// Crea una nueva cuenta con validaciones
  Future<AccountOperationResult> createAccount({
    required int usuarioId,
    required String nombre,
    required String tipo,
    required double saldo,
    required String moneda,
    String? institucion,
    String? nota,
  }) async {
    try {
      // Validar datos
      final validation = validateAccount(
        nombre: nombre,
        tipo: tipo,
        saldo: saldo,
        moneda: moneda,
      );

      if (!validation.isValid) {
        return AccountOperationResult(
          success: false,
          message: validation.errors.join(', '),
        );
      }

      // Crear cuenta
      final account = Account(
        usuarioId: usuarioId,
        nombre: nombre.trim(),
        tipo: tipo,
        moneda: moneda,
        saldo: saldo,
        institucion: institucion?.trim(),
        nota: nota?.trim(),
      );

      final id = await _accountRepo.insert(account);

      return AccountOperationResult(
        success: true,
        message: 'Cuenta creada exitosamente',
        accountId: id,
      );
    } catch (e) {
      return AccountOperationResult(
        success: false,
        message: 'Error al crear cuenta: ${e.toString()}',
      );
    }
  }

  /// Actualiza una cuenta existente
  Future<AccountOperationResult> updateAccount({
    required Account account,
  }) async {
    try {
      // Validar datos
      final validation = validateAccount(
        nombre: account.nombre,
        tipo: account.tipo,
        saldo: account.saldo,
        moneda: account.moneda,
      );

      if (!validation.isValid) {
        return AccountOperationResult(
          success: false,
          message: validation.errors.join(', '),
        );
      }

      final result = await _accountRepo.update(account);

      return AccountOperationResult(
        success: result > 0,
        message: result > 0 ? 'Cuenta actualizada exitosamente' : 'No se pudo actualizar la cuenta',
      );
    } catch (e) {
      return AccountOperationResult(
        success: false,
        message: 'Error al actualizar cuenta: ${e.toString()}',
      );
    }
  }

  /// Elimina una cuenta (soft delete)
  Future<AccountOperationResult> deleteAccount(int accountId) async {
    try {
      final result = await _accountRepo.softDelete(accountId);

      return AccountOperationResult(
        success: result > 0,
        message: result > 0 ? 'Cuenta eliminada exitosamente' : 'No se pudo eliminar la cuenta',
      );
    } catch (e) {
      return AccountOperationResult(
        success: false,
        message: 'Error al eliminar cuenta: ${e.toString()}',
      );
    }
  }

  /// Calcula el patrimonio total del usuario
  Future<PatrimonioSummary> calculatePatrimonio(int usuarioId) async {
    try {
      final summary = await _accountRepo.getSummary(usuarioId: usuarioId);

      return PatrimonioSummary(
        activos: summary['activos'] ?? 0,
        pasivos: summary['pasivos'] ?? 0,
        patrimonio: summary['patrimonio'] ?? 0,
      );
    } catch (e) {
      return PatrimonioSummary(
        activos: 0,
        pasivos: 0,
        patrimonio: 0,
      );
    }
  }

  /// Obtiene cuentas agrupadas por tipo (activos/pasivos)
  Future<Map<String, List<Account>>> getGroupedAccounts(int usuarioId) async {
    return await _accountRepo.getAccountsGroupedByType(usuarioId: usuarioId);
  }

  /// Lista todas las cuentas activas del usuario
  Future<List<Account>> listAccounts(int usuarioId) async {
    return await _accountRepo.list(usuarioId: usuarioId);
  }

  /// Obtiene una cuenta por ID
  Future<Account?> getAccountById(int accountId) async {
    return await _accountRepo.getById(accountId);
  }

  /// Ajusta el balance de una cuenta (usado cuando se registra una transacción)
  Future<bool> adjustAccountBalance({
    required int accountId,
    required double amount,
  }) async {
    return await _accountRepo.adjustBalance(
      accountId: accountId,
      amount: amount,
    );
  }
}

/// Resultado de validación de cuenta
class AccountValidationResult {
  final bool isValid;
  final List<String> errors;

  AccountValidationResult({
    required this.isValid,
    required this.errors,
  });
}

/// Resultado de operación de cuenta
class AccountOperationResult {
  final bool success;
  final String message;
  final int? accountId;

  AccountOperationResult({
    required this.success,
    required this.message,
    this.accountId,
  });
}

/// Resumen del patrimonio
class PatrimonioSummary {
  final double activos;
  final double pasivos;
  final double patrimonio;

  PatrimonioSummary({
    required this.activos,
    required this.pasivos,
    required this.patrimonio,
  });
}

