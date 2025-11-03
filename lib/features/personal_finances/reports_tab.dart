import 'package:flutter/material.dart';
import '../../core/models/transaction_model.dart';
import '../../core/repos/transaction_repo.dart';
import '../../core/services/auth_service.dart';
import '../../core/utils/date_picker_theme.dart';
import '../../core/utils/analytics_design_system.dart';
import 'widgets/reports_widgets.dart';
import 'widgets/dynamic_budget_section.dart';
import 'widgets/dynamic_trends_section.dart';
import 'widgets/dynamic_comparison_section.dart';

class ReportsTab extends StatefulWidget {
  const ReportsTab({super.key});

  @override
  State<ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<ReportsTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  String _selectedPeriod = 'mes';
  DateTimeRange _selectedDateRange = DateTimeRange(
    start: DateTime(DateTime.now().year, DateTime.now().month, 1),
    end: DateTime(DateTime.now().year, DateTime.now().month + 1, 0, 23, 59, 59),
  );

  List<AppTransaction> _transactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final authService = AuthService();
      final userId = authService.currentUserId;

      if (userId != null) {
        final repo = TransactionRepo();
        final transactions = await repo.list(
          usuarioId: userId,
          from: _selectedDateRange.start,
          to: _selectedDateRange.end,
        );

        setState(() {
          _transactions = transactions;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      rethrow;
    }
  }

  void _changePeriod(String period) {
    final now = DateTime.now();

    DateTimeRange newDateRange;
    switch (period) {
      case 'mes':
        newDateRange = DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month + 1, 0, 23, 59, 59),
        );
        break;
      case 'trimestre':
        final quarterStart = ((now.month - 1) ~/ 3) * 3 + 1;
        newDateRange = DateTimeRange(
          start: DateTime(now.year, quarterStart, 1),
          end: DateTime(now.year, quarterStart + 3, 0, 23, 59, 59),
        );
        break;
      case 'año':
        newDateRange = DateTimeRange(
          start: DateTime(now.year, 1, 1),
          end: DateTime(now.year, 12, 31, 23, 59, 59),
        );
        break;
      default:
        newDateRange = _selectedDateRange;
    }

    setState(() {
      _selectedPeriod = period;
      _selectedDateRange = newDateRange;
    });

    _loadData();
  }

  Future<void> _selectCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _selectedDateRange,
      locale: const Locale('es'),
      builder: (context, child) {
        return Theme(
          data: AppDatePickerTheme.darkDateRangePickerTheme(context),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
        _selectedPeriod = 'personalizado';
      });
      _loadData();
    }
  }

  Map<String, double> _calculateSummary() {
    double ingresos = 0;
    double gastos = 0;

    for (var transaction in _transactions) {
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
    switch (_selectedPeriod) {
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

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF13BB67),
        ),
      );
    }

    final summary = _calculateSummary();

    return RefreshIndicator(
      onRefresh: _loadData,
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
                selectedPeriod: _selectedPeriod,
                currentMonth: _selectedDateRange.start.month,
                currentYear: _selectedDateRange.start.year,
                summary: summary,
                onBudgetChanged: _loadData,
              ),
              const SizedBox(height: 24),

              // Tendencias
              Text('Tendencias', style: AnalyticsDesignSystem.h3),
              const SizedBox(height: 12),
              DynamicTrendsSection(
                selectedPeriod: _selectedPeriod,
                transactions: _transactions,
                dateRange: _selectedDateRange,
              ),
              const SizedBox(height: 24),

              // Comparativa
              Text('Comparativa de Períodos', style: AnalyticsDesignSystem.h3),
              const SizedBox(height: 12),
              DynamicComparisonSection(
                selectedPeriod: _selectedPeriod,
                currentDateRange: _selectedDateRange,
                currentTransactions: _transactions,
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
              selectedPeriod: _selectedPeriod,
              onTap: () => _changePeriod('mes'),
            ),
          ),
          const SizedBox(width: AnalyticsDesignSystem.spacing6),
          Expanded(
            child: ReportsWidgets.buildPeriodButton(
              label: 'Trim',
              period: 'trimestre',
              selectedPeriod: _selectedPeriod,
              onTap: () => _changePeriod('trimestre'),
            ),
          ),
          const SizedBox(width: AnalyticsDesignSystem.spacing6),
          Expanded(
            child: ReportsWidgets.buildPeriodButton(
              label: 'Año',
              period: 'año',
              selectedPeriod: _selectedPeriod,
              onTap: () => _changePeriod('año'),
            ),
          ),
          const SizedBox(width: AnalyticsDesignSystem.spacing6),
          Expanded(
            child: ReportsWidgets.buildPeriodButton(
              label: 'Pers',
              period: 'personalizado',
              selectedPeriod: _selectedPeriod,
              onTap: _selectCustomRange,
            ),
          ),
        ],
      ),
    );
  }
}
