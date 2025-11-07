import '../../../data/models/budget_period_model.dart';
import '../../data/repositories/budget_period_repo.dart';

/// Servicio para gestionar presupuestos con sincronización entre períodos
class BudgetPeriodService {
  final BudgetPeriodRepo _repo = BudgetPeriodRepo();

  /// Calcula el presupuesto trimestral basado en el mensual
  double calculateQuarterlyFromMonthly(double monthlyBudget) {
    return monthlyBudget * 3;
  }

  /// Calcula el presupuesto mensual basado en el trimestral
  double calculateMonthlyFromQuarterly(double quarterlyBudget) {
    return quarterlyBudget / 3;
  }

  /// Calcula el presupuesto anual basado en el mensual
  double calculateYearlyFromMonthly(double monthlyBudget) {
    return monthlyBudget * 12;
  }

  /// Calcula el presupuesto mensual basado en el anual
  double calculateMonthlyFromYearly(double yearlyBudget) {
    return yearlyBudget / 12;
  }

  /// Calcula el presupuesto trimestral basado en el anual
  double calculateQuarterlyFromYearly(double yearlyBudget) {
    return yearlyBudget / 4;
  }

  /// Calcula el presupuesto anual basado en el trimestral
  double calculateYearlyFromQuarterly(double quarterlyBudget) {
    return quarterlyBudget * 4;
  }

  /// Obtiene el mes de inicio del trimestre
  int getQuarterStartMonth(int month) {
    return ((month - 1) ~/ 3) * 3 + 1;
  }

  /// Obtiene el número de trimestre (1-4)
  int getQuarterNumber(int month) {
    return ((month - 1) ~/ 3) + 1;
  }

  /// Guarda un presupuesto mensual y sincroniza con trimestral y anual
  Future<void> saveMonthlyBudget({
    required int usuarioId,
    required double monto,
    required int mes,
    required int anio,
    bool syncToOthers = true,
  }) async {
    // Guardar presupuesto mensual
    await _repo.setBudget(
      usuarioId: usuarioId,
      monto: monto,
      periodo: 'mensual',
      mes: mes,
      anio: anio,
    );

    if (syncToOthers) {
      // Sincronizar con trimestral
      final quarterStartMonth = getQuarterStartMonth(mes);
      final quarterlyBudget = calculateQuarterlyFromMonthly(monto);
      await _repo.setBudget(
        usuarioId: usuarioId,
        monto: quarterlyBudget,
        periodo: 'trimestral',
        mes: quarterStartMonth,
        anio: anio,
      );

      // Sincronizar con anual
      final yearlyBudget = calculateYearlyFromMonthly(monto);
      await _repo.setBudget(
        usuarioId: usuarioId,
        monto: yearlyBudget,
        periodo: 'anual',
        mes: 1,
        anio: anio,
      );
    }
  }

  /// Guarda un presupuesto trimestral y sincroniza con mensual y anual
  Future<void> saveQuarterlyBudget({
    required int usuarioId,
    required double monto,
    required int mes,
    required int anio,
    bool syncToOthers = true,
  }) async {
    final quarterStartMonth = getQuarterStartMonth(mes);

    // Guardar presupuesto trimestral
    await _repo.setBudget(
      usuarioId: usuarioId,
      monto: monto,
      periodo: 'trimestral',
      mes: quarterStartMonth,
      anio: anio,
    );

    if (syncToOthers) {
      // Calcular y guardar presupuesto mensual equivalente
      final monthlyBudget = calculateMonthlyFromQuarterly(monto);

      // Guardar para los 3 meses del trimestre
      for (int i = 0; i < 3; i++) {
        final currentMonth = quarterStartMonth + i;
        await _repo.setBudget(
          usuarioId: usuarioId,
          monto: monthlyBudget,
          periodo: 'mensual',
          mes: currentMonth,
          anio: anio,
        );
      }

      // Sincronizar con anual
      final yearlyBudget = calculateYearlyFromQuarterly(monto);
      await _repo.setBudget(
        usuarioId: usuarioId,
        monto: yearlyBudget,
        periodo: 'anual',
        mes: 1,
        anio: anio,
      );
    }
  }

  /// Guarda un presupuesto anual y sincroniza con mensual y trimestral
  Future<void> saveYearlyBudget({
    required int usuarioId,
    required double monto,
    required int anio,
    bool syncToOthers = true,
  }) async {
    // Guardar presupuesto anual
    await _repo.setBudget(
      usuarioId: usuarioId,
      monto: monto,
      periodo: 'anual',
      mes: 1,
      anio: anio,
    );

    if (syncToOthers) {
      // Calcular y guardar presupuestos mensuales
      final monthlyBudget = calculateMonthlyFromYearly(monto);
      for (int month = 1; month <= 12; month++) {
        await _repo.setBudget(
          usuarioId: usuarioId,
          monto: monthlyBudget,
          periodo: 'mensual',
          mes: month,
          anio: anio,
        );
      }

      // Calcular y guardar presupuestos trimestrales
      final quarterlyBudget = calculateQuarterlyFromYearly(monto);
      for (int quarter = 0; quarter < 4; quarter++) {
        final quarterStartMonth = (quarter * 3) + 1;
        await _repo.setBudget(
          usuarioId: usuarioId,
          monto: quarterlyBudget,
          periodo: 'trimestral',
          mes: quarterStartMonth,
          anio: anio,
        );
      }
    }
  }

  /// Obtiene el presupuesto para el período actual
  Future<BudgetPeriod?> getBudgetForPeriod({
    required int usuarioId,
    required String periodo,
    required int mes,
    required int anio,
  }) async {
    if (periodo == 'trimestral') {
      final quarterStartMonth = getQuarterStartMonth(mes);
      return await _repo.getForPeriod(
        usuarioId: usuarioId,
        periodo: periodo,
        mes: quarterStartMonth,
        anio: anio,
      );
    } else if (periodo == 'anual') {
      return await _repo.getForPeriod(
        usuarioId: usuarioId,
        periodo: periodo,
        mes: 1,
        anio: anio,
      );
    } else {
      return await _repo.getForPeriod(
        usuarioId: usuarioId,
        periodo: periodo,
        mes: mes,
        anio: anio,
      );
    }
  }

  /// Elimina un presupuesto y opcionalmente sincroniza la eliminación
  Future<void> deleteBudget({
    required int usuarioId,
    required String periodo,
    required int mes,
    required int anio,
    bool syncToOthers = false,
  }) async {
    if (periodo == 'mensual') {
      await _repo.deleteForPeriod(
        usuarioId: usuarioId,
        periodo: 'mensual',
        mes: mes,
        anio: anio,
      );

      if (syncToOthers) {
        final quarterStartMonth = getQuarterStartMonth(mes);
        await _repo.deleteForPeriod(
          usuarioId: usuarioId,
          periodo: 'trimestral',
          mes: quarterStartMonth,
          anio: anio,
        );
        await _repo.deleteForPeriod(
          usuarioId: usuarioId,
          periodo: 'anual',
          mes: 1,
          anio: anio,
        );
      }
    } else if (periodo == 'trimestral') {
      final quarterStartMonth = getQuarterStartMonth(mes);
      await _repo.deleteForPeriod(
        usuarioId: usuarioId,
        periodo: 'trimestral',
        mes: quarterStartMonth,
        anio: anio,
      );

      if (syncToOthers) {
        // Eliminar los meses del trimestre
        for (int i = 0; i < 3; i++) {
          await _repo.deleteForPeriod(
            usuarioId: usuarioId,
            periodo: 'mensual',
            mes: quarterStartMonth + i,
            anio: anio,
          );
        }
        await _repo.deleteForPeriod(
          usuarioId: usuarioId,
          periodo: 'anual',
          mes: 1,
          anio: anio,
        );
      }
    } else if (periodo == 'anual') {
      await _repo.deleteForPeriod(
        usuarioId: usuarioId,
        periodo: 'anual',
        mes: 1,
        anio: anio,
      );

      if (syncToOthers) {
        // Eliminar todos los meses
        for (int month = 1; month <= 12; month++) {
          await _repo.deleteForPeriod(
            usuarioId: usuarioId,
            periodo: 'mensual',
            mes: month,
            anio: anio,
          );
        }
        // Eliminar todos los trimestres
        for (int quarter = 0; quarter < 4; quarter++) {
          await _repo.deleteForPeriod(
            usuarioId: usuarioId,
            periodo: 'trimestral',
            mes: (quarter * 3) + 1,
            anio: anio,
          );
        }
      }
    }
  }

  /// Obtiene el nombre del período para mostrar en UI
  String getPeriodName(String periodo) {
    switch (periodo) {
      case 'mensual':
        return 'Presupuesto Mensual';
      case 'trimestral':
        return 'Presupuesto Trimestral';
      case 'anual':
        return 'Presupuesto Anual';
      default:
        return 'Presupuesto';
    }
  }

  /// Obtiene el nombre del trimestre
  String getQuarterName(int month) {
    final quarter = getQuarterNumber(month);
    return 'Q$quarter';
  }
}

