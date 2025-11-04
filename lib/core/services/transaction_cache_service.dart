import '../models/transaction_model.dart';

// cache simple para no estar consultando la bd a cada rato
class TransactionCacheService {
  static final TransactionCacheService _instance = TransactionCacheService._internal();
  factory TransactionCacheService() => _instance;
  TransactionCacheService._internal();

  final Map<String, _CacheEntry> _cache = {};

  static const Duration _cacheTTL = Duration(minutes: 5);

  List<AppTransaction>? get({
    required int userId,
    required DateTime from,
    required DateTime to,
  }) {
    final key = _buildKey(userId, from, to);
    final entry = _cache[key];

    if (entry == null) return null;

    if (DateTime.now().difference(entry.timestamp) > _cacheTTL) {
      _cache.remove(key);
      return null;
    }

    return entry.transactions;
  }

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

  void invalidateUser(int userId) {
    _cache.removeWhere((key, _) => key.startsWith('$userId:'));
  }

  void cleanExpired() {
    final now = DateTime.now();
    _cache.removeWhere((_, entry) {
      return now.difference(entry.timestamp) > _cacheTTL;
    });
  }

  String _buildKey(int userId, DateTime from, DateTime to) {
    return '$userId:${from.toIso8601String()}:${to.toIso8601String()}';
  }

  int get cacheSize => _cache.length;

  void clear() {
    _cache.clear();
  }
}

class _CacheEntry {
  final List<AppTransaction> transactions;
  final DateTime timestamp;

  _CacheEntry({
    required this.transactions,
    required this.timestamp,
  });
}

