import 'package:flutter/material.dart';
import '../../app.dart';
import '../../presentation/features/transactions/views/budgets_overview_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GlobalAlertService {
  GlobalAlertService._();
  static final GlobalAlertService _instance = GlobalAlertService._();
  factory GlobalAlertService() => _instance;

  DateTime? _lastShown; // evitar spam rápido
  final Duration _cooldown = const Duration(seconds: 5);

  Future<void> showBudgetThresholdAlert({
    required int categoriaId,
    required String categoriaNombre,
    required double porcentaje,
    required double limite,
    required String periodo,
    required DateTime referencia,
  }) async {
    final messenger = rootScaffoldMessengerKey.currentState;
    final ctx = rootScaffoldMessengerKey.currentContext;
    if (messenger == null || ctx == null) return;

    final now = DateTime.now();
    if (_lastShown != null && now.difference(_lastShown!) < _cooldown) {
      return; // cooldown global
    }

    // Persistencia: sólo mostrar si es mayor al último registrado
    final prefs = await SharedPreferences.getInstance();
    final key = 'budget_alert_${referencia.year}_${referencia.month}_${periodo}_$categoriaId';
    final lastPct = prefs.getInt(key) ?? 0;
    final pctInt = porcentaje.round();
    if (pctInt <= lastPct) return; // ya se mostró un igual o mayor

    await prefs.setInt(key, pctInt);
    _lastShown = now;

    messenger.showSnackBar(
      SnackBar(
        content: Text(
            '⚠️ Presupuesto de "$categoriaNombre" alcanzó $pctInt% (Límite S/ ${limite.toStringAsFixed(2)})'
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.orange.shade700,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Ver detalle',
          textColor: Colors.white,
          onPressed: () {
            try {
              Navigator.of(ctx).push(
                MaterialPageRoute(
                  builder: (_) => const BudgetsOverviewView(),
                ),
              );
            } catch (e) {
              debugPrint('Error al navegar a BudgetsOverviewView: $e');
            }
          },
        ),
      ),
    );
  }

  /// Mtodo opcional para limpiar alertas antiguas (llamar periódicamente si es necesario)
  Future<void> cleanOldAlerts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      final now = DateTime.now();

      for (final key in keys) {
        if (key.startsWith('budget_alert_')) {
          // Parsear fecha del key: budget_alert_YYYY_MM_periodo_categoriaId
          final parts = key.split('_');
          if (parts.length >= 4) {
            final year = int.tryParse(parts[2]);
            final month = int.tryParse(parts[3]);

            if (year != null && month != null) {
              final alertDate = DateTime(year, month);
              final diff = now.difference(alertDate);

              // Eliminar alertas de más de 3 meses
              if (diff.inDays > 90) {
                await prefs.remove(key);
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error al limpiar alertas antiguas: $e');
    }
  }
}