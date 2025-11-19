import '../../models/dtos/transaction_model.dart';

class RecurrenceHelper {
  static DateTime? computeNextOccurrence({
    required DateTime base,
    required String? frecuencia,
    int? intervalDays,
  }) {
    if (frecuencia == null || frecuencia == 'una_vez') return null;
    switch (frecuencia) {
      case 'semanal':
        return base.add(const Duration(days: 7));
      case 'quincenal':
        return base.add(const Duration(days: 15));
      case 'mensual':
        final targetMonth = base.month + 1;
        final year = base.year + (targetMonth > 12 ? 1 : 0);
        final month = (targetMonth - 1) % 12 + 1;
        final dayInTargetMonth = _safeDay(year, month, base.day);
        return DateTime(year, month, dayInTargetMonth, base.hour, base.minute, base.second);
      case 'trimestral':
        final targetMonth = base.month + 3;
        final year = base.year + ((targetMonth - 1) ~/ 12);
        final month = ((targetMonth - 1) % 12) + 1;
        final dayInTargetMonth = _safeDay(year, month, base.day);
        return DateTime(year, month, dayInTargetMonth, base.hour, base.minute, base.second);
      case 'anual':
        final year = base.year + 1;
        final dayInTargetMonth = _safeDay(year, base.month, base.day);
        return DateTime(year, base.month, dayInTargetMonth, base.hour, base.minute, base.second);
      case 'personalizada':
        final n = (intervalDays ?? 0);
        if (n <= 0) return null;
        return base.add(Duration(days: n));
      default:
        return null;
    }
  }

  static int _safeDay(int year, int month, int day) {
    final lastDay = DateTime(year, month + 1, 0).day; // último día del mes
    return day <= lastDay ? day : lastDay;
  }

  static DateTime? computeNextFromTx(AppTransaction tx) {
    final base = tx.nextOccurrence ?? tx.fecha;
    return computeNextOccurrence(
      base: base,
      frecuencia: tx.frecuenciaRecurrencia,
      intervalDays: tx.recurrenceIntervalDays,
    );
  }

  static bool isRecurrenceActive(DateTime? endDate, DateTime now) {
    if (endDate == null) return true;
    return now.isBefore(endDate) || now.isAtSameMomentAs(endDate);
  }
}
