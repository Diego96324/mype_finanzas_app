import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/category_providers.dart';
import '../../models/dtos/category_model.dart';

class CategoryFormDialog extends ConsumerStatefulWidget {
  final String? tipo;
  final Category? editingCategory;
  final Category? parentCategory;

  const CategoryFormDialog({
    super.key,
    this.tipo,
    this.editingCategory,
    this.parentCategory,
  });

  @override
  ConsumerState<CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends ConsumerState<CategoryFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nombreController;
  late TextEditingController _descripcionController;
  String? _tipoSeleccionado;
  String _iconoSeleccionado = 'category';
  Color _colorSeleccionado = Colors.blue;

  final List<String> _iconosDisponibles = CategoryIcons.getAllIconNames();

  final List<Color> _coloresDisponibles = [
    Colors.red,
    Colors.pink,
    Colors.purple,
    Colors.deepPurple,
    Colors.indigo,
    Colors.blue,
    Colors.lightBlue,
    Colors.cyan,
    Colors.teal,
    Colors.green,
    Colors.lightGreen,
    Colors.lime,
    Colors.yellow,
    Colors.amber,
    Colors.orange,
    Colors.deepOrange,
    Colors.brown,
    Colors.grey,
  ];

  @override
  void initState() {
    super.initState();
    _nombreController = TextEditingController(
      text: widget.editingCategory?.nombre ?? '',
    );
    _descripcionController = TextEditingController(
      text: widget.editingCategory?.descripcion ?? '',
    );
    _tipoSeleccionado = widget.editingCategory?.tipo ??
                        widget.parentCategory?.tipo ??
                        widget.tipo;
    _iconoSeleccionado = widget.editingCategory?.icono ?? 'category';

    if (widget.editingCategory != null) {
      try {
        _colorSeleccionado = Color(int.parse(
          widget.editingCategory!.color.replaceFirst('#', '0xFF'),
        ));
      } catch (e) {
        _colorSeleccionado = Colors.blue;
      }
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _descripcionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.editingCategory != null;
    final isSubcategory = widget.parentCategory != null;

    return AlertDialog(
      title: Text(
        isEditing
            ? 'Editar Categoría'
            : isSubcategory
                ? 'Nueva Subcategoría'
                : 'Nueva Categoría',
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Categoría padre (si es subcategoría)
                if (widget.parentCategory != null) ...[
                  Text(
                    'Categoría Padre:',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Chip(
                    avatar: Icon(
                      _getIconData(widget.parentCategory!.icono),
                      size: 16,
                    ),
                    label: Text(widget.parentCategory!.nombre),
                  ),
                  const SizedBox(height: 16),
                ],

                // Nombre
                TextFormField(
                  controller: _nombreController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.label),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor ingrese un nombre';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Tipo (solo si no es subcategoría)
                if (!isSubcategory) ...[
                  DropdownButtonFormField<String>(
                    initialValue: _tipoSeleccionado,
                    decoration: const InputDecoration(
                      labelText: 'Tipo',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.swap_vert),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'ingreso', child: Text('Ingreso')),
                      DropdownMenuItem(value: 'egreso', child: Text('Egreso')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _tipoSeleccionado = value;
                      });
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor seleccione un tipo';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                ],

                // Descripción
                TextFormField(
                  controller: _descripcionController,
                  decoration: const InputDecoration(
                    labelText: 'Descripción (opcional)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.description),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),

                // Icono
                Text(
                  'Icono:',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 60,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _iconosDisponibles.length,
                    itemBuilder: (context, index) {
                      final icono = _iconosDisponibles[index];
                      final isSelected = icono == _iconoSeleccionado;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _iconoSeleccionado = icono;
                            });
                          },
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? _colorSeleccionado.withValues(alpha: 0.3)
                                  : Colors.grey.withValues(alpha: 0.1),
                              border: Border.all(
                                color: isSelected
                                    ? _colorSeleccionado
                                    : Colors.grey.withValues(alpha: 0.3),
                                width: isSelected ? 2 : 1,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              _getIconData(icono),
                              color: isSelected ? _colorSeleccionado : Colors.grey,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // Color
                Text(
                  'Color:',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 50,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _coloresDisponibles.length,
                    itemBuilder: (context, index) {
                      final color = _coloresDisponibles[index];
                      final isSelected = color == _colorSeleccionado;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _colorSeleccionado = color;
                            });
                          },
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? Colors.black : Colors.transparent,
                                width: 3,
                              ),
                            ),
                            child: isSelected
                                ? const Icon(Icons.check, color: Colors.white)
                                : null,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _guardarCategoria,
          child: Text(isEditing ? 'Actualizar' : 'Crear'),
        ),
      ],
    );
  }

  IconData _getIconData(String iconName) {
    return CategoryIcons.getIcon(iconName);
  }

  Future<void> _guardarCategoria() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Construir HEX sin canal alpha usando toARGB32
    final argb = _colorSeleccionado.toARGB32();
    final hexFull = argb.toRadixString(16).padLeft(8, '0');
    final colorHex = '#${hexFull.substring(2)}';
    final notifier = ref.read(categoriesStateProvider.notifier);

    bool success;
    if (widget.editingCategory != null) {
      // Actualizar categoría existente
      success = await notifier.updateCategory(
        categoryId: widget.editingCategory!.id!,
        nombre: _nombreController.text.trim(),
        descripcion: _descripcionController.text.trim().isEmpty
            ? null
            : _descripcionController.text.trim(),
        icono: _iconoSeleccionado,
        color: colorHex,
      );
    } else {
      // Crear nueva categoría
      success = await notifier.createCategory(
        nombre: _nombreController.text.trim(),
        tipo: _tipoSeleccionado!,
        categoriaPadreId: widget.parentCategory?.id,
        descripcion: _descripcionController.text.trim().isEmpty
            ? null
            : _descripcionController.text.trim(),
        icono: _iconoSeleccionado,
        color: colorHex,
      );
    }

    if (mounted) {
      // Primero cerrar el diálogo
      Navigator.pop(context, success);

      // Luego mostrar el snackbar si fue exitoso
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.editingCategory != null
                  ? 'Categoría actualizada'
                  : 'Categoría creada',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al guardar la categoría'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
