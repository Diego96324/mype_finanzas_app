import 'package:sqflite/sqflite.dart';
import '../../core/database/app_database.dart';
import '../models/gamification_profile_model.dart';
import '../models/gamification_achievement_model.dart';
import '../models/gamification_event_model.dart';
import '../models/user_achievement_model.dart';

class GamificationRepository {
  final Future<Database>? _overrideDbFuture;

  // Constructores para permitir inyección de dependencia o uso por defecto
  GamificationRepository({Future<Database>? dbFuture}) : _overrideDbFuture = dbFuture;
  GamificationRepository.withDb(Database db) : _overrideDbFuture = Future.value(db);

  Future<Database> get _dbFuture async => _overrideDbFuture ?? AppDatabase().database;

  // -------------------------------------------------------
  // PERFILES (Profiles)
  // -------------------------------------------------------

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

    // Verificamos si existe para decidir entre insert o update
    final existing = await db.query('gamification_profiles', where: 'usuario_id = ?', whereArgs: [profile.usuarioId], limit: 1);

    if (existing.isEmpty) {
      map['created_at'] = now;
      return db.insert('gamification_profiles', map);
    } else {
      // Mantenemos el created_at original, solo actualizamos el resto
      return db.update('gamification_profiles', map, where: 'usuario_id = ?', whereArgs: [profile.usuarioId]);
    }
  }

  // -------------------------------------------------------
  // LOGROS (Catálogo)
  // -------------------------------------------------------

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

  // -------------------------------------------------------
  // EVENTOS (Historial)
  // -------------------------------------------------------

  Future<int> insertEvent(GamificationEvent e) async {
    final db = await _dbFuture;
    final map = e.toMap();
    final now = DateTime.now().toIso8601String();
    // Si viene null, ponemos ahora. Si ya trae fecha, la respetamos.
    if (map['created_at'] == null) {
      map['created_at'] = now;
    }
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
    final rows = await db.query(
        'gamification_events',
        where: where.isEmpty ? null : where.join(' AND '),
        whereArgs: args.isEmpty ? null : args,
        orderBy: 'fecha_evento DESC',
        limit: limit
    );
    return rows.map((r) => GamificationEvent.fromMap(r)).toList();
  }

  // -------------------------------------------------------
  // PROGRESO DEL USUARIO (User Achievements)
  // -------------------------------------------------------

  /// 🔥 OPTIMIZACIÓN: Renombrado para coincidir con el Servicio.
  /// Antes se llamaba 'listUserAchievements'.
  Future<List<UserAchievement>> getUserAchievementsByUserId(int usuarioId) async {
    final db = await _dbFuture;
    final rows = await db.query('user_achievements', where: 'usuario_id = ?', whereArgs: [usuarioId]);
    return rows.map((r) => UserAchievement.fromMap(r)).toList();
  }

  Future<UserAchievement?> getUserAchievement(int usuarioId, int achievementId) async {
    final db = await _dbFuture;
    final rows = await db.query('user_achievements', where: 'usuario_id = ? AND achievement_id = ?', whereArgs: [usuarioId, achievementId], limit: 1);
    if (rows.isEmpty) return null;
    return UserAchievement.fromMap(rows.first);
  }

  Future<int> upsertUserAchievement(UserAchievement ua) async {
    final db = await _dbFuture;
    final now = DateTime.now().toIso8601String();
    final map = ua.toMap();
    map['updated_at'] = now;

    // Verificamos existencia por la combinación única usuario + logro
    final existing = await db.query(
        'user_achievements',
        where: 'usuario_id = ? AND achievement_id = ?',
        whereArgs: [ua.usuarioId, ua.achievementId],
        limit: 1
    );

    if (existing.isEmpty) {
      map['created_at'] = now;
      return db.insert('user_achievements', map);
    } else {
      // Mantenemos el created_at original
      // map.remove('created_at'); // Opcional: asegurarse de no sobrescribirlo
      return db.update(
          'user_achievements',
          map,
          where: 'usuario_id = ? AND achievement_id = ?',
          whereArgs: [ua.usuarioId, ua.achievementId]
      );
    }
  }
}