import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/components/date_picker_theme.dart';
import '../../profile/views/profile_view.dart';
import '../../transactions/views/add_transaction_view.dart';
import '../../analytics/views/analytics_view.dart';
import '../../reports/views/reports_view.dart' as reports;
import '../../transactions/views/search_filter_view.dart';
import '../../transactions/controllers/transactions_controller.dart';
import '../../transactions/views/transactions_list_view.dart';
import '../../transactions/views/transactions_quick_menu.dart';
import '../../transactions/views/budgets_overview_view.dart';
import '../../../widgets/main_nav_bar.dart';

class MyHomePage extends ConsumerStatefulWidget {
  const MyHomePage({super.key, required this.title, this.child});
  final String title;
  // Cuando `MyHomePage` se usa como ShellRoute, recibirá el `child` que
  // corresponde a la ruta activa (p. ej. AnalyticsScreen). Si es null,
  // se comporta como antes.
  final Widget? child;

  @override
  ConsumerState<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends ConsumerState<MyHomePage> {
  int _pageIndex = 0;
  String _transactionsMode = 'transacciones';
  bool _forceShowBudgets = false;

  late final List<Widget> _pages;
  // Provider de información de ruta y listener para sincronizar el índice
  RouteInformationProvider? _routeInfoProvider;
  VoidCallback? _routeInfoListener;

  @override
  void initState() {
    super.initState();
    _pages = [
      const TransactionsListView(),
      const AnalyticsScreen(),
      const reports.ReportsScreen(),
      const ProfileScreen(),
    ];
    // Dejamos _pageIndex en 0 inicialmente; en el post frame handler
    // leeremos la ubicación actual del router y sincronizaremos el índice.
    _pageIndex = 0;

    // Nos suscribimos al RouteInformationProvider del GoRouter después del primer frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        _routeInfoProvider = GoRouter.of(context).routeInformationProvider;
        // Inicializar a partir de la ubicación actual
        final initialLoc = _routeInfoProvider?.value.uri.toString() ?? '/';
        final initialIdx = _indexFromLocation(initialLoc);
        // Si la URL trae ?mode=presupuestos, sincronizamos el modo también
        final initialMode = Uri.tryParse(initialLoc)?.queryParameters['mode'];
        debugPrint('➡️ [MyHomePage] initial router location=$initialLoc -> idx=$initialIdx, mode=$initialMode');
        setState(() {
          if (initialIdx != _pageIndex) _pageIndex = initialIdx;
          if (initialMode != null && initialMode != _transactionsMode) _transactionsMode = initialMode;
        });

        _routeInfoListener = () {
          try {
            final loc = _routeInfoProvider?.value.uri.toString() ?? '/';
            final uri = Uri.tryParse(loc);
            final idx = _indexFromLocation(loc);
            final mode = uri?.queryParameters['mode'];
            debugPrint('➡️ [MyHomePage] routeInfoListener detected location=$loc -> idx=$idx, mode=$mode');
            setState(() {
              if (idx != _pageIndex) _pageIndex = idx;
              if (mode != null && mode != _transactionsMode) _transactionsMode = mode;
              // Solo actualizamos la bandera si la URL trae explícitamente el mode.
              if (mode != null) {
                _forceShowBudgets = (mode == 'presupuestos' && idx == 0);
              }
            });
          } catch (e) {
            debugPrint('➡️ [MyHomePage] routeInfoListener error: $e');
          }
        };
        _routeInfoProvider?.addListener(_routeInfoListener!);
      } catch (e) {
        debugPrint('➡️ [MyHomePage] could not attach routeInfo listener: $e');
      }
    });
  }

  int _indexFromLocation(String loc) {
    if (loc.startsWith('/analytics')) return 1;
    if (loc.startsWith('/reports')) return 2;
    if (loc.startsWith('/profile')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('➡️ [MyHomePage] build: _pageIndex=$_pageIndex, child=${widget.child?.runtimeType}');
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Calculamos el modo efectivo: preferimos el parámetro `mode` en la URL
    // (por ejemplo '/?mode=presupuestos') y si no existe usamos el estado local.
    final currentLocation = _routeInfoProvider?.value.uri.toString() ?? GoRouter.of(context).routeInformationProvider.value.uri.toString();
    final urlMode = Uri.tryParse(currentLocation)?.queryParameters['mode'];
    final effectiveMode = urlMode ?? _transactionsMode;

    debugPrint('➡️ [MyHomePage] effectiveMode=$effectiveMode (urlMode=$urlMode, _transactionsMode=$_transactionsMode)');

    // Usamos el estado local como fuente inmediata para la animación.
    // Cuando ShellRoute actualice el `child`, sincronizaremos `_pageIndex`
    // en didUpdateWidget para reflejar la ruta real.

    return Scaffold(
      extendBody: false,
      extendBodyBehindAppBar: false,
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
                icon: Icon(Icons.menu_rounded, color: colorScheme.onSurface),
                onPressed: () async {
                  await showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    showDragHandle: true,
                    backgroundColor: theme.scaffoldBackgroundColor,
                    builder: (_) => TransactionsQuickMenu(
                      currentMode: _transactionsMode,
                      onSelectMode: (mode) {
                        debugPrint('➡️ [MyHomePage] TransactionsQuickMenu selected mode: $mode');
                        // Actualizamos el modo y navegamos a '/' para forzar que
                        // la vista de transacciones (Inicio) se muestre incluso
                        // cuando se usa MyHomePage como ShellRoute.
                        setState(() {
                          _transactionsMode = mode;
                          _pageIndex = 0; // aseguramos que la pestaña Inicio quede activa inmediatamente
                          _forceShowBudgets = mode == 'presupuestos';
                        });
                        // Navegar a la ruta de inicio pasando el modo en la query
                        // para que, si MyHomePage está en un ShellRoute con `child`,
                        // podamos detectar el modo desde la URL y mostrar la vista adecuada.
                        final encoded = Uri(queryParameters: {'mode': mode}).query;
                        context.go('/?$encoded');
                      },
                    ),
                  );
                },
              ),
              actions: [
                IconButton(
                  icon: Icon(Icons.search, color: colorScheme.onSurface),
                  onPressed: () async {
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
                      controller.updateFiltersFromMap(result);
                    }
                  },
                ),
                IconButton(
                  tooltip: () {
                    final state = ref.watch(transactionsControllerProvider);
                    return state.filters.from != null && state.filters.to != null
                        ? 'Rango activo'
                        : 'Filtrar por fecha';
                  }(),
                  icon: Icon(Icons.date_range, color: colorScheme.onSurface),
                  onPressed: () async {
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
                      ref.read(transactionsControllerProvider.notifier)
                          .selectDateRange(picked.start, picked.end);
                    }
                  },
                ),
              ],
            )
          : null,
      body: () {
        // Si estamos en la pestaña Inicio y el modo efectivo pide 'presupuestos',
        // mostramos la vista de presupuestos aunque widget.child exista (ShellRoute).
        if (_pageIndex == 0 && (effectiveMode == 'presupuestos' || _forceShowBudgets)) {
          return const BudgetsOverviewView();
        }
        // Si hay un child (ShellRoute) y no estamos forzando presupuestos, lo mostramos.
        if (widget.child != null) return widget.child!;
        // Caso por defecto: comportamiento basado en _pageIndex/_transactionsMode
        if (_pageIndex == 0) {
          return _transactionsMode == 'transacciones' ? const TransactionsListView() : const BudgetsOverviewView();
        }
        return _pages[_pageIndex];
      }(),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: EdgeInsets.zero,
        child: MainNavBar(
          currentIndex: _pageIndex,
          onTap: _onTap,
          onAdd: _onAddTransaction, // FAB integrado en MainNavBar: pasamos la callback onAdd
        ),
      ),
    );
  }

  Future<void> _onAddTransaction() async {
    final saved = await Navigator.of(context, rootNavigator: true).push<bool>(
      MaterialPageRoute(builder: (_) => const AddTransactionScreen()),
    );
    if (saved == true) {
      ref.read(transactionsControllerProvider.notifier).reloadAfterCreate();
    }
  }

  void _onTap(int index) {
    const paths = ['/', '/analytics', '/reports', '/profile'];
    final path = paths[index];
    debugPrint('➡️ [MyHomePage] _onTap -> setting _pageIndex = $index (path: $path)');
    setState(() {
      _pageIndex = index;
      // al cambiar de pestaña, dejamos de forzar la vista de presupuestos
      _forceShowBudgets = false;
    });
    debugPrint('➡️ [MyHomePage] _onTap -> navigating to $path');
    context.go(path);
  }

  @override
  void didUpdateWidget(covariant MyHomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    debugPrint('➡️ [MyHomePage] didUpdateWidget: oldChild=${oldWidget.child?.runtimeType} newChild=${widget.child?.runtimeType}');
    // No intentamos sincronizar aquí: el listener sobre routeInformationProvider
    // hará la actualización de índice cuando la ubicación cambie.
  }

  @override
  void dispose() {
    try {
      if (_routeInfoProvider != null && _routeInfoListener != null) {
        _routeInfoProvider?.removeListener(_routeInfoListener!);
      }
    } catch (e) {
      debugPrint('➡️ [MyHomePage] error removing route listener: $e');
    }
    super.dispose();
  }
}
