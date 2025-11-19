import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/category_providers.dart';
import '../../models/services/auth_service.dart';
import '../../controllers/transactions/budgets_cache.dart';
import '../../controllers/budgets/category_budget_controller.dart';
import '../../models/dtos/category_model.dart';
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
  // Estado de paginación
  static const int _pageSize = 30;
  int _loaded = 0;
  bool _isLoadingMore = false;
  final ScrollController _scrollController = ScrollController();
  bool _reorderMode = false;
  List<Category> _reorderList = [];
  bool _initializedPaged = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _scrollController.addListener(_onScrollLoadMore);
    // iniciar paginación con primer lote
    _loaded = _pageSize;
    _initializedPaged = true;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScrollLoadMore() async {
    if (_isLoadingMore) return;
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      final repo = ref.read(categoryRepositoryProvider);
      final total = await repo.countUserPrincipalCategories();
      if (!mounted) return; // mounted check tras await
      if (_loaded < total) {
        setState(() => _isLoadingMore = true);
        final next = _loaded + _pageSize;
        final newLoaded = next > total ? total : next;
        setState(() => _loaded = newLoaded);
        setState(() => _isLoadingMore = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesStateProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2D2D2D),
        elevation: 0,
        title: Text(
          _reorderMode ? 'Reordenar Categorías' : 'Gestionar Categorías',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          if (!_reorderMode) ...[
            IconButton(
              icon: const Icon(Icons.business, color: Color(0xFF13BB67)),
              onPressed: _showBusinessTemplateSelector,
              tooltip: 'Plantillas de negocio',
            ),
            IconButton(
              icon: const Icon(Icons.swap_vert, color: Colors.white),
              tooltip: 'Reordenar (en pestaña Todas)',
              onPressed: () => setState(() {
                _reorderMode = true;
              }),
            ),
          ] else ...[
            TextButton(
              onPressed: () => setState(() {
                _reorderMode = false;
              }),
              child: const Text('Cancelar'),
            ),
            IconButton(
              icon: const Icon(Icons.check, color: Color(0xFF13BB67)),
              tooltip: 'Guardar orden',
              onPressed: _saveReorder,
            ),
          ],
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
    // Si estamos en modo reordenar, solo funciona en pestaña 'Todas'
    if (_reorderMode && tipo == null) {
      // construir lista de principales
      if (_reorderList.isEmpty) {
        _reorderList = allCategories.where((c) => c.esPrincipal).toList();
      }
      // filtro búsqueda
      final filtered = _searchQuery.isNotEmpty
          ? _reorderList.where((c) => c.nombre.toLowerCase().contains(_searchQuery.toLowerCase())).toList()
          : _reorderList;

      return ReorderableListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filtered.length,
        onReorder: (oldIndex, newIndex) {
          setState(() {
            if (newIndex > oldIndex) newIndex -= 1;
            final item = filtered.removeAt(oldIndex);
            filtered.insert(newIndex, item);
            // reflejar en _reorderList el nuevo orden global
            _reorderList = filtered;
          });
        },
        itemBuilder: (context, index) {
          final category = filtered[index];
          return ListTile(
            key: ValueKey('reorder_${category.id}'),
            tileColor: const Color(0xFF2D2D2D),
            leading: Icon(category.iconAsIconData, color: category.colorAsColor),
            title: Text(category.nombre, style: const TextStyle(color: Colors.white)),
            subtitle: Text(category.tipoDisplay, style: TextStyle(color: Colors.grey[400])),
            trailing: const Icon(Icons.drag_handle, color: Colors.white54),
          );
        },
      );
    }

    // Filtrar por tipo si es necesario
    List<Category> categories = tipo != null
        ? allCategories.where((c) => c.tipo == tipo).toList()
        : allCategories;

    // Si pestaña 'Todas' y no reordenando, usar paginación de principales, subcategorías lazy
    if (tipo == null && !_reorderMode) {
      if (!_initializedPaged) {
        _loaded = _pageSize;
        _initializedPaged = true;
      }
      final repo = ref.read(categoryRepositoryProvider);
      final future = repo.getUserCategoriesPaged(limit: _loaded, offset: 0);
      return FutureBuilder<List<Category>>(
        key: ValueKey('paged_$_loaded'),
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF13BB67)));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final pagedCategories = snapshot.data ?? const [];
          var list = _searchQuery.isNotEmpty
              ? pagedCategories.where((c) => c.nombre.toLowerCase().contains(_searchQuery.toLowerCase())).toList()
              : pagedCategories;

          return ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: list.length + (_isLoadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == list.length) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: CircularProgressIndicator(color: Color(0xFF13BB67)),
                  ),
                );
              }
              return _buildCategoryTileLazy(list[index]);
            },
          );
        },
      );
    }

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
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: categories.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == categories.length) {
          // Indicador de carga
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: CircularProgressIndicator(
                color: Color(0xFF13BB67),
              ),
            ),
          );
        }

        final category = categories[index];
        return _buildCategoryTile(category);
      },
    );
  }

  Widget _buildCategoryTileLazy(Category category) {
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
          children: [
            Builder(
              builder: (context) {
                final repo = ref.read(categoryRepositoryProvider);
                return FutureBuilder<List<Category>>(
                  future: repo.getSubcategories(category.id!),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: LinearProgressIndicator(minHeight: 2),
                      );
                    }
                    if (snapshot.hasError) {
                      return Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Text('Error cargando subcategorías', style: TextStyle(color: Colors.red[300])),
                      );
                    }
                    final subcats = snapshot.data ?? const [];
                    return Column(
                      children: subcats.map((s) => _buildSubcategoryTile(s, category)).toList(),
                    );
                  },
                );
              },
            ),
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

  Future<void> _saveReorder() async {
    if (_reorderList.isEmpty) {
      setState(() => _reorderMode = false);
      return;
    }
    final ids = _reorderList.map((e) => e.id!).toList();
    final ok = await ref.read(categoriesStateProvider.notifier).reorderCategories(ids);
    if (!mounted) return;
    if (ok) {
      ref.invalidate(categoriesStateProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Orden actualizado'), backgroundColor: Color(0xFF13BB67)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo actualizar el orden'), backgroundColor: Colors.red),
      );
    }
    setState(() => _reorderMode = false);
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
              _buildCategoryMenu(category, hasSubcategories: hasSubcategories),
            ],
          ),
          children: [
            if (hasSubcategories) ...[
              ...category.subcategorias!.map((subcat) => _buildSubcategoryTile(subcat, category)),
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

  Widget _buildCategoryMenu(Category category, {bool hasSubcategories = false}) {
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
          if (hasSubcategories && (category.subcategorias?.length ?? 0) > 1)
            const PopupMenuItem(
              value: 'reorder_sub',
              child: Row(
                children: [
                  Icon(Icons.sort, color: Colors.white, size: 20),
                  SizedBox(width: 12),
                  Text('Reordenar subcategorías', style: TextStyle(color: Colors.white)),
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
          case 'reorder_sub':
            _showReorderSubcategories(category);
            break;
        }
      },
    );
  }

  void _showReorderSubcategories(Category parent) async {
    // Capturar referencias antes de awaits
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(categoryRepositoryProvider);
    final subcats = await repo.getSubcategories(parent.id!);
    if (!mounted) return; // tras await
    if (subcats.length < 2) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No hay suficientes subcategorías para reordenar'), backgroundColor: Colors.orange),
      );
      return;
    }

    List<Category> workingList = List.of(subcats);

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            return AlertDialog(
              backgroundColor: const Color(0xFF2D2D2D),
              title: Row(
                children: [
                  const Icon(Icons.sort, color: Color(0xFF13BB67)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Reordenar subcategorías de "${parent.nombre}"',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 400,
                height: 400,
                child: ReorderableListView.builder(
                  itemCount: workingList.length,
                  buildDefaultDragHandles: false,
                  onReorder: (oldIndex, newIndex) {
                    setStateDialog(() {
                      if (newIndex > oldIndex) newIndex -= 1;
                      final item = workingList.removeAt(oldIndex);
                      workingList.insert(newIndex, item);
                    });
                  },
                  itemBuilder: (ctx, index) {
                    final sub = workingList[index];
                    return ListTile(
                      key: ValueKey('sub_${sub.id}'),
                      leading: ReorderableDragStartListener(
                        index: index,
                        child: Icon(sub.iconAsIconData, color: sub.colorAsColor),
                      ),
                      title: Text(sub.nombre, style: const TextStyle(color: Colors.white)),
                      subtitle: sub.descripcion != null
                          ? Text(sub.descripcion!, style: TextStyle(color: Colors.grey[400]))
                          : null,
                      trailing: Text('#${index + 1}', style: TextStyle(color: Colors.grey[500])),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
    if (!mounted) return; // tras await showDialog
    if (saved == true) {
      final ids = workingList.map((c) => c.id!).toList();
      final ok = await ref.read(categoriesStateProvider.notifier).reorderCategories(ids);
      if (!mounted) return; // tras await
      if (ok) {
        ref.invalidate(categoriesStateProvider);
        messenger.showSnackBar(
          const SnackBar(content: Text('Subcategorías reordenadas'), backgroundColor: Color(0xFF13BB67)),
        );
      } else {
        messenger.showSnackBar(
          const SnackBar(content: Text('Error al reordenar subcategorías'), backgroundColor: Colors.red),
        );
      }
    }
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
    if (!mounted) return; // tras await showDialog
    if (result == true) {
      ref.invalidate(categoriesStateProvider);
    }
  }

  void _showBusinessTemplateSelector() async {
    // Capturar context dependencias antes de awaits
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

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
    if (!mounted) return;
    if (confirmReplace != true) return;

    final templateId = await showDialog<String>(
      context: context,
      builder: (context) => const BusinessTemplateSelector(),
    );
    if (!mounted) return;
    if (templateId == null) return;

    // Mostrar loader sin await
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF13BB67)),
      ),
    );

    final success = await ref.read(categoriesStateProvider.notifier)
        .applyBusinessTemplate(templateId);
    if (!mounted) return;

    navigator.pop(); // cerrar loader
    if (success) {
      ref.invalidate(categoriesStateProvider);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Plantilla aplicada exitosamente'),
          backgroundColor: Color(0xFF13BB67),
        ),
      );
    } else {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Error al aplicar la plantilla'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _confirmDelete(Category category) {
    // Capturar messenger antes de async
    final messenger = ScaffoldMessenger.of(context);
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
              navigatorPopSafe(context); // función helper segura (definida abajo)
              final success = await ref.read(categoriesStateProvider.notifier)
                  .deleteCategory(category.id!);
              if (!mounted) return;
              if (success) {
                ref.invalidate(categoriesStateProvider);
                // Invalidar provider de categorías por tipo (por si hay vistas que lo usan)
                try { ref.invalidate(expenseCategoriesProvider); } catch (_) {}
                // Limpiar caché de presupuestos para evitar que queden tarjetas huérfanas
                try {
                  final uid = AuthService().currentUserId;
                  if (uid != null) BudgetsCache.instance().clearCategories(uid);
                } catch (_) {}
                // Invalidar controllers de presupuesto asociados a esta categoría para
                // forzar recarga / eliminación de tarjetas huérfanas.
                try {
                  final now = DateTime.now();
                  final keyMensual = CategoryBudgetKey(categoriaId: category.id!, periodo: 'mensual', referencia: DateTime(now.year, now.month, 1));
                  final keyTrimestral = CategoryBudgetKey(categoriaId: category.id!, periodo: 'trimestral', referencia: DateTime(now.year, now.month, 1));
                  ref.invalidate(categoryBudgetControllerProvider(keyMensual));
                  ref.invalidate(categoryBudgetControllerProvider(keyTrimestral));
                } catch (_) {}
              }
              messenger.showSnackBar(
                SnackBar(
                  content: Text(success
                      ? 'Categoría eliminada'
                      : 'No se pudo eliminar la categoría'),
                  backgroundColor: success ? const Color(0xFF13BB67) : Colors.red,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  void navigatorPopSafe(BuildContext ctx) {
    if (Navigator.of(ctx).canPop()) {
      Navigator.of(ctx).pop();
    }
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
