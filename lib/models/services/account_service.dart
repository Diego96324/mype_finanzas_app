import '../dtos/account_model.dart';
import '../repositories/account_repository.dart';

/// Servicio que maneja la lógica de negocio para las cuentas
class AccountService {
  final AccountRepository _accountRepo = AccountRepository();

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
    String? numeroFin,
    String? color,
    String? icono,
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

      // Crear cuenta usando el repositorio
      final account = await _accountRepo.createAccount(
        nombre: nombre.trim(),
        tipo: tipo,
        saldoInicial: saldo,
        moneda: moneda,
        institucion: institucion?.trim(),
        numeroFin: numeroFin,
        color: color,
        icono: icono,
      );

      if (account != null) {
        return AccountOperationResult(
          success: true,
          message: 'Cuenta creada exitosamente',
          accountId: account.id,
        );
      } else {
        return AccountOperationResult(
          success: false,
          message: 'No se pudo crear la cuenta',
        );
      }
    } catch (e) {
      return AccountOperationResult(
        success: false,
        message: 'Error al crear cuenta: ${e.toString()}',
      );
    }
  }

  /// Actualiza una cuenta existente
  Future<AccountOperationResult> updateAccount({
    required int accountId,
    String? nombre,
    String? tipo,
    double? saldo,
    String? moneda,
    String? institucion,
    String? numeroFin,
    String? color,
    String? icono,
    bool? incluirEnTotal,
  }) async {
    try {
      // Si se están cambiando datos críticos, validar
      if (nombre != null || tipo != null || saldo != null || moneda != null) {
        // Obtener la cuenta actual para los valores que no cambian
        final currentAccount = await _accountRepo.getAccountById(accountId);
        if (currentAccount == null) {
          return AccountOperationResult(
            success: false,
            message: 'Cuenta no encontrada',
          );
        }

        final validation = validateAccount(
          nombre: nombre ?? currentAccount.nombre,
          tipo: tipo ?? currentAccount.tipo,
          saldo: saldo ?? currentAccount.saldo,
          moneda: moneda ?? currentAccount.moneda,
        );

        if (!validation.isValid) {
          return AccountOperationResult(
            success: false,
            message: validation.errors.join(', '),
          );
        }
      }

      final result = await _accountRepo.updateAccount(
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

      return AccountOperationResult(
        success: result,
        message: result ? 'Cuenta actualizada exitosamente' : 'No se pudo actualizar la cuenta',
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
      final result = await _accountRepo.deleteAccount(accountId);

      return AccountOperationResult(
        success: result,
        message: result ? 'Cuenta eliminada exitosamente' : 'No se pudo eliminar la cuenta',
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
      final summary = await _accountRepo.getAccountsSummary();

      // Calcular activos y pasivos desde el resumen
      final porTipo = summary['porTipo'] as Map<String, double>;
      double activos = 0;
      double pasivos = 0;

      // Tipos de cuentas que son activos
      final tiposActivos = ['efectivo', 'debito', 'virtual', 'inversion', 'por_cobrar'];
      // Tipos de cuentas que son pasivos
      final tiposPasivos = ['credito', 'por_pagar'];

      porTipo.forEach((tipo, monto) {
        if (tiposActivos.contains(tipo)) {
          activos += monto;
        } else if (tiposPasivos.contains(tipo)) {
          pasivos += monto.abs(); // Convertir a positivo para mostrar
        }
      });

      return PatrimonioSummary(
        activos: activos,
        pasivos: pasivos,
        patrimonio: activos - pasivos,
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
    try {
      final accounts = await _accountRepo.getUserAccounts();

      final Map<String, List<Account>> grouped = {
        'activos': [],
        'pasivos': [],
      };

      final tiposPasivos = ['credito', 'por_pagar'];

      for (var account in accounts) {
        if (tiposPasivos.contains(account.tipo)) {
          grouped['pasivos']!.add(account);
        } else {
          grouped['activos']!.add(account);
        }
      }

      return grouped;
    } catch (e) {
      return {
        'activos': [],
        'pasivos': [],
      };
    }
  }

  /// Lista todas las cuentas activas del usuario
  Future<List<Account>> listAccounts(int usuarioId) async {
    return await _accountRepo.getUserAccounts();
  }

  /// Obtiene una cuenta por ID
  Future<Account?> getAccountById(int accountId) async {
    return await _accountRepo.getAccountById(accountId);
  }

  /// Ajusta el balance de una cuenta (usado cuando se registra una transacción)
  Future<bool> adjustAccountBalance({
    required int accountId,
    required double amount,
  }) async {
    // Primero obtener la cuenta actual
    final account = await _accountRepo.getAccountById(accountId);
    if (account == null) return false;

    // Calcular el nuevo balance
    final newBalance = account.saldo + amount;

    // Actualizar el balance
    return await _accountRepo.updateAccountBalance(accountId, newBalance);
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

