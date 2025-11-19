import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:mype_finanzas/controllers/gamification/gamification_providers.dart';
import 'package:mype_finanzas/models/services/auth_service.dart';
import 'package:mype_finanzas/models/dtos/gamification_profile_model.dart';
import 'package:mype_finanzas/models/dtos/gamification_achievement_model.dart';
import 'package:mype_finanzas/models/dtos/gamification_event_model.dart';
import 'package:mype_finanzas/models/dtos/user_achievement_model.dart';

class GamificationScreen extends ConsumerWidget {
  const GamificationScreen({super.key});

  String _formatDate(DateTime d) => DateFormat.yMMMd().add_Hm().format(d);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = AuthService().currentUserId;
    if (userId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Progreso y logros')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Inicia sesión para ver tu progreso.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ),
      );
    }

    final dashboardAsync = ref.watch(gamificationDashboardProvider(userId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gamificación'),
        leading: Navigator.of(context).canPop() ? const BackButton() : null,
      ),
      body: dashboardAsync.when(
        data: (dashboard) {
          final profile = dashboard['profile'] as GamificationProfile?;
          final achievements =
              dashboard['achievements'] as List<GamificationAchievement>? ??
                  [];

          final userProgressList =
              dashboard['user_progress'] as List<UserAchievement>? ?? [];
          final userProgressMap = {
            for (var ua in userProgressList) ua.achievementId: ua
          };

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(gamificationDashboardProvider(userId));
              await ref.read(gamificationDashboardProvider(userId).future);
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // Header
                SliverToBoxAdapter(
                  child: _buildHeader(context, profile),
                ),

                // Título "Logros"
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 8.0),
                    child: Text(
                      'Logros',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),

                // LISTA de logros (ya no grid)
                if (achievements.isEmpty)
                  _buildEmptyAchievementsState(context, ref, userId)
                else
                  SliverPadding(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 16.0),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                            (context, index) {
                          final achievement = achievements[index];
                          final userProgress =
                          userProgressMap[achievement.id];

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: _buildAchievementCard(
                              context,
                              achievement,
                              userProgress,
                            ),
                          );
                        },
                        childCount: achievements.length,
                      ),
                    ),
                  ),

                // Título "Historial de Puntos"
                SliverToBoxAdapter(
                  child: Padding(
                    padding:
                    const EdgeInsets.fromLTRB(16, 24, 16, 8),
                    child: Text(
                      'Historial de Puntos',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),

                // Lista de eventos (sliver)
                _buildEventsList(context, ref, userId),

                const SliverToBoxAdapter(child: SizedBox(height: 48)),
              ],
            ),
          );
        },
        loading: () =>
        const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text('Error: $err')),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // WIDGETS AUXILIARES
  // ---------------------------------------------------------------------------

  Widget _buildEventsList(
      BuildContext context, WidgetRef ref, int userId) {
    final eventsAsync = ref.watch(gamificationEventsProvider(userId));

    return eventsAsync.when(
      data: (events) {
        final evList = events.cast<GamificationEvent>();
        if (evList.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: Text(
                  'No hay actividad reciente.',
                  style: TextStyle(color: Colors.grey[500]),
                ),
              ),
            ),
          );
        }
        return SliverList(
          delegate: SliverChildBuilderDelegate(
                (context, index) {
              final e = evList[index];
              final esPositivo = e.puntosOtorgados > 0;

              return ListTile(
                dense: true,
                leading: CircleAvatar(
                  backgroundColor: esPositivo
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.grey.withValues(alpha: 0.1),
                  child: Text(
                    '${esPositivo ? '+' : ''}${e.puntosOtorgados}',
                    style: TextStyle(
                      color: esPositivo
                          ? Colors.green[700]
                          : Colors.grey[700],
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                title: Text(
                  e.descripcion ?? _formatEventType(e.tipoEvento),
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  _formatDate(e.fecha),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(fontSize: 11),
                ),
              );
            },
            childCount: evList.length,
          ),
        );
      },
      loading: () => const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (_, _) =>
      const SliverToBoxAdapter(child: SizedBox.shrink()),
    );
  }

  Widget _buildHeader(BuildContext context, GamificationProfile? profile) {
    final puntos = profile?.puntos ?? 0;
    final nivel = profile?.nivel ?? 1;
    final racha = profile?.rachaActual ?? 0;

    return Card(
      margin: const EdgeInsets.all(16.0),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _metricColumn(
              context,
              'Puntos',
              puntos.toString(),
              Icons.stars,
              Colors.amber,
            ),
            Container(
              width: 1,
              height: 40,
              color: Colors.grey[300],
            ),
            _metricColumn(
              context,
              'Nivel',
              nivel.toString(),
              Icons.trending_up,
              Colors.blue,
            ),
            Container(
              width: 1,
              height: 40,
              color: Colors.grey[300],
            ),
            _metricColumn(
              context,
              'Racha',
              '$racha días',
              Icons.local_fire_department,
              Colors.orange,
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricColumn(BuildContext context, String label, String value,
      IconData icon, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildAchievementCard(
      BuildContext context,
      GamificationAchievement a,
      UserAchievement? userProgress,
      ) {
    final isUnlocked = userProgress?.estado == 'unlocked';
    final progressVal = userProgress?.progresoActual ?? 0.0;
    final target = a.progresoObjetivo;
    final percent =
    (target > 0) ? (progressVal / target).clamp(0.0, 1.0) : 0.0;

    // 🎨 COLORES MEJORADOS PARA CONTRASTE
    final backgroundColor = isUnlocked
        ? Colors.green[600]
        : Theme.of(context).cardColor;

    final textColor = isUnlocked
        ? Colors.white
        : Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black87;

    final subtextColor =
    isUnlocked ? Colors.white70 : Colors.grey[600];

    final iconColor =
    isUnlocked ? Colors.amber[300] : Colors.grey[400];

    return Card(
      elevation: isUnlocked ? 3 : 1,
      color: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isUnlocked ? Colors.green[700]! : Colors.transparent,
          width: isUnlocked ? 2 : 0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Row(
          children: [
            Icon(
              isUnlocked
                  ? Icons.emoji_events
                  : _getIconFromName(a.iconName),
              color: iconColor,
              size: 28,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    a.nombre,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  if (isUnlocked)
                    Row(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          size: 12,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '¡Completado! +${a.puntos} pts',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          a.descripcion ?? 'Sigue así',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                            fontSize: 10,
                            color: subtextColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: percent,
                          minHeight: 4,
                          backgroundColor: Colors.grey[300],
                          color: Colors.blueAccent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Convierte el nombre del icono guardado en BD a un IconData de Material
  IconData _getIconFromName(String iconName) {
    switch (iconName) {
      case 'login':
        return Icons.login;
      case 'arrow_downward':
        return Icons.arrow_downward;
      case 'arrow_upward':
        return Icons.arrow_upward;
      case 'local_fire_department':
        return Icons.local_fire_department;
      case 'savings':
        return Icons.savings;
      case 'emoji_events':
        return Icons.emoji_events;
      case 'star':
        return Icons.star;
      case 'trending_up':
        return Icons.trending_up;
      default:
        return Icons.emoji_events;
    }
  }

  Widget _buildEmptyAchievementsState(
      BuildContext context, WidgetRef ref, int userId) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 16.0, vertical: 24.0),
        child: Column(
          children: [
            Icon(
              Icons.emoji_events_outlined,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 12),
            const Text('Aún no hay logros disponibles'),
            TextButton(
              onPressed: () {
                ref.invalidate(gamificationDashboardProvider(userId));
              },
              child: const Text('Recargar'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatEventType(String type) {
    return type.replaceAll('_', ' ').capitalize();
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}
