import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Imports corregidos según la estructura del proyecto
import '../../../../data/models/category_model.dart';
import '../../../../core/providers/category_providers.dart';
import '../../../../domain/services/auth_service.dart';
import '../../../../domain/services/category_budget_service.dart';
import '../../budgets/widgets/category_budget_card.dart';
import '../cache/budgets_cache.dart';

const _kPrefPeriodo = 'budgets_overview_periodo';
const _kPrefRef = 'budgets_overview_ref';
const _kPrefAlertsEnabled = 'budgets_alerts_enabled';
const _kPrefAlertsThreshold = 'budgets_alerts_threshold';
const _kPrefAlertsCategories = 'budgets_alerts_categories';

class BudgetsOverviewView extends ConsumerStatefulWidget {
  const BudgetsOverviewView({super.key});

  @override
  ConsumerState<BudgetsOverviewView> createState() => _BudgetsOverviewViewState();
}

class _BudgetsOverviewViewState extends ConsumerState<BudgetsOverviewView> {
  bool _loading = true;
  List<Category> _principal = [];
  String _periodo = 'mensual';
  DateTime _ref = DateTime.now();

  bool _alertsEnabled = true;
  double _alertsThreshold = 90.0;
  final _alertsThresholdCtrl = TextEditingController();
  Set<int> _alertsCategoryIds = {};

  bool _loadingAlerts = false;
  List<Map<String, dynamic>> _alertBudgets = [];

  @override
  void initState() {
    super.initState();
    // No usar ref.listen en initState (provoca assertion en esta versión de Riverpod).
    // _loadData inicializa la lista usando el cache / provider.
    _loadData();
  }

  @override
  void dispose() {
    _alertsThresholdCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final userId = AuthService().currentUserId;
    if (userId == null) {
      setState(() => _loading = false);
      return;
    }

    // Consultar cache primero
    final cache = BudgetsCache.instance();
    List<Category>? principalesNullable = cache.getCategories(userId);
    List<Category> principales;
    if (principalesNullable == null) {
      // Usar el provider de categorías por tipo para incluir las categorías del usuario
      final all = await ref.read(expenseCategoriesProvider.future);
      principales = all.where((c) => c.categoriaPadreId == null).toList();
      cache.setCategories(userId, principales);
    } else {
      principales = principalesNullable;
    }

    final prefs = await SharedPreferences.getInstance();
    final savedPeriodo = prefs.getString(_kPrefPeriodo);
    final savedRef = prefs.getInt(_kPrefRef);
    final savedAlertsEnabled = prefs.getBool(_kPrefAlertsEnabled);
    final savedAlertsThreshold = prefs.getDouble(_kPrefAlertsThreshold);
    final savedAlertCats = prefs.getStringList(_kPrefAlertsCategories);

    setState(() {
      _principal = principales;
      if (savedPeriodo == 'mensual' || savedPeriodo == 'trimestral') {
        _periodo = savedPeriodo!;
      }
      if (savedRef != null) {
        final year = savedRef ~/ 100;
        final month = savedRef % 100;
        _ref = DateTime(year, month, 1);
      }
      _alertsEnabled = savedAlertsEnabled ?? true;
      _alertsThreshold = (savedAlertsThreshold ?? 90).clamp(1, 100);
      _alertsThresholdCtrl.text = _alertsThreshold.toStringAsFixed(0);
      _alertsCategoryIds = {
        if (savedAlertCats != null)
          ...savedAlertCats.map((s) => int.tryParse(s)).whereType<int>(),
      };
      _loading = false;
    });
    // Si hay alertBudgets en cache, úsalo para evitar recálculos; si no, cárgalos
    final cachedAlerts = BudgetsCache.instance().getAlertBudgets(userId, _periodo, _ref);
    if (cachedAlerts != null) {
      setState(() {
        _alertBudgets = cachedAlerts;
        _loadingAlerts = false;
      });
    } else {
      await _loadAlertBudgets();
    }
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefPeriodo, _periodo);
    await prefs.setInt(_kPrefRef, _ref.year * 100 + _ref.month);
    await prefs.setBool(_kPrefAlertsEnabled, _alertsEnabled);
    await prefs.setDouble(_kPrefAlertsThreshold, _alertsThreshold);
    await prefs.setStringList(
        _kPrefAlertsCategories, _alertsCategoryIds.map((e) => e.toString()).toList());
  }

  Future<void> _loadAlertBudgets() async {
    setState(() {
      _loadingAlerts = true;
      _alertBudgets = [];
    });

    if (!_alertsEnabled) {
      setState(() => _loadingAlerts = false);
      return;
    }

    final service = CategoryBudgetService();
    final userId = AuthService().currentUserId;
    if (userId == null) {
      setState(() => _loadingAlerts = false);
      return;
    }

    final List<Map<String, dynamic>> results = [];
    // Obtener las categorías actuales desde el provider (asegura que incluyamos
    // categorías creadas por el usuario en otra pantalla)
    final allCats = await ref.read(expenseCategoriesProvider.future);
    final principales = allCats.where((c) => c.categoriaPadreId == null).toList();

    final catsToCheck = _alertsCategoryIds.isEmpty
        ? principales.where((c) => c.id != null).map((c) => c.id!).toList()
        : _alertsCategoryIds.toList();

    for (final catId in catsToCheck) {
      final cat = principales.firstWhere((c) => c.id == catId, orElse: () => principales.first);
      if (cat.id == null) continue;

      final summary = await service.getSummary(
        usuarioId: userId,
        categoriaId: cat.id!,
        periodo: _periodo,
        referencia: _ref,
      );

      if (summary != null && summary.porcentaje >= _alertsThreshold) {
        results.add({'categoria': cat, 'summary': summary});
      }
    }

    // Guardar en cache y actualizar estado
    BudgetsCache.instance().setAlertBudgets(userId, _periodo, _ref, results);
    setState(() {
      _alertBudgets = results;
      _loadingAlerts = false;
    });
  }

  // Fuerza recarga desde origen y limpia cache cuando el usuario presiona "Refrescar"
  Future<void> _forceReload() async {
    final userId = AuthService().currentUserId;
    if (userId != null) {
      BudgetsCache.instance().clearCategories(userId);
      BudgetsCache.instance().clearAlertBudgets(userId);
    }
    // Invalidar provider para forzar recarga de categorías
    try {
      ref.invalidate(expenseCategoriesProvider);
    } catch (_) {}
    await _loadData();
  }

  void _changePeriodo(String p) {
    setState(() => _periodo = p);
    _savePrefs();
  }

  void _changeReferencia(DateTime d) {
    setState(() => _ref = d);
    _savePrefs();
  }

  void _stepMonth(int delta) {
    final newMonth = _ref.month + delta;
    final newYear = _ref.year + (newMonth > 12 ? 1 : newMonth < 1 ? -1 : 0);
    final correctedMonth = newMonth > 12 ? 1 : newMonth < 1 ? 12 : newMonth;
    _changeReferencia(DateTime(newYear, correctedMonth, 1));
  }

  Future<void> _selectAlertCategories() async {
    final selected = await showDialog<Set<int>>(
      context: context,
      builder: (ctx) => _CategoryMultiSelectDialog(
        categories: _principal,
        selected: _alertsCategoryIds,
      ),
    );
    if (selected != null) {
      setState(() => _alertsCategoryIds = selected);
      _savePrefs();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Obtener categorías directamente desde el provider para que la UI se
    // actualice automáticamente cuando se creen/eliminen categorías.
    final catsAsync = ref.watch(expenseCategoriesProvider);
    List<Category> principalFromProvider = [];
    catsAsync.when(
      data: (list) {
        principalFromProvider = list.where((c) => c.categoriaPadreId == null).toList();
      },
      loading: () {},
      // Evitar underscore al inicio de nombres locales para no confundir con identificadores privados
      error: (error, stack) {},
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Presupuestos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => const _HelpDialog(),
              );
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(
        child: CircularProgressIndicator(),
      )
          : principalFromProvider.isEmpty
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.wallet,
                size: 64,
                color: Colors.grey.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'Sin categorías',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Crea categorías de egreso para gestionar presupuestos',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Selector de período y referencia
            Row(
              children: [
                Expanded(
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'mensual', label: Text('Mensual')),
                      ButtonSegment(value: 'trimestral', label: Text('Trimestral')),
                    ],
                    selected: {_periodo},
                    onSelectionChanged: (Set<String> sel) => _changePeriodo(sel.first),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: 'Mes anterior',
                  onPressed: () => _stepMonth(-1),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                TextButton(
                  child: Text(
                    '${_ref.year}-${_ref.month.toString().padLeft(2, '0')}',
                    style: theme.textTheme.titleMedium,
                  ),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _ref,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                      helpText: 'Selecciona mes de referencia',
                    );
                    if (picked != null) _changeReferencia(picked);
                  },
                ),
                IconButton(
                  tooltip: 'Mes siguiente',
                  onPressed: () => _stepMonth(1),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refrescar'),
                  onPressed: () async => await _forceReload(),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Título de sección
            Text(
              'Presupuestos por Categoría',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Período: ${_periodo == 'mensual' ? 'Mensual' : 'Trimestral'}',
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 16),

            // Lista lazy de todas las categorías con sus presupuestos
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: principalFromProvider.length,
              itemBuilder: (context, index) {
                final category = principalFromProvider[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: CategoryBudgetCard(
                    category: category,
                    periodo: _periodo,
                    referencia: _ref,
                  ),
                );
              },
            ),

            const SizedBox(height: 32),
            Text('Alertas de presupuesto', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Switch(
                          value: _alertsEnabled,
                          onChanged: (v) {
                            setState(() => _alertsEnabled = v);
                            _savePrefs();
                            if (v) _loadAlertBudgets();
                          },
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Activar alertas cuando el presupuesto alcance:',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                    if (_alertsEnabled) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _alertsThresholdCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Umbral (%)',
                                border: OutlineInputBorder(),
                                suffixText: '%',
                              ),
                              onChanged: (v) {
                                final val = double.tryParse(v);
                                if (val != null) {
                                  _alertsThreshold = val.clamp(1, 100);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            icon: const Icon(Icons.category),
                            label: Text(_alertsCategoryIds.isEmpty
                                ? 'Seleccionar categorías'
                                : 'Categorías (${_alertsCategoryIds.length})'),
                            onPressed: _selectAlertCategories,
                          ),
                          FilledButton.icon(
                            icon: const Icon(Icons.check_circle),
                            label: const Text('Guardar'),
                            onPressed: () {
                              _savePrefs();
                              _loadAlertBudgets();
                            },
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Lista de alertas activas
            if (_loadingAlerts)
              const LinearProgressIndicator()
            else if (_alertBudgets.isEmpty)
              const SizedBox.shrink()
            else
              Column(
                children: _alertBudgets.map((e) {
                  final cat = e['categoria'] as Category;
                  final summary = e['summary'] as CategoryBudgetSummary;
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.orange,
                        child: Text(summary.porcentaje.toStringAsFixed(0)),
                      ),
                      title: Text(cat.nombre),
                      subtitle: Text(
                          'Uso ${summary.porcentaje.toStringAsFixed(1)}% • Restante S/ ${summary.restante.toStringAsFixed(2)}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.refresh),
                        tooltip: 'Refrescar categoría',
                        onPressed: () async {
                          await _loadAlertBudgets();
                        },
                      ),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}

// Dialog para seleccionar múltiples categorías
class _CategoryMultiSelectDialog extends StatefulWidget {
  final List<Category> categories;
  final Set<int> selected;

  const _CategoryMultiSelectDialog({
    required this.categories,
    required this.selected,
  });

  @override
  State<_CategoryMultiSelectDialog> createState() => _CategoryMultiSelectDialogState();
}

class _CategoryMultiSelectDialogState extends State<_CategoryMultiSelectDialog> {
  late Set<int> _localSelected;

  @override
  void initState() {
    super.initState();
    _localSelected = Set.from(widget.selected);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Seleccionar categorías'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: widget.categories.map((cat) {
            final catId = cat.id;
            if (catId == null) return const SizedBox.shrink();

            return CheckboxListTile(
              title: Text(cat.nombre),
              value: _localSelected.contains(catId),
              onChanged: (checked) {
                setState(() {
                  if (checked == true) {
                    _localSelected.add(catId);
                  } else {
                    _localSelected.remove(catId);
                  }
                });
              },
            );
          }).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _localSelected),
          child: const Text('Aceptar'),
        ),
      ],
    );
  }
}

// Dialog de ayuda
class _HelpDialog extends StatelessWidget {
  const _HelpDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ayuda - Presupuestos'),
      content: const SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Esta pantalla te permite gestionar presupuestos por categoría de egreso.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text('• Selecciona una categoría para ver y configurar su presupuesto'),
            Text('• Elige entre período mensual o trimestral'),
            Text('• Navega por diferentes meses usando las flechas'),
            SizedBox(height: 12),
            Text(
              'Alertas:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('• Activa alertas para recibir notificaciones cuando el presupuesto alcance un % determinado'),
            Text('• Puedes seleccionar categorías específicas o monitorear todas'),
            Text('• Las alertas aparecerán en la parte inferior cuando se activen'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Entendido'),
        ),
      ],
    );
  }
}
