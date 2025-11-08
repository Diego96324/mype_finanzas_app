import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repo.dart';
import '../../domain/services/secure_storage_service.dart';
import '../../domain/services/backup_service.dart';

// ================= THEME =================
// Controlador simple de tema (dark/light)
class ThemeStateNotifier extends StateNotifier<bool> {
  ThemeStateNotifier() : super(true); // true => dark por defecto
  void toggle() => state = !state;
}

final themeStateProvider = StateNotifierProvider<ThemeStateNotifier, bool>((ref) => ThemeStateNotifier());
// Alias usado en varias vistas
final isDarkModeProvider = themeStateProvider;

// ================= AUTH =================
// Estado de autenticación basado en AsyncNotifier
final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository());
final secureStorageServiceProvider = Provider<SecureStorageService>((ref) => SecureStorageService());
final backupServiceProvider = Provider<BackupService>((ref) => BackupService());

class AuthController extends AsyncNotifier<User?> {
  final Map<String, String> _resetTokens = {};

  @override
  Future<User?> build() async {
    // Intentar restaurar sesión persistida
    try {
      final secure = ref.read(secureStorageServiceProvider);

      // Respetar preferencia de "Mantener sesión iniciada"
      final remember = await secure.getRememberMe();
      if (remember) {
        // 1) Intentar por token seguro primero
        final token = await secure.getAuthToken();
        if (token != null) {
          final repo = ref.read(authRepositoryProvider);
          final validated = await repo.validateSession(token);
          if (validated != null) {
            // Persistir user_json para acelerar próximos arranques
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('user_json', jsonEncode(validated.toMap()));
            return validated; // sesión válida
          }
        }
      }

      // 2) Fallback: intentar por user_json si existe
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('user_json');
      if (jsonStr != null) {
        try {
          final map = jsonDecode(jsonStr) as Map<String, dynamic>;
          final user = User.fromMap(map);
          return user;
        } catch (e) {
          debugPrint('⚠️ user_json corrupto: $e');
          await prefs.remove('user_json');
          return null;
        }
      }

      return null; // No autenticado
    } catch (e) {
      debugPrint('❌ Error restaurando sesión: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> login({required String email, required String password, bool rememberMe = true}) async {
    debugPrint('📩 AuthController.login llamado: email=$email rememberMe=$rememberMe');
    state = const AsyncLoading();
    final repo = ref.read(authRepositoryProvider);
    final result = await repo.login(email: email, password: password);
    if (result == null) {
      debugPrint('🚫 Login fallido (result null)');
      state = const AsyncData(null);
      return {'success': false, 'message': 'Credenciales inválidas'};
    }
    final user = result['user'] as User;
    final session = result['session'];
    debugPrint('✅ Login ok. UserID=${user.id}');

    // Guardar token y user persistido
    final secure = ref.read(secureStorageServiceProvider);
    await secure.saveAuthToken(session.token);
    await secure.saveUserId(user.id!);
    await secure.saveRememberMe(rememberMe);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_json', jsonEncode(user.toMap()));

    state = AsyncData(user);
    // Exportar respaldo tras login exitoso
    await ref.read(backupServiceProvider).exportBackup();
    return {'success': true, 'message': 'Inicio de sesión correcto'};
  }

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String nombre,
    String? apellido,
    String? telefono,
    bool rememberMe = true,
  }) async {
    state = const AsyncLoading();
    final repo = ref.read(authRepositoryProvider);
    final user = await repo.register(
      email: email,
      password: password,
      nombre: nombre,
      apellido: apellido,
      telefono: telefono,
    );
    if (user == null) {
      state = const AsyncData(null);
      return {'success': false, 'message': 'Email ya registrado'};
    }
    // Simular sesión creada tras registro
    final loginResult = await repo.login(email: email, password: password);
    if (loginResult != null) {
      final session = loginResult['session'];
      final secure = ref.read(secureStorageServiceProvider);
      await secure.saveAuthToken(session.token);
      await secure.saveUserId(user.id!);
      await secure.saveRememberMe(rememberMe);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_json', jsonEncode(user.toMap()));
    state = AsyncData(user);
    // Exportar respaldo tras registro exitoso
    await ref.read(backupServiceProvider).exportBackup();
    return {'success': true, 'message': 'Registro exitoso'};
  }

  Future<void> logout() async {
    state = const AsyncLoading();
    final secure = ref.read(secureStorageServiceProvider);
    await secure.clearSession();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_json');
    state = const AsyncData(null);
  }

  Future<Map<String, dynamic>> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    // Simulación mínima
    await Future.delayed(const Duration(milliseconds: 400));
    if (newPassword.length < 6) {
      return {'success': false, 'message': 'La nueva contraseña es muy corta'};
    }
    return {'success': true, 'message': 'Contraseña actualizada'};
  }

  // Flujo de recuperación de contraseña (simulado)
  Future<Map<String, dynamic>> requestPasswordReset({required String email}) async {
    await Future.delayed(const Duration(milliseconds: 400));
    if (email.isEmpty) {
      return {'success': false, 'message': 'Email inválido'};
    }
    final token = '123456';
    _resetTokens[email] = token;
    return {'success': true, 'message': 'Código enviado'};
  }

  Future<Map<String, dynamic>> validateResetToken({required String email, required String token}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final valid = _resetTokens[email];
    if (valid != null && valid == token) {
      return {'success': true};
    }
    return {'success': false, 'message': 'Código inválido'};
  }

  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String token,
    required String newPassword,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final valid = _resetTokens[email];
    if (valid == null || valid != token) {
      return {'success': false, 'message': 'Código inválido o expirado'};
    }
    if (newPassword.length < 6) {
      return {'success': false, 'message': 'La nueva contraseña es muy corta'};
    }
    _resetTokens.remove(email);
    return {'success': true, 'message': 'Contraseña restablecida'};
  }

  Future<bool> updateProfile({
    String? nombre,
    String? apellido,
    String? telefono,
    String? avatarUri,
  }) async {
    final current = state.value;
    if (current == null) return false;
    await Future.delayed(const Duration(milliseconds: 300));
    final updated = current.copyWith(
      nombre: nombre ?? current.nombre,
      apellido: apellido ?? current.apellido,
      telefono: telefono ?? current.telefono,
      // avatarUri no está en copyWith original, mantener por ahora
    );
    state = AsyncData(updated);
    return true;
  }
}

final authStateProvider = AsyncNotifierProvider<AuthController, User?>(AuthController.new);

final currentUserProvider = Provider<User?>((ref) => ref.watch(authStateProvider).value);
final isAuthenticatedProvider = Provider<bool>((ref) => ref.watch(authStateProvider).value != null);
final currentUserIdProvider = Provider<int?>((ref) => ref.watch(authStateProvider).value?.id);

// ================= LEGACY STUBS (anterior) =================
// Se mantiene para evitar rupturas si algún archivo antiguo lo usa.
class AuthState {
  final String userId;
  const AuthState(this.userId);
}
final authProvider = Provider<AuthState>((ref) => const AuthState('demoUser'));
