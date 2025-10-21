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
    // Convertir string a lista para permitir selección múltiple
    final initialTipo = widget.initialFilters['tipo'] ?? 'todos';
    _tipos = initialTipo == 'todos' ? ['todos'] : [initialTipo];

    // Inicializar orden sin ninguna selección
    _orders = [];

    _searchTermController = TextEditingController(text: widget.initialFilters['searchTerm']);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.grey[900],
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Buscar y Filtrar', style: TextStyle(color: Colors.white)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _searchTermController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Buscar por etiqueta...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                filled: true,
                fillColor: Colors.grey[800],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildMultiFilterSection('Tipo de transacción', ['todos', 'ingreso', 'egreso', 'transferencia'], _tipos, (selectedList) {
              setState(() => _tipos = selectedList);
            }),
            const SizedBox(height: 24),
            _buildMultiFilterSection('Orden', ['fecha_desc', 'fecha_asc', 'monto_desc', 'monto_asc'], _orders, (selectedList) {
              setState(() => _orders = selectedList);
            }),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                SizedBox(
                  width: 80,
                  height: 80,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _tipos = ['todos'];
                        _orders = [];
                        _searchTermController.clear();
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[800],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Icon(Icons.refresh, size: 32),
                  ),
                ),
                SizedBox(
                  width: 80,
                  height: 80,
                  child: ElevatedButton(
                    onPressed: () {
                      List<String> finalTipos = _tipos.isEmpty ? ['todos'] : _tipos;

                      Navigator.pop(context, {
                        'tipos': finalTipos, // Enviar la lista completa de tipos
                        'orders': _orders, // Enviar la lista completa de órdenes
                        'searchTerm': _searchTermController.text,
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Icon(Icons.check, size: 32),
                  ),
                ),
              ],
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildMultiFilterSection(String title, List<String> options, List<String> selectedValues, ValueChanged<List<String>> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Wrap(
            spacing: 8.0,
            children: options.map((option) {
              final isSelected = selectedValues.contains(option);
              return ChoiceChip(
                label: Text(
                  _getDisplayValue(option),
                  style: TextStyle(color: isSelected ? Colors.black : Colors.white),
                ),
                selected: isSelected,
                onSelected: (selected) {
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
                  } else if (title == 'Orden') {
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
                backgroundColor: Colors.grey[800],
                selectedColor: Colors.amber,
              );
            }).toList(),
          ),
        ),
      ],
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
