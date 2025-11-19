/// Utilidades para formatear montos y monedas de forma inteligente
class CurrencyFormatter {
  /// Formatea un monto sin decimales innecesarios
  ///
  /// Ejemplos:
  /// - 1000.0 → "1000"
  /// - 1000.50 → "1000.50"
  /// - 1234.99 → "1234.99"
  static String formatAmount(double amount) {
    if (amount == amount.toInt()) {
      // Si el número es entero, no mostrar decimales
      return amount.toInt().toString();
    } else {
      // Si tiene decimales, mostrarlos (máximo 2 decimales)
      return amount.toStringAsFixed(2);
    }
  }

  /// Formatea un monto con símbolo de moneda
  ///
  /// Ejemplos:
  /// - formatWithCurrency(1000, 'PEN') → "S/ 1000"
  /// - formatWithCurrency(1000.50, 'USD') → "\$ 1000.50"
  static String formatWithCurrency(double amount, String currency) {
    final symbol = getCurrencySymbol(currency);
    return '$symbol ${formatAmount(amount)}';
  }

  /// Obtiene el símbolo de la moneda
  ///
  /// Soporta: PEN, USD, EUR
  static String getCurrencySymbol(String currency) {
    switch (currency.toUpperCase()) {
      case 'PEN':
        return 'S/';
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      default:
        return currency;
    }
  }

  /// Formatea un monto con separadores de miles
  ///
  /// Ejemplos:
  /// - formatWithThousands(1000) → "1,000"
  /// - formatWithThousands(1234567.89) → "1,234,567.89"
  static String formatWithThousands(double amount) {
    final parts = formatAmount(amount).split('.');
    final integerPart = parts[0];
    final decimalPart = parts.length > 1 ? parts[1] : null;

    // Agregar separadores de miles
    final buffer = StringBuffer();
    var count = 0;
    for (var i = integerPart.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(integerPart[i]);
      count++;
    }

    final formattedInteger = buffer.toString().split('').reversed.join();

    if (decimalPart != null) {
      return '$formattedInteger.$decimalPart';
    }
    return formattedInteger;
  }

  /// Formatea un monto con separadores de miles y símbolo de moneda
  ///
  /// Ejemplos:
  /// - formatComplete(1234567, 'PEN') → "S/ 1,234,567"
  /// - formatComplete(1234567.89, 'USD') → "\$ 1,234,567.89"
  static String formatComplete(double amount, String currency) {
    final symbol = getCurrencySymbol(currency);
    return '$symbol ${formatWithThousands(amount)}';
  }

  /// Parsea un string de monto a double, eliminando separadores y símbolos
  ///
  /// Ejemplos:
  /// - parseAmount("1,234.56") → 1234.56
  /// - parseAmount("S/ 1,234") → 1234.0
  static double? parseAmount(String amountString) {
    try {
      // Eliminar símbolos de moneda y espacios
      var cleaned = amountString
          .replaceAll(RegExp(r'[S/\$€,\s]'), '')
          .trim();

      return double.parse(cleaned);
    } catch (e) {
      return null;
    }
  }

  /// Valida si un string representa un monto válido
  static bool isValidAmount(String amountString) {
    return parseAmount(amountString) != null;
  }
}

