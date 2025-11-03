import 'package:flutter/material.dart';

/// Clase con validadores reutilizables y mensajes de error consistentes
class FormValidators {
  // Email
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Ingrese su email';
    }
    final emailRegex = RegExp(r'^[\w\-.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Formato de email inválido';
    }
    return null;
  }

  // Contraseña
  static String? validatePassword(String? value, {int minLength = 6}) {
    if (value == null || value.isEmpty) {
      return 'Ingrese una contraseña';
    }
    if (value.length < minLength) {
      return 'Mínimo $minLength caracteres';
    }
    return null;
  }

  // Confirmar contraseña
  static String? validateConfirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) {
      return 'Confirme su contraseña';
    }
    if (value != password) {
      return 'Las contraseñas no coinciden';
    }
    return null;
  }

  // Nombre
  static String? validateName(String? value, {int minLength = 2}) {
    if (value == null || value.trim().isEmpty) {
      return 'Este campo es obligatorio';
    }
    if (value.trim().length < minLength) {
      return 'Mínimo $minLength caracteres';
    }
    return null;
  }

  // Teléfono opcional
  static String? validatePhoneOptional(String? value) {
    if (value != null && value.isNotEmpty) {
      if (value.length < 9) {
        return 'Teléfono inválido (mín. 9 dígitos)';
      }
      final phoneRegex = RegExp(r'^[0-9+\-\s()]+$');
      if (!phoneRegex.hasMatch(value)) {
        return 'Solo números y símbolos permitidos';
      }
    }
    return null;
  }

  // Monto (número decimal)
  static String? validateAmount(String? value, {bool allowNegative = false}) {
    if (value == null || value.trim().isEmpty) {
      return 'Ingrese un monto';
    }
    final amount = double.tryParse(value.trim());
    if (amount == null) {
      return 'Ingrese un número válido';
    }
    if (!allowNegative && amount < 0) {
      return 'El monto no puede ser negativo';
    }
    return null;
  }

  // Texto requerido genérico
  static String? validateRequired(String? value, {String? fieldName}) {
    if (value == null || value.trim().isEmpty) {
      return '${fieldName ?? 'Este campo'} es obligatorio';
    }
    return null;
  }

  // Máximo de caracteres
  static String? validateMaxLength(String? value, int maxLength, {String? fieldName}) {
    if (value != null && value.length > maxLength) {
      return '${fieldName ?? 'Este campo'} no puede exceder $maxLength caracteres';
    }
    return null;
  }

  // Combinado: requerido + máximo
  static String? validateRequiredMaxLength(String? value, int maxLength, {String? fieldName}) {
    final requiredError = validateRequired(value, fieldName: fieldName);
    if (requiredError != null) return requiredError;

    return validateMaxLength(value, maxLength, fieldName: fieldName);
  }
}

/// Estado de validación de un campo
enum ValidationState {
  none,
  validating,
  success,
  error,
}

/// Controlador para manejar el estado de validación de un campo
class ValidationController extends ChangeNotifier {
  ValidationState _state = ValidationState.none;
  String? _errorMessage;

  ValidationState get state => _state;
  String? get errorMessage => _errorMessage;
  bool get hasError => _state == ValidationState.error;
  bool get isValid => _state == ValidationState.success;

  void setValidating() {
    _state = ValidationState.validating;
    _errorMessage = null;
    notifyListeners();
  }

  void setSuccess() {
    _state = ValidationState.success;
    _errorMessage = null;
    notifyListeners();
  }

  void setError(String message) {
    _state = ValidationState.error;
    _errorMessage = message;
    notifyListeners();
  }

  void reset() {
    _state = ValidationState.none;
    _errorMessage = null;
    notifyListeners();
  }
}

