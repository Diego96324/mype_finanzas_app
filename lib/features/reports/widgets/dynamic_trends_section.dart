import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../core/models/transaction_model.dart';
import '../../../core/theme/analytics_design_system.dart';

class DynamicTrendsSection extends StatelessWidget {
  final String selectedPeriod;
  final List<AppTransaction> transactions;
  final DateTimeRange dateRange;

  const DynamicTrendsSection({
    super.key,
    required this.selectedPeriod,
    required this.transactions,
    required this.dateRange,
  });

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
      child: KeyedSubtree(
        key: ValueKey('$selectedPeriod-${dateRange.start}-${dateRange.end}'),
        child: _buildTrendsChart(),
      ),
    );
  }

  Widget _buildTrendsChart() {
    if (transactions.isEmpty) {
      return AnalyticsDesignSystem.buildEmptyState(
        message: 'No hay datos para mostrar tendencias',
        icon: Icons.trending_up,
        minHeight: 250,
      );
    }

    final chartData = _createChartData();

    if (chartData.isEmpty) {
      return AnalyticsDesignSystem.buildEmptyState(
        message: 'No hay datos suficientes para el gráfico',
        icon: Icons.trending_up,
        minHeight: 250,
      );
    }

    final spots = chartData.map((data) => FlSpot(data.index.toDouble(), data.balance)).toList();
    final labels = {for (var data in chartData) data.index: data.label};

    final yInterval = _calculateYInterval(spots);
    final uniqueYValues = _calculateUniqueYValues(spots, yInterval);

    return AnalyticsDesignSystem.buildChartContainer(
      title: _getChartTitle(),
      headerAction: AnalyticsDesignSystem.buildBadge(
        label: _getChartSubtitle(),
        color: AnalyticsDesignSystem.info,
      ),
      height: 250,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: true,
            verticalInterval: _calculateBottomInterval(chartData.length).toDouble(),
            horizontalInterval: yInterval,
            getDrawingVerticalLine: (value) => FlLine(
              color: AnalyticsDesignSystem.divider.withValues(alpha: 0.5),
              strokeWidth: 1,
            ),
            getDrawingHorizontalLine: (value) => FlLine(
              color: AnalyticsDesignSystem.divider,
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 55,
                interval: yInterval,
                getTitlesWidget: (value, meta) {
                  if (!uniqueYValues.contains(value)) {
                    return const SizedBox.shrink();
                  }

                  final formattedValue = _formatYAxisValue(value);

                  return Padding(
                    padding: const EdgeInsets.only(right: AnalyticsDesignSystem.spacing8),
                    child: Text(
                      formattedValue,
                      textAlign: TextAlign.right,
                      style: AnalyticsDesignSystem.caption,
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: _calculateBottomInterval(chartData.length).toDouble(),
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  final label = labels[index];
                  if (label == null) return const SizedBox();

                  return Padding(
                    padding: const EdgeInsets.only(top: AnalyticsDesignSystem.spacing6),
                    child: Text(
                      label,
                      style: AnalyticsDesignSystem.caption,
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border(
              left: BorderSide(color: AnalyticsDesignSystem.border, width: 1),
              bottom: BorderSide(color: AnalyticsDesignSystem.border, width: 1),
            ),
          ),
          minX: 0,
          maxX: (chartData.length - 1).toDouble(),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.3,
              color: AnalyticsDesignSystem.primary,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: chartData.length <= 15,
                getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                  radius: 4,
                  color: AnalyticsDesignSystem.primary,
                  strokeWidth: 2,
                  strokeColor: AnalyticsDesignSystem.backgroundSecondary,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AnalyticsDesignSystem.primary.withValues(alpha: 0.25),
                    AnalyticsDesignSystem.primary.withValues(alpha: 0.05),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_ChartDataPoint> _createChartData() {
    final dataPoints = <_ChartDataPoint>[];

    switch (selectedPeriod) {
      case 'mes':
        dataPoints.addAll(_createMonthlyData());
        break;
      case 'trimestre':
        dataPoints.addAll(_createQuarterlyData());
        break;
      case 'año':
        dataPoints.addAll(_createYearlyData());
        break;
      default:
        dataPoints.addAll(_createCustomData());
    }

    return dataPoints;
  }

  List<_ChartDataPoint> _createMonthlyData() {
    final daysInMonth = DateTime(dateRange.start.year, dateRange.start.month + 1, 0).day;
    final dailyBalances = <int, double>{};

    for (int day = 1; day <= daysInMonth; day++) {
      dailyBalances[day] = 0;
    }

    for (var transaction in transactions) {
      final day = transaction.fecha.day;
      final amount = transaction.tipo == 'ingreso' ? transaction.monto : -transaction.monto;
      dailyBalances[day] = (dailyBalances[day] ?? 0) + amount;
    }

    final points = <_ChartDataPoint>[];
    int index = 0;

    for (int day = 1; day <= daysInMonth; day++) {
      final showLabel = daysInMonth <= 15 || day == 1 || day == daysInMonth || day % 3 == 0;
      points.add(_ChartDataPoint(
        index: index,
        label: showLabel ? '$day' : '',
        balance: dailyBalances[day]!,
        sortKey: day.toDouble(),
      ));
      index++;
    }

    return points;
  }

  List<_ChartDataPoint> _createQuarterlyData() {
    final weeklyBalances = <int, double>{};

    for (var transaction in transactions) {
      final weekNumber = _getWeekOfQuarter(transaction.fecha);
      final amount = transaction.tipo == 'ingreso' ? transaction.monto : -transaction.monto;
      weeklyBalances[weekNumber] = (weeklyBalances[weekNumber] ?? 0) + amount;
    }

    final weeks = weeklyBalances.keys.toList()..sort();
    if (weeks.isEmpty) return [];

    final minWeek = weeks.first;
    final maxWeek = weeks.last;

    final points = <_ChartDataPoint>[];
    int index = 0;

    for (int week = minWeek; week <= maxWeek; week++) {
      final balance = weeklyBalances[week] ?? 0;
      points.add(_ChartDataPoint(
        index: index,
        label: 'S$week',
        balance: balance,
        sortKey: week.toDouble(),
      ));
      index++;
    }

    return points;
  }

  List<_ChartDataPoint> _createYearlyData() {
    final monthlyBalances = <int, double>{};

    for (int month = 1; month <= 12; month++) {
      monthlyBalances[month] = 0;
    }

    for (var transaction in transactions) {
      final month = transaction.fecha.month;
      final amount = transaction.tipo == 'ingreso' ? transaction.monto : -transaction.monto;
      monthlyBalances[month] = (monthlyBalances[month] ?? 0) + amount;
    }

    const monthNames = ['E', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];

    final points = <_ChartDataPoint>[];
    for (int month = 1; month <= 12; month++) {
      points.add(_ChartDataPoint(
        index: month - 1,
        label: monthNames[month - 1],
        balance: monthlyBalances[month]!,
        sortKey: month.toDouble(),
      ));
    }

    return points;
  }

  List<_ChartDataPoint> _createCustomData() {
    final Map<DateTime, double> dailyBalances = {};

    for (var transaction in transactions) {
      final dateKey = DateTime(transaction.fecha.year, transaction.fecha.month, transaction.fecha.day);
      final amount = transaction.tipo == 'ingreso' ? transaction.monto : -transaction.monto;
      dailyBalances[dateKey] = (dailyBalances[dateKey] ?? 0) + amount;
    }

    final sortedDates = dailyBalances.keys.toList()..sort();

    final points = <_ChartDataPoint>[];
    int index = 0;

    for (var date in sortedDates) {
      final showLabel = sortedDates.length <= 10 || index % 2 == 0;
      points.add(_ChartDataPoint(
        index: index,
        label: showLabel ? DateFormat('dd/MM').format(date) : '',
        balance: dailyBalances[date]!,
        sortKey: date.millisecondsSinceEpoch.toDouble(),
      ));
      index++;
    }

    return points;
  }

  int _getWeekOfQuarter(DateTime date) {
    final quarterStart = ((date.month - 1) ~/ 3) * 3 + 1;
    final quarterStartDate = DateTime(date.year, quarterStart, 1);
    final difference = date.difference(quarterStartDate).inDays;
    return (difference ~/ 7) + 1;
  }

  String _getChartTitle() {
    switch (selectedPeriod) {
      case 'mes':
        return 'Balance Diario';
      case 'trimestre':
        return 'Balance Semanal';
      case 'año':
        return 'Balance Mensual';
      default:
        return 'Balance del Período';
    }
  }

  String _getChartSubtitle() {
    switch (selectedPeriod) {
      case 'mes':
        return 'Ingresos - Gastos por día';
      case 'trimestre':
        return 'Ingresos - Gastos por semana';
      case 'año':
        return 'Ingresos - Gastos por mes';
      default:
        return 'Ingresos - Gastos';
    }
  }

  double _calculateYInterval(List<FlSpot> spots) {
    if (spots.isEmpty) return 500;

    final values = spots.map((spot) => spot.y).toList();
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final range = (maxValue - minValue).abs();

    if (range == 0) {
      if (maxValue.abs() < 100) return 20;
      if (maxValue.abs() < 1000) return 200;
      return 1000;
    }

    final roughInterval = range / 5;

    if (roughInterval < 10) return 10;
    if (roughInterval < 20) return 20;
    if (roughInterval < 50) return 50;
    if (roughInterval < 100) return 100;
    if (roughInterval < 200) return 200;
    if (roughInterval < 500) return 500;
    if (roughInterval < 1000) return 1000;
    if (roughInterval < 2000) return 2000;
    if (roughInterval < 5000) return 5000;
    if (roughInterval < 10000) return 10000;
    if (roughInterval < 20000) return 20000;
    if (roughInterval < 50000) return 50000;
    return 100000;
  }

  int _calculateBottomInterval(int dataCount) {
    if (dataCount <= 7) return 1;
    if (dataCount <= 12) return 2;
    if (dataCount <= 20) return 3;
    if (dataCount <= 31) return 5;
    return 7;
  }

  Set<double> _calculateUniqueYValues(List<FlSpot> spots, double interval) {
    if (spots.isEmpty) return {};

    final values = spots.map((spot) => spot.y).toList();
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final minValue = values.reduce((a, b) => a < b ? a : b);

    final minRounded = (minValue / interval).floor() * interval;
    final maxRounded = (maxValue / interval).ceil() * interval;

    final allValues = <double>[];
    double current = minRounded;
    while (current <= maxRounded) {
      allValues.add(current);
      current += interval;
    }

    final uniqueFormatted = <String, double>{};
    for (var value in allValues) {
      final formatted = _formatYAxisValue(value);
      if (!uniqueFormatted.containsKey(formatted)) {
        uniqueFormatted[formatted] = value;
      }
    }

    return uniqueFormatted.values.toSet();
  }

  String _formatYAxisValue(double value) {
    if (value == 0) return '0';

    final absValue = value.abs();
    final sign = value < 0 ? '-' : '';

    if (absValue >= 1000000) {
      final millions = absValue / 1000000;
      final rounded = millions.round();

      if ((millions - rounded).abs() < 0.05) {
        return '$sign${rounded}M';
      }

      final formatted = millions.toStringAsFixed(1);
      return '$sign${formatted.replaceAll('.0', '')}M';
    }

    if (absValue >= 1000) {
      final thousands = absValue / 1000;
      final rounded = thousands.round();

      if ((thousands - rounded).abs() < 0.05) {
        return '$sign${rounded}k';
      }

      if (thousands < 10) {
        final formatted = thousands.toStringAsFixed(1);
        return '$sign${formatted.replaceAll('.0', '')}k';
      }

      return '$sign${rounded}k';
    }

    return '$sign${absValue.round()}';
  }
}

class _ChartDataPoint {
  final int index;
  final String label;
  final double balance;
  final double sortKey;

  _ChartDataPoint({
    required this.index,
    required this.label,
    required this.balance,
    required this.sortKey,
  });
}

