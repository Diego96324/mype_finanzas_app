import 'package:flutter/foundation.dart';

import 'package:mype_finanzas/data/repositories/gamification_repository.dart';
import 'package:mype_finanzas/data/models/gamification_profile_model.dart';
import 'package:mype_finanzas/data/models/gamification_achievement_model.dart';
import 'package:mype_finanzas/data/models/gamification_event_model.dart';
import 'package:mype_finanzas/data/models/user_achievement_model.dart';
import 'package:mype_finanzas/core/constants/gamification_constants.dart';

class GamificationService {
  final GamificationRepository _repo;

  GamificationService(this._repo);

  // Reglas: puntos por tipo de transacción
  int _pointsForType(String tipo) {
    return GamificationConstants.pointsPerTransactionType[tipo] ?? GamificationConstants.defaultPoints;
  }

  // Calcular nivel: nivel = 1 + puntos ~/ pointsPerLevel
  int computeLevel(int puntos) {
    return 1 + (puntos ~/ GamificationConstants.pointsPerLevel);
  }

  // Actualizar racha en base a ultima_fecha_evento: si la fecha del nuevo evento es el día siguiente, incrementar racha; si es el mismo día, no cambiar; si hay gap mayor, reset racha a 1
  Map<String, int> updateStreak(int currentStreak, int currentMaxStreak, DateTime? ultimaFechaEvento, DateTime fechaEvento) {
    // Devuelve mapa con keys: 'racha' (racha actual) y 'max' (racha máxima)
    if (ultimaFechaEvento == null) {
      // primer evento: racha actual empieza en 1, conservar max previo
      return {'racha': 1, 'max': currentMaxStreak};
    }
    final last = DateTime(ultimaFechaEvento.year, ultimaFechaEvento.month, ultimaFechaEvento.day);
    final current = DateTime(fechaEvento.year, fechaEvento.month, fechaEvento.day);
    final diff = current.difference(last).inDays;
    if (diff == 0) return {'racha': currentStreak, 'max': currentMaxStreak}; // mismo día: no cambia
    if (diff == 1) {
      final newRacha = currentStreak + 1; // día siguiente -> incrementar
      final newMax = newRacha > currentMaxStreak ? newRacha : currentMaxStreak;
      return {'racha': newRacha, 'max': newMax};
    }
    // rompió racha: reiniciar racha actual a 1, conservar el récord máximo
    return {'racha': 1, 'max': currentMaxStreak};
  }

  // Registrar evento: guarda gamification_event, actualiza profile con puntos/nivel/racha y evalúa logros
  Future<void> recordEvent({required int usuarioId, required String tipoEvento, String? descripcion, required DateTime fechaEvento, int puntosOtorgados = 0, String? transactionType}) async {
    final now = DateTime.now();
    final points = puntosOtorgados > 0 ? puntosOtorgados : (transactionType != null ? _pointsForType(transactionType) : 0);

    final event = GamificationEvent(
      usuarioId: usuarioId,
      tipoEvento: tipoEvento,
      descripcion: descripcion,
      puntosOtorgados: points,
      fechaEvento: fechaEvento,
      createdAt: now,
    );

    await _repo.insertEvent(event);

    // Update profile
    final profile = await _repo.getProfile(usuarioId);
    final pointsToAdd = points; // caller decides points (or inferred)
    if (profile == null) {
      final newProfile = GamificationProfile(usuarioId: usuarioId, puntos: pointsToAdd, nivel: computeLevel(pointsToAdd), rachaActual: 1, rachaMaxima: 1, ultimaFechaEvento: fechaEvento, createdAt: now, updatedAt: now);
      await _repo.upsertProfile(newProfile);
    } else {
      final updatedPuntos = profile.puntos + pointsToAdd;
      final updatedNivel = computeLevel(updatedPuntos);
      final updatedRachaData = updateStreak(profile.rachaActual, profile.rachaMaxima, profile.ultimaFechaEvento, fechaEvento);
      final updatedProfile = profile.copyWith(puntos: updatedPuntos, nivel: updatedNivel, rachaActual: updatedRachaData['racha'], rachaMaxima: updatedRachaData['max'], ultimaFechaEvento: fechaEvento, updatedAt: now);
      await _repo.upsertProfile(updatedProfile);
    }

    // Re-evaluar achievements (simple)
    try {
      await evaluateAchievements(usuarioId);
    } catch (e) {
      debugPrint('Error evaluando achievements: $e');
    }
  }

  // Evaluar logros: ejemplo simple (puede expandirse con reglas más complejas)
  Future<void> evaluateAchievements(int usuarioId) async {
    final profile = await _repo.getProfile(usuarioId);
    if (profile == null) return;

    final List<GamificationAchievement> achievements = await _repo.listAchievements();
    for (final a in achievements) {
      if (a.id == null) continue; // skip malformed catalog entries
      final achId = a.id!;
      final userRec = await _repo.getUserAchievement(usuarioId, achId);

      // Helper to upsert unlocked user achievement and emit event
      Future<void> unlockAchievement() async {
        final now = DateTime.now();
        final ua = UserAchievement(
          usuarioId: usuarioId,
          achievementId: achId,
          progresoActual: a.progresoObjetivo,
          estado: GamificationConstants.achievementUnlocked,
          ultimaActualizacion: now,
          createdAt: userRec?.createdAt ?? now,
          updatedAt: now,
        );
        await _repo.upsertUserAchievement(ua);
        await _repo.insertEvent(GamificationEvent(usuarioId: usuarioId, tipoEvento: 'achievement_unlocked', descripcion: a.nombre, puntosOtorgados: 0, fechaEvento: DateTime.now(), createdAt: DateTime.now()));
      }

      if (a.tipo == 'points') {
        final achieved = profile.puntos >= a.progresoObjetivo;
        if (achieved) {
          if (userRec == null || userRec.estado != GamificationConstants.achievementUnlocked) {
            await unlockAchievement();
          }
        } else {
          // track in-progress progress
          final newProg = (profile.puntos.toDouble() > a.progresoObjetivo) ? a.progresoObjetivo : profile.puntos.toDouble();
          if (userRec == null) {
            final now = DateTime.now();
            final ua = UserAchievement(usuarioId: usuarioId, achievementId: achId, progresoActual: newProg, estado: GamificationConstants.achievementInProgress, ultimaActualizacion: now, createdAt: now, updatedAt: now);
            await _repo.upsertUserAchievement(ua);
          } else if (newProg > userRec.progresoActual) {
            final updated = userRec.copyWith(progresoActual: newProg, estado: GamificationConstants.achievementInProgress, ultimaActualizacion: DateTime.now(), updatedAt: DateTime.now());
            await _repo.upsertUserAchievement(updated);
          }
        }
      }

      if (a.tipo == 'streak') {
        final achieved = profile.rachaActual >= a.progresoObjetivo;
        if (achieved) {
          if (userRec == null || userRec.estado != GamificationConstants.achievementUnlocked) {
            await unlockAchievement();
          }
        } else {
          final newProg = (profile.rachaActual.toDouble() > a.progresoObjetivo) ? a.progresoObjetivo : profile.rachaActual.toDouble();
          if (userRec == null) {
            final now = DateTime.now();
            final ua = UserAchievement(usuarioId: usuarioId, achievementId: achId, progresoActual: newProg, estado: GamificationConstants.achievementInProgress, ultimaActualizacion: now, createdAt: now, updatedAt: now);
            await _repo.upsertUserAchievement(ua);
          } else if (newProg > userRec.progresoActual) {
            final updated = userRec.copyWith(progresoActual: newProg, estado: GamificationConstants.achievementInProgress, ultimaActualizacion: DateTime.now(), updatedAt: DateTime.now());
            await _repo.upsertUserAchievement(updated);
          }
        }
      }
    }
  }

  // Obtener dashboard con resumen: profile + últimos eventos + achievements
  Future<Map<String, dynamic>> getDashboard(int usuarioId) async {
    final profile = await _repo.getProfile(usuarioId);
    final events = await _repo.listEvents(usuarioId: usuarioId, limit: 20);
    final achievements = await _repo.listAchievements();
    return {
      'profile': profile,
      'events': events,
      'achievements': achievements,
    };
  }
}
