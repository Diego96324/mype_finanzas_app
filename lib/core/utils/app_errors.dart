class AppErrorKeys {
  static const String unauthenticated = 'error.unauthenticated';
  static const String loadTransactions = 'error.load_transactions';
  static const String saveTransaction = 'error.save_transaction';
  static const String updateTransaction = 'error.update_transaction';
  static const String deleteTransaction = 'error.delete_transaction';
  static const String network = 'error.network';
}

class AppErrorMessages {
  static String of(String key) {
    // Aquí luego se conectará con Intl/l10n.
    switch (key) {
      case AppErrorKeys.unauthenticated:
        return 'Usuario no autenticado';
      case AppErrorKeys.loadTransactions:
        return 'Error al cargar transacciones';
      case AppErrorKeys.saveTransaction:
        return 'Error al guardar transacción';
      case AppErrorKeys.updateTransaction:
        return 'Error al actualizar transacción';
      case AppErrorKeys.deleteTransaction:
        return 'Error al eliminar transacción';
      case AppErrorKeys.network:
        return 'Error de red, inténtalo nuevamente';
      default:
        return 'Ocurrió un error inesperado';
    }
  }
}

