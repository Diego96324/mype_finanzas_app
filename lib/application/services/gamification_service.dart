import 'package:flutter/foundation.dart';
import 'package:mype_finanzas/core/constants/gamification_constants.dart';
import 'package:mype_finanzas/data/models/gamification_achievement_model.dart';
import 'package:mype_finanzas/data/models/gamification_event_model.dart';
import 'package:mype_finanzas/data/models/gamification_profile_model.dart';
import 'package:mype_finanzas/data/models/user_achievement_model.dart';
import 'package:mype_finanzas/data/repositories/gamification_repository.dart';

class GamificationService {
  final GamificationRepository _repo;

  GamificationService(this._repo);

  // --- LÓGICA PURA (Helpers) ---

  int _pointsForType(String tipo) {
    return GamificationConstants.pointsPerTransactionType[tipo] ??
        GamificationConstants.defaultPoints;
  }

  int computeLevel(int puntos) {
    if (GamificationConstants.pointsPerLevel == 0) return 1; // Evitar división por cero
    return 1 + (puntos ~/ GamificationConstants.pointsPerLevel);
  }

  Map<String, int> updateStreak(
      int currentStreak,
      int currentMaxStreak,
      DateTime? ultimaFechaEvento,
      DateTime fechaEvento,
      ) {
    if (ultimaFechaEvento == null) {
      return {'racha': 1, 'max': currentMaxStreak > 0 ? currentMaxStreak : 1};
    }

    // Normalizamos las fechas para ignorar horas/minutos/segundos
    final last = DateTime(ultimaFechaEvento.year, ultimaFechaEvento.month, ultimaFechaEvento.day);
    final current = DateTime(fechaEvento.year, fechaEvento.month, fechaEvento.day);

    final diff = current.difference(last).inDays;

    if (diff == 0) {
      // Mismo día, no cambia nada
      return {'racha': currentStreak, 'max': currentMaxStreak};
    } else if (diff == 1) {
      // Día consecutivo, aumenta racha
      final newRacha = currentStreak + 1;
      final newMax = newRacha > currentMaxStreak ? newRacha : currentMaxStreak;
      return {'racha': newRacha, 'max': newMax};
    } else {
      // Rompió la racha (diff > 1 o diff negativo si fechaEvento es anterior)
      // Reiniciamos a 1, pero mantenemos el récord histórico
      return {'racha': 1, 'max': currentMaxStreak};
    }
  }

  // --- MÉTODOS PRINCIPALES ---

  /// Registra un evento, actualiza el perfil y verifica logros.
  Future<void> recordEvent({
    required int usuarioId,
    required String tipoEvento,
    String? descripcion,
    required DateTime fechaEvento,
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
      fechaEvento: fechaEvento,
      createdAt: now,
    );
    await _repo.insertEvent(event);

    // 3. Obtener o Crear Perfil
    final profile = await _repo.getProfile(usuarioId);

    late GamificationProfile updatedProfile;

    if (profile == null) {
      // Crear nuevo perfil
      updatedProfile = GamificationProfile(
        usuarioId: usuarioId,
        puntos: points,
        nivel: computeLevel(points),
        rachaActual: 1,
        rachaMaxima: 1,
        ultimaFechaEvento: fechaEvento,
        createdAt: now,
        updatedAt: now,
      );
    } else {
      // Actualizar perfil existente
      final updatedPuntos = profile.puntos + points;
      final updatedNivel = computeLevel(updatedPuntos);
      final streakData = updateStreak(
        profile.rachaActual,
        profile.rachaMaxima,
        profile.ultimaFechaEvento,
        fechaEvento,
      );

      updatedProfile = profile.copyWith(
        puntos: updatedPuntos,
        nivel: updatedNivel,
        rachaActual: streakData['racha'],
        rachaMaxima: streakData['max'],
        ultimaFechaEvento: fechaEvento,
        updatedAt: now,
      );
    }

    // Guardar perfil actualizado
    await _repo.upsertProfile(updatedProfile);

    // 4. Evaluar logros (Solo si hubo cambios relevantes)
    try {
      // Pasamos el perfil actualizado para evitar volver a consultarlo dentro
      await evaluateAchievements(usuarioId, currentProfile: updatedProfile);
    } catch (e) {
      debugPrint('⚠️ Error evaluando logros: $e');
    }
  }

  /// Evalúa si el usuario ha desbloqueado nuevos logros.
  /// [currentProfile] es opcional, si no se pasa, se busca en BD.
  Future<void> evaluateAchievements(int usuarioId, {GamificationProfile? currentProfile}) async {
    // 1. Obtener datos necesarios
    final profile = currentProfile ?? await _repo.getProfile(usuarioId);
    if (profile == null) return;

    final List<GamificationAchievement> allAchievements = await _repo.listAchievements();

    // 🔥 OPTIMIZACIÓN: Traer todos los logros del usuario de golpe y crear un Mapa
    // Esto evita llamar a la BD dentro del bucle for.
    // Necesitas agregar este meodo en tu repositorio: getUserAchievementsByUserId(id)
    final userAchievementsList = await _repo.getUserAchievementsByUserId(usuarioId);

    // Convertimos la lista a un Mapa para búsqueda rápida: Map<achievementId, UserAchievement>
    final Map<int, UserAchievement> userAchievementsMap = {
      for (var ua in userAchievementsList)
        ua.achievementId: ua
    };

    for (final achievement in allAchievements) {
      if (achievement.id == null) continue;

      final achId = achievement.id!;
      final userRec = userAchievementsMap[achId]; // Búsqueda en memoria (Rápida ⚡)

      // Si ya está desbloqueado, saltamos (a menos que tengas logros repetibles)
      if (userRec?.estado == GamificationConstants.achievementUnlocked) continue;

      bool shouldUnlock = false;
      double currentProgress = 0;

      // 2. Evaluar reglas según el tipo
      switch (achievement.tipo) {
        case 'points':
          currentProgress = profile.puntos.toDouble();
          shouldUnlock = currentProgress >= achievement.progresoObjetivo;
          break;

        case 'streak':
          currentProgress = profile.rachaActual.toDouble();
          shouldUnlock = currentProgress >= achievement.progresoObjetivo;
          break;

      // Aquí puedes agregar más casos: 'transaction_count', 'budget_compliance', etc.
        default:
          continue;
      }

      // 3. Actualizar estado o Desbloquear
      final now = DateTime.now();

      if (shouldUnlock) {
        // 🎉 LOGRO DESBLOQUEADO
        await _unlockAchievement(usuarioId, achId, achievement.nombre, achievement.progresoObjetivo);
      } else {
        // 🚧 ACTUALIZAR PROGRESO (Solo si aumentó)
        // No actualizamos si el progreso es menor (ej. racha bajó a 1, no queremos borrar el progreso visual del logro)
        // A MENOS que sea un logro de racha y quieras que la barra baje. Usualmente se prefiere 'high watermark'.
        final recordedProgress = userRec?.progresoActual ?? 0.0;

        // Solo actualizamos DB si el progreso actual es mayor al registrado O si no existe registro
        if (currentProgress > recordedProgress) {
          final ua = UserAchievement(
            id: userRec?.id, // Mantener ID si existe para update, null para insert
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

  /// Helper privado para desbloquear un logro y registrar el evento
  Future<void> _unlockAchievement(int usuarioId, int achievementId, String achievementName, double targetProgress) async {
    final now = DateTime.now();

    // 1. Guardar registro del logro desbloqueado
    final ua = UserAchievement(
      usuarioId: usuarioId,
      achievementId: achievementId,
      progresoActual: targetProgress,
      estado: GamificationConstants.achievementUnlocked,
      ultimaActualizacion: now,
      createdAt: now, // Nota: Si ya existía 'in_progress', deberíamos preservar el createdAt original, pero simplificamos aquí
      updatedAt: now,
    );

    // Nota: upsertUserAchievement debe manejar la lógica de "si existe update, si no insert" basado en (usuarioId, achievementId)
    await _repo.upsertUserAchievement(ua);

    // 2. Registrar evento especial para mostrar notificación en UI
    await _repo.insertEvent(GamificationEvent(
      usuarioId: usuarioId,
      tipoEvento: 'achievement_unlocked',
      descripcion: '¡Logro desbloqueado: $achievementName!',
      puntosOtorgados: 0, // Opcional: dar puntos extra por desbloquear logros
      fechaEvento: now,
      createdAt: now,
    ));

    debugPrint('🏆 Logro desbloqueado: $achievementName');
  }

  Future<Map<String, dynamic>> getDashboard(int usuarioId) async {
    final profile = await _repo.getProfile(usuarioId);
    final events = await _repo.listEvents(usuarioId: usuarioId, limit: 20);

    // Aquí también podríamos optimizar trayendo solo los logros desbloqueados o próximos a desbloquear
    // para no enviar toda la lista si son muchos.
    final achievements = await _repo.listAchievements();
    final userAchievements = await _repo.getUserAchievementsByUserId(usuarioId);

    return {
      'profile': profile,
      'events': events,
      'achievements': achievements, // Catálogo completo
      'user_progress': userAchievements, // Estado actual del usuario
    };
  }
}