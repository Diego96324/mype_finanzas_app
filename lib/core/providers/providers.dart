// ignore_for_file: type_annotate_public_apis

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/models/user_model.dart';
import '../../data/repositories/auth_repo.dart';
import '../../domain/services/secure_storage_service.dart';

part 'providers.g.dart';

@riverpod
AuthRepository authRepository(dynamic authRepositoryRef) {
  return AuthRepository();
}

@Riverpod(keepAlive: true)
SecureStorageService secureStorage(dynamic secureStorageRef) {
  return SecureStorageService();
}

@Riverpod(keepAlive: true)
Future<SharedPreferences> sharedPreferences(dynamic sharedPreferencesRef) async {
  return await SharedPreferences.getInstance();
}

@riverpod
class AuthState extends _$AuthState {
  @override
  Future<User?> build() async {
    return await _restoreSession();
  }

  Future<User?> _restoreSession() async {
    try {
      final secureStorage = ref.read(secureStorageProvider);
      final token = await secureStorage.getAuthToken();

      if (token != null) {
        final authRepo = ref.read(authRepositoryProvider);
        final user = await authRepo.validateSession(token);
        if (user != null) {
          return user;
        } else {
          await secureStorage.deleteAuthToken();
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final authRepo = ref.read(authRepositoryProvider);
      final result = await authRepo.login(email: email, password: password);

      if (result == null) {
        return {
          'success': false,
          'message': 'Credenciales inválidas',
        };
      }

      final user = result['user'] as User;
      final token = (result['session'] as dynamic).token as String;

      final secureStorage = ref.read(secureStorageProvider);
      await secureStorage.saveAuthToken(token);

      state = AsyncValue.data(user);

      return {
        'success': true,
        'user': user,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error al iniciar sesión: $e',
      };
    }
  }

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String nombre,
    String? apellido,
    String? telefono,
  }) async {
    try {
      final authRepo = ref.read(authRepositoryProvider);
      final user = await authRepo.register(
        email: email,
        password: password,
        nombre: nombre,
        apellido: apellido,
        telefono: telefono,
      );

      if (user == null) {
        return {
          'success': false,
          'message': 'El email ya está registrado',
        };
      }

      // login automatico despues de registrarse
      return await login(email: email, password: password);
    } catch (e) {
      return {
        'success': false,
        'message': 'Error al registrar usuario: $e',
      };
    }
  }

  Future<void> logout() async {
    try {
      final secureStorage = ref.read(secureStorageProvider);
      await secureStorage.deleteAuthToken();
      state = const AsyncValue.data(null);
    } catch (e) {
      // nada que hacer aqui
    }
  }

  Future<bool> updateProfile({
    String? nombre,
    String? apellido,
    String? telefono,
    String? avatarUri,
  }) async {
    final currentUser = state.value;
    if (currentUser == null) return false;

    try {
      final authRepo = ref.read(authRepositoryProvider);
      final success = await authRepo.updateProfile(
        userId: currentUser.id!,
        nombre: nombre,
        apellido: apellido,
        telefono: telefono,
        avatarUri: avatarUri,
      );

      if (success) {
        final updatedUser = await authRepo.getUserById(currentUser.id!);
        if (updatedUser != null) {
          state = AsyncValue.data(updatedUser);
        }
      }

      return success;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final currentUser = state.value;
    if (currentUser == null) {
      return {
        'success': false,
        'message': 'No hay sesión activa',
      };
    }

    try {
      final authRepo = ref.read(authRepositoryProvider);
      final success = await authRepo.changePassword(
        userId: currentUser.id!,
        oldPassword: oldPassword,
        newPassword: newPassword,
      );

      if (success) {
        return {
          'success': true,
          'message': 'Contraseña actualizada exitosamente',
        };
      } else {
        return {
          'success': false,
          'message': 'La contraseña actual es incorrecta',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error al cambiar la contraseña',
      };
    }
  }
}

@riverpod
bool isAuthenticated(dynamic isAuthenticatedRef) {
  final authState = isAuthenticatedRef.watch(authStateProvider);
  return authState.value != null;
}

@riverpod
User? currentUser(dynamic currentUserRef) {
  final authState = currentUserRef.watch(authStateProvider);
  return authState.value;
}

@riverpod
int? currentUserId(dynamic currentUserIdRef) {
  final user = currentUserIdRef.watch(currentUserProvider);
  return user?.id;
}

@riverpod
class ThemeState extends _$ThemeState {
  @override
  Future<bool> build() async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    return prefs.getBool('dark_mode') ?? true;
  }

  Future<void> toggle() async {
    final isDark = state.value ?? true;
    final newValue = !isDark;

    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setBool('dark_mode', newValue);

    state = AsyncValue.data(newValue);
  }
}

@riverpod
bool isDarkMode(dynamic isDarkModeRef) {
  final themeState = isDarkModeRef.watch(themeStateProvider);
  return themeState.value ?? true;
}

