import 'package:flutter/material.dart';

import '../../core/models/transaction_model.dart';
import '../../core/repos/transaction_repo.dart';
import '../../core/utils/date_utils.dart';
import '../profile/profile_screen.dart';
import '../transactions/add_transaction_screen.dart';
import '../transactions/transaction_detail_screen.dart';
import 'analytics_screen.dart';
import 'reports_screen.dart';
import 'search_filter_screen.dart';

/// Contenedor principal con la barra de navegación.
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
      const ReportsScreen(),
      const ProfileScreen(),
    ];
  }

  // Widget para construir cada item de la barra de navegación
  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _pageIndex == index;
    const activeColor = Colors.white;
    final inactiveColor = Colors.white.withValues(alpha: 0.93); // 93% de opacidad

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _pageIndex = index),
        borderRadius: BorderRadius.circular(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Efecto de luz superior
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
                          color: activeColor.withValues(alpha: 0.70), // 70% de opacidad
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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _pageIndex == 0
          ? AppBar(
              backgroundColor: Colors.grey[900],
              centerTitle: true,
              title: const Text(
                'Mis Gastos',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              leading: IconButton(
                icon: const Icon(Icons.search, color: Colors.white),
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
                  icon: const Icon(Icons.date_range, color: Colors.white),
                  onPressed: () async {
                    _transactionsPageKey.currentState?.selectDateRange();
                  },
                ),
              ],
            )
          : null,
      body: _pages[_pageIndex],
      bottomNavigationBar: BottomAppBar(
        color: Colors.grey[900],
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
          ? FloatingActionButton(
              onPressed: () async {
                final saved = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => const AddTransactionScreen()),
                );
                if (saved == true) {
                  _transactionsPageKey.currentState?._loadTransactions();
                }
              },
              tooltip: 'Nueva transacción',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}


/// Widget para la página de transacciones (el contenido de la antigua home).
class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key});

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  final _repo = TransactionRepo();
  late Future<List<AppTransaction>> _futureTransactions;

  List<String> _tipoFilters = ['todos']; // Cambiar a lista para múltiples tipos
  List<String> _orderFilters = []; // Cambiar a lista para múltiples órdenes
  DateTimeRange? _range;
  String? _searchTerm;

  // Getters públicos para acceder desde el AppBar
  String get tipoFilter => _tipoFilters.contains('todos') ? 'todos' : _tipoFilters.first;
  String get order => _orderFilters.isNotEmpty ? _orderFilters.first : 'fecha_desc';
  DateTimeRange? get range => _range;
  String? get searchTerm => _searchTerm;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  void _loadTransactions() {
    if (!mounted) return;
    setState(() {
      _futureTransactions = _repo.listMultiple(
        tipos: _tipoFilters.contains('todos') ? null : _tipoFilters,
        from: _range?.start,
        to: _range?.end,
        orders: _orderFilters.isNotEmpty ? _orderFilters : ['fecha_desc'], // Pasar lista de órdenes
        searchTerm: _searchTerm,
      );
    });
  }

  void updateFilters(Map<String, dynamic> filters) {
    setState(() {
      // Manejar tanto el formato anterior como el nuevo
      if (filters.containsKey('tipos')) {
        _tipoFilters = List<String>.from(filters['tipos']);
      } else if (filters.containsKey('tipo')) {
        _tipoFilters = [filters['tipo']];
      }

      // Manejar órdenes múltiples
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
    return SafeArea(
      child: Column(
        children: [
          // Barra de fecha
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            color: Colors.black,
            child: Text(
              _getCurrentDateString(),
              style: const TextStyle(
                color: Color(0xFFE0E0E0), // Gris claro tirando a blanco
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
              textAlign: TextAlign.left,
            ),
          ),
          Expanded(
            child: FutureBuilder<List<AppTransaction>>(
              future: _futureTransactions,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.white));
                }
                if (snapshot.hasError) {
                  return Center(child: Text('❌ Error: ${snapshot.error}', style: TextStyle(color: Colors.white)));
                }

                final transactions = snapshot.data ?? [];
                if (transactions.isEmpty) {
                  return const Center(child: Text('No hay transacciones con el filtro actual', style: TextStyle(color: Colors.white)));
                }

                return ListView.builder(
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final t = transactions[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        leading: Icon(
                          t.tipo == 'ingreso'
                              ? Icons.arrow_upward
                              : t.tipo == 'egreso'
                                  ? Icons.arrow_downward
                                  : Icons.swap_horiz,
                          color: t.tipo == 'ingreso'
                              ? Colors.green
                              : t.tipo == 'egreso'
                                  ? Colors.red
                                  : Colors.blue,
                        ),
                        title: Text(
                          'S/. ${t.monto.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${t.etiqueta ?? 'Sin etiqueta'}\n${formatDate(t.fecha)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        isThreeLine: true,
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
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _getCurrentDateString() {
    final now = DateTime.now();
    final months = [
      'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic'
    ];
    final weekdays = [
      'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'
    ];

    final day = now.day;
    final month = months[now.month - 1];
    final weekday = weekdays[now.weekday - 1];

    return '$day $month    $weekday';
  }
}
