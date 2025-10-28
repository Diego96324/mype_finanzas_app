import '../models/account_model.dart';
import '../db/app_database.dart';

class AccountRepo {
  final _db = AppDatabase();

  Future<int> insert(Account account) async {
    final db = await _db.database;
    return await db.insert('accounts', account.toMap());
  }

  Future<int> update(Account account) async {
    final db = await _db.database;
    return await db.update(
      'accounts',
      account.toMap(),
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

  Future<List<Account>> list({required int usuarioId}) async {
    final db = await _db.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'accounts',
      where: 'usuario_id = ?',
      whereArgs: [usuarioId],
      orderBy: 'fecha_creacion DESC',
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
    final accounts = await list(usuarioId: usuarioId);

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
}

