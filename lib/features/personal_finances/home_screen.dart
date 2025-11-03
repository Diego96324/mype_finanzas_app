import 'package:flutter/material.dart';

import '../../core/models/transaction_model.dart';
import '../../core/repos/transaction_repo.dart';
import '../../core/services/auth_service.dart';
import '../../core/utils/date_picker_theme.dart';
import '../profile/profile_screen.dart';
import '../transactions/add_transaction_screen.dart';
import '../transactions/transaction_detail_screen.dart';
import '../analytics/analytics_screen.dart';
import 'reports_screen.dart' as reports;
import 'search_filter_screen.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _pageIndex = 0;

  final GlobalKey<_TransactionsPageState> _transactionsPageKey = GlobalKey();

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      TransactionsPage(key: _transactionsPageKey),
      const AnalyticsScreen(),
      const reports.ReportsScreen(),
      const ProfileScreen(),
    ];
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _pageIndex == index;
    final colorScheme = Theme.of(context).colorScheme;
    final activeColor = colorScheme.onSurface;
    final inactiveColor = colorScheme.onSurface.withValues(alpha: 0.6);

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _pageIndex = index),
        borderRadius: BorderRadius.circular(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 3,
              width: isSelected ? 30 : 0,
              decoration: BoxDecoration(
                color: activeColor,
                borderRadius: BorderRadius.circular(2),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: activeColor.withValues(alpha: 0.70),
                          blurRadius: 10,
                          spreadRadius: 3,
                          offset: const Offset(0, -1),
                        ),
                      ]
                    : [],
              ),
            ),
            const SizedBox(height: 6),
            Icon(
              icon,
              color: isSelected ? activeColor : inactiveColor,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? activeColor : inactiveColor,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: _pageIndex == 0
          ? AppBar(
              backgroundColor: theme.appBarTheme.backgroundColor,
              centerTitle: true,
              title: Text(
                'Mis Gastos',
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              leading: IconButton(
                icon: Icon(Icons.search, color: colorScheme.onSurface),
                onPressed: () async {
                  final result = await Navigator.push<Map<String, dynamic>>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SearchFilterScreen(
                        initialFilters: {
                          'tipo': _transactionsPageKey.currentState?.tipoFilter ?? 'todos',
                          'order': _transactionsPageKey.currentState?.order ?? 'fecha_desc',
                          'searchTerm': _transactionsPageKey.currentState?.searchTerm,
                        },
                      ),
                    ),
                  );
                  if (result != null) {
                    _transactionsPageKey.currentState?.updateFilters(result);
                  }
                },
              ),
              actions: [
                IconButton(
                  tooltip: _transactionsPageKey.currentState?.range == null
                      ? 'Filtrar por fecha'
                      : 'Rango activo',
                  icon: Icon(Icons.date_range, color: colorScheme.onSurface),
                  onPressed: () async {
                    _transactionsPageKey.currentState?.selectDateRange();
                  },
                ),
              ],
            )
          : null,
      body: _pages[_pageIndex],
      bottomNavigationBar: BottomAppBar(
        color: theme.appBarTheme.backgroundColor,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(Icons.list_alt, 'Transacciones', 0),
            _buildNavItem(Icons.bar_chart, 'Análisis', 1),
            _buildNavItem(Icons.assignment, 'Informes', 2),
            _buildNavItem(Icons.person, 'Perfil', 3),
          ],
        ),
      ),
      floatingActionButton: _pageIndex == 0
          ? Container(
              width: 65,
              height: 65,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [colorScheme.primary, colorScheme.secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.primary.withValues(alpha: 0.5),
                    blurRadius: 20,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(32.5),
                  onTap: () async {
                    final saved = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(builder: (_) => const AddTransactionScreen()),
                    );
                    if (saved == true) {
                      _transactionsPageKey.currentState?._loadTransactions();
                    }
                  },
                  child: Center(
                    child: Icon(
                      Icons.add_rounded,
                      color: colorScheme.onPrimary,
                      size: 32,
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key});

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> with WidgetsBindingObserver {
  final _repo = TransactionRepo();
  late Future<List<AppTransaction>> _futureTransactions;

  List<String> _tipoFilters = ['todos'];
  List<String> _orderFilters = [];
  DateTimeRange? _range;
  String? _searchTerm;

  late Future<double> _totalIngresos;
  late Future<double> _totalEgresos;

  String get tipoFilter => _tipoFilters.contains('todos') ? 'todos' : _tipoFilters.first;
  String get order => _orderFilters.isNotEmpty ? _orderFilters.first : 'fecha_desc';
  DateTimeRange? get range => _range;
  String? get searchTerm => _searchTerm;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadTransactions();
    _loadTotals();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() {});
    }
  }

  void _loadTransactions() {
    if (!mounted) return;
    final authService = AuthService();
    final usuarioId = authService.currentUserId;

    _futureTransactions = _repo.listMultiple(
      usuarioId: usuarioId,
      tipos: _tipoFilters.contains('todos') ? null : _tipoFilters,
      from: _range?.start,
      to: _range?.end,
      orders: _orderFilters.isNotEmpty ? _orderFilters : ['fecha_desc'],
      searchTerm: _searchTerm,
    );

    if (mounted) setState(() {});
    _loadTotalsAsync();
  }

  void _loadTotals() {
    if (!mounted) return;
    final authService = AuthService();
    final usuarioId = authService.currentUserId;

    _totalIngresos = _repo.total('ingreso', usuarioId: usuarioId);
    _totalEgresos = _repo.total('egreso', usuarioId: usuarioId);

    if (mounted) setState(() {});
  }

  Future<void> _loadTotalsAsync() async {
    if (!mounted) return;
    final authService = AuthService();
    final usuarioId = authService.currentUserId;

    final results = await Future.wait([
      _repo.total('egreso', usuarioId: usuarioId),
      _repo.total('ingreso', usuarioId: usuarioId),
    ]);

    if (!mounted) return;

    _totalEgresos = Future.value(results[0]);
    _totalIngresos = Future.value(results[1]);

    if (mounted) setState(() {});
  }

  void updateFilters(Map<String, dynamic> filters) {
    setState(() {
      if (filters.containsKey('tipos')) {
        _tipoFilters = List<String>.from(filters['tipos']);
      } else if (filters.containsKey('tipo')) {
        _tipoFilters = [filters['tipo']];
      }

      if (filters.containsKey('orders')) {
        _orderFilters = List<String>.from(filters['orders']);
      } else if (filters.containsKey('order')) {
        _orderFilters = [filters['order']];
      }

      _searchTerm = filters['searchTerm'];
      _loadTransactions();
    });
  }

  Future<void> selectDateRange() async {
    final now = DateTime.now();
    final initial = _range ??
        DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month + 1, 0),
        );
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2010),
      lastDate: DateTime(2100),
      initialDateRange: initial,
      helpText: 'Selecciona rango',
      locale: const Locale('es', 'PE'),
      builder: (context, child) {
        return Theme(
          data: AppDatePickerTheme.darkDateRangePickerTheme(context),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _range = picked;
        _loadTransactions();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SafeArea(
      child: Container(
        color: theme.scaffoldBackgroundColor,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                border: Border(
                  bottom: BorderSide(
                    color: theme.dividerColor,
                    width: 1,
                  ),
                ),
              ),
              child: FutureBuilder<List<double>>(
                future: Future.wait([_totalEgresos, _totalIngresos]),
                builder: (context, snapshot) {
                  final egresos = snapshot.data?[0] ?? 0.0;
                  final ingresos = snapshot.data?[1] ?? 0.0;
                  final saldo = ingresos - egresos;

                  return Row(
                    children: [
                      Expanded(
                        child: _buildCompactStatCard(
                          context,
                          'Gastos',
                          egresos,
                          Icons.trending_down_rounded,
                          Colors.redAccent,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildCompactStatCard(
                          context,
                          'Ingresos',
                          ingresos,
                          Icons.trending_up_rounded,
                          Colors.greenAccent,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildCompactStatCard(
                          context,
                          'Saldo',
                          saldo,
                          Icons.account_balance_wallet_rounded,
                          saldo >= 0 ? Colors.blueAccent : Colors.orangeAccent,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            Expanded(
              child: Container(
                color: theme.scaffoldBackgroundColor,
                child: FutureBuilder<List<AppTransaction>>(
                  future: _futureTransactions,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 40,
                              height: 40,
                              child: CircularProgressIndicator(
                                color: colorScheme.primary,
                                strokeWidth: 3,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Cargando transacciones...',
                              style: TextStyle(
                                color: colorScheme.onSurface.withValues(alpha: 0.7),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline_rounded,
                              color: colorScheme.error,
                              size: 48,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Error al cargar',
                              style: TextStyle(
                                color: colorScheme.onSurface,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${snapshot.error}',
                              style: TextStyle(
                                color: colorScheme.onSurface.withValues(alpha: 0.6),
                                fontSize: 13,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }

                    final transactions = snapshot.data ?? [];

                    if (transactions.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: colorScheme.primary.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.receipt_long_rounded,
                                size: 40,
                                color: colorScheme.primary.withValues(alpha: 0.5),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No hay transacciones',
                              style: TextStyle(
                                color: colorScheme.onSurface,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Toca el botón + para agregar una',
                              style: TextStyle(
                                color: colorScheme.onSurface.withValues(alpha: 0.6),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final groupedTransactions = _groupTransactionsByDate(transactions);

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      itemCount: groupedTransactions.length,
                      itemBuilder: (context, groupIndex) {
                        final group = groupedTransactions[groupIndex];
                        final date = group['date'] as DateTime;
                        final txList = group['transactions'] as List<AppTransaction>;

                        double dayIngresos = 0;
                        double dayEgresos = 0;
                        for (var tx in txList) {
                          if (tx.tipo == 'ingreso') {
                            dayIngresos += tx.monto;
                          } else if (tx.tipo == 'egreso') {
                            dayEgresos += tx.monto;
                          }
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildDateSeparator(context, date, dayEgresos, dayIngresos),

                            ...txList.map((t) {
                              final Color typeColor;

                              switch (t.tipo) {
                                case 'ingreso':
                                  typeColor = Colors.greenAccent;
                                  break;
                                case 'egreso':
                                  typeColor = Colors.redAccent;
                                  break;
                                default:
                                  typeColor = Colors.blueAccent;
                              }

                              return Container(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  decoration: BoxDecoration(
                                    color: theme.cardColor,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: typeColor.withValues(alpha: 0.2),
                                      width: 1,
                                    ),
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(10),
                                      onTap: () async {
                                        final changed = await Navigator.push<bool>(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => TransactionDetailScreen(tx: t),
                                          ),
                                        );
                                        if (changed == true) {
                                          _loadTransactions();
                                        }
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 32,
                                              height: 32,
                                              decoration: BoxDecoration(
                                                color: typeColor.withValues(alpha: 0.12),
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: typeColor.withValues(alpha: 0.3),
                                                  width: 1.5,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),

                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    t.etiqueta ?? 'Sin etiqueta',
                                                    style: TextStyle(
                                                      color: colorScheme.onSurface,
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  if (t.nota != null && t.nota!.isNotEmpty) ...[
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      t.nota!,
                                                      style: TextStyle(
                                                        color: colorScheme.onSurface.withValues(alpha: 0.5),
                                                        fontSize: 11,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),

                                            const SizedBox(width: 8),

                                            Text(
                                              'S/. ${t.monto.toStringAsFixed(2)}',
                                              style: TextStyle(
                                                color: typeColor,
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Icon(
                                              Icons.chevron_right_rounded,
                                              color: colorScheme.onSurface.withValues(alpha: 0.25),
                                              size: 18,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                            }),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactStatCard(BuildContext context, String label, double amount, IconData icon, Color color) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 18,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: colorScheme.onSurface.withValues(alpha: 0.7),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'S/. ${amount.toStringAsFixed(2)}',
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _groupTransactionsByDate(List<AppTransaction> transactions) {
    final Map<String, List<AppTransaction>> grouped = {};

    for (var tx in transactions) {
      final dateKey = '${tx.fecha.year}-${tx.fecha.month.toString().padLeft(2, '0')}-${tx.fecha.day.toString().padLeft(2, '0')}';
      if (!grouped.containsKey(dateKey)) {
        grouped[dateKey] = [];
      }
      grouped[dateKey]!.add(tx);
    }

    final result = grouped.entries.map((entry) {
      return {
        'date': DateTime.parse(entry.key),
        'transactions': entry.value,
      };
    }).toList();

    result.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));

    return result;
  }

  Widget _buildDateSeparator(BuildContext context, DateTime date, double dayEgresos, double dayIngresos) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final now = DateTime.now();
    final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
    final isYesterday = date.year == now.year && date.month == now.month && date.day == now.day - 1;

    final months = [
      'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic'
    ];
    final weekdays = [
      'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'
    ];

    final dateStr = isToday
        ? 'Hoy'
        : isYesterday
            ? 'Ayer'
            : '${date.day} ${months[date.month - 1]} • ${weekdays[date.weekday - 1]}';

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.dividerColor,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.calendar_today_rounded,
            color: colorScheme.primary,
            size: 14,
          ),
          const SizedBox(width: 8),
          Text(
            dateStr,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          if (dayEgresos > 0) ...[
            Icon(
              Icons.arrow_downward_rounded,
              color: Colors.redAccent,
              size: 12,
            ),
            const SizedBox(width: 2),
            Text(
              'S/. ${dayEgresos.toStringAsFixed(2)}',
              style: const TextStyle(
                color: Colors.redAccent,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (dayEgresos > 0 && dayIngresos > 0) const SizedBox(width: 12),
          if (dayIngresos > 0) ...[
            Icon(
              Icons.arrow_upward_rounded,
              color: Colors.greenAccent,
              size: 12,
            ),
            const SizedBox(width: 2),
            Text(
              'S/. ${dayIngresos.toStringAsFixed(2)}',
              style: const TextStyle(
                color: Colors.greenAccent,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
