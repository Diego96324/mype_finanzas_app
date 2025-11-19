import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/dtos/transaction_model.dart';
import '../../../models/repositories/transaction_repository.dart';
import '../../../core/providers/providers.dart';
import '../../core/theme/analytics_design_system.dart';
import '../../../core/utils/currency_formatter.dart';

class DynamicComparisonSection extends ConsumerStatefulWidget {
  final String selectedPeriod;
  final DateTimeRange currentDateRange;
  final List<AppTransaction> currentTransactions;

  const DynamicComparisonSection({
    super.key,
    required this.selectedPeriod,
    required this.currentDateRange,
    required this.currentTransactions,
  });

  @override
  ConsumerState<DynamicComparisonSection> createState() => _DynamicComparisonSectionState();
}

class _DynamicComparisonSectionState extends ConsumerState<DynamicComparisonSection> {
  List<AppTransaction> _previousTransactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPreviousPeriodData();
  }

  @override
  void didUpdateWidget(DynamicComparisonSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedPeriod != widget.selectedPeriod ||
        oldWidget.currentDateRange != widget.currentDateRange) {
      _loadPreviousPeriodData();
    }
  }

  Future<void> _loadPreviousPeriodData() async {
    setState(() => _isLoading = true);

    try {
      // Usamos el provider en lugar de AuthService
      final userId = ref.read(currentUserIdProvider);

      if (userId != null) {
        final previousRange = _calculatePreviousPeriod();
        final repo = TransactionRepo();
        final transactions = await repo.list(
          usuarioId: userId,
          from: previousRange.start,
          to: previousRange.end,
        );

        if (mounted) {
          setState(() {
            _previousTransactions = transactions;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  DateTimeRange _calculatePreviousPeriod() {
    final current = widget.currentDateRange;

    switch (widget.selectedPeriod) {
      case 'mes':
        final previousMonth = DateTime(current.start.year, current.start.month - 1, 1);
        return DateTimeRange(
          start: previousMonth,
          end: DateTime(previousMonth.year, previousMonth.month + 1, 0, 23, 59, 59),
        );

      case 'trimestre':
        final quarterStart = current.start.month;
        final previousQuarterStart = quarterStart - 3;
        final previousYear = previousQuarterStart <= 0 ? current.start.year - 1 : current.start.year;
        final adjustedMonth = previousQuarterStart <= 0 ? previousQuarterStart + 12 : previousQuarterStart;

        return DateTimeRange(
          start: DateTime(previousYear, adjustedMonth, 1),
          end: DateTime(previousYear, adjustedMonth + 3, 0, 23, 59, 59),
        );

      case 'año':
        return DateTimeRange(
          start: DateTime(current.start.year - 1, 1, 1),
          end: DateTime(current.start.year - 1, 12, 31, 23, 59, 59),
        );

      default:
        final duration = current.end.difference(current.start);
        return DateTimeRange(
          start: current.start.subtract(duration),
          end: current.start.subtract(const Duration(days: 1)),
        );
    }
  }

  Map<String, double> _calculateSummary(List<AppTransaction> transactions) {
    double ingresos = 0;
    double gastos = 0;

    for (var transaction in transactions) {
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

  String _getCurrentPeriodName() {
    final start = widget.currentDateRange.start;

    switch (widget.selectedPeriod) {
      case 'mes':
        return _getMonthName(start.month);
      case 'trimestre':
        final quarter = ((start.month - 1) ~/ 3) + 1;
        return 'Q$quarter ${start.year}';
      case 'año':
        return '${start.year}';
      default:
        return 'Actual';
    }
  }

  String _getPreviousPeriodName() {
    final start = widget.currentDateRange.start;

    switch (widget.selectedPeriod) {
      case 'mes':
        final previousMonth = start.month == 1 ? 12 : start.month - 1;
        return _getMonthName(previousMonth);
      case 'trimestre':
        final currentQuarter = ((start.month - 1) ~/ 3) + 1;
        final previousQuarter = currentQuarter == 1 ? 4 : currentQuarter - 1;
        final year = currentQuarter == 1 ? start.year - 1 : start.year;
        return 'Q$previousQuarter $year';
      case 'año':
        return '${start.year - 1}';
      default:
        return 'Anterior';
    }
  }

  String _getMonthName(int month) {
    const months = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
    ];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.02),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          ),
        );
      },
      child: _buildComparison(),
    );
  }

  Widget _buildComparison() {
    if (_isLoading) {
      return AnalyticsDesignSystem.buildCard(
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(AnalyticsDesignSystem.spacing32),
            child: CircularProgressIndicator(
              color: AnalyticsDesignSystem.primary,
              strokeWidth: 2,
            ),
          ),
        ),
      );
    }

    final currentSummary = _calculateSummary(widget.currentTransactions);
    final previousSummary = _calculateSummary(_previousTransactions);

    return AnalyticsDesignSystem.buildCard(
      padding: const EdgeInsets.symmetric(
        vertical: AnalyticsDesignSystem.spacing16,
        horizontal: AnalyticsDesignSystem.spacing12,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: MediaQuery.of(context).size.width -
                    (AnalyticsDesignSystem.spacing12 * 2) -  // Card horizontal
                    (AnalyticsDesignSystem.spacing16 * 2),   // reports_tab padding
          ),
          child: Table(
            columnWidths: const {
              0: FlexColumnWidth(2.5),
              1: FlexColumnWidth(2.0),
              2: FlexColumnWidth(2.0),
              3: FlexColumnWidth(2.0),
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              // Header Row
              TableRow(
                children: [
                  _buildTableCell(
                    'Categoría',
                    isHeader: true,
                    align: TextAlign.left,
                  ),
                  _buildTableCell(
                    _getCurrentPeriodName(),
                    isHeader: true,
                    align: TextAlign.center,
                    color: AnalyticsDesignSystem.primary,
                  ),
                  _buildTableCell(
                    _getPreviousPeriodName(),
                    isHeader: true,
                    align: TextAlign.center,
                  ),
                  _buildTableCell(
                    'Cambio',
                    isHeader: true,
                    align: TextAlign.center,
                  ),
                ],
              ),

              // Divider Row
              TableRow(
                children: List.generate(
                  4,
                  (index) => Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AnalyticsDesignSystem.spacing8,
                      horizontal: AnalyticsDesignSystem.spacing6,
                    ),
                    child: AnalyticsDesignSystem.buildDivider(),
                  ),
                ),
              ),

              // Ingresos Row
              _buildDataRow(
                'Ingresos',
                currentSummary['ingresos']!,
                previousSummary['ingresos']!,
                AnalyticsDesignSystem.primary,
              ),

              // Gastos Row
              _buildDataRow(
                'Gastos',
                currentSummary['gastos']!,
                previousSummary['gastos']!,
                AnalyticsDesignSystem.danger,
              ),

              // Divider Row
              TableRow(
                children: List.generate(
                  4,
                  (index) => Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AnalyticsDesignSystem.spacing8,
                      horizontal: AnalyticsDesignSystem.spacing6,
                    ),
                    child: AnalyticsDesignSystem.buildDivider(),
                  ),
                ),
              ),

              // Balance Row
              _buildDataRow(
                'Balance',
                currentSummary['balance']!,
                previousSummary['balance']!,
                currentSummary['balance']! >= 0
                    ? AnalyticsDesignSystem.primary
                    : AnalyticsDesignSystem.warning,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTableCell(
    String text, {
    bool isHeader = false,
    TextAlign align = TextAlign.left,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AnalyticsDesignSystem.spacing8,
        horizontal: AnalyticsDesignSystem.spacing6,
      ),
      child: Text(
        text,
        textAlign: align,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
        style: isHeader
            ? AnalyticsDesignSystem.bodyBold.copyWith(
                color: color ?? AnalyticsDesignSystem.textSecondary,
              )
            : AnalyticsDesignSystem.bodyNormal.copyWith(
                color: color ?? AnalyticsDesignSystem.textPrimary,
              ),
      ),
    );
  }

  TableRow _buildDataRow(
    String label,
    double currentValue,
    double previousValue,
    Color color,
  ) {
    final difference = currentValue - previousValue;
    final percentChange = previousValue != 0
        ? ((difference / previousValue) * 100).toDouble()
        : 0.0;
    final isPositive = difference >= 0;

    return TableRow(
      children: [
        // Categoría
        _buildTableCell(
          label,
          align: TextAlign.left,
          color: AnalyticsDesignSystem.textPrimary,
        ),

        // Valor Actual
        _buildTableCell(
          'S/ ${CurrencyFormatter.formatAmount(currentValue)}',
          align: TextAlign.center,
          color: color,
        ),

        // Valor Anterior
        _buildTableCell(
          'S/ ${CurrencyFormatter.formatAmount(previousValue)}',
          align: TextAlign.center,
          color: AnalyticsDesignSystem.textSecondary,
        ),

        // Cambio Porcentual
        Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AnalyticsDesignSystem.spacing8,
            horizontal: AnalyticsDesignSystem.spacing6,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                size: 14,
                color: isPositive
                    ? AnalyticsDesignSystem.primary
                    : AnalyticsDesignSystem.danger,
              ),
              const SizedBox(width: AnalyticsDesignSystem.spacing4),
              Text(
                '${percentChange.abs().toStringAsFixed(1)}%',
                textAlign: TextAlign.center,
                style: AnalyticsDesignSystem.bodyBold.copyWith(
                  color: isPositive
                      ? AnalyticsDesignSystem.primary
                      : AnalyticsDesignSystem.danger,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

