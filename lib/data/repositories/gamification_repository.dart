import 'package:sqflite/sqflite.dart';
import '../../core/database/app_database.dart';
import '../models/gamification_profile_model.dart';
import '../models/gamification_achievement_model.dart';
import '../models/gamification_event_model.dart';

class GamificationRepository {
  final Future<Database>? _overrideDbFuture;
  GamificationRepository({Future<Database>? dbFuture}) : _overrideDbFuture = dbFuture;
  GamificationRepository.withDb(Database db) : _overrideDbFuture = Future.value(db);

  Future<Database> get _dbFuture async => _overrideDbFuture ?? AppDatabase().database;

  Future<GamificationProfile?> getProfile(int usuarioId) async {
    final db = await _dbFuture;
    final rows = await db.query('gamification_profiles', where: 'usuario_id = ?', whereArgs: [usuarioId], limit: 1);
    if (rows.isEmpty) return null;
    return GamificationProfile.fromMap(rows.first);
  }

  Future<int> upsertProfile(GamificationProfile profile) async {
    final db = await _dbFuture;
    final now = DateTime.now().toIso8601String();
    final map = profile.toMap();
    map['updated_at'] = now;
    final existing = await db.query('gamification_profiles', where: 'usuario_id = ?', whereArgs: [profile.usuarioId], limit: 1);
    if (existing.isEmpty) {
      map['created_at'] = now;
      return db.insert('gamification_profiles', map);
    } else {
      return db.update('gamification_profiles', map, where: 'usuario_id = ?', whereArgs: [profile.usuarioId]);
    }
  }

  Future<List<GamificationAchievement>> listAchievements({String? tipo}) async {
    final db = await _dbFuture;
    if (tipo != null) {
      final rows = await db.query('gamification_achievements', where: 'tipo = ?', whereArgs: [tipo]);
      return rows.map((r) => GamificationAchievement.fromMap(r)).toList();
    }
    final rows = await db.query('gamification_achievements');
    return rows.map((r) => GamificationAchievement.fromMap(r)).toList();
  }

  Future<int> insertAchievement(GamificationAchievement a) async {
    final db = await _dbFuture;
    final map = a.toMap();
    final now = DateTime.now().toIso8601String();
    map['created_at'] = now;
    map['updated_at'] = now;
    return db.insert('gamification_achievements', map);
  }

  Future<int> updateAchievement(GamificationAchievement a) async {
    if (a.id == null) throw ArgumentError('updateAchievement requires id');
    final db = await _dbFuture;
    final map = a.toMap()..remove('id');
    map['updated_at'] = DateTime.now().toIso8601String();
    return db.update('gamification_achievements', map, where: 'id = ?', whereArgs: [a.id]);
  }

  Future<int> insertEvent(GamificationEvent e) async {
    final db = await _dbFuture;
    final map = e.toMap();
    final now = DateTime.now().toIso8601String();
    map['created_at'] = map['created_at'] ?? now;
    return db.insert('gamification_events', map);
  }

  Future<List<GamificationEvent>> listEvents({int? usuarioId, int? limit}) async {
    final db = await _dbFuture;
    final where = <String>[];
    final args = <dynamic>[];
    if (usuarioId != null) {
      where.add('usuario_id = ?');
      args.add(usuarioId);
    }
    final rows = await db.query('gamification_events', where: where.isEmpty ? null : where.join(' AND '), whereArgs: args.isEmpty ? null : args, orderBy: 'fecha_evento DESC', limit: limit);
    return rows.map((r) => GamificationEvent.fromMap(r)).toList();
  }
}

