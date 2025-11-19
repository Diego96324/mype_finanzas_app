import 'package:flutter/foundation.dart';
import 'package:mype_finanzas/core/constants/gamification_constants.dart';
import 'package:mype_finanzas/models/dtos/gamification_achievement_model.dart';
import 'package:mype_finanzas/models/dtos/gamification_event_model.dart';
import 'package:mype_finanzas/models/dtos/gamification_profile_model.dart';
import 'package:mype_finanzas/models/dtos/user_achievement_model.dart';
import 'package:mype_finanzas/models/repositories/gamification_repository.dart';

class GamificationService {
  final GamificationRepository _repo;

  GamificationService(this._repo);

  // =========================================================================
  // LÓGICA PURA (Helpers)
  // =========================================================================

  int _pointsForType(String tipo) {
    return GamificationConstants.pointsPerTransactionType[tipo] ??
        GamificationConstants.defaultPoints;
  }

  int computeLevel(int puntos) {
    if (GamificationConstants.pointsPerLevel == 0) return 1;
    return 1 + (puntos ~/ GamificationConstants.pointsPerLevel);
  }

  Map<String, int> updateStreak(
      int currentStreak,
      int currentMaxStreak,
      DateTime? ultimaFecha,
      DateTime fecha,
      ) {
    if (ultimaFecha == null) {
      return {'racha': 1, 'max': currentMaxStreak > 0 ? currentMaxStreak : 1};
    }

    final last = DateTime(ultimaFecha.year, ultimaFecha.month, ultimaFecha.day);
    final current = DateTime(fecha.year, fecha.month, fecha.day);
    final diff = current.difference(last).inDays;

    if (diff == 0) {
      return {'racha': currentStreak, 'max': currentMaxStreak};
    } else if (diff == 1) {
      final newRacha = currentStreak + 1;
      final newMax = newRacha > currentMaxStreak ? newRacha : currentMaxStreak;
      return {'racha': newRacha, 'max': newMax};
    } else {
      return {'racha': 1, 'max': currentMaxStreak};
    }
  }

  // =========================================================================
  // MÉTODOS PRINCIPALES
  // =========================================================================

  /// Registra un evento, actualiza el perfil y verifica logros.
  Future<void> recordEvent({
    required int usuarioId,
    required String tipoEvento,
    String? descripcion,
    required DateTime fecha,
    int puntosOtorgados = 0,
    String? transactionType,
  }) async {
    final now = DateTime.now();

    // 1. Calcular puntos
    final points = puntosOtorgados > 0
        ? puntosOtorgados
        : (transactionType != null ? _pointsForType(transactionType) : 0);

    // 2. Insertar evento en el historial
    final event = GamificationEvent(
      usuarioId: usuarioId,
      tipoEvento: tipoEvento,
      descripcion: descripcion,
      puntosOtorgados: points,
      fecha: fecha,
      createdAt: now,
    );
    await _repo.insertEvent(event);

    // 3. Obtener o Crear Perfil
    final profile = await _repo.getProfile(usuarioId);

    late GamificationProfile updatedProfile;

    if (profile == null) {
      updatedProfile = GamificationProfile(
        usuarioId: usuarioId,
        puntos: points,
        nivel: computeLevel(points),
        rachaActual: 1,
        rachaMaxima: 1,
        ultimaFechaEvento: fecha,
        createdAt: now,
        updatedAt: now,
      );
    } else {
      final updatedPuntos = profile.puntos + points;
      final updatedNivel = computeLevel(updatedPuntos);
      final streakData = updateStreak(
        profile.rachaActual,
        profile.rachaMaxima,
        profile.ultimaFechaEvento,
        fecha,
      );

      updatedProfile = profile.copyWith(
        puntos: updatedPuntos,
        nivel: updatedNivel,
        rachaActual: streakData['racha'],
        rachaMaxima: streakData['max'],
        ultimaFechaEvento: fecha,
        updatedAt: now,
      );
    }

    // Guardar perfil actualizado
    await _repo.upsertProfile(updatedProfile);

    // 4. Evaluar logros
    try {
      await evaluateAchievements(usuarioId, currentProfile: updatedProfile);
    } catch (e) {
      debugPrint('⚠️ Error evaluando logros: $e');
    }
  }

  /// Evalúa si el usuario ha desbloqueado nuevos logros.
  Future<void> evaluateAchievements(int usuarioId, {GamificationProfile? currentProfile}) async {
    // 1. Obtener datos necesarios
    final profile = currentProfile ?? await _repo.getProfile(usuarioId);
    if (profile == null) return;

    final List<GamificationAchievement> allAchievements = await _repo.listAchievements();
    final userAchievementsList = await _repo.getUserAchievementsByUserId(usuarioId);

    // Mapa para búsqueda rápida
    final Map<int, UserAchievement> userAchievementsMap = {
      for (var ua in userAchievementsList) ua.achievementId: ua
    };

    for (final achievement in allAchievements) {
      if (achievement.id == null) continue;

      final achId = achievement.id!;
      final userRec = userAchievementsMap[achId];

      // Si ya está desbloqueado, saltamos
      if (userRec?.estado == GamificationConstants.achievementUnlocked) continue;

      bool shouldUnlock = false;
      double currentProgress = 0;

      // 2. Evaluar reglas según el código del logro
      switch (achievement.code) {
      // -----------------------------------------------------------------
      // FIRST_LOGIN - Primer inicio de sesión
      // -----------------------------------------------------------------
        case 'FIRST_LOGIN':
          final loginCount = await _repo.countEventsByType(usuarioId, 'login');
          currentProgress = loginCount.toDouble();
          shouldUnlock = currentProgress >= achievement.progresoObjetivo;
          break;

      // -----------------------------------------------------------------
      // FIRST_INCOME - Primer ingreso registrado
      // -----------------------------------------------------------------
        case 'FIRST_INCOME':
          final incomeCount = await _repo.countEventsByType(usuarioId, 'ingreso');
          currentProgress = incomeCount.toDouble();
          shouldUnlock = currentProgress >= achievement.progresoObjetivo;
          break;

      // -----------------------------------------------------------------
      // FIRST_EXPENSE - Primer gasto registrado
      // -----------------------------------------------------------------
        case 'FIRST_EXPENSE':
          final expenseCount = await _repo.countEventsByType(usuarioId, 'egreso');
          currentProgress = expenseCount.toDouble();
          shouldUnlock = currentProgress >= achievement.progresoObjetivo;
          break;

      // -----------------------------------------------------------------
      // STREAK_3_DAYS - Racha de 3 días consecutivos
      // -----------------------------------------------------------------
        case 'STREAK_3_DAYS':
          currentProgress = profile.rachaActual.toDouble();
          shouldUnlock = currentProgress >= achievement.progresoObjetivo;
          break;

      // -----------------------------------------------------------------
      // SAVER - Ingresos superan gastos del mes
      // -----------------------------------------------------------------
        case 'SAVER':
          final balance = await _calculateMonthlyBalance(usuarioId);
          // El progreso es 1 si ahorra, 0 si no
          currentProgress = balance > 0 ? 1.0 : 0.0;
          shouldUnlock = currentProgress >= achievement.progresoObjetivo;
          break;

      // -----------------------------------------------------------------
      // Casos genéricos por tipo (para logros futuros)
      // -----------------------------------------------------------------
        default:
        // Fallback a evaluación por tipo
          switch (achievement.tipo) {
            case 'points':
              currentProgress = profile.puntos.toDouble();
              shouldUnlock = currentProgress >= achievement.progresoObjetivo;
              break;

            case 'racha':
              currentProgress = profile.rachaActual.toDouble();
              shouldUnlock = currentProgress >= achievement.progresoObjetivo;
              break;

            case 'nivel':
              currentProgress = profile.nivel.toDouble();
              shouldUnlock = currentProgress >= achievement.progresoObjetivo;
              break;

            default:
              continue; // Tipo no reconocido, saltar
          }
      }

      // 3. Actualizar estado o Desbloquear
      final now = DateTime.now();

      if (shouldUnlock) {
        // 🎉 LOGRO DESBLOQUEADO
        await _unlockAchievement(
          usuarioId,
          achId,
          achievement.nombre,
          achievement.progresoObjetivo,
          achievement.puntos, // 🆕 Puntos del logro
        );
      } else {
        // 🚧 ACTUALIZAR PROGRESO (Solo si aumentó)
        final recordedProgress = userRec?.progresoActual ?? 0.0;

        if (currentProgress > recordedProgress) {
          final ua = UserAchievement(
            id: userRec?.id,
            usuarioId: usuarioId,
            achievementId: achId,
            progresoActual: currentProgress,
            estado: GamificationConstants.achievementInProgress,
            ultimaActualizacion: now,
            createdAt: userRec?.createdAt ?? now,
            updatedAt: now,
          );
          await _repo.upsertUserAchievement(ua);
        }
      }
    }
  }

  /// Calcula el balance del mes actual (ingresos - gastos)
  Future<double> _calculateMonthlyBalance(int usuarioId) async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    // Obtener eventos del mes
    final events = await _repo.listEvents(
      usuarioId: usuarioId,
      desde: startOfMonth,
      hasta: endOfMonth,
    );

    double ingresos = 0;
    double gastos = 0;

    for (final event in events) {
      if (event.tipoEvento == 'ingreso') {
        ingresos += event.puntosOtorgados;
      } else if (event.tipoEvento == 'egreso') {
        gastos += event.puntosOtorgados;
      }
    }

    return ingresos - gastos;
  }

  /// Helper privado para desbloquear un logro y registrar el evento
  Future<void> _unlockAchievement(
      int usuarioId,
      int achievementId,
      String achievementName,
      double targetProgress,
      int achievementPoints, // 🆕 Puntos a otorgar
      ) async {
    final now = DateTime.now();

    // 1. Guardar registro del logro desbloqueado
    final ua = UserAchievement(
      usuarioId: usuarioId,
      achievementId: achievementId,
      progresoActual: targetProgress,
      estado: GamificationConstants.achievementUnlocked,
      ultimaActualizacion: now,
      createdAt: now,
      updatedAt: now,
    );
    await _repo.upsertUserAchievement(ua);

    // 2. Otorgar puntos del logro al perfil
    if (achievementPoints > 0) {
      final profile = await _repo.getProfile(usuarioId);
      if (profile != null) {
        final updatedPuntos = profile.puntos + achievementPoints;
        final updatedProfile = profile.copyWith(
          puntos: updatedPuntos,
          nivel: computeLevel(updatedPuntos),
          updatedAt: now,
        );
        await _repo.upsertProfile(updatedProfile);
      }
    }

    // 3. Registrar evento especial para mostrar notificación en UI
    await _repo.insertEvent(GamificationEvent(
      usuarioId: usuarioId,
      tipoEvento: 'achievement_unlocked',
      descripcion: '¡Logro desbloqueado: $achievementName!',
      puntosOtorgados: achievementPoints,
      fecha: now,
      createdAt: now,
    ));

    debugPrint('🏆 Logro desbloqueado: $achievementName (+$achievementPoints pts)');
  }

  // =========================================================================
  // MÉTODOS PÚBLICOS ADICIONALES
  // =========================================================================

  /// Registra un login y evalúa el logro FIRST_LOGIN
  Future<void> recordLogin(int usuarioId) async {
    await recordEvent(
      usuarioId: usuarioId,
      tipoEvento: 'login',
      descripcion: 'Inicio de sesión',
      fecha: DateTime.now(),
      puntosOtorgados: GamificationConstants.defaultPoints,
    );
  }

  /// Registra una transacción de ingreso
  Future<void> recordIncome(int usuarioId, double monto, {String? descripcion}) async {
    await recordEvent(
      usuarioId: usuarioId,
      tipoEvento: 'ingreso',
      descripcion: descripcion ?? 'Ingreso registrado',
      fecha: DateTime.now(),
      puntosOtorgados: _pointsForType('ingreso'),
      transactionType: 'ingreso',
    );
  }

  /// Registra una transacción de gasto
  Future<void> recordExpense(int usuarioId, double monto, {String? descripcion}) async {
    await recordEvent(
      usuarioId: usuarioId,
      tipoEvento: 'egreso',
      descripcion: descripcion ?? 'Gasto registrado',
      fecha: DateTime.now(),
      puntosOtorgados: _pointsForType('egreso'),
      transactionType: 'egreso',
    );
  }

  /// Registra una transferencia entre cuentas
  Future<void> recordTransfer(int usuarioId, double monto, {String? descripcion}) async {
    await recordEvent(
      usuarioId: usuarioId,
      tipoEvento: 'transferencia',
      descripcion: descripcion ?? 'Transferencia realizada',
      fecha: DateTime.now(),
      puntosOtorgados: _pointsForType('transferencia'),
      transactionType: 'transferencia',
    );
  }

  /// Obtiene el dashboard de gamificación para un usuario
  Future<Map<String, dynamic>> getDashboard(int usuarioId) async {
    final profile = await _repo.getProfile(usuarioId);
    final events = await _repo.listEvents(usuarioId: usuarioId, limit: 20);
    final achievements = await _repo.listAchievements();
    final userAchievements = await _repo.getUserAchievementsByUserId(usuarioId);
    final summary = await _repo.getUserGamificationSummary(usuarioId);

    // Combinar logros con progreso del usuario para la UI
    final achievementsWithProgress = <Map<String, dynamic>>[];

    final userAchMap = {
      for (var ua in userAchievements) ua.achievementId: ua
    };

    for (final ach in achievements) {
      if (ach.id == null) continue;
      final userProgress = userAchMap[ach.id!];

      achievementsWithProgress.add({
        'achievement': ach,
        'progress': userProgress?.progresoActual ?? 0.0,
        'estado': userProgress?.estado ?? 'locked',
        'porcentaje': userProgress != null && ach.progresoObjetivo > 0
            ? (userProgress.progresoActual / ach.progresoObjetivo * 100).clamp(0, 100)
            : 0.0,
      });
    }

    return {
      'profile': profile,
      'events': events,
      'achievements': achievements, // ← Lista original para compatibilidad
      'user_progress': userAchievements, // ← Progreso del usuario
      'achievements_with_progress': achievementsWithProgress, // ← Combinado para UI mejorada
      'summary': summary,
    };
  }

  /// Obtiene logros desbloqueados recientemente (para notificaciones)
  Future<List<Map<String, dynamic>>> getRecentUnlocks(int usuarioId, {int limit = 5}) async {
    final recentUa = await _repo.getRecentlyUnlocked(usuarioId, limit: limit);
    final results = <Map<String, dynamic>>[];

    for (final ua in recentUa) {
      final achievement = await _repo.getAchievementById(ua.achievementId);
      if (achievement != null) {
        results.add({
          'achievement': achievement,
          'unlocked_at': ua.ultimaActualizacion,
        });
      }
    }

    return results;
  }

  /// Inicializa el sistema de gamificación para un nuevo usuario
  Future<void> initializeForUser(int usuarioId) async {
    // 1. Crear perfil inicial
    await _repo.getOrCreateProfile(usuarioId);

    // 2. Inicializar progreso en todos los logros
    await _repo.initializeUserAchievements(usuarioId);

    debugPrint('🎮 Gamificación inicializada para usuario $usuarioId');
  }
}