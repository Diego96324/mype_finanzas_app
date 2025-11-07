import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/date_picker_theme.dart';
import '../../profile/views/profile_screen.dart';
import '../../transactions/views/add_transaction_view.dart';
import '../../analytics/views/analytics_view.dart';
import '../../reports/views/reports_view.dart' as reports;
import '../../transactions/views/search_filter_view.dart';
import '../../transactions/controllers/transactions_controller.dart';
import '../../transactions/views/transactions_list_view.dart';

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
      const TransactionsListView(),
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

