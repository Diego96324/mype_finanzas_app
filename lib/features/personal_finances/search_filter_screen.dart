import 'package:flutter/material.dart';

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

  @override
  void initState() {
    super.initState();
    final initialTipo = widget.initialFilters['tipo'] ?? 'todos';
    _tipos = initialTipo == 'todos' ? ['todos'] : [initialTipo];
    _orders = [];
    _searchTermController = TextEditingController(text: widget.initialFilters['searchTerm']);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        title: Text(
          'Buscar y Filtrar',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
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
                        color: colorScheme.onSurface.withValues(alpha: 0.1),
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
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {});
                  },
                ),
              ),
              const SizedBox(height: 32),
              _buildMultiFilterSection(
                context,
                'Tipo de transacción',
                ['todos', 'ingreso', 'egreso', 'transferencia'],
                _tipos,
                (selectedList) {
                  setState(() => _tipos = selectedList);
                },
              ),
              const SizedBox(height: 28),
              _buildMultiFilterSection(
                context,
                'Ordenar por',
                ['fecha_desc', 'fecha_asc', 'monto_desc', 'monto_asc'],
                _orders,
                (selectedList) {
                  setState(() => _orders = selectedList);
                },
              ),
              const SizedBox(height: 48),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _tipos = ['todos'];
                          _orders = [];
                          _searchTermController.clear();
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
                          color: colorScheme.onSurface.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
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
                        List<String> finalTipos = _tipos.isEmpty ? ['todos'] : _tipos;

                        Navigator.pop(context, {
                          'tipos': finalTipos,
                          'orders': _orders,
                          'searchTerm': _searchTermController.text,
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
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
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
}

