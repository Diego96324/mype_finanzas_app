import 'package:flutter_test/flutter_test.dart';
import 'package:mype_finanzas/core/providers/budget_notifications_provider.dart';
import 'package:mype_finanzas/domain/services/budget_notification_service.dart';

class FakeBudgetNotificationService implements BudgetNotificationService {
  List<BudgetNotification> _active = [];
  bool checkCalled = false;

  @override
  List<BudgetNotification> get activeNotifications => _active;

  @override
  Future<void> checkAllBudgets() async {
    checkCalled = true;
    // Simular detección de una notificación
    _active = [
      BudgetNotification(
        id: 'fake_1',
        type: BudgetAlertType.categoryMonthly,
        title: 'Fake Alert',
        message: 'Mensaje falso',
        percentage: 95.0,
        limit: 100.0,
        spent: 95.0,
        timestamp: DateTime.now(),
        categoryId: 1,
        categoryName: 'TestCat',
        periodo: 'mensual',
        referencia: DateTime.now(),
      )
    ];
  }

  @override
  Future<void> dismissNotification(String notificationId) async {
    _active.removeWhere((n) => n.id == notificationId);
  }

  @override
  Future<void> loadActiveNotifications() async {}

  @override
  Future<void> cleanOldNotifications() async {}

  @override
  Future<void> onTransactionChanged() async {
    // Reusar la verificación
    await checkAllBudgets();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BudgetNotificationsController flow', () {
    test('onTransactionChanged populates notifications from service', () async {
      final fake = FakeBudgetNotificationService();
      final controller = BudgetNotificationsController(service: fake, runCheck: false);

      expect(controller.state.notifications, isEmpty);

      await controller.onTransactionChanged();

      expect(fake.checkCalled, true);
      expect(controller.state.notifications, isNotEmpty);
      expect(controller.state.notifications.first.id, 'fake_1');
    });

    test('checkBudgets populates notifications from service', () async {
      final fake = FakeBudgetNotificationService();
      final controller = BudgetNotificationsController(service: fake, runCheck: false);

      await controller.checkBudgets();

      expect(fake.checkCalled, true);
      expect(controller.state.notifications, isNotEmpty);
    });

    test('dismissNotification removes notification', () async {
      final fake = FakeBudgetNotificationService();
      final controller = BudgetNotificationsController(service: fake, runCheck: false);

      await controller.checkBudgets();
      expect(controller.state.notifications, isNotEmpty);

      final id = controller.state.notifications.first.id;
      await controller.dismissNotification(id);

      expect(controller.state.notifications.where((n) => n.id == id), isEmpty);
    });
  });
}

