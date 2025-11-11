import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mype_finanzas/presentation/features/gamification/views/gamification_screen.dart';
import 'package:mype_finanzas/presentation/providers/gamification/gamification_providers.dart';
import 'package:mype_finanzas/data/models/gamification_profile_model.dart';
import 'package:mype_finanzas/data/models/gamification_achievement_model.dart';
import 'package:mype_finanzas/data/models/gamification_event_model.dart';
import 'package:mype_finanzas/domain/services/auth_service.dart';
import 'package:mype_finanzas/core/providers/providers.dart' show currentUserIdProvider;

class FakeRepoOverride {
  static final profile = GamificationProfile(usuarioId: 1, puntos: 123, nivel: 1, rachaActual: 2, rachaMaxima: 5, ultimaFechaEvento: DateTime.now(), createdAt: DateTime.now(), updatedAt: DateTime.now());
  static final achievements = [
    GamificationAchievement(id: 1, tipo: 'points', nombre: 'Prueba', descripcion: 'desc', progresoActual: 0, progresoObjetivo: 10, estado: 'locked', ultimaActualizacion: null, createdAt: DateTime.now(), updatedAt: DateTime.now()),
    GamificationAchievement(id: 2, tipo: 'streak', nombre: 'Racha', descripcion: 'desc', progresoActual: 0, progresoObjetivo: 3, estado: 'unlocked', ultimaActualizacion: null, createdAt: DateTime.now(), updatedAt: DateTime.now()),
  ];
  static final events = [
    GamificationEvent(id: 1, usuarioId: 1, tipoEvento: 'transaction_created', descripcion: 'creada', puntosOtorgados: 5, fechaEvento: DateTime.now(), createdAt: DateTime.now()),
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GamificationScreen widget', () {
    setUp(() {
      // Ensure AuthService has a container with currentUserId=1
      final container = ProviderContainer(overrides: []);
      AuthService.setContainer(container);
    });

    testWidgets('renders header, achievements and events', (WidgetTester tester) async {
      final overrides = <Override>[];
      // Override dashboard provider to return desired data
      overrides.add(gamificationDashboardProvider.overrideWithProvider(
        FutureProvider.family<Map<String, dynamic>, int>((ref, userId) async {
          return {
            'profile': FakeRepoOverride.profile,
            'achievements': FakeRepoOverride.achievements,
          };
        }),
      ));

      overrides.add(gamificationEventsProvider.overrideWithProvider(
        FutureProvider.autoDispose.family<List<GamificationEvent>, int>((ref, userId) async {
          return FakeRepoOverride.events;
        }),
      ));

      // Make currentUserId available to AuthService via container
      overrides.add(currentUserIdProvider.overrideWithValue(1));

      final container = ProviderContainer(overrides: overrides);
      // set container for AuthService to return currentUserId=1
      AuthService.setContainer(container);

      await tester.pumpWidget(ProviderScope(overrides: overrides, child: MaterialApp(home: const GamificationScreen())));
      await tester.pumpAndSettle();

      expect(find.text('Puntos'), findsWidgets);
      expect(find.text('Nivel'), findsWidgets);
      expect(find.text('Racha'), findsWidgets);
      // achievements
      expect(find.text('Prueba'), findsOneWidget);
      expect(find.text('Racha'), findsWidgets);
      // events
      expect(find.text('creada'), findsOneWidget);
    });

    testWidgets('shows empty state when no achievements/events', (WidgetTester tester) async {
      final overrides = <Override>[];
      overrides.add(gamificationDashboardProvider.overrideWithProvider(
        FutureProvider.family<Map<String, dynamic>, int>((ref, userId) async {
          return {
            'profile': FakeRepoOverride.profile,
            'achievements': <GamificationAchievement>[],
          };
        }),
      ));

      overrides.add(gamificationEventsProvider.overrideWithProvider(
        FutureProvider.autoDispose.family<List<GamificationEvent>, int>((ref, userId) async {
          return <GamificationEvent>[];
        }),
      ));

      overrides.add(currentUserIdProvider.overrideWithValue(1));
      final container = ProviderContainer(overrides: overrides);
      AuthService.setContainer(container);

      await tester.pumpWidget(ProviderScope(overrides: overrides, child: MaterialApp(home: const GamificationScreen())));
      await tester.pumpAndSettle();

      expect(find.text('Aún no tienes logros'), findsOneWidget);
      expect(find.text('No hay eventos recientes.'), findsOneWidget);
    });

    testWidgets('loading state resolves to data', (WidgetTester tester) async {
      final overrides = <Override>[];
      // Dashboard loading: simulate by using a provider that delays
      overrides.add(gamificationDashboardProvider.overrideWithProvider(
        FutureProvider.family<Map<String, dynamic>, int>((ref, userId) async {
          await Future.delayed(const Duration(milliseconds: 100));
          return {
            'profile': FakeRepoOverride.profile,
            'achievements': FakeRepoOverride.achievements,
          };
        }),
      ));

      overrides.add(gamificationEventsProvider.overrideWithProvider(
        FutureProvider.autoDispose.family<List<GamificationEvent>, int>((ref, userId) async {
          await Future.delayed(const Duration(milliseconds: 100));
          return FakeRepoOverride.events;
        }),
      ));

      overrides.add(currentUserIdProvider.overrideWithValue(1));
      final container = ProviderContainer(overrides: overrides);
      AuthService.setContainer(container);

      await tester.pumpWidget(ProviderScope(overrides: overrides, child: MaterialApp(home: const GamificationScreen())));
      // initial pump shows loading
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Cargando gamificación...'), findsOneWidget);

      // Now let providers resolve
      await tester.pumpAndSettle();
      expect(find.text('Puntos'), findsWidgets);
    });

    testWidgets('error state shows retry UI', (WidgetTester tester) async {
      final errorOverrides = <Override>[];
      errorOverrides.add(gamificationDashboardProvider.overrideWithProvider(
        FutureProvider.family<Map<String, dynamic>, int>((ref, userId) async {
          throw Exception('boom');
        }),
      ));
      errorOverrides.add(gamificationEventsProvider.overrideWithProvider(
        FutureProvider.autoDispose.family<List<GamificationEvent>, int>((ref, userId) async {
          throw Exception('err');
        }),
      ));
      errorOverrides.add(currentUserIdProvider.overrideWithValue(1));
      final errorContainer = ProviderContainer(overrides: errorOverrides);
      AuthService.setContainer(errorContainer);

      await tester.pumpWidget(ProviderScope(overrides: errorOverrides, child: MaterialApp(home: const GamificationScreen())));
      await tester.pumpAndSettle();
      // Should show an error message and a retry button
      expect(find.textContaining('Error cargando gamificación'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Reintentar'), findsOneWidget);
    });
  });
}
