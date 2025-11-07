import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../core/database/app_database.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/session_model.dart';

class AuthRepository {
  final AppDatabase _db = AppDatabase();

  String _generateToken() {
    final random = Random.secure();
    final values = List<int>.generate(32, (i) => random.nextInt(256));
    return values.map((e) => e.toRadixString(16).padLeft(2, '0')).join();
  }

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
        return null; // ya existe ese email
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
      debugPrint('❌ Error al registrar usuario: $e');
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
        'fecha_expiracion': now.add(const Duration(days: 30)).toIso8601String(), // sesion dura 30 dias
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
      debugPrint('❌ Error al iniciar sesión: $e');
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
      debugPrint('❌ Error al cerrar sesión: $e');
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
        await logout(token); // ya expiro, cerramos la sesion
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
      debugPrint('❌ Error al validar sesión: $e');
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
      debugPrint('❌ Error al obtener usuario: $e');
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
      debugPrint('❌ Error al actualizar perfil: $e');
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
      debugPrint('❌ Error al cambiar contraseña: $e');
      return false;
    }
  }

  // ========== RECUPERACIÓN DE CONTRASEÑA ==========

  /// Genera un token de 6 dígitos para recuperación de contraseña
  String _generateResetToken() {
    final random = Random.secure();
    final code = random.nextInt(900000) + 100000; // 6 dígitos entre 100000-999999
    return code.toString();
  }

  /// Crea un token de recuperación de contraseña
  Future<Map<String, dynamic>> createPasswordResetToken({
    required String email,
    String? ipAddress,
  }) async {
    try {
      final database = await _db.database;
      final now = DateTime.now();

      // Verificar si el email existe
      final users = await database.query(
        'usuarios',
        where: 'email = ? AND activo = 1',
        whereArgs: [email.toLowerCase()],
      );

      if (users.isEmpty) {
        return {
          'success': false,
          'message': 'No existe una cuenta con ese email',
        };
      }

      final user = User.fromMap(users.first);

      // Invalidar tokens anteriores no usados
      await database.update(
        'password_reset_tokens',
        {'usado': 1},
        where: 'usuario_id = ? AND usado = 0',
        whereArgs: [user.id],
      );

      // Generar nuevo token
      final token = _generateResetToken();
      final expiracion = now.add(const Duration(minutes: 15)); // Expira en 15 minutos

      await database.insert('password_reset_tokens', {
        'usuario_id': user.id,
        'email': email.toLowerCase(),
        'token': token,
        'fecha_creacion': now.toIso8601String(),
        'fecha_expiracion': expiracion.toIso8601String(),
        'usado': 0,
        'ip_address': ipAddress,
      });

      debugPrint('✅ Token de recuperación creado: $token para ${user.email}');

      return {
        'success': true,
        'token': token,
        'email': user.email,
        'expiracion': expiracion,
      };
    } catch (e) {
      debugPrint('❌ Error al crear token de recuperación: $e');
      return {
        'success': false,
        'message': 'Error al generar token de recuperación',
      };
    }
  }

  /// Valida un token de recuperación
  Future<Map<String, dynamic>> validateResetToken({
    required String email,
    required String token,
  }) async {
    try {
      final database = await _db.database;
      final now = DateTime.now();

      debugPrint('🔍 Validando token:');
      debugPrint('   Email: ${email.toLowerCase()}');
      debugPrint('   Token: $token');

      final tokens = await database.query(
        'password_reset_tokens',
        where: 'email = ? AND token = ? AND usado = 0',
        whereArgs: [email.toLowerCase(), token],
      );

      debugPrint('   Tokens encontrados: ${tokens.length}');

      if (tokens.isEmpty) {
        // Verificar qué tokens existen para este email
        final allTokens = await database.query(
          'password_reset_tokens',
          where: 'email = ?',
          whereArgs: [email.toLowerCase()],
          orderBy: 'fecha_creacion DESC',
          limit: 5,
        );

        debugPrint('❌ Token no encontrado. Tokens en BD para este email:');
        for (var t in allTokens) {
          debugPrint('   - Token: ${t['token']}, Usado: ${t['usado']}, Expiración: ${t['fecha_expiracion']}');
        }

        return {
          'success': false,
          'message': 'Token inválido o ya utilizado',
        };
      }

      final tokenData = tokens.first;
      final expiracion = DateTime.parse(tokenData['fecha_expiracion'] as String);

      debugPrint('   Expiración: $expiracion');
      debugPrint('   Ahora: $now');

      if (now.isAfter(expiracion)) {
        debugPrint('❌ Token expirado');
        return {
          'success': false,
          'message': 'El token ha expirado. Solicita uno nuevo.',
        };
      }

      debugPrint('✅ Token válido');
      return {
        'success': true,
        'userId': tokenData['usuario_id'],
        'tokenId': tokenData['id'],
      };
    } catch (e) {
      debugPrint('❌ Error al validar token: $e');
      return {
        'success': false,
        'message': 'Error al validar token',
      };
    }
  }

  /// Resetea la contraseña usando un token válido
  Future<Map<String, dynamic>> resetPasswordWithToken({
    required String email,
    required String token,
    required String newPassword,
  }) async {
    try {
      final database = await _db.database;

      // Validar token
      final validation = await validateResetToken(email: email, token: token);
      if (validation['success'] != true) {
        return validation;
      }

      final userId = validation['userId'] as int;
      final tokenId = validation['tokenId'] as int;

      // Actualizar contraseña
      await database.update(
        'usuarios',
        {
          'password_hash': _hashPassword(newPassword),
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [userId],
      );

      // Marcar token como usado
      await database.update(
        'password_reset_tokens',
        {'usado': 1},
        where: 'id = ?',
        whereArgs: [tokenId],
      );

      // Cerrar todas las sesiones activas por seguridad
      await database.update(
        'sesiones',
        {'activa': 0},
        where: 'usuario_id = ?',
        whereArgs: [userId],
      );

      debugPrint('✅ Contraseña reseteada exitosamente para usuario $userId');

      return {
        'success': true,
        'message': 'Contraseña actualizada correctamente',
      };
    } catch (e) {
      debugPrint('❌ Error al resetear contraseña: $e');
      return {
        'success': false,
        'message': 'Error al resetear contraseña',
      };
    }
  }

  /// Limpia tokens expirados (mantenimiento)
  Future<void> cleanExpiredTokens() async {
    try {
      final database = await _db.database;
      final now = DateTime.now().toIso8601String();

      await database.delete(
        'password_reset_tokens',
        where: 'fecha_expiracion < ?',
        whereArgs: [now],
      );

      debugPrint('✅ Tokens expirados limpiados');
    } catch (e) {
      debugPrint('❌ Error al limpiar tokens: $e');
    }
  }
}
