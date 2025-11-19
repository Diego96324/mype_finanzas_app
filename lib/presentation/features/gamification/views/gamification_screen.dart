import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:mype_finanzas/presentation/providers/gamification/gamification_providers.dart';
import 'package:mype_finanzas/domain/services/auth_service.dart';
import 'package:mype_finanzas/data/models/gamification_profile_model.dart';
import 'package:mype_finanzas/data/models/gamification_achievement_model.dart';
import 'package:mype_finanzas/data/models/gamification_event_model.dart';
// Asegúrate de importar el modelo de progreso de usuario
import 'package:mype_finanzas/data/models/user_achievement_model.dart';

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
            child: Text('Inicia sesión para ver tu progreso.', style: Theme.of(context).textTheme.bodyLarge),
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
          // 1. Extraer datos del Dashboard
          final profile = dashboard['profile'] as GamificationProfile?;
          final achievements = dashboard['achievements'] as List<GamificationAchievement>? ?? [];

          // 🔥 LÓGICA CRÍTICA: Obtener el progreso específico del usuario
          // Convertimos la lista de progreso en un Mapa para buscar rápido por ID
          final userProgressList = dashboard['user_progress'] as List<UserAchievement>? ?? [];
          final userProgressMap = {
            for (var ua in userProgressList) ua.achievementId: ua
          };

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(gamificationDashboardProvider(userId));
              // Esperar recarga
              await ref.read(gamificationDashboardProvider(userId).future);
            },
            child: CustomScrollView(
              slivers: [
                // --- Header (Puntos, Nivel) ---
                SliverToBoxAdapter(
                  child: _buildHeader(context, profile),
                ),

                // --- Título Logros ---
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Text('Logros', style: Theme.of(context).textTheme.titleMedium),
                  ),
                ),

                // --- Grid de Logros ---
                if (achievements.isEmpty)
                  _buildEmptyAchievementsState(context, ref, userId)
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 2.5, // Ajustado para que quepa mejor
                      ),
                      delegate: SliverChildBuilderDelegate(
                            (context, index) {
                          final achievement = achievements[index];
                          // Buscamos si el usuario tiene progreso en este logro específico
                          final userProgress = userProgressMap[achievement.id];

                          return _buildAchievementCard(context, achievement, userProgress);
                        },
                        childCount: achievements.length,
                      ),
                    ),
                  ),

                // --- Título Historial ---
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                    child: Text('Historial de Puntos', style: Theme.of(context).textTheme.titleMedium),
                  ),
                ),

                // --- Lista de Eventos (Historial) ---
                _buildEventsList(ref, userId),

                const SliverToBoxAdapter(child: SizedBox(height: 48)),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text('Error: $err')),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // WIDGETS AUXILIARES
  // ---------------------------------------------------------------------------

  Widget _buildEventsList(WidgetRef ref, int userId) {
    final eventsAsync = ref.watch(gamificationEventsProvider(userId));

    return eventsAsync.when(
      data: (events) {
        final evList = events.cast<GamificationEvent>();
        if (evList.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Center(child: Text('No hay actividad reciente.', style: TextStyle(color: Colors.grey))),
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
                  backgroundColor: esPositivo ? Colors.green.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                  child: Text(
                    '+${e.puntosOtorgados}',
                    style: TextStyle(
                        color: esPositivo ? Colors.green[700] : Colors.grey[700],
                        fontWeight: FontWeight.bold,
                        fontSize: 12
                    ),
                  ),
                ),
                // 🔥 AQUÍ ESTÁ EL ARREGLO VISUAL: Usamos descripcion en vez de tipoEvento
                title: Text(
                  e.descripcion ?? _formatEventType(e.tipoEvento),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  _formatDate(e.fechaEvento),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
                ),
              );
            },
            childCount: evList.length,
          ),
        );
      },
      loading: () => const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()))),
      error: (_, _) => const SliverToBoxAdapter(child: SizedBox.shrink()),
    );
  }

  Widget _buildHeader(BuildContext context, GamificationProfile? profile) {
    final puntos = profile?.puntos ?? 0;
    final nivel = profile?.nivel ?? 1;
    final racha = profile?.rachaActual ?? 0;

    return Card(
      margin: const EdgeInsets.all(16.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _metricColumn(context, 'Puntos', puntos.toString(), Icons.stars, Colors.amber),
            Container(width: 1, height: 40, color: Colors.grey[300]),
            _metricColumn(context, 'Nivel', nivel.toString(), Icons.trending_up, Colors.blue),
            Container(width: 1, height: 40, color: Colors.grey[300]),
            _metricColumn(context, 'Racha', '$racha días', Icons.local_fire_department, Colors.orange),
          ],
        ),
      ),
    );
  }

  Widget _metricColumn(BuildContext context, String label, String value, IconData icon, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _buildAchievementCard(BuildContext context, GamificationAchievement a, UserAchievement? userProgress) {
    // Determinamos si está desbloqueado mirando el progreso del usuario, no el catálogo
    final isUnlocked = userProgress?.estado == 'unlocked';
    // Si no está desbloqueado, calculamos porcentaje (si es de tipo puntos/racha)
    final progressVal = userProgress?.progresoActual ?? 0.0;
    final target = a.progresoObjetivo;
    final percent = (target > 0) ? (progressVal / target).clamp(0.0, 1.0) : 0.0;

    return Card(
      elevation: 1,
      color: isUnlocked ? Colors.green.withValues(alpha: 0.1) : Colors.grey[50],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isUnlocked ? Colors.green.withValues(alpha: 0.3) : Colors.transparent,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Row(
          children: [
            Icon(
              isUnlocked ? Icons.emoji_events : Icons.lock,
              color: isUnlocked ? Colors.orange : Colors.grey[400],
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
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isUnlocked ? Colors.black87 : Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  if (isUnlocked)
                    Text('¡Completado!', style: TextStyle(fontSize: 10, color: Colors.green[700], fontWeight: FontWeight.bold))
                  else
                  // Barra de progreso miniatura
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            a.descripcion ?? 'Sigue así',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis
                        ),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: percent,
                          minHeight: 4,
                          backgroundColor: Colors.grey[200],
                          color: Colors.blueAccent,
                          borderRadius: BorderRadius.circular(2),
                        )
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

  Widget _buildEmptyAchievementsState(BuildContext context, WidgetRef ref, int userId) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
        child: Column(
          children: [
            Icon(Icons.emoji_events_outlined, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            const Text('Aún no hay logros disponibles'),
            TextButton(
              onPressed: () {
                ref.invalidate(gamificationDashboardProvider(userId));
              },
              child: const Text('Recargar'),
            )
          ],
        ),
      ),
    );
  }

  // Fallback por si la descripción viene nula (para eventos viejos)
  String _formatEventType(String type) {
    return type.replaceAll('_', ' ').capitalize();
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}