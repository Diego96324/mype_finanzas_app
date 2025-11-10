import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app.dart';
import '../../domain/services/budget_notification_service.dart';
import '../providers/budget_notifications_provider.dart';

/// Widget global que muestra notificaciones de presupuesto en toda la app
class BudgetNotificationBanner extends ConsumerStatefulWidget {
  final Widget child;

  const BudgetNotificationBanner({super.key, required this.child});

  @override
  ConsumerState<BudgetNotificationBanner> createState() => _BudgetNotificationBannerState();
}

class _BudgetNotificationBannerState extends ConsumerState<BudgetNotificationBanner> {
  String? _currentShownId;

  @override
  void didUpdateWidget(covariant BudgetNotificationBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowSnackBar());
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowSnackBar());
  }

  void _maybeShowSnackBar() {
    final notifications = ref.read(budgetNotificationsProvider).notifications;

    if (notifications.isNotEmpty) {
      final first = notifications.first;
      if (_currentShownId != first.id) {
        _showFloatingSnackBar(first);
      }
    } else {
      _hideSnackBar();
    }
  }

  void _showFloatingSnackBar(BudgetNotification notification) {
    final messenger = rootScaffoldMessengerKey.currentState;
    if (messenger == null) return;

    // Ocultar snackbar previo
    messenger.hideCurrentSnackBar();

    final color = _getColorForPercentage(notification.percentage);
    final topOffset = MediaQuery.of(context).padding.top + kToolbarHeight + 8.0;

    // Subir opacidad para que sea claramente visible en pantallas pequeñas.
    final bgOpacity = 0.50; // menos transparente
    final textColor = _textColorForBackground(color.withValues(alpha: bgOpacity));

    final snack = SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.fromLTRB(8, topOffset, 8, 0),
      backgroundColor: Colors.transparent,
      elevation: 0,
      duration: const Duration(seconds: 8),
      content: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: bgOpacity),
          borderRadius: BorderRadius.circular(10),
          border: Border(left: BorderSide(color: color.withValues(alpha: 1.0), width: 6)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.22), blurRadius: 12, offset: const Offset(0, 5)),
          ],
        ),
        child: Row(
          children: [
            Icon(_getIconForType(notification.type), color: color, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(notification.title, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: textColor)),
                  const SizedBox(height: 6),
                  Text(notification.message, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: textColor)),
                ],
              ),
            ),
            TextButton(
              onPressed: () {
                ref.read(budgetNotificationsProvider.notifier).dismissNotification(notification.id);
              },
              child: Text('Entendido', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );

    messenger.showSnackBar(snack);
    _currentShownId = notification.id;
  }

  void _hideSnackBar() {
    final messenger = rootScaffoldMessengerKey.currentState;
    messenger?.hideCurrentSnackBar();
    _currentShownId = null;
  }

  Color _textColorForBackground(Color bg) {
    return bg.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
  }

  Color _getColorForPercentage(double percentage) {
    if (percentage >= 100) return Colors.red;
    if (percentage >= 90) return Colors.orange;
    if (percentage >= 75) return Colors.amber;
    return Colors.green;
  }

  IconData _getIconForType(BudgetAlertType type) {
    switch (type) {
      case BudgetAlertType.generalMonthly:
      case BudgetAlertType.generalQuarterly:
      case BudgetAlertType.generalYearly:
        return Icons.account_balance_wallet_outlined;
      case BudgetAlertType.categoryMonthly:
      case BudgetAlertType.categoryQuarterly:
        return Icons.category_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Escuchar cambios para disparar show/hide de snackbars
    ref.watch(budgetNotificationsProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowSnackBar());
    return widget.child;
  }
}
