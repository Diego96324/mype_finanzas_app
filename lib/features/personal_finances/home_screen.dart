import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/transaction_model.dart';
import '../../core/utils/date_picker_theme.dart';
import '../profile/profile_screen.dart';
import '../transactions/add_transaction_screen.dart';
import '../transactions/transaction_detail_screen.dart';
import '../analytics/analytics_screen.dart';
import 'reports_screen.dart' as reports;
import 'search_filter_screen.dart';
import '../transactions/controllers/transactions_controller.dart';

class MyHomePage extends ConsumerStatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  ConsumerState<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends ConsumerState<MyHomePage> {
  int _pageIndex = 0;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      const TransactionsPage(),
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
                  // Obtenemos los filtros actuales del controlador
                  final controller = ref.read(transactionsControllerProvider.notifier);

                  final result = await Navigator.push<Map<String, dynamic>>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SearchFilterScreen(
                        initialFilters: {
                          'tipo': controller.currentTypeFilter,
                          'order': controller.currentOrder,
                          'searchTerm': controller.currentSearchTerm,
                        },
                      ),
                    ),
                  );
                  if (result != null) {
                    // Aplicamos los filtros directamente al controlador
                    controller.updateFiltersFromMap(result);
                  }
                },
              ),
              actions: [
                IconButton(
                  tooltip: () {
                    final state = ref.watch(transactionsControllerProvider);
                    return state.filters.from != null && state.filters.to != null
                        ? 'Rango activo'
                        : 'Filtrar por fecha';
                  }(),
                  icon: Icon(Icons.date_range, color: colorScheme.onSurface),
                  onPressed: () async {
                    // Obtenemos el rango actual del controlador
                    final now = DateTime.now();
                    final state = ref.read(transactionsControllerProvider);
                    final currentRange = state.filters.from != null && state.filters.to != null
                        ? DateTimeRange(start: state.filters.from!, end: state.filters.to!)
                        : DateTimeRange(
                            start: DateTime(now.year, now.month, 1),
                            end: DateTime(now.year, now.month + 1, 0),
                          );

                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2010),
                      lastDate: DateTime(2100),
                      initialDateRange: currentRange,
                      helpText: 'Selecciona rango',
                      locale: const Locale('es', 'PE'),
                      builder: (context, child) {
                        return Theme(
                          data: AppDatePickerTheme.darkDateRangePickerTheme(context),
                          child: child!,
                        );
                      },
                    );

                    if (picked != null && context.mounted) {
                      // Aplicamos el rango directamente al controlador
                      ref.read(transactionsControllerProvider.notifier)
                          .selectDateRange(picked.start, picked.end);
                    }
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
                      // Recargamos usando el controlador
                      ref.read(transactionsControllerProvider.notifier).reloadAfterCreate();
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

class TransactionsPage extends ConsumerStatefulWidget {
  const TransactionsPage({super.key});

  @override
  ConsumerState<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends ConsumerState<TransactionsPage> {
  DateTimeRange? _range;

  @override
  void initState() {
    super.initState();
    // El controlador ya carga las transacciones automáticamente

    // Debug: ver cuando se carga la página
    WidgetsBinding.instance.addPostFrameCallback((_) {
      print('🔍 [TransactionsPage] Página cargada');
    });
  }

  // Getters que usan los métodos del controlador
  String get tipoFilter {
    return ref.read(transactionsControllerProvider.notifier).currentTypeFilter;
  }

  String get order {
    return ref.read(transactionsControllerProvider.notifier).currentOrder;
  }

  DateTimeRange? get range => _range;

  String? get searchTerm {
    return ref.read(transactionsControllerProvider.notifier).currentSearchTerm;
  }


  void updateFilters(Map<String, dynamic> filters) {
    // Ahora delega el trabajo al controlador
    final controller = ref.read(transactionsControllerProvider.notifier);
    controller.updateFiltersFromMap(filters);
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
      });

      // Le decimos al controlador que filtre por esas fechas
      final controller = ref.read(transactionsControllerProvider.notifier);
      controller.selectDateRange(picked.start, picked.end);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Observamos el estado del controlador
    final state = ref.watch(transactionsControllerProvider);

    // Debug: vemos cuando cambia el estado
    ref.listen<TransactionsState>(
      transactionsControllerProvider,
      (previous, next) {
        print('🔍 [TransactionsPage] Estado cambió:');
        print('   - loading: ${next.isLoading}');
        print('   - transacciones: ${next.transactions.length}');
        print('   - error: ${next.error}');
      },
    );

    final stats = state.stats ?? {};
    final egresos = stats['egresos'] ?? 0.0;
    final ingresos = stats['ingresos'] ?? 0.0;
    final saldo = ingresos - egresos;

    return SafeArea(
      child: Container(
        color: theme.scaffoldBackgroundColor,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colorScheme.surfaceContainerHighest,
                    colorScheme.surface,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                border: Border(
                  bottom: BorderSide(
                    color: theme.dividerColor.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildEnhancedStatCard(
                      context,
                      'Gastos',
                      egresos,
                      Icons.receipt_long_rounded,
                      Colors.redAccent,
                      false,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: _buildEnhancedStatCard(
                      context,
                      'Saldo Total',
                      saldo,
                      Icons.account_balance_wallet_rounded,
                      saldo >= 0 ? const Color(0xFF10A05B) : const Color(0xFFFF9800),
                      true,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildEnhancedStatCard(
                      context,
                      'Ingresos',
                      ingresos,
                      Icons.attach_money_rounded,
                      Colors.greenAccent,
                      false,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: Container(
                color: theme.scaffoldBackgroundColor,
                child: Builder(
                  builder: (context) {
                    // Si está cargando y no hay datos, mostramos el loading
                    if (state.isLoading && state.transactions.isEmpty) {
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

                    // Si hay error, lo mostramos
                    if (state.error != null) {
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
                              state.error!,
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

                    final transactions = state.transactions;

                    // Si no hay transacciones, mostramos el estado vacío
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

                        // Verificamos si hay cambio de año
                        final showYearSeparator = groupIndex > 0 &&
                            date.year != (groupedTransactions[groupIndex - 1]['date'] as DateTime).year;

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
                            // Separador de año si cambia
                            if (showYearSeparator)
                              _buildYearSeparator(context, date.year),

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

                              return Dismissible(
                                key: Key('transaction_${t.id}'),
                                confirmDismiss: (direction) async {
                                  if (direction == DismissDirection.endToStart) {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (BuildContext dialogContext) {
                                        return AlertDialog(
                                          backgroundColor: const Color(0xFF2D2D2D),
                                          title: const Text(
                                            '¿Eliminar transacción?',
                                            style: TextStyle(color: Colors.white),
                                          ),
                                          content: Text(
                                            '¿Estás seguro de que deseas eliminar "${t.etiqueta ?? 'esta transacción'}"?',
                                            style: const TextStyle(color: Colors.grey),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(dialogContext, false),
                                              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                                            ),
                                            ElevatedButton(
                                              onPressed: () => Navigator.pop(dialogContext, true),
                                              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                              child: const Text('Eliminar'),
                                            ),
                                          ],
                                        );
                                      },
                                    );

                                    if (confirm == true) {
                                      final controller = ref.read(transactionsControllerProvider.notifier);
                                      final success = await controller.deleteTransaction(t.id!);

                                      if (success && context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Transacción eliminada'),
                                            backgroundColor: Color(0xFF13BB67),
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      }
                                    }
                                    return false;
                                  } else if (direction == DismissDirection.startToEnd) {
                                    await Navigator.push<bool>(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => TransactionDetailScreen(tx: t),
                                      ),
                                    );
                                    // El controlador se actualiza automáticamente
                                    return false;
                                  }
                                  return false;
                                },
                                background: Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.blueAccent,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  alignment: Alignment.centerLeft,
                                  padding: const EdgeInsets.only(left: 20),
                                  child: const Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.edit_rounded, color: Colors.white, size: 28),
                                      SizedBox(height: 4),
                                      Text(
                                        'Editar',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                secondaryBackground: Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 20),
                                  child: const Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.delete_rounded, color: Colors.white, size: 28),
                                      SizedBox(height: 4),
                                      Text(
                                        'Eliminar',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: theme.cardColor,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: typeColor.withValues(alpha: 0.35),
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.06),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(12),
                                        onTap: () async {
                                          await Navigator.push<bool>(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => TransactionDetailScreen(tx: t),
                                            ),
                                          );
                                          // El controlador se actualiza automáticamente
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 44,
                                                height: 44,
                                                decoration: BoxDecoration(
                                                  color: typeColor.withValues(alpha: 0.15),
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: typeColor.withValues(alpha: 0.35),
                                                    width: 2,
                                                  ),
                                                ),
                                                child: Icon(
                                                  t.tipo == 'ingreso'
                                                      ? Icons.trending_up_rounded
                                                      : Icons.trending_down_rounded,
                                                  color: typeColor,
                                                  size: 22,
                                                ),
                                              ),
                                              const SizedBox(width: 12),

                                              Expanded(
                                                flex: 3,
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      t.etiqueta ?? 'Sin etiqueta',
                                                      style: TextStyle(
                                                        color: colorScheme.onSurface,
                                                        fontSize: 15,
                                                        fontWeight: FontWeight.w600,
                                                        letterSpacing: 0.1,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                    if (t.nota != null && t.nota!.isNotEmpty) ...[
                                                      const SizedBox(height: 3),
                                                      Text(
                                                        t.nota!,
                                                        style: TextStyle(
                                                          color: colorScheme.onSurface.withValues(alpha: 0.55),
                                                          fontSize: 12,
                                                          height: 1.2,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),

                                              const SizedBox(width: 8),

                                              Expanded(
                                                flex: 2,
                                                child: FittedBox(
                                                  fit: BoxFit.scaleDown,
                                                  alignment: Alignment.centerRight,
                                                  child: Text(
                                                    'S/. ${t.monto.toStringAsFixed(2)}',
                                                    style: TextStyle(
                                                      color: typeColor,
                                                      fontSize: 15,
                                                      fontWeight: FontWeight.bold,
                                                      letterSpacing: -0.3,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 4),

                                              Icon(
                                                Icons.chevron_right_rounded,
                                                color: colorScheme.onSurface.withValues(alpha: 0.45),
                                                size: 20,
                                              ),
                                            ],
                                          ),
                                        ),
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

  Widget _buildEnhancedStatCard(
    BuildContext context,
    String label,
    double amount,
    IconData icon,
    Color color,
    bool isHighlighted,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: EdgeInsets.all(isHighlighted ? 14 : 12),
      decoration: BoxDecoration(
        gradient: isHighlighted
            ? LinearGradient(
                colors: [
                  color.withValues(alpha: 0.08),
                  color.withValues(alpha: 0.04),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isHighlighted ? null : colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withValues(alpha: isHighlighted ? 0.35 : 0.25),
          width: isHighlighted ? 2 : 1.5,
        ),
        boxShadow: isHighlighted
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.15),
                  blurRadius: 12,
                  spreadRadius: 1,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(isHighlighted ? 10 : 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: isHighlighted ? 28 : 20,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: colorScheme.onSurface.withValues(alpha: 0.65),
              fontSize: isHighlighted ? 11 : 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'S/. ${amount.toStringAsFixed(2)}',
              style: TextStyle(
                color: color,
                fontSize: isHighlighted ? 16 : 13,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
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

  Widget _buildYearSeparator(BuildContext context, int year) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          // Línea izquierda
          Expanded(
            child: Container(
              height: 0.5,
              color: colorScheme.onSurface.withValues(alpha: 0.15),
            ),
          ),
          // Año con estilo minimalista
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              year.toString(),
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.4),
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
          ),
          // Línea derecha
          Expanded(
            child: Container(
              height: 0.5,
              color: colorScheme.onSurface.withValues(alpha: 0.15),
            ),
          ),
        ],
      ),
    );
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
      margin: const EdgeInsets.only(top: 12, bottom: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colorScheme.primaryContainer.withValues(alpha: 0.25),
                colorScheme.surface.withValues(alpha: 0.95),
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.15),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.calendar_today_rounded,
                  color: colorScheme.primary,
                  size: 14,
                ),
              ),
              const SizedBox(width: 10),

              Flexible(
                flex: 2,
                child: Text(
                  dateStr,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                    height: 1.0,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                ),
              ),

              if (dayEgresos > 0 || dayIngresos > 0) ...[
                const SizedBox(width: 8),
                Flexible(
                  flex: 3,
                  fit: FlexFit.loose,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (dayEgresos > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: Colors.redAccent.withValues(alpha: 0.15),
                                width: 0.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.arrow_downward_rounded,
                                  color: Colors.redAccent.withValues(alpha: 0.7),
                                  size: 10,
                                ),
                                const SizedBox(width: 2),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 70),
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      'S/. ${dayEgresos.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        color: Colors.redAccent.withValues(alpha: 0.85),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: -0.1,
                                        height: 1.0,
                                      ),
                                      maxLines: 1,
                                      softWrap: false,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (dayEgresos > 0 && dayIngresos > 0) const SizedBox(width: 4),
                        if (dayIngresos > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.greenAccent.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: Colors.greenAccent.withValues(alpha: 0.15),
                                width: 0.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.arrow_upward_rounded,
                                  color: Colors.greenAccent.withValues(alpha: 0.7),
                                  size: 10,
                                ),
                                const SizedBox(width: 2),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 70),
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      'S/. ${dayIngresos.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        color: Colors.greenAccent.withValues(alpha: 0.85),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: -0.1,
                                        height: 1.0,
                                      ),
                                      maxLines: 1,
                                      softWrap: false,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
