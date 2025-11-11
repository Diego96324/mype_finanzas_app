import 'package:flutter_test/flutter_test.dart';
import 'package:mype_finanzas/data/models/gamification_profile_model.dart';
import 'package:mype_finanzas/data/models/gamification_achievement_model.dart';
import 'package:mype_finanzas/data/models/gamification_event_model.dart';

void main() {
  group('Gamification model serialization', () {
    test('GamificationProfile toJson/fromJson', () {
      final now = DateTime.now();
      final p = GamificationProfile(usuarioId: 1, puntos: 10, nivel: 2, rachaActual: 3, rachaMaxima: 5, ultimaFechaEvento: now, createdAt: now, updatedAt: now);
      final json = p.toJson();
      final p2 = GamificationProfile.fromJson(json);
      expect(p2.usuarioId, equals(p.usuarioId));
      expect(p2.puntos, equals(p.puntos));
      expect(p2.nivel, equals(p.nivel));
    });

    test('GamificationAchievement toJson/fromJson', () {
      final now = DateTime.now();
      final a = GamificationAchievement(id: 1, tipo: 'milestone', nombre: 'Prueba', descripcion: 'desc', progresoActual: 0.5, progresoObjetivo: 1.0, estado: 'in_progress', ultimaActualizacion: now, createdAt: now, updatedAt: now);
      final json = a.toJson();
      final a2 = GamificationAchievement.fromJson(json);
      expect(a2.nombre, equals(a.nombre));
      expect(a2.tipo, equals(a.tipo));
      expect(a2.progresoActual, equals(a.progresoActual));
    });

    test('GamificationEvent toJson/fromJson', () {
      final now = DateTime.now();
      final e = GamificationEvent(id: 1, usuarioId: 1, tipoEvento: 'txn_created', descripcion: 'evento', puntosOtorgados: 10, fechaEvento: now, createdAt: now);
      final json = e.toJson();
      final e2 = GamificationEvent.fromJson(json);
      expect(e2.tipoEvento, equals(e.tipoEvento));
      expect(e2.puntosOtorgados, equals(e.puntosOtorgados));
    });

    // Placeholders: añadir pruebas CRUD para repositorio en la tarde
  });
}

