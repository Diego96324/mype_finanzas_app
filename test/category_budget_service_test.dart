import 'package:flutter_test/flutter_test.dart';
import 'package:mype_finanzas/domain/services/category_budget_service.dart';

void main() {
  group('CategoryBudgetService period helpers', () {
    final service = CategoryBudgetService();
    test('computeRange mensual', () {
      final ref = DateTime(2025, 3, 15);
      final r = service.computeRange('mensual', ref);
      expect(r.start, DateTime(2025, 3, 1));
      expect(r.end.year, 2025);
      expect(r.end.month, 3);
    });
    test('computeRange trimestral', () {
      final ref = DateTime(2025, 5, 10); // Q2
      final r = service.computeRange('trimestral', ref);
      expect(r.start, DateTime(2025, 4, 1));
      expect(r.end, DateTime(2025, 6, 30, 23, 59, 59, 999));
    });
  });
}

