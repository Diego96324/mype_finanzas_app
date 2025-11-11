import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mype_finanzas/data/repositories/gamification_repository.dart';
import 'package:mype_finanzas/application/services/gamification_service.dart';

// Provider para el repositorio (se puede reemplazar en tests)
final gamificationRepositoryProvider = Provider<GamificationRepository>((ref) {
  return GamificationRepository();
});

// Provider para el servicio
final gamificationServiceProvider = Provider<GamificationService>((ref) {
  final repo = ref.read(gamificationRepositoryProvider);
  return GamificationService(repo);
});

// Dashboard provider (AsyncValue<Map<String, dynamic>>)
final gamificationDashboardProvider = FutureProvider.family<Map<String, dynamic>, int>((ref, usuarioId) async {
  final service = ref.read(gamificationServiceProvider);
  return service.getDashboard(usuarioId);
});

// Provider para eventos (lista de eventos)
final gamificationEventsProvider = FutureProvider.autoDispose.family<List<dynamic>, int>((ref, usuarioId) async {
  final service = ref.read(gamificationServiceProvider);
  final dashboard = await service.getDashboard(usuarioId);
  return dashboard['events'] as List<dynamic>;
});
