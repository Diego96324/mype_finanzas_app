import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../../core/database/app_database.dart';
import '../../domain/services/auth_service.dart';
import '../models/account_model.dart';

class AccountRepository {
  final AppDatabase _db = AppDatabase();
  final AuthService _auth = AuthService();

  // Obtener todas las cuentas del usuario actual
  Future<List<Account>> getUserAccounts() async {
    try {
      final userId = _auth.currentUserId;
      if (userId == null) {
        debugPrint('❌ No hay usuario autenticado');
        return [];
      }

      final database = await _db.database;
      final accounts = await database.query(
        'cuentas',
        where: 'usuario_id = ? AND activa = 1',
        whereArgs: [userId],
        orderBy: 'created_at DESC',
      );

      return accounts.map((map) => Account.fromMap(map)).toList();
    } catch (e) {
      debugPrint('❌ Error al obtener cuentas: $e');
      return [];
    }
  }

  // Obtener una cuenta específica
  Future<Account?> getAccountById(int accountId) async {
    try {
      final userId = _auth.currentUserId;
      if (userId == null) return null;

      final database = await _db.database;
      final accounts = await database.query(
        'cuentas',
        where: 'id = ? AND usuario_id = ? AND activa = 1',
        whereArgs: [accountId, userId],
        limit: 1,
      );

      if (accounts.isEmpty) return null;
      return Account.fromMap(accounts.first);
    } catch (e) {
      debugPrint('❌ Error al obtener cuenta: $e');
      return null;
    }
  }

  // Crear nueva cuenta
  Future<Account?> createAccount({
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
      final userId = _auth.currentUserId;
      if (userId == null) {
        debugPrint('❌ No hay usuario autenticado');
        return null;
      }

      final database = await _db.database;
      final now = DateTime.now();

      // Verificar si ya existe una cuenta con el mismo nombre
      final existing = await database.query(
        'cuentas',
        where: 'usuario_id = ? AND nombre = ? AND activa = 1',
        whereArgs: [userId, nombre],
      );

      if (existing.isNotEmpty) {
        debugPrint('❌ Ya existe una cuenta con ese nombre');
        return null;
      }

      // Insertar nueva cuenta
      final accountId = await database.insert('cuentas', {
        'usuario_id': userId,
        'nombre': nombre,
        'tipo': tipo,
        'saldo': saldoInicial,
        'saldo_inicial': saldoInicial,
        'numero_fin': numeroFin,
        'institucion': institucion,
        'moneda': moneda,
        'color': color ?? _getDefaultColor(tipo),
        'icono': icono ?? _getDefaultIcon(tipo),
        'activa': 1,
        'incluir_en_total': 1,
        'orden': await _getNextOrder(userId),
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      // Registrar transacción inicial si hay saldo
      if (saldoInicial != 0) {
        // Obtener la categoría "Otros Ingresos" para asignarla
        final categorias = await database.query(
          'categorias',
          where: 'nombre = ? AND es_predeterminada = 1',
          whereArgs: ['Otros Ingresos'],
          limit: 1,
        );

        final categoriaId = categorias.isNotEmpty ? categorias.first['id'] as int? : null;

        // Determinar si la cuenta es pasiva para registrar correctamente la transacción de apertura
        final tiposPasivos = ['credito', 'por_pagar'];
        final bool esPasivo = tiposPasivos.contains(tipo);

        // Si la cuenta es pasiva, un saldo inicial positivo representa una obligación (egreso en la lista de movimientos),
        // mientras que para cuentas normales un saldo positivo se registra como 'ingreso'.
        final aperturaTipo = esPasivo
            ? (saldoInicial >= 0 ? 'egreso' : 'ingreso')
            : (saldoInicial >= 0 ? 'ingreso' : 'egreso');

        await database.insert('transacciones', {
          'usuario_id': userId,
          'cuenta_id': accountId,
          'categoria_id': categoriaId,
          'tipo': aperturaTipo,
          'descripcion': 'Saldo inicial',
          'etiqueta': nombre, // ✅ Etiqueta = Nombre de la cuenta
          'nota': institucion != null && institucion.isNotEmpty
              ? 'Apertura de cuenta en $institucion'
              : 'Apertura de cuenta', // ✅ Nota = Institución o descripción
          'monto': saldoInicial.abs(),
          'fecha': now.toIso8601String(),
          'es_recurrente': 0,
          'es_apertura_cuenta': 1, // ✅ Marcar como transacción de apertura
          'confirmada': 1,
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        });
      }

      return getAccountById(accountId);
    } catch (e) {
      debugPrint('❌ Error al crear cuenta: $e');
      return null;
    }
  }

  // Actualizar cuenta
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
      final userId = _auth.currentUserId;
      if (userId == null) return false;

      final database = await _db.database;
      final updateData = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Agregar solo los campos que se van a actualizar
      if (nombre != null) updateData['nombre'] = nombre;
      if (tipo != null) updateData['tipo'] = tipo;
      if (saldo != null) updateData['saldo'] = saldo;
      if (numeroFin != null) updateData['numero_fin'] = numeroFin;
      if (institucion != null) updateData['institucion'] = institucion;
      if (color != null) updateData['color'] = color;
      if (icono != null) updateData['icono'] = icono;
      if (incluirEnTotal != null) updateData['incluir_en_total'] = incluirEnTotal ? 1 : 0;
      if (moneda != null) updateData['moneda'] = moneda;

      final rowsAffected = await database.update(
        'cuentas',
        updateData,
        where: 'id = ? AND usuario_id = ?',
        whereArgs: [accountId, userId],
      );

      // Si se actualizó el nombre, la institución o el saldo, actualizar también la transacción de apertura
      if (rowsAffected > 0 && (nombre != null || institucion != null || saldo != null)) {
        await _updateOpeningTransaction(database, accountId, nombre, institucion, saldo);
      }

      return rowsAffected > 0;
    } catch (e) {
      debugPrint('❌ Error al actualizar cuenta: $e');
      return false;
    }
  }

  // Actualizar la transacción de apertura de cuenta
  Future<void> _updateOpeningTransaction(
    Database database,
    int accountId,
    String? nombre,
    String? institucion,
    double? saldo,
  ) async {
    try {
      final transactionUpdateData = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (nombre != null) {
        transactionUpdateData['etiqueta'] = nombre;
      }

      if (institucion != null) {
        transactionUpdateData['nota'] = institucion.isNotEmpty
            ? 'Apertura de cuenta en $institucion'
            : 'Apertura de cuenta';
      }

      // Obtener el tipo de la cuenta actual para decidir el tipo de la transacción de apertura
      final cuentas = await database.query(
        'cuentas',
        columns: ['tipo', 'saldo'],
        where: 'id = ?',
        whereArgs: [accountId],
        limit: 1,
      );

      String? cuentaTipo;
      double currentSaldo = 0.0;
      if (cuentas.isNotEmpty) {
        cuentaTipo = cuentas.first['tipo'] as String?;
        final saldoVal = cuentas.first['saldo'] as num?;
        currentSaldo = saldoVal != null ? saldoVal.toDouble() : 0.0;
      }

      if (saldo != null) {
        transactionUpdateData['monto'] = saldo.abs();
      }

      // Determinar si la cuenta es pasiva para registrar correctamente la transacción de apertura
      final tiposPasivos = ['credito', 'por_pagar'];
      final bool esPasivo = cuentaTipo != null && tiposPasivos.contains(cuentaTipo);

      // Si ya se va a actualizar el monto, o queremos asegurar que el tipo sea consistente, calculamos el tipo correcto
      if (transactionUpdateData.containsKey('monto') || cuentaTipo != null) {
        final effectiveSaldo = (saldo != null) ? saldo : currentSaldo;
        final aperturaTipo = esPasivo
            ? (effectiveSaldo >= 0 ? 'egreso' : 'ingreso')
            : (effectiveSaldo >= 0 ? 'ingreso' : 'egreso');

        transactionUpdateData['tipo'] = aperturaTipo;
      }

      if (transactionUpdateData.length > 1) { // Más de solo updated_at
        await database.update(
          'transacciones',
          transactionUpdateData,
          where: 'cuenta_id = ? AND es_apertura_cuenta = 1',
          whereArgs: [accountId],
        );
        debugPrint('✅ Transacción de apertura actualizada');
      }
    } catch (e) {
      debugPrint('❌ Error al actualizar transacción de apertura: $e');
    }
  }

  // Método utilitario para corregir en lote transacciones de apertura existentes
  Future<int> fixOpeningTransactionsTypes() async {
    try {
      final userId = _auth.currentUserId;
      if (userId == null) return 0;

      final database = await _db.database;
      // Obtener todas las transacciones de apertura con su cuenta
      final rows = await database.rawQuery('''
        SELECT t.id as tid, t.cuenta_id as cid, t.monto as monto, c.tipo as cuenta_tipo
        FROM transacciones t
        LEFT JOIN cuentas c ON c.id = t.cuenta_id
        WHERE t.es_apertura_cuenta = 1 AND c.usuario_id = ?
      ''', [userId]);

      int updated = 0;
      final tiposPasivos = ['credito', 'por_pagar'];

      for (final r in rows) {
        final tid = r['tid'] as int?;
        final monto = (r['monto'] as num?)?.toDouble() ?? 0.0;
        final cuentaTipo = r['cuenta_tipo'] as String?;
        final esPasivo = cuentaTipo != null && tiposPasivos.contains(cuentaTipo);
        final aperturaTipo = esPasivo ? (monto >= 0 ? 'egreso' : 'ingreso') : (monto >= 0 ? 'ingreso' : 'egreso');

        if (tid != null) {
          final res = await database.update(
            'transacciones',
            {'tipo': aperturaTipo, 'updated_at': DateTime.now().toIso8601String()},
            where: 'id = ?',
            whereArgs: [tid],
          );
          if (res > 0) updated += 1;
        }
      }

      debugPrint('✅ Corregidas $updated transacciones de apertura');
      return updated;
    } catch (e) {
      debugPrint('❌ Error al corregir transacciones de apertura: $e');
      return 0;
    }
  }

  // Reordenar cuentas
  Future<bool> reorderAccounts(List<int> accountIds) async {
    try {
      final userId = _auth.currentUserId;
      if (userId == null) return false;

      final database = await _db.database;

      return await database.transaction((txn) async {
        for (int i = 0; i < accountIds.length; i++) {
          await txn.update(
            'cuentas',
            {'orden': i},
            where: 'id = ? AND usuario_id = ?',
            whereArgs: [accountIds[i], userId],
          );
        }
        return true;
      });
    } catch (e) {
      debugPrint('❌ Error al reordenar cuentas: $e');
      return false;
    }
  }

  // Actualizar cuenta cuando se edita la transacción de apertura
  Future<bool> updateAccountFromTransaction({
    required int accountId,
    required String nombre,
    String? institucion,
  }) async {
    try {
      final userId = _auth.currentUserId;
      if (userId == null) return false;

      final database = await _db.database;
      final rowsAffected = await database.update(
        'cuentas',
        {
          'nombre': nombre,
          'institucion': institucion,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ? AND usuario_id = ?',
        whereArgs: [accountId, userId],
      );

      debugPrint('✅ Cuenta actualizada desde transacción: $nombre');
      return rowsAffected > 0;
    } catch (e) {
      debugPrint('❌ Error al actualizar cuenta desde transacción: $e');
      return false;
    }
  }

  // Eliminar cuenta cuando se elimina la transacción de apertura
  Future<bool> deleteAccountFromTransaction(int accountId) async {
    try {
      final userId = _auth.currentUserId;
      if (userId == null) return false;

      final database = await _db.database;

      // Eliminar la cuenta (esto también eliminará las transacciones asociadas por CASCADE)
      final rowsAffected = await database.delete(
        'cuentas',
        where: 'id = ? AND usuario_id = ?',
        whereArgs: [accountId, userId],
      );

      debugPrint('✅ Cuenta eliminada desde transacción de apertura');
      return rowsAffected > 0;
    } catch (e) {
      debugPrint('❌ Error al eliminar cuenta desde transacción: $e');
      return false;
    }
  }

  // Eliminar cuenta (soft delete) - método público
  Future<bool> deleteAccount(int accountId) async {
    try {
      final userId = _auth.currentUserId;
      if (userId == null) return false;

      final database = await _db.database;

      // Verificar si hay transacciones asociadas
      final transactions = await database.query(
        'transacciones',
        where: 'cuenta_id = ? OR cuenta_destino_id = ?',
        whereArgs: [accountId, accountId],
        limit: 1,
      );

      if (transactions.isNotEmpty) {
        // Si hay transacciones, solo desactivar
        final rowsAffected = await database.update(
          'cuentas',
          {
            'activa': 0,
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ? AND usuario_id = ?',
          whereArgs: [accountId, userId],
        );
        return rowsAffected > 0;
      } else {
        // Si no hay transacciones, eliminar permanentemente
        final rowsAffected = await database.delete(
          'cuentas',
          where: 'id = ? AND usuario_id = ?',
          whereArgs: [accountId, userId],
        );
        return rowsAffected > 0;
      }
    } catch (e) {
      debugPrint('❌ Error al eliminar cuenta: $e');
      return false;
    }
  }

  // Actualizar saldo de una cuenta
  Future<bool> updateAccountBalance(int accountId, double newBalance) async {
    try {
      final userId = _auth.currentUserId;
      if (userId == null) return false;

      final database = await _db.database;
      final rowsAffected = await database.update(
        'cuentas',
        {
          'saldo': newBalance,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ? AND usuario_id = ?',
        whereArgs: [accountId, userId],
      );

      return rowsAffected > 0;
    } catch (e) {
      debugPrint('❌ Error al actualizar saldo: $e');
      return false;
    }
  }

  // Transferir dinero entre cuentas
  Future<bool> transferBetweenAccounts({
    required int fromAccountId,
    required int toAccountId,
    required double amount,
    String? descripcion,
  }) async {
    try {
      final userId = _auth.currentUserId;
      if (userId == null) return false;

      if (amount <= 0) {
        debugPrint('❌ El monto debe ser mayor a 0');
        return false;
      }

      final database = await _db.database;

      // Iniciar transacción para asegurar atomicidad
      return await database.transaction((txn) async {
        // Obtener cuentas
        final fromAccounts = await txn.query(
          'cuentas',
          where: 'id = ? AND usuario_id = ? AND activa = 1',
          whereArgs: [fromAccountId, userId],
        );

        final toAccounts = await txn.query(
          'cuentas',
          where: 'id = ? AND usuario_id = ? AND activa = 1',
          whereArgs: [toAccountId, userId],
        );

        if (fromAccounts.isEmpty || toAccounts.isEmpty) {
          throw Exception('Una o ambas cuentas no existen');
        }

        final fromAccount = Account.fromMap(fromAccounts.first);
        final toAccount = Account.fromMap(toAccounts.first);

        // Verificar saldo suficiente
        if (fromAccount.saldo < amount) {
          throw Exception('Saldo insuficiente');
        }

        // Actualizar saldos
        await txn.update(
          'cuentas',
          {'saldo': fromAccount.saldo - amount},
          where: 'id = ?',
          whereArgs: [fromAccountId],
        );

        await txn.update(
          'cuentas',
          {'saldo': toAccount.saldo + amount},
          where: 'id = ?',
          whereArgs: [toAccountId],
        );

        final now = DateTime.now().toIso8601String();

        // Registrar transacción de transferencia
        await txn.insert('transacciones', {
          'usuario_id': userId,
          'cuenta_id': fromAccountId,
          'cuenta_destino_id': toAccountId,
          'categoria_id': null, // Las transferencias no tienen categoría
          'tipo': 'transferencia',
          'descripcion': descripcion ?? 'Transferencia entre cuentas',
          'monto': amount,
          'fecha': now,
          'es_recurrente': 0,
          'confirmada': 1,
          'created_at': now,
          'updated_at': now,
        });

        return true;
      });
    } catch (e) {
      debugPrint('❌ Error en transferencia: $e');
      return false;
    }
  }

  // Obtener resumen de cuentas
  Future<Map<String, dynamic>> getAccountsSummary() async {
    try {
      final userId = _auth.currentUserId;
      if (userId == null) {
        return {
          'total': 0.0,
          'porTipo': {},
          'cuentas': 0,
        };
      }

      final database = await _db.database;
      final accounts = await database.query(
        'cuentas',
        where: 'usuario_id = ? AND activa = 1',
        whereArgs: [userId],
      );

      double total = 0;
      Map<String, double> porTipo = {};

      for (var account in accounts) {
        final acc = Account.fromMap(account);
        if (acc.incluirEnTotal) {
          total += acc.saldo;
        }
        porTipo[acc.tipo] = (porTipo[acc.tipo] ?? 0) + acc.saldo;
      }

      return {
        'total': total,
        'porTipo': porTipo,
        'cuentas': accounts.length,
      };
    } catch (e) {
      debugPrint('❌ Error al obtener resumen: $e');
      return {
        'total': 0.0,
        'porTipo': {},
        'cuentas': 0,
      };
    }
  }

  // Helpers privados
  Future<int> _getNextOrder(int userId) async {
    final database = await _db.database;
    final result = await database.rawQuery(
      'SELECT MAX(orden) as max_order FROM cuentas WHERE usuario_id = ?',
      [userId],
    );
    final maxOrder = result.first['max_order'] as int?;
    return (maxOrder ?? -1) + 1;
  }

  String _getDefaultColor(String tipo) {
    switch (tipo) {
      case 'efectivo':
        return '#4CAF50';
      case 'banco':
        return '#2196F3';
      case 'debito':
      case 'tarjeta_debito':
        return '#9C27B0';
      case 'credito':
      case 'tarjeta_credito':
        return '#FF9800';
      case 'virtual':
        return '#E91E63';
      case 'ahorros':
        return '#00BCD4';
      case 'inversion':
        return '#FFC107';
      case 'por_cobrar':
        return '#8BC34A';
      case 'por_pagar':
        return '#F44336';
      default:
        return '#607D8B';
    }
  }

  String _getDefaultIcon(String tipo) {
    switch (tipo) {
      case 'efectivo':
        return 'cash';
      case 'banco':
        return 'bank';
      case 'debito':
      case 'tarjeta_debito':
        return 'debit_card';
      case 'credito':
      case 'tarjeta_credito':
        return 'credit_card';
      case 'virtual':
        return 'account_balance_wallet';
      case 'ahorros':
        return 'savings';
      case 'inversion':
        return 'trending_up';
      case 'por_cobrar':
        return 'arrow_forward';
      case 'por_pagar':
        return 'arrow_back';
      default:
        return 'account_balance_wallet';
    }
  }
}
