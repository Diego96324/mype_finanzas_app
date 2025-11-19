import '../../models/dtos/category_model.dart';

/// Caché muy simple en memoria para la pantalla de "Presupuestos por categoría".
/// Evita recargas innecesarias al volver a la pantalla.
class BudgetsCache {
  BudgetsCache._();
  static final BudgetsCache _instance = BudgetsCache._();
  factory BudgetsCache.instance() => _instance;

  // categorías por userId
  final Map<int, List<Category>> _categoriesByUser = {};

  // alert budgets por clave (userId|periodo|refYrefM)
  final Map<String, List<Map<String, dynamic>>> _alertBudgetsByKey = {};

  List<Category>? getCategories(int userId) => _categoriesByUser[userId];
  void setCategories(int userId, List<Category> cats) => _categoriesByUser[userId] = cats;
  void clearCategories([int? userId]) {
    if (userId == null) {
      _categoriesByUser.clear();
    } else {
      _categoriesByUser.remove(userId);
    }
  }

  // Usamos un formato limpio: userId:periodo:YYYYMM
  String _makeAlertsKey(int userId, String periodo, DateTime ref) {
    return '$userId:$periodo:${ref.year}${ref.month.toString().padLeft(2, '0')}';
  }

  List<Map<String, dynamic>>? getAlertBudgets(int userId, String periodo, DateTime ref) =>
      _alertBudgetsByKey[_makeAlertsKey(userId, periodo, ref)];

  void setAlertBudgets(int userId, String periodo, DateTime ref, List<Map<String, dynamic>> value) =>
      _alertBudgetsByKey[_makeAlertsKey(userId, periodo, ref)] = value;

  void clearAlertBudgets([int? userId]) {
    if (userId == null) {
      _alertBudgetsByKey.clear();
    } else {
      // las claves usan el formato '${userId}:...'
      final prefix = '$userId:';
      final keys = _alertBudgetsByKey.keys.where((k) => k.startsWith(prefix)).toList();
      for (final k in keys) {
        _alertBudgetsByKey.remove(k);
      }
    }
  }
}
