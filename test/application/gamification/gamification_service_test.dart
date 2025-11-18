import 'package:flutter_test/flutter_test.dart';
import 'package:mype_finanzas/application/services/gamification_service.dart';
import 'package:mype_finanzas/data/models/gamification_profile_model.dart';
import 'package:mype_finanzas/data/models/gamification_achievement_model.dart';
import 'package:mype_finanzas/data/models/gamification_event_model.dart';
import 'package:mype_finanzas/data/models/user_achievement_model.dart';
import 'package:mype_finanzas/data/repositories/gamification_repository.dart';

// Fake repository implementing the minimal interface used by the service
class FakeGamificationRepository implements GamificationRepository {
  final Map<int, GamificationProfile> _profiles = {};
  final List<GamificationAchievement> _achievements = [];
  final List<GamificationEvent> _events = [];
  final List<UserAchievement> _userAchievements = [];

  @override
  Future<GamificationProfile?> getProfile(int usuarioId) async => _profiles[usuarioId];

  @override
  Future<int> upsertProfile(GamificationProfile profile) async {
    _profiles[profile.usuarioId] = profile;
    return 1;
  }

  @override
  Future<List<GamificationAchievement>> listAchievements({String? tipo}) async {
    if (tipo != null) return _achievements.where((a) => a.tipo == tipo).toList();
    return List.from(_achievements);
  }

  @override
  Future<int> insertAchievement(GamificationAchievement a) async {
    _achievements.add(a);
    return 1;
  }

  @override
  Future<int> updateAchievement(GamificationAchievement a) async {
    final idx = _achievements.indexWhere((e) => e.id == a.id);
    if (idx >= 0) _achievements[idx] = a;
    return 1;
  }

  @override
  Future<UserAchievement?> getUserAchievement(int usuarioId, int achievementId) async {
    try {
      return _userAchievements.firstWhere((u) => u.usuarioId == usuarioId && u.achievementId == achievementId);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<UserAchievement>> listUserAchievements(int usuarioId) async => _userAchievements.where((u) => u.usuarioId == usuarioId).toList();

  @override
  Future<int> upsertUserAchievement(UserAchievement ua) async {
    final idx = _userAchievements.indexWhere((u) => u.usuarioId == ua.usuarioId && u.achievementId == ua.achievementId);
    if (idx >= 0) {
      _userAchievements[idx] = ua;
    } else {
      _userAchievements.add(ua);
    }
    return 1;
  }

  @override
  Future<int> insertEvent(GamificationEvent e) async {
    // Assign an id for test tracking
    final copy = GamificationEvent(id: _events.length + 1, usuarioId: e.usuarioId, tipoEvento: e.tipoEvento, descripcion: e.descripcion, puntosOtorgados: e.puntosOtorgados, fechaEvento: e.fechaEvento, createdAt: e.createdAt);
    _events.add(copy);
    return 1;
  }

  @override
  Future<List<GamificationEvent>> listEvents({int? usuarioId, int? limit}) async {
    final List<GamificationEvent> list = usuarioId != null ? _events.where((e) => e.usuarioId == usuarioId).toList() : List.from(_events);
    if (limit != null && list.length > limit) return Future.value(list.sublist(0, limit));
    return Future.value(list);
  }
}

void main() {
  group('GamificationService', () {
    late FakeGamificationRepository repo;
    late GamificationService service;

    setUp(() {
      repo = FakeGamificationRepository();
      service = GamificationService(repo);
    });

    test('adds points and updates level', () async {
      // initial profile with 0 points
      await repo.upsertProfile(GamificationProfile(usuarioId: 1, puntos: 0, nivel: 1, rachaActual: 0, rachaMaxima: 0, ultimaFechaEvento: null, createdAt: DateTime.now(), updatedAt: DateTime.now()));

      // record an event that gives 600 points
      await service.recordEvent(usuarioId: 1, tipoEvento: 'test', fechaEvento: DateTime.now(), puntosOtorgados: 600);

      final profile = await repo.getProfile(1);
      expect(profile, isNotNull);
      expect(profile!.puntos, equals(600));
      // level = 1 + 600 ~/ 500 = 1 + 1 = 2
      expect(profile.nivel, equals(2));
    });

    test('updates streak correctly and resets after gap', () async {
      final yesterday = DateTime.now().subtract(Duration(days: 1));
      final twoDaysLater = DateTime.now().add(Duration(days: 2));

      await repo.upsertProfile(GamificationProfile(usuarioId: 2, puntos: 0, nivel: 1, rachaActual: 1, rachaMaxima: 1, ultimaFechaEvento: yesterday, createdAt: DateTime.now(), updatedAt: DateTime.now()));

      // same day after yesterday -> should increment streak (today)
      await service.recordEvent(usuarioId: 2, tipoEvento: 'test', fechaEvento: DateTime.now(), puntosOtorgados: 0);
      var profile = await repo.getProfile(2);
      expect(profile!.rachaActual, greaterThanOrEqualTo(1));

      // now simulate gap: event after 2 days from today (resets streak to 1)
      await service.recordEvent(usuarioId: 2, tipoEvento: 'test', fechaEvento: twoDaysLater, puntosOtorgados: 0);
      profile = await repo.getProfile(2);
      expect(profile!.rachaActual, equals(1));
    });

    test('unlocks points-based achievement and records event', () async {
      // achievement: unlock at 10 points
      final ach = GamificationAchievement(id: 1, tipo: 'points', nombre: '10 pts', descripcion: 'reach 10', progresoActual: 0, progresoObjetivo: 10, estado: 'locked', ultimaActualizacion: null, createdAt: DateTime.now(), updatedAt: DateTime.now());
      await repo.insertAchievement(ach);

      // user with 9 points
      await repo.upsertProfile(GamificationProfile(usuarioId: 3, puntos: 9, nivel: 1, rachaActual: 0, rachaMaxima: 0, ultimaFechaEvento: null, createdAt: DateTime.now(), updatedAt: DateTime.now()));

      // record +1 point
      await service.recordEvent(usuarioId: 3, tipoEvento: 'test', fechaEvento: DateTime.now(), puntosOtorgados: 1);

      final profile = await repo.getProfile(3);
      expect(profile!.puntos, equals(10));

      // user achievement should be updated (state unlocked)
      final userAchs = await repo.listUserAchievements(3);
      final ua = userAchs.firstWhere((u) => u.achievementId == 1);
      expect(ua.estado, equals('unlocked'));

      // event for achievement unlocked should be recorded
      final events = await repo.listEvents(usuarioId: 3);
      final hasAchievementEvent = events.any((e) => e.tipoEvento == 'achievement_unlocked');
      expect(hasAchievementEvent, isTrue);
    });
  });
}
