import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../providers/providers.dart';

/// Singleton de AuthService - DEPRECADO
/// Este servicio ahora es un wrapper del provider de Riverpod
/// Para nuevas funcionalidades, usar directamente authStateProvider
///
/// NOTA: Los métodos login, register, logout, etc. ya no están aquí.
/// Usar ref.read(authStateProvider.notifier).login() en su lugar.
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  // Container global de Riverpod (se configura en main.dart)
  static ProviderContainer? _container;

  static void setContainer(ProviderContainer container) {
    _container = container;
  }

  User? get currentUser {
    if (_container != null) {
      return _container!.read(currentUserProvider);
    }
    return null;
  }

  bool get isAuthenticated {
    if (_container != null) {
      return _container!.read(isAuthenticatedProvider);
    }
    return false;
  }

  int? get currentUserId {
    if (_container != null) {
      return _container!.read(currentUserIdProvider);
    }
    return null;
  }

  // Estos métodos están deprecados - usar authStateProvider.notifier en su lugar
  @Deprecated('Use ref.read(authStateProvider.notifier).login() instead')
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    debugPrint('⚠️ AuthService.login() está deprecado. Usa authStateProvider.notifier.login()');
    return {
      'success': false,
      'message': 'Método deprecado. Usa Riverpod providers.',
    };
  }

  @Deprecated('Use ref.read(authStateProvider.notifier).register() instead')
  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String nombre,
    String? apellido,
    String? telefono,
  }) async {
    debugPrint('⚠️ AuthService.register() está deprecado. Usa authStateProvider.notifier.register()');
    return {
      'success': false,
      'message': 'Método deprecado. Usa Riverpod providers.',
    };
  }

  @Deprecated('Use ref.read(authStateProvider.notifier).logout() instead')
  Future<void> logout() async {
    debugPrint('⚠️ AuthService.logout() está deprecado. Usa authStateProvider.notifier.logout()');
  }

  @Deprecated('Use ref.read(authStateProvider.notifier).updateProfile() instead')
  Future<bool> updateProfile({
    String? nombre,
    String? apellido,
    String? telefono,
    String? avatarUri,
  }) async {
    debugPrint('⚠️ AuthService.updateProfile() está deprecado. Usa authStateProvider.notifier.updateProfile()');
    return false;
  }

  @Deprecated('Use ref.read(authStateProvider.notifier).changePassword() instead')
  Future<Map<String, dynamic>> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    debugPrint('⚠️ AuthService.changePassword() está deprecado. Usa authStateProvider.notifier.changePassword()');
    return {
      'success': false,
      'message': 'Método deprecado. Usa Riverpod providers.',
    };
  }
}
