import '../models/transaction_model.dart';

/// 🗄️ Servicio de caché pa' las transacciones
/// Evita estar consultando la BD cada 5 segundos como loco
class TransactionCacheService {
  static final TransactionCacheService _instance = TransactionCacheService._internal();
  factory TransactionCacheService() => _instance;
  TransactionCacheService._internal();

  // 📦 Caché de transacciones por rango de fechas
  final Map<String, _CacheEntry> _cache = {};

  // ⏰ Tiempo de vida del caché (5 minutos)
  static const Duration _cacheTTL = Duration(minutes: 5);

  /// Obtener transacciones desde caché o BD
  List<AppTransaction>? get({
    required int userId,
    required DateTime from,
    required DateTime to,
  }) {
    final key = _buildKey(userId, from, to);
    final entry = _cache[key];

    if (entry == null) return null;

    // Verificar si el caché expiró
    if (DateTime.now().difference(entry.timestamp) > _cacheTTL) {
      _cache.remove(key);
      return null;
    }

    return entry.transactions;
  }

  /// Guardar transacciones en caché
  void put({
    required int userId,
    required DateTime from,
    required DateTime to,
    required List<AppTransaction> transactions,
  }) {
    final key = _buildKey(userId, from, to);
    _cache[key] = _CacheEntry(
      transactions: transactions,
      timestamp: DateTime.now(),
    );
  }

  void invalidateAll() {
    _cache.clear();
  }

  /// Invalidar caché de un usuario específico
  void invalidateUser(int userId) {
    _cache.removeWhere((key, _) => key.startsWith('$userId:'));
  }

  /// Limpiar caché expirado (limpieza periódica)
  void cleanExpired() {
    final now = DateTime.now();
    _cache.removeWhere((_, entry) {
      return now.difference(entry.timestamp) > _cacheTTL;
    });
  }

  /// Construir clave única para el caché
  String _buildKey(int userId, DateTime from, DateTime to) {
    return '$userId:${from.toIso8601String()}:${to.toIso8601String()}';
  }

  /// Obtener tamaño del caché (para debugging)
  int get cacheSize => _cache.length;

  void clear() {
    _cache.clear();
  }
}

/// 📦 Entrada del caché con timestamp
class _CacheEntry {
  final List<AppTransaction> transactions;
  final DateTime timestamp;

  _CacheEntry({
    required this.transactions,
    required this.timestamp,
  });
}

