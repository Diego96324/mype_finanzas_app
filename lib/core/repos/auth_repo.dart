import 'dart:math';
import 'package:sqflite/sqflite.dart';
import '../db/app_database.dart';
import '../models/user_model.dart';
import '../models/session_model.dart';

class AuthRepository {
  final AppDatabase _db = AppDatabase();

  String _generateToken() {
    final random = Random.secure();
    final values = List<int>.generate(32, (i) => random.nextInt(256));
    return values.map((e) => e.toRadixString(16).padLeft(2, '0')).join();
  }

  // TODO: usar bcrypt o argon2 en producción
  String _hashPassword(String password) {
    return 'hash_$password';
  }

  Future<User?> register({
    required String email,
    required String password,
    required String nombre,
    String? apellido,
    String? telefono,
  }) async {
    try {
      final database = await _db.database;
      final now = DateTime.now();

      final existing = await database.query(
        'usuarios',
        where: 'email = ?',
        whereArgs: [email.toLowerCase()],
      );

      if (existing.isNotEmpty) {
        return null;
      }

      final userId = await database.insert('usuarios', {
        'email': email.toLowerCase(),
        'password_hash': _hashPassword(password),
        'nombre': nombre,
        'apellido': apellido,
        'telefono': telefono,
        'fecha_registro': now.toIso8601String(),
        'ultima_conexion': null,
        'activo': 1,
        'rol': 'usuario',
        'avatar_uri': null,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      final userMap = await database.query(
        'usuarios',
        where: 'id = ?',
        whereArgs: [userId],
      );

      return User.fromMap(userMap.first);
    } catch (e) {
      print('Error al registrar usuario: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> login({
    required String email,
    required String password,
  }) async {
    try {
      final database = await _db.database;
      final now = DateTime.now();

      final users = await database.query(
        'usuarios',
        where: 'email = ? AND password_hash = ? AND activo = 1',
        whereArgs: [email.toLowerCase(), _hashPassword(password)],
      );

      if (users.isEmpty) {
        return null;
      }

      final user = User.fromMap(users.first);

      await database.update(
        'usuarios',
        {
          'ultima_conexion': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [user.id],
      );

      final token = _generateToken();
      final sessionId = await database.insert('sesiones', {
        'usuario_id': user.id,
        'token': token,
        'dispositivo': 'mobile',
        'ip_address': null,
        'fecha_inicio': now.toIso8601String(),
        'fecha_expiracion': now.add(const Duration(days: 30)).toIso8601String(),
        'activa': 1,
        'created_at': now.toIso8601String(),
      });

      final sessionMap = await database.query(
        'sesiones',
        where: 'id = ?',
        whereArgs: [sessionId],
      );

      return {
        'user': user,
        'session': Session.fromMap(sessionMap.first),
      };
    } catch (e) {
      print('Error al iniciar sesión: $e');
      return null;
    }
  }

  Future<bool> logout(String token) async {
    try {
      final database = await _db.database;
      await database.update(
        'sesiones',
        {'activa': 0},
        where: 'token = ?',
        whereArgs: [token],
      );
      return true;
    } catch (e) {
      print('Error al cerrar sesión: $e');
      return false;
    }
  }

  Future<User?> validateSession(String token) async {
    try {
      final database = await _db.database;

      final sessions = await database.query(
        'sesiones',
        where: 'token = ? AND activa = 1',
        whereArgs: [token],
      );

      if (sessions.isEmpty) return null;

      final session = Session.fromMap(sessions.first);

      if (session.isExpired) {
        await logout(token);
        return null;
      }

      final users = await database.query(
        'usuarios',
        where: 'id = ? AND activo = 1',
        whereArgs: [session.usuarioId],
      );

      if (users.isEmpty) return null;

      return User.fromMap(users.first);
    } catch (e) {
      print('Error al validar sesión: $e');
      return null;
    }
  }

  Future<User?> getUserById(int userId) async {
    try {
      final database = await _db.database;
      final users = await database.query(
        'usuarios',
        where: 'id = ?',
        whereArgs: [userId],
      );

      if (users.isEmpty) return null;
      return User.fromMap(users.first);
    } catch (e) {
      print('Error al obtener usuario: $e');
      return null;
    }
  }

  Future<bool> updateProfile({
    required int userId,
    String? nombre,
    String? apellido,
    String? telefono,
    String? avatarUri,
  }) async {
    try {
      final database = await _db.database;
      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (nombre != null) updates['nombre'] = nombre;
      if (apellido != null) updates['apellido'] = apellido;
      if (telefono != null) updates['telefono'] = telefono;
      if (avatarUri != null) updates['avatar_uri'] = avatarUri;

      await database.update(
        'usuarios',
        updates,
        where: 'id = ?',
        whereArgs: [userId],
      );

      return true;
    } catch (e) {
      print('Error al actualizar perfil: $e');
      return false;
    }
  }

  Future<bool> changePassword({
    required int userId,
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      final database = await _db.database;

      final users = await database.query(
        'usuarios',
        where: 'id = ? AND password_hash = ?',
        whereArgs: [userId, _hashPassword(oldPassword)],
      );

      if (users.isEmpty) return false;

      await database.update(
        'usuarios',
        {
          'password_hash': _hashPassword(newPassword),
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [userId],
      );

      return true;
    } catch (e) {
      print('Error al cambiar contraseña: $e');
      return false;
    }
  }
}
