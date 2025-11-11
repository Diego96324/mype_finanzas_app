import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:mype_finanzas/presentation/providers/gamification/gamification_providers.dart';
import 'package:mype_finanzas/domain/services/auth_service.dart';
import 'package:mype_finanzas/data/models/gamification_profile_model.dart';
import 'package:mype_finanzas/data/models/gamification_achievement_model.dart';
import 'package:mype_finanzas/data/models/gamification_event_model.dart';

class GamificationScreen extends ConsumerWidget {
  const GamificationScreen({super.key});

  String _formatDate(DateTime d) => DateFormat.yMMMd().add_Hm().format(d);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = AuthService().currentUserId;
    if (userId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Gamificación')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('Inicia sesión para ver tu progreso de gamificación.', style: Theme.of(context).textTheme.bodyLarge),
          ),
        ),
      );
    }

    final dashboardAsync = ref.watch(gamificationDashboardProvider(userId));
    final eventsAsync = ref.watch(gamificationEventsProvider(userId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gamificación'),
        // Mostrar botón de back si hay una ruta previa en la pila
        leading: Navigator.of(context).canPop() ? const BackButton() : null,
      ),
      body: dashboardAsync.when(
        data: (dashboard) {
          final profile = dashboard['profile'] as GamificationProfile?;
          final achievements = dashboard['achievements'] as List<GamificationAchievement>? ?? [];

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(gamificationDashboardProvider(userId));
              ref.invalidate(gamificationEventsProvider(userId));
              // esperar a que el dashboard se recargue
              await ref.read(gamificationDashboardProvider(userId).future);
            },
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _buildHeader(context, profile),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Text('Logros', style: Theme.of(context).textTheme.titleMedium),
                  ),
                ),
                // Si no hay logros, mostrar mensaje vacío estilizado
                if (achievements.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(Icons.emoji_events_outlined, size: 48, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(height: 12),
                          Text('Aún no tienes logros', style: Theme.of(context).textTheme.titleSmall),
                          const SizedBox(height: 8),
                          Text('Realiza acciones como registrar transacciones para ganar puntos y desbloquear logros.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () {
                              ref.invalidate(gamificationDashboardProvider(userId));
                              ref.invalidate(gamificationEventsProvider(userId));
                            },
                            child: const Text('Actualizar'),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 3,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final a = achievements[index];
                          return _buildAchievementCard(context, a);
                        },
                        childCount: achievements.length,
                      ),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    child: Text('Eventos recientes', style: Theme.of(context).textTheme.titleMedium),
                  ),
                ),
                // Events list
                eventsAsync.when(
                  data: (events) {
                    final evList = events.cast<GamificationEvent>();
                    if (evList.isEmpty) {
                      return SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Center(child: Text('No hay eventos recientes.', style: Theme.of(context).textTheme.bodyMedium)),
                        ),
                      );
                    }
                    return SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final e = evList[index];
                          return ListTile(
                            leading: CircleAvatar(child: Text(e.puntosOtorgados.toString())),
                            title: Text(e.tipoEvento.replaceAll('_', ' '), style: Theme.of(context).textTheme.bodyMedium),
                            subtitle: Text(e.descripcion ?? '', style: Theme.of(context).textTheme.bodySmall),
                            trailing: Text(_formatDate(e.fechaEvento), style: Theme.of(context).textTheme.bodySmall),
                          );
                        },
                        childCount: evList.length,
                      ),
                    );
                  },
                  loading: () => SliverToBoxAdapter(
                      child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Center(child: CircularProgressIndicator()),
                  )),
                  error: (err, st) => SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          Text('Error cargando eventos: $err', style: Theme.of(context).textTheme.bodyMedium),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () => ref.invalidate(gamificationEventsProvider(userId)),
                            child: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(child: const SizedBox(height: 48)),
              ],
            ),
          );
        },
        loading: () => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                CircularProgressIndicator(),
                SizedBox(height: 12),
                Text('Cargando gamificación...'),
              ],
            ),
          ),
        ),
        error: (err, st) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Error cargando gamificación: $err', style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    ref.invalidate(gamificationDashboardProvider(userId));
                    ref.invalidate(gamificationEventsProvider(userId));
                  },
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, GamificationProfile? profile) {
    final puntos = profile?.puntos ?? 0;
    final nivel = profile?.nivel ?? 1;
    final racha = profile?.rachaActual ?? 0;

    return Card(
      margin: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _metricColumn(context, 'Puntos', puntos.toString()),
            _metricColumn(context, 'Nivel', nivel.toString()),
            _metricColumn(context, 'Racha', racha.toString()),
          ],
        ),
      ),
    );
  }

  Widget _metricColumn(BuildContext context, String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _buildAchievementCard(BuildContext context, GamificationAchievement a) {
    final unlocked = a.estado == 'unlocked';
    return Card(
      color: unlocked ? Colors.green[50] : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
        child: Row(
          children: [
            Icon(unlocked ? Icons.emoji_events : Icons.lock, color: unlocked ? Colors.orange : Colors.grey),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(a.nombre, style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 2),
                  Text(a.descripcion ?? '', style: Theme.of(context).textTheme.bodySmall, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(a.estado.replaceAll('_', ' '), style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
