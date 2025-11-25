import 'package:flutter/material.dart';

// Tema para que todos los date pickers se vean iguales y no desentonen
class AppDatePickerTheme {
  // Color principal verde de la app
  static const Color _primaryGreen = Color(0xFF13BB67);
  static const Color _surfaceDark = Color(0xFF2D2D2D);
  static const Color _surfaceDarker = Color(0xFF3D3D3D);

  /// Tema oscuro para DatePicker (selector de fecha simple)
  static ThemeData darkDatePickerTheme(BuildContext context) {
    return Theme.of(context).copyWith(
      colorScheme: ColorScheme.dark(
        primary: _primaryGreen,
        onPrimary: Colors.white,
        surface: _surfaceDark,
        onSurface: Colors.white,
        surfaceContainerHighest: _surfaceDarker,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: _surfaceDark,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _primaryGreen,
        ),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: _surfaceDark,
        headerBackgroundColor: _primaryGreen,
        headerForegroundColor: Colors.white,
        // Color cuando se marca un día
        dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return _primaryGreen;
          }
          return null;
        }),
        dayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return Colors.white;
        }),
        // Color para hoy
        todayBackgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return _primaryGreen;
          }
          return _primaryGreen.withValues(alpha: 0.2);
        }),
        todayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return _primaryGreen;
        }),
        todayBorder: BorderSide(
          color: _primaryGreen.withValues(alpha: 0.5),
          width: 1.5,
        ),
        // Colores para el selector de año
        yearBackgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return _primaryGreen;
          }
          return null;
        }),
        yearForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return Colors.white;
        }),
      ),
    );
  }

  /// Tema oscuro para DateRangePicker (selector de rango de fechas)
  static ThemeData darkDateRangePickerTheme(BuildContext context) {
    return Theme.of(context).copyWith(
      colorScheme: ColorScheme.dark(
        primary: _primaryGreen,
        onPrimary: Colors.white,
        surface: _surfaceDark,
        onSurface: Colors.white,
        surfaceContainerHighest: _surfaceDarker,
        secondary: _primaryGreen,
        onSecondary: Colors.white,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: _surfaceDark,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _primaryGreen,
        ),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: _surfaceDark,
        headerBackgroundColor: _primaryGreen,
        headerForegroundColor: Colors.white,
        rangePickerBackgroundColor: _surfaceDark,
        rangePickerHeaderBackgroundColor: _primaryGreen,
        rangePickerHeaderForegroundColor: Colors.white,
        // Color de resaltado del rango - verde suave y transparente
        rangeSelectionBackgroundColor: _primaryGreen.withValues(alpha: 0.15),
        // Color de overlay al pasar el mouse/touch
        rangeSelectionOverlayColor: WidgetStateProperty.all(
          _primaryGreen.withValues(alpha: 0.08),
        ),
        // Color de los días seleccionados
        dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return _primaryGreen;
          }
          return null;
        }),
        dayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return Colors.white;
        }),
        // Color del día actual (hoy)
        todayBackgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return _primaryGreen;
          }
          return _primaryGreen.withValues(alpha: 0.2);
        }),
        todayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return _primaryGreen;
        }),
        todayBorder: BorderSide(
          color: _primaryGreen.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
    );
  }
}

