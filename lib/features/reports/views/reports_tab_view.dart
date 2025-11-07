import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/date_picker_theme.dart';
import '../../../core/theme/analytics_design_system.dart';
import '../widgets/reports_widgets.dart';
import '../widgets/dynamic_budget_section.dart';
import '../widgets/dynamic_trends_section.dart';
import '../widgets/dynamic_comparison_section.dart';
import '../controllers/reports_controller.dart';

class ReportsTab extends ConsumerStatefulWidget {
  const ReportsTab({super.key});

  @override
  ConsumerState<ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends ConsumerState<ReportsTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;


  void _changePeriod(String period) {
    // Delegamos al controlador
    ref.read(reportsControllerProvider.notifier).changePeriod(period);
  }

  Future<void> _selectCustomRange() async {
    final state = ref.read(reportsControllerProvider);

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: state.dateRange,
      locale: const Locale('es'),
      builder: (context, child) {
        return Theme(
          data: AppDatePickerTheme.darkDateRangePickerTheme(context),
          child: child!,
        );
      },
    );

    if (picked != null) {
      // Delegamos al controlador
      ref.read(reportsControllerProvider.notifier)
          .changePeriod('personalizado', customRange: picked);
    }
  }

  Map<String, double> _calculateSummary() {
    final state = ref.read(reportsControllerProvider);
    double ingresos = 0;
    double gastos = 0;

    for (var transaction in state.transactions) {
      if (transaction.tipo == 'ingreso') {
        ingresos += transaction.monto;
      } else {
        gastos += transaction.monto;
      }
    }

    return {
      'ingresos': ingresos,
      'gastos': gastos,
      'balance': ingresos - gastos,
    };
  }

  String _getDynamicBudgetTitle() {
    final state = ref.read(reportsControllerProvider);
    switch (state.selectedPeriod) {
      case 'trimestre':
        return 'Presupuesto Trimestral';
      case 'año':
        return 'Presupuesto Anual';
      default:
        return 'Presupuesto Mensual';
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // Observamos el estado del controlador
    final state = ref.watch(reportsControllerProvider);

    if (state.isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF13BB67),
        ),
      );
    }

    final summary = _calculateSummary();

    return RefreshIndicator(
      onRefresh: () async {
        // Refrescamos usando el controlador
        await ref.read(reportsControllerProvider.notifier).refresh();
      },
      color: const Color(0xFF13BB67),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPeriodSelector(),
              const SizedBox(height: 24),

              // Presupuesto
              Text(_getDynamicBudgetTitle(), style: AnalyticsDesignSystem.h3),
              const SizedBox(height: 12),
              DynamicBudgetSection(
                selectedPeriod: state.selectedPeriod,
                currentMonth: state.dateRange.start.month,
                currentYear: state.dateRange.start.year,
                summary: summary,
                onBudgetChanged: () async {
                  // Refrescamos usando el controlador
                  await ref.read(reportsControllerProvider.notifier).refresh();
                },
              ),
              const SizedBox(height: 24),

              // Tendencias
              Text('Tendencias', style: AnalyticsDesignSystem.h3),
              const SizedBox(height: 12),
              DynamicTrendsSection(
                selectedPeriod: state.selectedPeriod,
                transactions: state.transactions,
                dateRange: state.dateRange,
              ),
              const SizedBox(height: 24),

              // Comparativa
              Text('Comparativa de Períodos', style: AnalyticsDesignSystem.h3),
              const SizedBox(height: 12),
              DynamicComparisonSection(
                selectedPeriod: state.selectedPeriod,
                currentDateRange: state.dateRange,
                currentTransactions: state.transactions,
              ),
              const SizedBox(height: 24),
              ReportsWidgets.buildExportButton(context),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    final state = ref.watch(reportsControllerProvider);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AnalyticsDesignSystem.spacing12,
        vertical: AnalyticsDesignSystem.spacing8,
      ),
      decoration: BoxDecoration(
        color: AnalyticsDesignSystem.backgroundSecondary,
        borderRadius: BorderRadius.circular(AnalyticsDesignSystem.radiusMedium),
        boxShadow: AnalyticsDesignSystem.shadowSoft,
      ),
      child: Row(
        children: [
          Expanded(
            child: ReportsWidgets.buildPeriodButton(
              label: 'Mes',
              period: 'mes',
              selectedPeriod: state.selectedPeriod,
              onTap: () => _changePeriod('mes'),
            ),
          ),
          const SizedBox(width: AnalyticsDesignSystem.spacing6),
          Expanded(
            child: ReportsWidgets.buildPeriodButton(
              label: 'Trim',
              period: 'trimestre',
              selectedPeriod: state.selectedPeriod,
              onTap: () => _changePeriod('trimestre'),
            ),
          ),
          const SizedBox(width: AnalyticsDesignSystem.spacing6),
          Expanded(
            child: ReportsWidgets.buildPeriodButton(
              label: 'Año',
              period: 'año',
              selectedPeriod: state.selectedPeriod,
              onTap: () => _changePeriod('año'),
            ),
          ),
          const SizedBox(width: AnalyticsDesignSystem.spacing6),
          Expanded(
            child: ReportsWidgets.buildPeriodButton(
              label: 'Pers',
              period: 'personalizado',
              selectedPeriod: state.selectedPeriod,
              onTap: _selectCustomRange,
            ),
          ),
        ],
      ),
    );
  }
}
