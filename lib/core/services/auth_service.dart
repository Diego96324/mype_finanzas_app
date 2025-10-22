import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../repos/auth_repo.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final AuthRepository _authRepo = AuthRepository();
  User? _currentUser;
  String? _currentToken;

  User? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  int? get currentUserId => _currentUser?.id;

  Future<bool> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token != null) {
        final user = await _authRepo.validateSession(token);
        if (user != null) {
          _currentUser = user;
          _currentToken = token;
          return true;
        } else {
          await logout();
        }
      }
      return false;
    } catch (e) {
      print('Error al inicializar AuthService: $e');
      return false;
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
      final user = await _authRepo.register(
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

      return await login(email: email, password: password);
    } catch (e) {
      return {
        'success': false,
        'message': 'Error al registrar usuario: $e',
      };
    }
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final result = await _authRepo.login(email: email, password: password);

      if (result == null) {
        return {
          'success': false,
          'message': 'Credenciales inválidas',
        };
      }

      _currentUser = result['user'] as User;
      _currentToken = (result['session'] as dynamic).token as String;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', _currentToken!);

      return {
        'success': true,
        'user': _currentUser,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error al iniciar sesión: $e',
      };
    }
  }

  Future<void> logout() async {
    try {
      if (_currentToken != null) {
        await _authRepo.logout(_currentToken!);
      }

      _currentUser = null;
      _currentToken = null;

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
    } catch (e) {
      print('Error al cerrar sesión: $e');
    }
  }

  Future<bool> updateProfile({
    String? nombre,
    String? apellido,
    String? telefono,
    String? avatarUri,
  }) async {
    if (_currentUser == null) return false;

    try {
      final success = await _authRepo.updateProfile(
        userId: _currentUser!.id!,
        nombre: nombre,
        apellido: apellido,
        telefono: telefono,
        avatarUri: avatarUri,
      );

      if (success) {
        final updatedUser = await _authRepo.getUserById(_currentUser!.id!);
        if (updatedUser != null) {
          _currentUser = updatedUser;
        }
      }

      return success;
    } catch (e) {
      print('Error al actualizar perfil: $e');
      return false;
    }
  }

  Future<bool> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    if (_currentUser == null) return false;

    try {
      return await _authRepo.changePassword(
        userId: _currentUser!.id!,
        oldPassword: oldPassword,
        newPassword: newPassword,
      );
    } catch (e) {
      print('Error al cambiar contraseña: $e');
      return false;
    }
  }
}
