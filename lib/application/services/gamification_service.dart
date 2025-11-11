import 'package:flutter/foundation.dart';

import 'package:mype_finanzas/data/repositories/gamification_repository.dart';
import 'package:mype_finanzas/data/models/gamification_profile_model.dart';
import 'package:mype_finanzas/data/models/gamification_achievement_model.dart';
import 'package:mype_finanzas/data/models/gamification_event_model.dart';
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
  int updateStreak(int currentStreak, DateTime? ultimaFechaEvento, DateTime fechaEvento) {
    if (ultimaFechaEvento == null) return 1;
    final last = DateTime(ultimaFechaEvento.year, ultimaFechaEvento.month, ultimaFechaEvento.day);
    final current = DateTime(fechaEvento.year, fechaEvento.month, fechaEvento.day);
    final diff = current.difference(last).inDays;
    if (diff == 0) return currentStreak; // mismo día
    if (diff == 1) return currentStreak + 1; // día siguiente
    return 1; // rompió racha
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
      final updatedRacha = updateStreak(profile.rachaActual, profile.ultimaFechaEvento, fechaEvento);
      final updatedRachaMaxima = updatedRacha > profile.rachaMaxima ? updatedRacha : profile.rachaMaxima;
      final updatedProfile = profile.copyWith(puntos: updatedPuntos, nivel: updatedNivel, rachaActual: updatedRacha, rachaMaxima: updatedRachaMaxima, ultimaFechaEvento: fechaEvento, updatedAt: now);
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
      // Ejemplos de reglas básicas:
      if (a.tipo == 'points' && a.progresoObjetivo <= profile.puntos) {
        if (a.estado != GamificationConstants.achievementUnlocked) {
          final updated = a.copyWith(progresoActual: a.progresoObjetivo, estado: GamificationConstants.achievementUnlocked, ultimaActualizacion: DateTime.now(), updatedAt: DateTime.now());
          await _repo.updateAchievement(updated);
          await _repo.insertEvent(GamificationEvent(usuarioId: usuarioId, tipoEvento: 'achievement_unlocked', descripcion: a.nombre, puntosOtorgados: 0, fechaEvento: DateTime.now(), createdAt: DateTime.now()));
        }
      }

      if (a.tipo == 'streak' && a.progresoObjetivo <= profile.rachaActual) {
        if (a.estado != GamificationConstants.achievementUnlocked) {
          final updated = a.copyWith(progresoActual: a.progresoObjetivo, estado: GamificationConstants.achievementUnlocked, ultimaActualizacion: DateTime.now(), updatedAt: DateTime.now());
          await _repo.updateAchievement(updated);
          await _repo.insertEvent(GamificationEvent(usuarioId: usuarioId, tipoEvento: 'achievement_unlocked', descripcion: a.nombre, puntosOtorgados: 0, fechaEvento: DateTime.now(), createdAt: DateTime.now()));
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
