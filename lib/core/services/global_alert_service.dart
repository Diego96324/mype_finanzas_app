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
    if (_lastShown != null && now.difference(_lastShown!) < _cooldown) return; // cooldown global

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
        content: Text('⚠️ Presupuesto de "$categoriaNombre" alcanzó ${pctInt}% (Límite S/ ${limite.toStringAsFixed(2)})'),
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
                  builder: (_) => BudgetsOverviewView(initialCategoryId: categoriaId),
                ),
              );
            } catch (_) {}
          },
        ),
      ),
    );
  }
}
