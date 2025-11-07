import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/category_providers.dart';
import '../../../../data/models/category_model.dart';
import 'category_form_dialog.dart';
import 'business_template_selector.dart';

class CategoriesManagementView extends ConsumerStatefulWidget {
  const CategoriesManagementView({super.key});

  @override
  ConsumerState<CategoriesManagementView> createState() => _CategoriesManagementViewState();
}

class _CategoriesManagementViewState extends ConsumerState<CategoriesManagementView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesStateProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2D2D2D),
        elevation: 0,
        title: const Text(
          'Gestionar Categorías',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.business, color: Color(0xFF13BB67)),
            onPressed: _showBusinessTemplateSelector,
            tooltip: 'Plantillas de negocio',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF13BB67),
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Ingresos'),
            Tab(text: 'Gastos'),
            Tab(text: 'Todas'),
          ],
        ),
      ),
      body: categoriesAsync.when(
        data: (categories) => Column(
          children: [
            _buildSearchBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildCategoryList(categories, 'ingreso'),
                  _buildCategoryList(categories, 'egreso'),
                  _buildCategoryList(categories, null),
                ],
              ),
            ),
          ],
        ),
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFF13BB67)),
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 64),
              const SizedBox(height: 16),
              Text(
                'Error al cargar categorías',
                style: TextStyle(color: Colors.grey[400]),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => ref.refresh(categoriesStateProvider),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF13BB67),
                ),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCategoryForm(null),
        backgroundColor: const Color(0xFF13BB67),
        icon: const Icon(Icons.add),
        label: const Text('Nueva Categoría'),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF2D2D2D),
        border: Border(
          bottom: BorderSide(
            color: Color(0xFF3A3A3A),
            width: 1,
          ),
        ),
      ),
      child: TextField(
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Buscar categorías...',
          hintStyle: TextStyle(color: Colors.grey[500]),
          prefixIcon: const Icon(Icons.search, color: Color(0xFF13BB67)),
          filled: true,
          fillColor: const Color(0xFF1E1E1E),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        ),
      ),
    );
  }

  Widget _buildCategoryList(List<Category> allCategories, String? tipo) {
    // Filtrar por tipo si es necesario
    List<Category> categories = tipo != null
        ? allCategories.where((c) => c.tipo == tipo).toList()
        : allCategories;

    // Filtrar por búsqueda
    if (_searchQuery.isNotEmpty) {
      categories = categories.where((c) =>
      c.nombre.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (c.descripcion?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false)
      ).toList();
    }

    if (categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.category_outlined,
              size: 64,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No se encontraron categorías'
                  : 'No hay categorías ${tipo == "ingreso" ? "de ingreso" : tipo == "egreso" ? "de gasto" : ""}',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[400],
              ),
            ),
            if (_searchQuery.isEmpty) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => _showCategoryForm(tipo),
                icon: const Icon(Icons.add, color: Color(0xFF13BB67)),
                label: Text(
                  'Crear primera categoría',
                  style: TextStyle(color: Colors.grey[300]),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        return _buildCategoryTile(category);
      },
    );
  }

  Widget _buildCategoryTile(Category category) {
    final hasSubcategories = category.subcategorias?.isNotEmpty ?? false;

    return Card(
      color: const Color(0xFF2D2D2D),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: category.colorAsColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              category.iconAsIconData,
              color: category.colorAsColor,
              size: 24,
            ),
          ),
          title: Text(
            category.nombre,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          subtitle: category.descripcion != null
              ? Text(
            category.descripcion!,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 13,
            ),
          )
              : null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (category.esPredeterminada)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Sistema',
                    style: TextStyle(
                      color: Colors.blue,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              _buildCategoryMenu(category),
            ],
          ),
          children: [
            if (hasSubcategories) ...[
              ...category.subcategorias!.map((subcat) =>
                  _buildSubcategoryTile(subcat, category)
              ),
            ],
            // Botón para agregar subcategoría
            if (!category.esPredeterminada)
              ListTile(
                leading: const SizedBox(width: 40),
                title: TextButton.icon(
                  onPressed: () => _showCategoryForm(category.tipo, parentCategory: category),
                  icon: const Icon(Icons.add, size: 18, color: Color(0xFF13BB67)),
                  label: Text(
                    'Agregar subcategoría',
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                  style: TextButton.styleFrom(
                    alignment: Alignment.centerLeft,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubcategoryTile(Category subcategory, Category parent) {
    return ListTile(
      contentPadding: const EdgeInsets.only(left: 72, right: 16),
      leading: Icon(
        subcategory.iconAsIconData,
        color: subcategory.colorAsColor,
        size: 20,
      ),
      title: Text(
        subcategory.nombre,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
        ),
      ),
      trailing: _buildCategoryMenu(subcategory),
    );
  }

  Widget _buildCategoryMenu(Category category) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, color: Colors.grey[400]),
      color: const Color(0xFF3A3A3A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      itemBuilder: (context) => [
        if (!category.esPredeterminada) ...[
          const PopupMenuItem(
            value: 'edit',
            child: Row(
              children: [
                Icon(Icons.edit, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Text('Editar', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete, color: Colors.red, size: 20),
                SizedBox(width: 12),
                Text('Eliminar', style: TextStyle(color: Colors.red)),
              ],
            ),
          ),
        ] else ...[
          const PopupMenuItem(
            value: 'info',
            child: Row(
              children: [
                Icon(Icons.info, color: Colors.blue, size: 20),
                SizedBox(width: 12),
                Text('Categoría del sistema', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
        ],
      ],
      onSelected: (value) {
        switch (value) {
          case 'edit':
            _showCategoryForm(category.tipo, editingCategory: category);
            break;
          case 'delete':
            _confirmDelete(category);
            break;
          case 'info':
            _showSystemCategoryInfo();
            break;
        }
      },
    );
  }

  void _showCategoryForm(String? tipo, {Category? editingCategory, Category? parentCategory}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => CategoryFormDialog(
        tipo: tipo ?? editingCategory?.tipo ?? 'egreso',
        editingCategory: editingCategory,
        parentCategory: parentCategory,
      ),
    );

    if (result == true && mounted) {
      // Refrescar la lista de categorías
      ref.invalidate(categoriesStateProvider);
    }
  }

  void _showBusinessTemplateSelector() async {
    // Primero mostrar advertencia
    final confirmReplace = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2D2D2D),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange[400], size: 24),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Advertencia',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: const Text(
            'Al aplicar una plantilla de negocio, se ELIMINARÁN todas tus categorías actuales y se reemplazarán con las de la plantilla seleccionada.\n\n¿Deseas continuar?',
            style: TextStyle(fontSize: 15),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );

    if (confirmReplace != true || !mounted) return;

    // Si confirma, mostrar selector de plantillas
    final templateId = await showDialog<String>(
      context: context,
      builder: (context) => const BusinessTemplateSelector(),
    );

    if (templateId != null && mounted) {
      // Mostrar indicador de carga
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF13BB67),
          ),
        ),
      );

      final success = await ref.read(categoriesStateProvider.notifier)
          .applyBusinessTemplate(templateId);

      if (mounted) {
        // Cerrar indicador de carga
        Navigator.pop(context);

        if (success) {
          // Invalidar provider después de aplicar plantilla exitosamente
          ref.invalidate(categoriesStateProvider);

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Plantilla aplicada exitosamente'),
              backgroundColor: Color(0xFF13BB67),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error al aplicar la plantilla'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _confirmDelete(Category category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2D2D2D),
        title: const Text(
          'Eliminar categoría',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          '¿Estás seguro de eliminar "${category.nombre}"?',
          style: TextStyle(color: Colors.grey[300]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: TextStyle(color: Colors.grey[400])),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await ref.read(categoriesStateProvider.notifier)
                  .deleteCategory(category.id!);

              if (mounted) {
                if (success) {
                  // Invalidar provider después de eliminar exitosamente
                  ref.invalidate(categoriesStateProvider);
                }

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success
                        ? 'Categoría eliminada'
                        : 'No se pudo eliminar la categoría'),
                    backgroundColor: success ? const Color(0xFF13BB67) : Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  void _showSystemCategoryInfo() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Las categorías del sistema no se pueden modificar'),
        backgroundColor: Colors.blue,
      ),
    );
  }
}