import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecureStorageService {
  static const _storage = FlutterSecureStorage();

  // Keys para almacenamiento
  static const String _authTokenKey = 'auth_token';
  static const String _userIdKey = 'user_id';
  static const String _sessionExpiryKey = 'session_expiry';
  static const String _rememberMeKey = 'remember_me';

  // Token y sesión
  Future<void> saveAuthToken(String token) async {
    await _storage.write(key: _authTokenKey, value: token);
    // Guardar timestamp de cuando se guardó el token
    final now = DateTime.now().toIso8601String();
    await _storage.write(key: _sessionExpiryKey, value: now);
  }

  Future<String?> getAuthToken() async {
    try {
      final token = await _storage.read(key: _authTokenKey);

      // Verificar si el token ha expirado (30 días)
      if (token != null) {
        final expiryStr = await _storage.read(key: _sessionExpiryKey);
        if (expiryStr != null) {
          final expiry = DateTime.parse(expiryStr);
          final now = DateTime.now();
          final difference = now.difference(expiry).inDays;

          if (difference > 30) {
            // Token expirado, limpiar
            await deleteAuthToken();
            return null;
          }
        }
      }

      return token;
    } catch (e) {
      return null;
    }
  }

  Future<void> deleteAuthToken() async {
    await _storage.delete(key: _authTokenKey);
    await _storage.delete(key: _sessionExpiryKey);
    await _storage.delete(key: _userIdKey);
  }

  // Usuario ID para consultas rápidas
  Future<void> saveUserId(int userId) async {
    await _storage.write(key: _userIdKey, value: userId.toString());
  }

  Future<int?> getUserId() async {
    try {
      final userIdStr = await _storage.read(key: _userIdKey);
      if (userIdStr != null) {
        return int.tryParse(userIdStr);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Remember me preference
  Future<void> saveRememberMe(bool remember) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberMeKey, remember);
  }

  Future<bool> getRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_rememberMeKey) ?? false;
  }

  // Limpiar toda la data de sesión
  Future<void> clearSession() async {
    await _storage.deleteAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_rememberMeKey);
  }

  // Verificar si hay una sesión activa
  Future<bool> hasActiveSession() async {
    final token = await getAuthToken();
    return token != null;
  }

  // Renovar sesión (actualizar timestamp)
  Future<void> renewSession() async {
    final token = await getAuthToken();
    if (token != null) {
      final now = DateTime.now().toIso8601String();
      await _storage.write(key: _sessionExpiryKey, value: now);
    }
  }
}