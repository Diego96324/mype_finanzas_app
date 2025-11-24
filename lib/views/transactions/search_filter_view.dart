import 'package:flutter/material.dart';
import '../../models/repositories/category_repository.dart' as catrepo;
import '../../models/dtos/category_model.dart' as models;

class SearchFilterScreen extends StatefulWidget {
  final Map<String, dynamic> initialFilters;

  const SearchFilterScreen({super.key, this.initialFilters = const {}});

  @override
  State<SearchFilterScreen> createState() => _SearchFilterScreenState();
}

class _SearchFilterScreenState extends State<SearchFilterScreen> {
  late List<String> _tipos;
  late List<String> _orders;
  late TextEditingController _searchTermController;

  DateTime? _fromDate;
  DateTime? _toDate;
  List<models.Category> _allCategories = [];
  final Set<int> _selectedCategoryIds = {};
  final _minAmountCtrl = TextEditingController();
  final _maxAmountCtrl = TextEditingController();
  bool _tagOnly = false;
  bool _noteOnly = false;
  bool _onlyRecurrent = false;
  bool _hasAttachment = false;
  String? _frecuencia;

  final TextEditingController _categorySearchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final initialTipo = widget.initialFilters['tipo'] ?? 'todos';
    _tipos = initialTipo == 'todos' ? ['todos'] : [initialTipo];
    _orders = [];
    _searchTermController = TextEditingController(text: widget.initialFilters['searchTerm']);

    _fromDate = widget.initialFilters['from'] as DateTime?;
    _toDate = widget.initialFilters['to'] as DateTime?;
    final lista = widget.initialFilters['categoriaIds'] as List<int>?;
    if (lista != null) _selectedCategoryIds.addAll(lista);
    final minAmount = widget.initialFilters['minAmount'] as double?;
    final maxAmount = widget.initialFilters['maxAmount'] as double?;
    if (minAmount != null) _minAmountCtrl.text = minAmount.toString();
    if (maxAmount != null) _maxAmountCtrl.text = maxAmount.toString();
    _tagOnly = (widget.initialFilters['tagOnly'] as bool?) ?? false;
    _noteOnly = (widget.initialFilters['noteOnly'] as bool?) ?? false;
    _onlyRecurrent = (widget.initialFilters['onlyRecurrent'] as bool?) ?? false;
    _hasAttachment = (widget.initialFilters['hasAttachment'] as bool?) ?? false;
    _frecuencia = widget.initialFilters['frecuencia'] as String?;

    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final repo = catrepo.CategoryRepository();
    final categories = await repo.getUserCategories();
    setState(() => _allCategories = categories);
  }

  @override
  void dispose() {
    _minAmountCtrl.dispose();
    _maxAmountCtrl.dispose();
    _categorySearchCtrl.dispose();
    super.dispose();
  }

  // --- NUEVO: Apertura modal de selección de categorías ---
  Future<void> _openCategorySelector() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setModalState) {
          List<models.Category> visibles = _allCategories;
          final query = _categorySearchCtrl.text.trim().toLowerCase();
          if (query.isNotEmpty) {
            visibles = _allCategories.where((c) {
              final matchPrincipal = c.nombre.toLowerCase().contains(query);
              final matchSub = c.subcategorias?.any((s) => s.nombre.toLowerCase().contains(query)) ?? false;
              return matchPrincipal || matchSub;
            }).toList();
          }

          // IDs seleccionables (excluye transferencia y nulos)
          final allSelectableIds = _allCategories
              .expand((c) => [c, ...?c.subcategorias])
              .where((c) => c.tipo != 'transferencia' && c.id != null)
              .map((c) => c.id!)
              .toSet();
          final allSelected = allSelectableIds.isNotEmpty && allSelectableIds.every((id) => _selectedCategoryIds.contains(id));

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              top: 12,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 5,
                  width: 60,
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).dividerColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Row(
                    children: [
                      const Icon(Icons.category_outlined),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Seleccionar categorías',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            _selectedCategoryIds.clear();
                          });
                        },
                        child: const Text('Limpiar'),
                      ),
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            if (allSelected) {
                              // Deseleccionar todo
                              _selectedCategoryIds.removeWhere((id) => allSelectableIds.contains(id));
                            } else {
                              // Seleccionar todo
                              _selectedCategoryIds.addAll(allSelectableIds);
                            }
                          });
                        },
                        child: Text(allSelected ? 'Quitar todo' : 'Seleccionar todo'),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: TextField(
                    controller: _categorySearchCtrl,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: 'Buscar categoría...',
                      isDense: true,
                      filled: true,
                      fillColor: Theme.of(ctx).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    ),
                    onChanged: (_) => setModalState(() {}),
                  ),
                ),
                if (_allCategories.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      padding: const EdgeInsets.only(bottom: 12),
                      itemCount: visibles.length,
                      itemBuilder: (ctx, i) {
                        final cat = visibles[i];
                        final subcats = cat.subcategorias ?? [];
                        final allChecked = subcats.isNotEmpty && subcats.every((s) => _selectedCategoryIds.contains(s.id));
                        return ExpansionTile(
                          title: Row(
                            children: [
                              Checkbox(
                                value: cat.id != null && _selectedCategoryIds.contains(cat.id),
                                onChanged: (v) {
                                  setModalState(() {
                                    if (v == true) {
                                      if (cat.id != null) _selectedCategoryIds.add(cat.id!);
                                    } else {
                                      if (cat.id != null) _selectedCategoryIds.remove(cat.id!);
                                    }
                                  });
                                },
                              ),
                              Expanded(
                                child: Text(
                                  cat.nombre,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                              if (subcats.isNotEmpty)
                                IconButton(
                                  icon: Icon(
                                    allChecked ? Icons.checklist_rtl : Icons.playlist_add_check,
                                    color: Theme.of(ctx).colorScheme.primary,
                                  ),
                                  onPressed: () {
                                    setModalState(() {
                                      if (allChecked) {
                                        for (final s in subcats) {
                                          if (s.id != null) _selectedCategoryIds.remove(s.id!);
                                        }
                                      } else {
                                        for (final s in subcats) {
                                          if (s.id != null) _selectedCategoryIds.add(s.id!);
                                        }
                                      }
                                    });
                                  },
                                  tooltip: allChecked ? 'Quitar subcategorías' : 'Seleccionar todas las subcategorías',
                                ),
                            ],
                          ),
                          children: subcats.map((s) {
                            final checked = s.id != null && _selectedCategoryIds.contains(s.id!);
                            return ListTile(
                              dense: true,
                              visualDensity: VisualDensity.compact,
                              leading: Checkbox(
                                value: checked,
                                onChanged: (v) {
                                  setModalState(() {
                                    if (s.id == null) return;
                                    if (v == true) {
                                      _selectedCategoryIds.add(s.id!);
                                    } else {
                                      _selectedCategoryIds.remove(s.id!);
                                    }
                                  });
                                },
                              ),
                              title: Text(s.nombre),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            setState(() {});
                          },
                          child: const Text('Cerrar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            setState(() {});
                          },
                          icon: const Icon(Icons.check),
                          label: const Text('Aplicar'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  // --- NUEVO: Rediseño del panel compacto de categorías ---
  Widget _buildCategories(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final seleccionadas = _selectedCategoryIds.length;
    final textoResumen = seleccionadas == 0
        ? 'Ninguna seleccionada'
        : seleccionadas == 1
            ? '1 categoría'
            : '$seleccionadas categorías';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.onSurface.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.category_outlined, color: colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Categorías',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      textoResumen,
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: _openCategorySelector,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Elegir'),
              ),
            ],
          ),
          if (seleccionadas > 0) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _allCategories
                  .expand((c) => [c, ...?c.subcategorias])
                  .where((c) => c.id != null && _selectedCategoryIds.contains(c.id!))
                  .take(8) // mostrar solo primeras 8
                  .map((c) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colorScheme.primary.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          c.nombre,
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ))
                  .toList(),
            ),
            if (seleccionadas > 8)
              Padding(
                padding: const EdgeInsets.only(top: 6.0),
                child: Text(
                  '+${seleccionadas - 8} más',
                  style: TextStyle(fontSize: 11, color: colorScheme.onSurface.withValues(alpha: 0.55)),
                ),
              )
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    TextStyle sectionTitle(ColorScheme cs) => TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: cs.onSurface,
        );

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Buscar y Filtrar',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),

              // 🔍 Buscador principal
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchTermController,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 16,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Buscar por etiqueta...',
                    hintStyle: TextStyle(
                      color: colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: colorScheme.primary,
                      size: 24,
                    ),
                    suffixIcon: _searchTermController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.clear_rounded,
                              color: colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                            onPressed: () {
                              setState(() {
                                _searchTermController.clear();
                              });
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: colorScheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: colorScheme.onSurface.withValues(alpha: 0.10),
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: colorScheme.primary,
                        width: 2,
                      ),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),

              const SizedBox(height: 28),

              // 📅 Fechas
              Text('Rango de fechas', style: sectionTitle(colorScheme)),
              const SizedBox(height: 12),
              _buildDateRange(context),

              const SizedBox(height: 28),

              // 🏷 Categorías
              Text('Categorías', style: sectionTitle(colorScheme)),
              const SizedBox(height: 12),
              _buildCategories(context),

              const SizedBox(height: 28),

              // 💸 Montos
              Text('Rango de montos', style: sectionTitle(colorScheme)),
              const SizedBox(height: 12),
              _buildAmountRange(context),

              const SizedBox(height: 24),

              // 🔧 Filtros avanzados (switches + frecuencia)
              _buildAdvancedFiltersCard(context),

              const SizedBox(height: 28),

              // 🎯 Tipo de transacción
              _buildMultiFilterSection(
                context,
                'Tipo de transacción',
                ['todos', 'ingreso', 'egreso', 'transferencia'],
                _tipos,
                (selectedList) {
                  setState(() => _tipos = selectedList);
                },
              ),

              const SizedBox(height: 24),

              // ↕ Orden
              _buildMultiFilterSection(
                context,
                'Ordenar por',
                ['fecha_desc', 'fecha_asc', 'monto_desc', 'monto_asc'],
                _orders,
                (selectedList) {
                  setState(() => _orders = selectedList);
                },
              ),

              const SizedBox(height: 80), // espacio para los botones de abajo
            ],
          ),
        ),
      ),

      // 🟢 Botones fijos abajo
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _tipos = ['todos'];
                      _orders = [];
                      _searchTermController.clear();
                      _fromDate = null;
                      _toDate = null;
                      _selectedCategoryIds.clear();
                      _minAmountCtrl.clear();
                      _maxAmountCtrl.clear();
                      _tagOnly = false;
                      _noteOnly = false;
                      _onlyRecurrent = false;
                      _hasAttachment = false;
                      _frecuencia = null;
                    });
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  label: const Text(
                    'Limpiar',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colorScheme.onSurface,
                    side: BorderSide(
                      color: colorScheme.onSurface.withValues(alpha: 0.30),
                      width: 1.5,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    final finalTipos = _tipos.isEmpty ? ['todos'] : _tipos;

                    Navigator.pop(context, {
                      'tipos': finalTipos,
                      'orders': _orders,
                      'searchTerm': _searchTermController.text,
                      'from': _fromDate,
                      'to': _toDate,
                      'categoriaIds': _selectedCategoryIds.toList(),
                      'minAmount': double.tryParse(
                        _minAmountCtrl.text.replaceAll(',', '.'),
                      ),
                      'maxAmount': double.tryParse(
                        _maxAmountCtrl.text.replaceAll(',', '.'),
                      ),
                      'tagOnly': _tagOnly,
                      'noteOnly': _noteOnly,
                      'onlyRecurrent': _onlyRecurrent,
                      'hasAttachment': _hasAttachment,
                      'frecuencia': _frecuencia,
                    });
                  },
                  icon: const Icon(Icons.check_rounded, size: 20),
                  label: const Text(
                    'Aplicar',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMultiFilterSection(
    BuildContext context,
    String title,
    List<String> options,
    List<String> selectedValues,
    ValueChanged<List<String>> onChanged,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.onSurface.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
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
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  title == 'Tipo de transacción'
                      ? Icons.category_rounded
                      : Icons.sort_rounded,
                  color: colorScheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: options.map((option) {
              final isSelected = selectedValues.contains(option);
              return _buildFilterChip(
                context,
                option,
                isSelected,
                (selected) {
                  List<String> newSelection = List.from(selectedValues);

                  if (title == 'Tipo de transacción') {
                    if (option == 'todos') {
                      newSelection = selected ? ['todos'] : [];
                    } else {
                      if (newSelection.contains('todos')) {
                        newSelection.remove('todos');
                      }
                      if (selected) {
                        newSelection.add(option);
                      } else {
                        newSelection.remove(option);
                      }

                      if (newSelection.length == 3 &&
                          newSelection.contains('ingreso') &&
                          newSelection.contains('egreso') &&
                          newSelection.contains('transferencia')) {
                        newSelection = ['todos'];
                      }
                    }
                  } else if (title == 'Ordenar por') {
                    if (selected) {
                      if (option == 'fecha_desc' || option == 'fecha_asc') {
                        newSelection.removeWhere((item) => item == 'fecha_desc' || item == 'fecha_asc');
                        newSelection.add(option);
                      } else if (option == 'monto_desc' || option == 'monto_asc') {
                        newSelection.removeWhere((item) => item == 'monto_desc' || item == 'monto_asc');
                        newSelection.add(option);
                      }
                    } else {
                      newSelection.remove(option);
                    }
                  }

                  onChanged(newSelection);
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    BuildContext context,
    String option,
    bool isSelected,
    ValueChanged<bool> onSelected,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    IconData? icon;
    switch (option) {
      case 'todos':
        icon = Icons.all_inclusive_rounded;
        break;
      case 'ingreso':
        icon = Icons.arrow_downward_rounded;
        break;
      case 'egreso':
        icon = Icons.arrow_upward_rounded;
        break;
      case 'transferencia':
        icon = Icons.swap_horiz_rounded;
        break;
      case 'fecha_desc':
        icon = Icons.calendar_today_rounded;
        break;
      case 'fecha_asc':
        icon = Icons.calendar_month_rounded;
        break;
      case 'monto_desc':
        icon = Icons.trending_up_rounded;
        break;
      case 'monto_asc':
        icon = Icons.trending_down_rounded;
        break;
    }

    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? colorScheme.onPrimary
                  : colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 8),
          ],
          Text(
            _getDisplayValue(option),
            style: TextStyle(
              color: isSelected
                  ? colorScheme.onPrimary
                  : colorScheme.onSurface,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ],
      ),
      selected: isSelected,
      onSelected: onSelected,
      backgroundColor: isDark
          ? colorScheme.surfaceContainerHighest
          : Colors.grey.shade100,
      selectedColor: colorScheme.primary,
      checkmarkColor: colorScheme.onPrimary,
      elevation: isSelected ? 2 : 0,
      pressElevation: 4,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isSelected
              ? colorScheme.primary
              : colorScheme.onSurface.withValues(alpha: 0.2),
          width: isSelected ? 1.5 : 1,
        ),
      ),
    );
  }

  String _getDisplayValue(String value) {
    switch (value) {
      case 'todos':
        return 'Todos';
      case 'ingreso':
        return 'Ingreso';
      case 'egreso':
        return 'Egreso';
      case 'transferencia':
        return 'Transferencia';
      case 'fecha_desc':
        return 'Recientes';
      case 'fecha_asc':
        return 'Antiguos';
      case 'monto_desc':
        return 'Mayor monto';
      case 'monto_asc':
        return 'Menor monto';
      default:
        return value;
    }
  }

  Widget _buildDateRange(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildDateTile(
            context,
            label: 'Desde',
            date: _fromDate,
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _fromDate ?? DateTime.now(),
                firstDate: DateTime(2010),
                lastDate: DateTime(2100),
              );
              if (picked != null) setState(() => _fromDate = picked);
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildDateTile(
            context,
            label: 'Hasta',
            date: _toDate,
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _toDate ?? DateTime.now(),
                firstDate: DateTime(2010),
                lastDate: DateTime(2100),
              );
              if (picked != null) setState(() => _toDate = picked);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDateTile(BuildContext context, {required String label, DateTime? date, required VoidCallback onTap}) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.onSurface.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            const Icon(Icons.date_range),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withValues(alpha: 0.6))),
                  const SizedBox(height: 4),
                  Text(
                    date == null ? 'Cualquier fecha' : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: colorScheme.onSurface.withValues(alpha: 0.4)),
          ],
        ),
      ),
    );
  }


  Widget _buildAmountRange(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.onSurface.withValues(alpha: 0.10),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _minAmountCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Monto mínimo',
                prefixText: 'S/. ',
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _maxAmountCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Monto máximo',
                prefixText: 'S/. ',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedFiltersCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune_rounded, size: 20, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Filtros avanzados',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          _buildSwitchRow(
            context,
            icon: Icons.label_outline,
            title: 'Buscar solo en etiqueta',
            subtitle: 'Ignorar el contenido de la nota',
            value: _tagOnly,
            onChanged: (v) {
              setState(() {
                _tagOnly = v;
                if (v) _noteOnly = false;
              });
            },
          ),
          const Divider(height: 16),

          _buildSwitchRow(
            context,
            icon: Icons.sticky_note_2_outlined,
            title: 'Buscar solo en nota',
            subtitle: 'Ignorar la etiqueta cuando esté activo',
            value: !_tagOnly && _noteOnly,
            onChanged: (v) {
              setState(() {
                _noteOnly = v;
                if (v) _tagOnly = false;
              });
            },
          ),
          const Divider(height: 16),

          _buildSwitchRow(
            context,
            icon: Icons.repeat_rounded,
            title: 'Solo recurrentes',
            subtitle: 'Transacciones con frecuencia definida',
            value: _onlyRecurrent,
            onChanged: (v) => setState(() => _onlyRecurrent = v),
          ),
          const Divider(height: 16),

          _buildSwitchRow(
            context,
            icon: Icons.attachment_rounded,
            title: 'Con comprobante',
            subtitle: 'Recibos, vouchers o imágenes adjuntas',
            value: _hasAttachment,
            onChanged: (v) => setState(() => _hasAttachment = v),
          ),

          const SizedBox(height: 16),

          DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: 'Frecuencia'),
            initialValue: _frecuencia,
            items: const [
              DropdownMenuItem(value: null, child: Text('Cualquiera')),
              DropdownMenuItem(value: 'semanal', child: Text('Semanal')),
              DropdownMenuItem(value: 'quincenal', child: Text('Quincenal')),
              DropdownMenuItem(value: 'mensual', child: Text('Mensual')),
              DropdownMenuItem(value: 'personalizada', child: Text('Personalizada')),
            ],
            onChanged: (val) => setState(() => _frecuencia = val),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: colorScheme.primary.withValues(alpha: 0.9)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ],
          ),
        ),
        Switch.adaptive(
          value: value,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
