import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../dtos/user_model.dart';
import '../../core/providers/providers.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

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

  @Deprecated('Use ref.read(authStateProvider.notifier).login() instead')
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
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
    return {
      'success': false,
      'message': 'Método deprecado. Usa Riverpod providers.',
    };
  }

  @Deprecated('Use ref.read(authStateProvider.notifier).logout() instead')
  Future<void> logout() async {
  }

  @Deprecated('Use ref.read(authStateProvider.notifier).updateProfile() instead')
  Future<bool> updateProfile({
    String? nombre,
    String? apellido,
    String? telefono,
    String? avatarUri,
  }) async {
    return false;
  }

  @Deprecated('Use ref.read(authStateProvider.notifier).changePassword() instead')
  Future<Map<String, dynamic>> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    return {
      'success': false,
      'message': 'Método deprecado. Usa Riverpod providers.',
    };
  }
}
