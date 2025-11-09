import 'package:flutter/material.dart';
import 'package:mype_finanzas/core/widgets/empty_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../domain/entities/category.dart';
import '../../../../../domain/repositories/category_repository.dart';
import '../../../../../domain/services/auth_service.dart';
import '../../../../../domain/services/category_budget_service.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../widgets/category_budget_card.dart';

const _kPrefPeriodo = 'budgets_overview_periodo';
const _kPrefRef = 'budgets_overview_ref';
const _kPrefCatId = 'budgets_overview_cat_id';
const _kPrefAlertsEnabled = 'budgets_alerts_enabled';
const _kPrefAlertsThreshold = 'budgets_alerts_threshold';
const _kPrefAlertsCategories = 'budgets_alerts_categories';

class BudgetsOverviewView extends StatefulWidget {
  const BudgetsOverviewView({super.key});

  @override
  State<BudgetsOverviewView> createState() => _BudgetsOverviewViewState();
}

class _BudgetsOverviewViewState extends State<BudgetsOverviewView> {
  bool _loading = true;
  List<Category> _principal = [];
  Category? _selected;
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
    _loadData();
  }

  Future<void> _applyInitialCategory() async {
    final prefs = await SharedPreferences.getInstance();
    final catId = prefs.getInt(_kPrefCatId);
    if (catId == null) return;
    for (final c in _principal) {
      if (c.id == catId) {
        setState(() => _selected = c);
        break;
      }
    }
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final userId = AuthService().currentUserId;
    if (userId == null) {
      setState(() => _loading = false);
      return;
    }
    final repo = CategoryRepository();
    final all = await repo.list(userId, tipo: 'egreso');
    final principales = all.where((c) => c.categoriaPadreId == null).toList();

    final prefs = await SharedPreferences.getInstance();
    final savedPeriodo = prefs.getString(_kPrefPeriodo);
    final savedRef = prefs.getInt(_kPrefRef);
    final savedCatId = prefs.getInt(_kPrefCatId);
    final savedAlertsEnabled = prefs.getBool(_kPrefAlertsEnabled);
    final savedAlertsThreshold = prefs.getDouble(_kPrefAlertsThreshold);
    final savedAlertCats = prefs.getStringList(_kPrefAlertsCategories);

    Category? sel;
    if (savedCatId != null) {
      for (final c in principales) {
        if (c.id == savedCatId) {
          sel = c;
          break;
        }
      }
    }

    setState(() {
      _principal = principales;
      _selected = sel ?? (principales.isNotEmpty ? principales.first : null);
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
    await _applyInitialCategory();
    await _loadAlertBudgets();
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefPeriodo, _periodo);
    await prefs.setInt(_kPrefRef, _ref.year * 100 + _ref.month);
    if (_selected?.id != null) {
      await prefs.setInt(_kPrefCatId, _selected!.id!);
    }
    await prefs.setBool(_kPrefAlertsEnabled, _alertsEnabled);
    await prefs.setDouble(_kPrefAlertsThreshold, _alertsThreshold);
    await prefs.setStringList(_kPrefAlertsCategories, _alertsCategoryIds.map((e) => e.toString()).toList());
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
    final List<Map<String, dynamic>> results = [];
    final catsToCheck = _alertsCategoryIds.isEmpty
        ? _principal
        : _principal.where((c) => _alertsCategoryIds.contains(c.id)).toList();
    for (final cat in catsToCheck) {
      if (userId == null) break;
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
    setState(() {
      _alertBudgets = results;
      _loadingAlerts = false;
    });
  }

  Future<void> _selectAlertCategories() async {
    final selected = Set<int>.from(_alertsCategoryIds);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Seleccionar categorías para alertas'),
        content: SizedBox(
          width: 380,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _principal.length,
            itemBuilder: (_, i) {
              final c = _principal[i];
              final checked = selected.contains(c.id);
              return CheckboxListTile(
                value: checked,
                onChanged: (val) {
                  setState(() {
                    if (val == true) {
                      selected.add(c.id!);
                    } else {
                      selected.remove(c.id);
                    }
                  });
                },
                title: Text(c.nombre),
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              setState(() => _alertsCategoryIds = selected);
              _savePrefs();
              _loadAlertBudgets();
              Navigator.pop(ctx);
            },
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );
  }

  void _changePeriodo(String value) {
    setState(() => _periodo = value);
    _savePrefs();
    _loadAlertBudgets();
  }

  void _changeReferencia(DateTime date) {
    setState(() => _ref = DateTime(date.year, date.month, 1));
    _savePrefs();
    _loadAlertBudgets();
  }

  void _stepMonth(int delta) {
    final y = _ref.year;
    final m = _ref.month + delta;
    final newDate = DateTime(y, m, 1);
    setState(() => _ref = newDate);
    _savePrefs();
    _loadAlertBudgets();
  }

  @override
  void dispose() {
    _alertsThresholdCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _principal.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text('No hay categorías principales de egreso disponibles.', style: theme.textTheme.bodyMedium),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Selección de categoría
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<Category>(
                              value: _selected,
                              decoration: const InputDecoration(labelText: 'Categoría'),
                              items: _principal.map((c) => DropdownMenuItem(value: c, child: Text(c.nombre))).toList(),
                              onChanged: (c) {
                                setState(() => _selected = c);
                                _savePrefs();
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Selector de período
                      Center(
                        child: SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'mensual', label: Text('Mensual'), icon: Icon(Icons.calendar_month)),
                            ButtonSegment(value: 'trimestral', label: Text('Trimestral'), icon: Icon(Icons.calendar_view_month)),
                          ],
                          selected: {_periodo},
                          onSelectionChanged: (v) => _changePeriodo(v.first),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Navegación de mes
                      Row(
                        children: [
                          IconButton(
                            tooltip: 'Mes anterior',
                            onPressed: () => _stepMonth(-1),
                            icon: const Icon(Icons.chevron_left_rounded),
                          ),
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.date_range),
                              label: Text('${_ref.year}-${_ref.month.toString().padLeft(2, '0')}'),
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
                            onPressed: () => setState(() {}),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      if (_selected != null) ...[
                        Text(
                          'Presupuesto ${_periodo == 'mensual' ? 'mensual' : 'trimestral'}',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        CategoryBudgetCard(
                          category: _selected!,
                          periodo: _periodo,
                          referencia: _ref,
                        ),
                      ],

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
                                      _loadAlertBudgets();
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  Text('Activar alertas de exceso por categoría', style: theme.textTheme.bodySmall),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // Fila del umbral
                              Row(
                                children: [
                                  SizedBox(
                                    width: 120,
                                    child: TextFormField(
                                      controller: _alertsThresholdCtrl,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: false),
                                      decoration: const InputDecoration(suffixText: '%', labelText: 'Umbral'),
                                      onChanged: (v) {
                                        final d = double.tryParse(v);
                                        if (d != null) {
                                          _alertsThreshold = d.clamp(1, 100);
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // Acciones abajo en Wrap para pantallas pequeñas
                              Align(
                                alignment: Alignment.centerRight,
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  alignment: WrapAlignment.end,
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
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
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
                                subtitle: Text('Uso ${summary.porcentaje.toStringAsFixed(1)}% • Restante S/ ${summary.restante.toStringAsFixed(2)}'),
                                trailing: IconButton(
                                  icon: const Icon(Icons.refresh),
                                  tooltip: 'Refrescar categoría',
                                  onPressed: () async {
                                    await _loadAlertBudgets();
                                  },
                                ),
                                onTap: () {
                                  setState(() => _selected = cat);
                                  _savePrefs();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Seleccionada categoría ${cat.nombre} para detalle')),
                                  );
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          icon: const Icon(Icons.refresh),
                          label: const Text('Actualizar alertas'),
                          onPressed: _loadAlertBudgets,
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
