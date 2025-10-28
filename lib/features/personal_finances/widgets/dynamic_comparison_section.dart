import 'package:flutter/material.dart';
import '../../../core/models/transaction_model.dart';
import '../../../core/repos/transaction_repo.dart';
import '../../../core/services/auth_service.dart';
import 'reports_widgets.dart';

class DynamicComparisonSection extends StatefulWidget {
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
  State<DynamicComparisonSection> createState() => _DynamicComparisonSectionState();
}

class _DynamicComparisonSectionState extends State<DynamicComparisonSection> {
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
      final authService = AuthService();
      final userId = authService.currentUserId;

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
        // Mes anterior
        final previousMonth = DateTime(current.start.year, current.start.month - 1, 1);
        return DateTimeRange(
          start: previousMonth,
          end: DateTime(previousMonth.year, previousMonth.month + 1, 0, 23, 59, 59),
        );

      case 'trimestre':
        // Trimestre anterior
        final quarterStart = current.start.month;
        final previousQuarterStart = quarterStart - 3;
        final previousYear = previousQuarterStart <= 0 ? current.start.year - 1 : current.start.year;
        final adjustedMonth = previousQuarterStart <= 0 ? previousQuarterStart + 12 : previousQuarterStart;

        return DateTimeRange(
          start: DateTime(previousYear, adjustedMonth, 1),
          end: DateTime(previousYear, adjustedMonth + 3, 0, 23, 59, 59),
        );

      case 'año':
        // Año anterior
        return DateTimeRange(
          start: DateTime(current.start.year - 1, 1, 1),
          end: DateTime(current.start.year - 1, 12, 31, 23, 59, 59),
        );

      default:
        // Para período personalizado, usar el mismo rango de días pero hacia atrás
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

  String _getPeriodLabel() {
    switch (widget.selectedPeriod) {
      case 'mes':
        return 'Mes';
      case 'trimestre':
        return 'Trimestre';
      case 'año':
        return 'Año';
      default:
        return 'Período';
    }
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
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
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
      return Container(
        height: 200,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF2D2D2D),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF13BB67),
            strokeWidth: 2,
          ),
        ),
      );
    }

    final currentSummary = _calculateSummary(widget.currentTransactions);
    final previousSummary = _calculateSummary(_previousTransactions);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D2D),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Header con nombres de períodos
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  '',
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  _getCurrentPeriodName(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF13BB67),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  _getPreviousPeriodName(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Expanded(
                flex: 2,
                child: SizedBox(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Filas de comparación
          ReportsWidgets.buildComparisonRow(
            'Ingresos',
            currentSummary['ingresos']!,
            previousSummary['ingresos']!,
            const Color(0xFF13BB67),
          ),
          const SizedBox(height: 12),
          ReportsWidgets.buildComparisonRow(
            'Gastos',
            currentSummary['gastos']!,
            previousSummary['gastos']!,
            Colors.redAccent,
          ),
          const SizedBox(height: 12),
          ReportsWidgets.buildComparisonRow(
            'Balance',
            currentSummary['balance']!,
            previousSummary['balance']!,
            currentSummary['balance']! >= 0 ? const Color(0xFF13BB67) : Colors.redAccent,
          ),
          if (_previousTransactions.isEmpty && widget.currentTransactions.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.orange.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 18,
                    color: Colors.orange[300],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No hay datos del ${_getPeriodLabel().toLowerCase()} anterior para comparar',
                      style: TextStyle(
                        color: Colors.orange[300],
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

