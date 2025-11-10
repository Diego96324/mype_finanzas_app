import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../../../../data/models/transaction_model.dart';
import '../../../../core/theme/components/date_picker_theme.dart';
import '../../transactions/views/add_transaction_view.dart';
import '../controllers/analytics_controller.dart';
import '../../../shared/utils/currency_formatter.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Período seleccionado (mes, trimestre, año, personalizado)
  String _selectedPeriod = 'mes';

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _changePeriod(String period) {
    setState(() {
      _selectedPeriod = period;
    });

    // Le decimos al controlador que cambie el período
    ref.read(analyticsControllerProvider.notifier).changePeriod(period);
  }

  void _moveTimeRange(bool forward) {
    // Usamos el métdo del controlador para mover el rango
    ref.read(analyticsControllerProvider.notifier).moveTimeRange(forward);
  }

  Future<void> _selectCustomRange() async {
    final state = ref.read(analyticsControllerProvider);
    final currentRange = state.dateRange ?? DateTimeRange(
      start: DateTime.now().subtract(const Duration(days: 30)),
      end: DateTime.now(),
    );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: currentRange,
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
        _selectedPeriod = 'personalizado';
      });
      // Le decimos al controlador que cambie al rango personalizado
      ref.read(analyticsControllerProvider.notifier)
          .changePeriod('personalizado', customRange: picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Observamos el estado del controlador
    final state = ref.watch(analyticsControllerProvider);
    final transactions = state.transactions;
    final isLoading = state.isLoading;
    final error = state.error;

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        leading: const SizedBox(width: 48),
        title: const Text(
          'Análisis',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF2D2D2D),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              // Refrescamos usando el controlador
              ref.read(analyticsControllerProvider.notifier).refresh();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // Refrescamos usando el controlador
          await ref.read(analyticsControllerProvider.notifier).refresh();
        },
        color: const Color(0xFF13BB67),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: isLoading && transactions.isEmpty
              ? _buildLoadingState()
              : error != null
                  ? _buildErrorState(error)
                  : _buildAnalyticsContent(transactions),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: const Color(0xFF13BB67),
          ),
          const SizedBox(height: 16),
          Text(
            'Cargando análisis...',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(
            'Error al cargar datos',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[300],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsContent(List<AppTransaction> transactions) {
    if (transactions.isEmpty) {
      return _buildEmptyState();
    }

    // Calcular estadísticas
    double totalIngresos = 0;
    double totalGastos = 0;

    for (var t in transactions) {
      if (t.tipo == 'ingreso') {
        totalIngresos += t.monto;
      } else if (t.tipo == 'gasto' || t.tipo == 'egreso') {
        totalGastos += t.monto;
      }
    }

    final balance = totalIngresos - totalGastos;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        children: [
          // Selector de período
          _buildPeriodSelector(),

          // Línea de tiempo deslizable
          _buildTimeline(),

          // Tarjetas de resumen
          _buildSummaryCards(totalIngresos, totalGastos, balance),

          // Gráfico de barras
          _buildBarChart(transactions),

          // Gráfico circular
          _buildPieChart(totalIngresos, totalGastos),

          // Transacciones recientes
          _buildRecentTransactions(transactions),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icono animado
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 600),
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: const Color(0xFF13BB67).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.analytics_outlined,
                        size: 80,
                        color: const Color(0xFF13BB67),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              Text(
                'No hay registros',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[300],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'No se encontraron transacciones en el período seleccionado',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[500],
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              _buildPeriodSelector(),
              const SizedBox(height: 16),
              _buildTimeline(),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  final state = ref.read(analyticsControllerProvider);
                  final dateRange = state.dateRange;

                  // Navegar a agregar transacción
                  Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute(
                      builder: (context) => AddTransactionScreen(
                        initialDate: dateRange?.start ?? DateTime.now(),
                        allowedDateRange: dateRange,
                      ),
                    ),
                  ).then((_) {
                    // Recargar usando el controlador
                    ref.read(analyticsControllerProvider.notifier).refresh();
                  });
                },
                icon: const Icon(Icons.add),
                label: const Text('Agregar Transacción'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF13BB67),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D2D),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildPeriodChip('Semana', 'semana'),
          _buildPeriodChip('Mes', 'mes'),
          _buildPeriodChip('Año', 'año'),
          _buildPeriodChip('Custom', 'personalizado', onTap: _selectCustomRange),
        ],
      ),
    );
  }

  Widget _buildPeriodChip(String label, String value, {VoidCallback? onTap}) {
    final isSelected = _selectedPeriod == value;

    return Expanded(
      child: GestureDetector(
        onTap: onTap ?? () => _changePeriod(value),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF13BB67) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey[400],
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeline() {
    final state = ref.watch(analyticsControllerProvider);
    final dateRange = state.dateRange;

    if (dateRange == null) {
      return const SizedBox.shrink();
    }

    final formatter = DateFormat('dd MMM yyyy', 'es');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF13BB67),
            const Color(0xFF13BB67).withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF13BB67).withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () => _moveTimeRange(false),
                icon: const Icon(Icons.chevron_left, color: Colors.white),
                tooltip: 'Período anterior',
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'Período Seleccionado',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${formatter.format(dateRange.start)} - ${formatter.format(dateRange.end)}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _moveTimeRange(true),
                icon: const Icon(Icons.chevron_right, color: Colors.white),
                tooltip: 'Período siguiente',
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Indicador visual de línea de tiempo
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
            child: FractionallySizedBox(
              widthFactor: 0.5,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(double ingresos, double gastos, double balance) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Ingresos',
                  ingresos,
                  Icons.trending_up,
                  const Color(0xFF13BB67),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  'Gastos',
                  gastos,
                  Icons.trending_down,
                  Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildSummaryCard(
            'Balance',
            balance,
            Icons.account_balance_wallet,
            balance >= 0 ? const Color(0xFF13BB67) : Colors.orange,
            isLarge: true,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, double amount, IconData icon, Color color, {bool isLarge = false}) {

    return Container(
      padding: EdgeInsets.all(isLarge ? 20 : 16),
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D2D),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: isLarge ? CrossAxisAlignment.center : CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (!isLarge) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[400],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'S/ ${CurrencyFormatter.formatAmount(amount)}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
          if (isLarge) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[400],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'S/ ${CurrencyFormatter.formatAmount(amount)}',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBarChart(List<AppTransaction> transactions) {
    // Agrupar por día
    final Map<DateTime, double> ingresosDay = {};
    final Map<DateTime, double> gastosDay = {};

    for (var t in transactions) {
      final day = DateTime(t.fecha.year, t.fecha.month, t.fecha.day);

      if (t.tipo == 'ingreso') {
        ingresosDay[day] = (ingresosDay[day] ?? 0) + t.monto;
      } else if (t.tipo == 'gasto' || t.tipo == 'egreso') {
        gastosDay[day] = (gastosDay[day] ?? 0) + t.monto;
      }
    }

    // Obtener solo los días con transacciones (sin días vacíos)
    final allDays = {...ingresosDay.keys, ...gastosDay.keys}.toList()..sort();

    if (allDays.isEmpty) return const SizedBox.shrink();

    // Tomar máximo 10 días más recientes para mejor visualización
    final displayDays = allDays.length > 10 ? allDays.sublist(allDays.length - 10) : allDays;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D2D),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF13BB67).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.bar_chart,
                  color: Color(0xFF13BB67),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Ingresos vs Gastos',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[200],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 250,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceEvenly,
                maxY: _getMaxValue(ingresosDay, gastosDay) * 1.2,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (group) => Colors.black87,
                    tooltipPadding: const EdgeInsets.all(8),
                    tooltipMargin: 8,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final day = displayDays[group.x.toInt()];
                      final formatter = DateFormat('dd/MM', 'es');

                      return BarTooltipItem(
                        '${formatter.format(day)}\n',
                        const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        children: [
                          TextSpan(
                            text: 'S/ ${CurrencyFormatter.formatAmount(rod.toY)}',
                            style: TextStyle(
                              color: rodIndex == 0 ? const Color(0xFF13BB67) : Colors.red,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= displayDays.length) return const SizedBox.shrink();
                        final day = displayDays[value.toInt()];

                        // Si hay pocas transacciones, mostrar día/mes, sino solo día
                        final format = displayDays.length <= 7 ? 'dd/MM' : 'dd';

                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            DateFormat(format, 'es').format(day),
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                      reservedSize: 30,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          NumberFormat.compact(locale: 'es').format(value),
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: _getMaxValue(ingresosDay, gastosDay) / 5,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey[800],
                      strokeWidth: 1,
                    );
                  },
                ),
                borderData: FlBorderData(show: false),
                barGroups: displayDays.asMap().entries.map((entry) {
                  final index = entry.key;
                  final day = entry.value;

                  // Ajustar ancho de barras según cantidad de días
                  final barWidth = displayDays.length <= 5 ? 12.0 : 8.0;

                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: ingresosDay[day] ?? 0,
                        color: const Color(0xFF13BB67),
                        width: barWidth,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                      BarChartRodData(
                        toY: gastosDay[day] ?? 0,
                        color: Colors.red,
                        width: barWidth,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem('Ingresos', const Color(0xFF13BB67)),
              const SizedBox(width: 24),
              _buildLegendItem('Gastos', Colors.red),
            ],
          ),
        ],
      ),
    );
  }

  double _getMaxValue(Map<DateTime, double> ingresos, Map<DateTime, double> gastos) {
    final maxIngreso = ingresos.values.isEmpty ? 0.0 : ingresos.values.reduce((a, b) => a > b ? a : b);
    final maxGasto = gastos.values.isEmpty ? 0.0 : gastos.values.reduce((a, b) => a > b ? a : b);
    return maxIngreso > maxGasto ? maxIngreso : maxGasto;
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[400],
          ),
        ),
      ],
    );
  }

  Widget _buildPieChart(double ingresos, double gastos) {
    if (ingresos == 0 && gastos == 0) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D2D),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF13BB67).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.pie_chart,
                  color: Color(0xFF13BB67),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Distribución',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[200],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 60,
                sections: [
                  PieChartSectionData(
                    value: ingresos,
                    title: '${(ingresos / (ingresos + gastos) * 100).toStringAsFixed(1)}%',
                    color: const Color(0xFF13BB67),
                    radius: 50,
                    titleStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  PieChartSectionData(
                    value: gastos,
                    title: '${(gastos / (ingresos + gastos) * 100).toStringAsFixed(1)}%',
                    color: Colors.red,
                    radius: 50,
                    titleStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem('Ingresos', const Color(0xFF13BB67)),
              const SizedBox(width: 24),
              _buildLegendItem('Gastos', Colors.red),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTransactions(List<AppTransaction> transactions) {
    final recent = transactions.take(5).toList();

    if (recent.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D2D),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF13BB67).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.history,
                  color: Color(0xFF13BB67),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Últimas transacciones',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[200],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...recent.map((t) => _buildCompactTransactionItem(t)),
        ],
      ),
    );
  }

  Widget _buildCompactTransactionItem(AppTransaction transaction) {
    final isIngreso = transaction.tipo == 'ingreso';
    final color = isIngreso ? const Color(0xFF13BB67) : Colors.red;
    final etiqueta = transaction.etiqueta ?? (isIngreso ? 'Ingreso' : 'Egreso');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fila con etiqueta y monto
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  etiqueta,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[300],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'S/ ${CurrencyFormatter.formatAmount(transaction.monto)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Barra de progreso (100%)
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: 1.0,
              minHeight: 6,
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}
