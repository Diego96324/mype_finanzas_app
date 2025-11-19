import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../views/core/theme/date_picker_theme.dart';
import '../providers/providers.dart';
import '../../views/profile/profile_view.dart';
import 'package:mype_finanzas/views/transactions/add_transaction_view.dart';
import '../../views/analytics/analytics_view.dart';
import '../../views/reports/reports_view.dart' as reports;
import '../../views/transactions/search_filter_view.dart';
import '../../controllers/transactions/transactions_controller.dart';
import '../../views/transactions/transactions_list_view.dart';
import '../../views/transactions/transactions_quick_menu.dart';
import '../../views/transactions/budgets_overview_view.dart';
import '../../views/layout/main_nav_bar.dart';

class MyHomePage extends ConsumerStatefulWidget {
  const MyHomePage({super.key, required this.title, this.child});
  final String title;
  final Widget? child;

  @override
  ConsumerState<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends ConsumerState<MyHomePage> {
  int _pageIndex = 0;
  String _transactionsMode = 'transacciones';

  late final List<Widget> _pages;
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
    _pageIndex = ref.read(shellCurrentIndexProvider);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        _routeInfoProvider = GoRouter.of(context).routeInformationProvider;

        final initialLoc = _routeInfoProvider?.value.uri.toString() ?? '/';
        final initialIdx = _indexFromLocation(initialLoc);
        final initialMode = Uri.tryParse(initialLoc)?.queryParameters['mode'];

        setState(() {
          if (initialIdx != _pageIndex) _pageIndex = initialIdx;
          if (initialMode != null && initialMode != _transactionsMode) {
            _transactionsMode = initialMode;
          }
        });

        _routeInfoListener = () {
          if (!mounted) return;
          final loc = _routeInfoProvider?.value.uri.toString() ?? '/';
          final idx = _indexFromLocation(loc);
          final mode = Uri.tryParse(loc)?.queryParameters['mode'];
          
          final desired = ref.read(shellDesiredIndexProvider);
          if (desired != null) return;
          
          final shouldBlock = ref.read(routeSyncBlockProvider);
          if (shouldBlock) return;

          setState(() {
            if (idx != _pageIndex) _pageIndex = idx;
            if (mode != null && mode != _transactionsMode) _transactionsMode = mode;
          });
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
    
    // Usamos un Consumer para escuchar solo el shellDesiredIndexProvider y reconstruir lo mínimo
    return Consumer(
      builder: (context, ref, _) {
        final shellDesired = ref.watch(shellDesiredIndexProvider);
        final displayedIndex = shellDesired ?? _pageIndex;

        final currentLocation = GoRouter.of(context).routeInformationProvider.value.uri.toString();
        final urlMode = Uri.tryParse(currentLocation)?.queryParameters['mode'];
        final effectiveMode = urlMode ?? _transactionsMode;

        debugPrint('➡️ [MyHomePage] Consumer build: displayedIndex=$displayedIndex, effectiveMode=$effectiveMode');

        return Scaffold(
          extendBody: false,
          extendBodyBehindAppBar: false,
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: displayedIndex == 0
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
                            setState(() {
                              _transactionsMode = mode;
                              _pageIndex = 0;
                            });
                            ref.read(shellCurrentIndexProvider.notifier).state = 0;
                            final encoded = Uri(queryParameters: {'mode': mode}).query;
                            context.go('/?$encoded');
                          },
                        ),
                      );
                    },
                  ),
                  actions: [
                    IconButton(
                      tooltip: 'Gamificación',
                      icon: Icon(Icons.emoji_events, color: colorScheme.onSurface),
                      onPressed: () => context.push('/gamification'),
                    ),
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
                      tooltip: 'Filtrar por fecha',
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
                          locale: const Locale('es', 'PE'),
                          builder: (context, child) => Theme(
                            data: AppDatePickerTheme.darkDateRangePickerTheme(context),
                            child: child!,
                          ),
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
            if (displayedIndex == 0 && effectiveMode == 'presupuestos') {
              return const BudgetsOverviewView();
            }
            if (shellDesired != null) {
              return _pages[shellDesired];
            }
            if (widget.child != null) return widget.child!;
            if (displayedIndex == 0) {
              return _transactionsMode == 'transacciones' ? const TransactionsListView() : const BudgetsOverviewView();
            }
            return _pages[displayedIndex];
          }(),
          bottomNavigationBar: SafeArea(
            top: false,
            minimum: EdgeInsets.zero,
            child: MainNavBar(
              currentIndex: displayedIndex,
              onTap: _onTap,
              onAdd: _onAddTransaction,
            ),
          ),
        );
      },
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
    setState(() {
      _pageIndex = index;
    });
    ref.read(shellCurrentIndexProvider.notifier).state = _pageIndex;
    try {
      ref.read(shellDesiredIndexProvider.notifier).state = null;
    } catch (_) {}
    context.go(path);
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
