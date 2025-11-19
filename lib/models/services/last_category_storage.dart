import 'package:shared_preferences/shared_preferences.dart';

class LastCategoryStorage {
  static const _prefix = 'last_category_id_';

  // Lee la última categoría por usuario y opcionalmente por tipo (ingreso/egreso/transferencia)
  Future<int?> readLast(int userId, {String? tipo}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_buildKey(userId, tipo));
  }

  // Escribe la última categoría por usuario y opcionalmente por tipo
  Future<void> writeLast(int userId, int categoryId, {String? tipo}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_buildKey(userId, tipo), categoryId);
  }

  // Limpia la última categoría específica (por tipo si se pasa)
  Future<void> clear(int userId, {String? tipo}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_buildKey(userId, tipo));
  }

  // Limpia todas las posibles claves para un usuario (incluye legacy sin tipo)
  Future<void> clearAllForUser(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = <String>{
      _buildKey(userId, 'ingreso'),
      _buildKey(userId, 'egreso'),
      _buildKey(userId, 'transferencia'),
      _buildLegacyKey(userId),
    };
    for (final k in keys) {
      await prefs.remove(k);
    }
  }

  String _buildKey(int userId, String? tipo) {
    if (tipo == null || tipo.isEmpty) {
      // clave legacy sin tipo
      return _buildLegacyKey(userId);
    }
    return '$_prefix${userId}_$tipo';
  }

  String _buildLegacyKey(int userId) => '$_prefix$userId';
}
