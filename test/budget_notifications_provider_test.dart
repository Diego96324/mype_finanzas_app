import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mype_finanzas/core/providers/budget_notifications_provider.dart';
import 'package:mype_finanzas/domain/services/budget_notification_service.dart';

class FakeBudgetNotificationService implements BudgetNotificationService {
  List<BudgetNotification> _active = [];
  bool dismissedCalled = false;

  @override
  List<BudgetNotification> get activeNotifications => _active;

  @override
  Future<void> checkAllBudgets() async {}

  @override
  Future<void> dismissNotification(String notificationId) async {
    dismissedCalled = true;
    _active.removeWhere((n) => n.id == notificationId);
  }

  @override
  Future<void> loadActiveNotifications() async {}

  @override
  Future<void> cleanOldNotifications() async {}

  @override
  Future<void> onTransactionChanged() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BudgetNotificationsController', () {
    test('markNotificationAsShown updates prefs and calls dismiss', () async {
      SharedPreferences.setMockInitialValues({});

      final fake = FakeBudgetNotificationService();
      fake._active = [
        BudgetNotification(
          id: 'test_1',
          type: BudgetAlertType.categoryMonthly,
          title: 't',
          message: 'm',
          percentage: 95.0,
          limit: 100.0,
          spent: 95.0,
          timestamp: DateTime.now(),
          categoryId: 1,
          categoryName: 'c',
          periodo: 'mensual',
          referencia: DateTime(2025, 3, 1),
        ),
      ];

      final controller = BudgetNotificationsController(service: fake, runCheck: false);

      await controller.markNotificationAsShown('test_1', categoriaId: 1, porcentaje: 95.0, periodo: 'mensual', referencia: DateTime(2025, 3, 1));

      final prefs = await SharedPreferences.getInstance();
      final key = 'budget_alert_2025_3_mensual_1';
      expect(prefs.getInt(key), 95);
      expect(fake.dismissedCalled, true);
    });
  });
}

