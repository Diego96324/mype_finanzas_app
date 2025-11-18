import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repo.dart';
import '../../domain/services/secure_storage_service.dart';
import '../../domain/services/backup_service.dart';

// ================= THEME =================
// Nota: el proyecto ha migrado a Riverpod para el control del tema. Usa
// `themeStateProvider` como la única fuente de verdad. El archivo
// `lib/domain/services/theme_service.dart` está marcado como obsoleto.
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
    debugPrint('➡️ [AuthController] build() start');
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

      debugPrint('➡️ [AuthController] build() finished -> null (no session)');
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
    debugPrint('➡️ [AuthController] logout() called');
    // Si hay una operación crítica en curso (ej. updateProfile con cámara/recorte),
    // esperamos un corto periodo para evitar que la app haga redirect erróneo a login.
    final authOpActive = ref.read(routeSyncAuthOpProvider);
    final externalActive = ref.read(routeSyncExternalActiveProvider);
    if (authOpActive || externalActive) {
      debugPrint('➡️ [AuthController] logout delayed due to active auth/camera operation');
      // Reintentar por hasta 2500ms comprobando cada 500ms
      const retryInterval = Duration(milliseconds: 500);
      const maxAttempts = 5;
      var attempts = 0;
      while ((ref.read(routeSyncAuthOpProvider) || ref.read(routeSyncExternalActiveProvider)) && attempts < maxAttempts) {
        await Future.delayed(retryInterval);
        attempts++;
      }
      if (ref.read(routeSyncAuthOpProvider) || ref.read(routeSyncExternalActiveProvider)) {
        debugPrint('➡️ [AuthController] logout aborted: auth/camera operation still active after waiting');
        return; // Abort logout to avoid disrupting ongoing flow
      }
      debugPrint('➡️ [AuthController] proceeding with logout after delay');
    }

    state = const AsyncLoading();
    final secure = ref.read(secureStorageServiceProvider);
    await secure.clearSession();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_json');
    state = const AsyncData(null);
    debugPrint('➡️ [AuthController] logout() completed');
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
    bool clearAvatar = false,
  }) async {
    final current = state.value;
    if (current == null) return false;
    await Future.delayed(const Duration(milliseconds: 300));
    String? newAvatar;
    if (clearAvatar) {
      newAvatar = null;
    } else if (avatarUri != null) {
      newAvatar = avatarUri;
    } else {
      newAvatar = current.avatarUri;
    }
    final updated = current.copyWith(
      nombre: nombre ?? current.nombre,
      apellido: apellido ?? current.apellido,
      telefono: telefono ?? current.telefono,
      avatarUri: newAvatar,
    );
    state = AsyncData(updated);
    // Persist user_json so other parts of the app (that read SharedPreferences)
    // see the updated avatar immediately and avoid stale cached user data.
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_json', jsonEncode(updated.toMap()));
      debugPrint('➡️ [AuthController] persisted updated user_json after updateProfile');
    } catch (e) {
      debugPrint('⚠️ [AuthController] could not persist user_json after updateProfile: $e');
    }

    // Marcamos que hay una operación de auth en curso para evitar redirecciones
    try {
      ref.read(routeSyncAuthOpProvider.notifier).state = true;
      ref.read(routeSyncLastAuthProvider.notifier).state = DateTime.now();
    } catch (_) {}

    // Persistir cambios en la base de datos si tenemos userId
    try {
      if (current.id != null) {
        final repo = ref.read(authRepositoryProvider);
        await repo.updateProfile(
          userId: current.id!,
          nombre: nombre,
          apellido: apellido,
          telefono: telefono,
          avatarUri: avatarUri,
          clearAvatar: clearAvatar,
        );
      }
    } catch (e) {
      debugPrint('⚠️ Error persistiendo perfil en DB: $e');
    } finally {
      try {
        ref.read(routeSyncAuthOpProvider.notifier).state = false;
      } catch (_) {}
      debugPrint('➡️ [AuthController] updateProfile completed; authOp cleared');
    }
    return true;
  }

  /// Borra el avatar del usuario: actualiza la BD, el estado en memoria y persiste en prefs.
  Future<bool> deleteAvatar() async {
    final current = state.value;
    if (current == null || current.id == null) return false;

    final userId = current.id!;
    try {
      // 1) Build updated user in memory and set state FIRST so UI reacts immediately
      final updated = current.copyWith(avatarUri: null, updatedAt: DateTime.now());
      state = AsyncData(updated);
      debugPrint('[AuthController] deleteAvatar -> state.user.avatarUri=${state.value?.avatarUri}');

      // 2) Then persist the change to DB
      final repo = ref.read(authRepositoryProvider);
      final ok = await repo.updateProfile(userId: userId, clearAvatar: true);
      if (!ok) {
        debugPrint('⚠️ [AuthController] deleteAvatar: repo.updateProfile returned false');
        // We keep the in-memory state (optimistic). Optionally could rollback.
      }

      // 3) Persistir user_json para que lectores por SharedPreferences vean el cambio
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_json', jsonEncode(updated.toMap()));
        debugPrint('➡️ [AuthController] deleteAvatar persisted user_json');
      } catch (e) {
        debugPrint('⚠️ [AuthController] deleteAvatar could not persist user_json: $e');
      }

      return true;
    } catch (e) {
      debugPrint('❌ [AuthController] deleteAvatar error: $e');
      return false;
    }
  }
}

final authStateProvider = AsyncNotifierProvider<AuthController, User?>(AuthController.new);

final currentUserProvider = Provider<User?>((ref) => ref.watch(authStateProvider).value);
final isAuthenticatedProvider = Provider<bool>((ref) => ref.watch(authStateProvider).value != null);
final currentUserIdProvider = Provider<int?>((ref) => ref.watch(authStateProvider).value?.id);

// Cuando true, los listeners de ruta (MyHomePage) deben ignorar el próximo cambio
final routeSyncBlockProvider = StateProvider<bool>((ref) => false);

// Nuevo: providers reactivos que reemplazan las banderas estáticas usadas antes
final routeSyncUnblockAtProvider = StateProvider<DateTime?>((ref) => null);
final routeSyncExternalActiveProvider = StateProvider<bool>((ref) => false);
final routeSyncAuthOpProvider = StateProvider<bool>((ref) => false);
final routeSyncLastAuthProvider = StateProvider<DateTime?>((ref) => null);

// Permite a vistas pedir que el Shell (`MyHomePage`) muestre una pestaña
// concreta sin realizar una navegación URL; es útil para operaciones que
// abren actividades externas (cámara/recorte) y queremos mantener la UI.
final shellDesiredIndexProvider = StateProvider<int?>((ref) => null);

// ================= LEGACY STUBS (anterior) =================
// Se mantiene para evitar rupturas si algún archivo antiguo lo usa.
class AuthState {
  final String userId;
  const AuthState(this.userId);
}
final authProvider = Provider<AuthState>((ref) => const AuthState('demoUser'));
