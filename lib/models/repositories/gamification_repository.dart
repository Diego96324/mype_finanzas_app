import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';
import '../dtos/gamification_profile_model.dart';
import '../dtos/gamification_achievement_model.dart';
import '../dtos/gamification_event_model.dart';
import '../dtos/user_achievement_model.dart';

class GamificationRepository {
  final Future<Database>? _overrideDbFuture;

  // Constructores para permitir inyección de dependencia o uso por defecto
  GamificationRepository({Future<Database>? dbFuture}) : _overrideDbFuture = dbFuture;
  GamificationRepository.withDb(Database db) : _overrideDbFuture = Future.value(db);

  Future<Database> get _dbFuture async => _overrideDbFuture ?? AppDatabase().database;

  // =========================================================================
  // PERFILES (Profiles)
  // =========================================================================

  Future<GamificationProfile?> getProfile(int usuarioId) async {
    final db = await _dbFuture;
    final rows = await db.query(
      'gamification_profiles',
      where: 'usuario_id = ?',
      whereArgs: [usuarioId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return GamificationProfile.fromMap(rows.first);
  }

  Future<int> upsertProfile(GamificationProfile profile) async {
    final db = await _dbFuture;
    final now = DateTime.now().toIso8601String();
    final map = profile.toMap();
    map['updated_at'] = now;

    final existing = await db.query(
      'gamification_profiles',
      where: 'usuario_id = ?',
      whereArgs: [profile.usuarioId],
      limit: 1,
    );

    if (existing.isEmpty) {
      map['created_at'] = now;
      return db.insert('gamification_profiles', map);
    } else {
      map.remove('created_at'); // Preservar el original
      return db.update(
        'gamification_profiles',
        map,
        where: 'usuario_id = ?',
        whereArgs: [profile.usuarioId],
      );
    }
  }

  /// Crea un perfil inicial para un usuario si no existe
  Future<GamificationProfile> getOrCreateProfile(int usuarioId) async {
    final existing = await getProfile(usuarioId);
    if (existing != null) return existing;

    final now = DateTime.now();
    final newProfile = GamificationProfile(
      usuarioId: usuarioId,
      puntos: 0,
      nivel: 1,
      rachaActual: 0,
      rachaMaxima: 0,
      ultimaFechaEvento: null,
      createdAt: now,
      updatedAt: now,
    );

    await upsertProfile(newProfile);
    return newProfile;
  }

  // =========================================================================
  // LOGROS - CATÁLOGO (Achievements)
  // =========================================================================

  /// Lista todos los logros del catálogo
  Future<List<GamificationAchievement>> listAchievements({String? tipo}) async {
    final db = await _dbFuture;

    if (tipo != null) {
      final rows = await db.query(
        'gamification_achievements',
        where: 'tipo = ?',
        whereArgs: [tipo],
        orderBy: 'puntos ASC',
      );
      return rows.map((r) => GamificationAchievement.fromMap(r)).toList();
    }

    final rows = await db.query(
      'gamification_achievements',
      orderBy: 'tipo ASC, puntos ASC',
    );
    return rows.map((r) => GamificationAchievement.fromMap(r)).toList();
  }

  /// Obtiene un logro por su ID
  Future<GamificationAchievement?> getAchievementById(int id) async {
    final db = await _dbFuture;
    final rows = await db.query(
      'gamification_achievements',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return GamificationAchievement.fromMap(rows.first);
  }

  /// Obtiene un logro por su código único
  Future<GamificationAchievement?> getAchievementByCode(String code) async {
    final db = await _dbFuture;
    final rows = await db.query(
      'gamification_achievements',
      where: 'code = ?',
      whereArgs: [code],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return GamificationAchievement.fromMap(rows.first);
  }

  /// Inserta un nuevo logro en el catálogo
  Future<int> insertAchievement(GamificationAchievement a) async {
    final db = await _dbFuture;
    final now = DateTime.now().toIso8601String();
    final map = a.toMap();
    map.remove('id'); // Dejar que SQLite asigne el ID
    map['created_at'] = now;
    map['updated_at'] = now;
    return db.insert('gamification_achievements', map);
  }

  /// Actualiza un logro existente
  Future<int> updateAchievement(GamificationAchievement a) async {
    if (a.id == null) throw ArgumentError('updateAchievement requires id');
    final db = await _dbFuture;
    final map = a.toMap()..remove('id')..remove('created_at');
    map['updated_at'] = DateTime.now().toIso8601String();
    return db.update(
      'gamification_achievements',
      map,
      where: 'id = ?',
      whereArgs: [a.id],
    );
  }

  /// Elimina un logro del catálogo (usar con cuidado)
  Future<int> deleteAchievement(int id) async {
    final db = await _dbFuture;
    return db.delete(
      'gamification_achievements',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Cuenta el total de logros en el catálogo
  Future<int> countAchievements() async {
    final db = await _dbFuture;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM gamification_achievements');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // =========================================================================
  // EVENTOS (Historial)
  // =========================================================================

  /// Inserta un nuevo evento de gamificación
  Future<int> insertEvent(GamificationEvent e) async {
    final db = await _dbFuture;
    final now = DateTime.now().toIso8601String();
    final map = e.toMap();
    map.remove('id'); // Dejar que SQLite asigne el ID

    // Asegurar que created_at tenga valor
    if (map['created_at'] == null) {
      map['created_at'] = now;
    }

    return db.insert('gamification_events', map);
  }

  /// Lista eventos de gamificación con filtros opcionales
  Future<List<GamificationEvent>> listEvents({
    int? usuarioId,
    String? tipoEvento,
    DateTime? desde,
    DateTime? hasta,
    int? limit,
  }) async {
    final db = await _dbFuture;
    final where = <String>[];
    final args = <dynamic>[];

    if (usuarioId != null) {
      where.add('usuario_id = ?');
      args.add(usuarioId);
    }

    if (tipoEvento != null) {
      where.add('tipo_evento = ?');
      args.add(tipoEvento);
    }

    if (desde != null) {
      where.add('fecha >= ?');
      args.add(desde.toIso8601String());
    }

    if (hasta != null) {
      where.add('fecha <= ?');
      args.add(hasta.toIso8601String());
    }

    final rows = await db.query(
      'gamification_events',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'fecha DESC',
      limit: limit,
    );

    return rows.map((r) => GamificationEvent.fromMap(r)).toList();
  }

  /// Obtiene los puntos totales ganados por un usuario
  Future<int> getTotalPointsEarned(int usuarioId) async {
    final db = await _dbFuture;
    final result = await db.rawQuery(
      'SELECT SUM(puntos_otorgados) as total FROM gamification_events WHERE usuario_id = ?',
      [usuarioId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Cuenta eventos por tipo para un usuario
  Future<int> countEventsByType(int usuarioId, String tipoEvento) async {
    final db = await _dbFuture;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM gamification_events WHERE usuario_id = ? AND tipo_evento = ?',
      [usuarioId, tipoEvento],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // =========================================================================
  // PROGRESO DEL USUARIO (User Achievements)
  // =========================================================================

  /// Obtiene todos los logros de un usuario con su progreso
  Future<List<UserAchievement>> getUserAchievementsByUserId(int usuarioId) async {
    final db = await _dbFuture;
    final rows = await db.query(
      'user_achievements',
      where: 'usuario_id = ?',
      whereArgs: [usuarioId],
    );
    return rows.map((r) => UserAchievement.fromMap(r)).toList();
  }

  /// Obtiene el progreso de un usuario en un logro específico
  Future<UserAchievement?> getUserAchievement(int usuarioId, int achievementId) async {
    final db = await _dbFuture;
    final rows = await db.query(
      'user_achievements',
      where: 'usuario_id = ? AND achievement_id = ?',
      whereArgs: [usuarioId, achievementId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return UserAchievement.fromMap(rows.first);
  }

  /// Obtiene el progreso de un usuario en un logro por código
  Future<UserAchievement?> getUserAchievementByCode(int usuarioId, String achievementCode) async {
    final achievement = await getAchievementByCode(achievementCode);
    if (achievement?.id == null) return null;
    return getUserAchievement(usuarioId, achievement!.id!);
  }

  /// Inserta o actualiza el progreso de un usuario en un logro
  Future<int> upsertUserAchievement(UserAchievement ua) async {
    final db = await _dbFuture;
    final now = DateTime.now().toIso8601String();
    final map = ua.toMap();
    map['updated_at'] = now;
    map['ultima_actualizacion'] = now;
    map.remove('id'); // Manejamos por usuario_id + achievement_id

    final existing = await db.query(
      'user_achievements',
      where: 'usuario_id = ? AND achievement_id = ?',
      whereArgs: [ua.usuarioId, ua.achievementId],
      limit: 1,
    );

    if (existing.isEmpty) {
      map['created_at'] = now;
      return db.insert('user_achievements', map);
    } else {
      map.remove('created_at'); // Preservar el original
      return db.update(
        'user_achievements',
        map,
        where: 'usuario_id = ? AND achievement_id = ?',
        whereArgs: [ua.usuarioId, ua.achievementId],
      );
    }
  }

  /// Obtiene o crea el progreso de un usuario en un logro
  Future<UserAchievement> getOrCreateUserAchievement(int usuarioId, int achievementId) async {
    final existing = await getUserAchievement(usuarioId, achievementId);
    if (existing != null) return existing;

    final now = DateTime.now();
    final newUa = UserAchievement(
      usuarioId: usuarioId,
      achievementId: achievementId,
      progresoActual: 0,
      estado: 'locked',
      ultimaActualizacion: now,
      createdAt: now,
      updatedAt: now,
    );

    await upsertUserAchievement(newUa);
    return newUa;
  }

  /// Cuenta logros desbloqueados por un usuario
  Future<int> countUnlockedAchievements(int usuarioId) async {
    final db = await _dbFuture;
    final result = await db.rawQuery(
      "SELECT COUNT(*) as count FROM user_achievements WHERE usuario_id = ? AND estado = 'unlocked'",
      [usuarioId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Obtiene logros desbloqueados recientemente
  Future<List<UserAchievement>> getRecentlyUnlocked(int usuarioId, {int limit = 5}) async {
    final db = await _dbFuture;
    final rows = await db.query(
      'user_achievements',
      where: "usuario_id = ? AND estado = 'unlocked'",
      whereArgs: [usuarioId],
      orderBy: 'ultima_actualizacion DESC',
      limit: limit,
    );
    return rows.map((r) => UserAchievement.fromMap(r)).toList();
  }

  // =========================================================================
  // MÉTODOS COMBINADOS (JOINs útiles)
  // =========================================================================

  /// Obtiene logros con el progreso del usuario (LEFT JOIN)
  /// Retorna un mapa con el achievement y su user_achievement (puede ser null si no tiene progreso)
  Future<List<Map<String, dynamic>>> getAchievementsWithProgress(int usuarioId) async {
    final db = await _dbFuture;
    final rows = await db.rawQuery('''
      SELECT 
        a.*,
        ua.progreso_actual as user_progreso,
        ua.estado as user_estado,
        ua.ultima_actualizacion as user_ultima_actualizacion
      FROM gamification_achievements a
      LEFT JOIN user_achievements ua 
        ON a.id = ua.achievement_id AND ua.usuario_id = ?
      ORDER BY a.tipo ASC, a.puntos ASC
    ''', [usuarioId]);

    return rows;
  }

  /// Inicializa el progreso de un usuario en todos los logros existentes
  Future<void> initializeUserAchievements(int usuarioId) async {
    final achievements = await listAchievements();
    final now = DateTime.now();

    for (final achievement in achievements) {
      if (achievement.id == null) continue;

      final existing = await getUserAchievement(usuarioId, achievement.id!);
      if (existing == null) {
        await upsertUserAchievement(UserAchievement(
          usuarioId: usuarioId,
          achievementId: achievement.id!,
          progresoActual: 0,
          estado: 'locked',
          ultimaActualizacion: now,
          createdAt: now,
          updatedAt: now,
        ));
      }
    }
  }

  // =========================================================================
  // ESTADÍSTICAS
  // =========================================================================

  /// Obtiene un resumen de gamificación para un usuario
  Future<Map<String, dynamic>> getUserGamificationSummary(int usuarioId) async {
    final profile = await getProfile(usuarioId);
    final totalAchievements = await countAchievements();
    final unlockedAchievements = await countUnlockedAchievements(usuarioId);
    final totalPointsEarned = await getTotalPointsEarned(usuarioId);

    return {
      'puntos': profile?.puntos ?? 0,
      'nivel': profile?.nivel ?? 1,
      'racha_actual': profile?.rachaActual ?? 0,
      'racha_maxima': profile?.rachaMaxima ?? 0,
      'logros_desbloqueados': unlockedAchievements,
      'logros_totales': totalAchievements,
      'puntos_historicos': totalPointsEarned,
      'porcentaje_completado': totalAchievements > 0
          ? (unlockedAchievements / totalAchievements * 100).round()
          : 0,
    };
  }
}