import '../../../data/models/account_model.dart';
import '../../core/database/app_database.dart';

class AccountRepo {
  final _db = AppDatabase();

  Future<int> insert(Account account) async {
    final db = await _db.database;

    // Actualizar fecha de actualización
    final accountToInsert = account.copyWith(
      fechaActualizacion: DateTime.now(),
    );

    return await db.insert('accounts', accountToInsert.toMap());
  }

  Future<int> update(Account account) async {
    final db = await _db.database;

    // Actualizar fecha de actualización
    final accountToUpdate = account.copyWith(
      fechaActualizacion: DateTime.now(),
    );

    return await db.update(
      'accounts',
      accountToUpdate.toMap(),
      where: 'id = ?',
      whereArgs: [account.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await _db.database;
    return await db.delete(
      'accounts',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> softDelete(int id) async {
    final db = await _db.database;
    return await db.update(
      'accounts',
      {'activa': 0, 'fecha_actualizacion': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Account>> list({
    required int usuarioId,
    bool includeInactive = false,
    String? orderBy,
  }) async {
    final db = await _db.database;

    String whereClause = 'usuario_id = ?';
    List<dynamic> whereArgs = [usuarioId];

    if (!includeInactive) {
      whereClause += ' AND activa = 1';
    }

    final List<Map<String, dynamic>> maps = await db.query(
      'accounts',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: orderBy ?? 'fecha_creacion DESC',
    );

    return List.generate(maps.length, (i) => Account.fromMap(maps[i]));
  }

  Future<Account?> getById(int id) async {
    final db = await _db.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'accounts',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Account.fromMap(maps.first);
  }

  Future<Map<String, double>> getSummary({required int usuarioId}) async {
    final accounts = await list(usuarioId: usuarioId, includeInactive: false);

    double activos = 0;
    double pasivos = 0;

    for (var account in accounts) {
      if (account.isPasivo) {
        pasivos += account.saldo.abs();
      } else {
        activos += account.saldo;
      }
    }

    return {
      'activos': activos,
      'pasivos': pasivos,
      'patrimonio': activos - pasivos,
    };
  }

  Future<Map<String, List<Account>>> getAccountsGroupedByType({
    required int usuarioId,
  }) async {
    final accounts = await list(usuarioId: usuarioId);

    final Map<String, List<Account>> grouped = {
      'activos': [],
      'pasivos': [],
    };

    for (var account in accounts) {
      if (account.isPasivo) {
        grouped['pasivos']!.add(account);
      } else {
        grouped['activos']!.add(account);
      }
    }

    return grouped;
  }

  Future<List<Account>> getAccountsByType({
    required int usuarioId,
    required String tipo,
  }) async {
    final db = await _db.database;

    final List<Map<String, dynamic>> maps = await db.query(
      'accounts',
      where: 'usuario_id = ? AND tipo = ? AND activa = 1',
      whereArgs: [usuarioId, tipo],
      orderBy: 'fecha_creacion DESC',
    );

    return List.generate(maps.length, (i) => Account.fromMap(maps[i]));
  }

  Future<bool> updateBalance({
    required int accountId,
    required double newBalance,
  }) async {
    final db = await _db.database;

    final result = await db.update(
      'accounts',
      {
        'saldo': newBalance,
        'fecha_actualizacion': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [accountId],
    );

    return result > 0;
  }

  Future<bool> adjustBalance({
    required int accountId,
    required double amount,
  }) async {
    final account = await getById(accountId);
    if (account == null) return false;

    final newBalance = account.saldo + amount;
    return await updateBalance(accountId: accountId, newBalance: newBalance);
  }
}

