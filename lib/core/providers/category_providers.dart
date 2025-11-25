import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../models/repositories/category_repository.dart';
import '../../models/dtos/category_model.dart';

part 'category_providers.g.dart';

// Repositorio de categorías
@riverpod
CategoryRepository categoryRepository(Ref ref) {
  return CategoryRepository();
}

// Estado general de las categorías del usuario
@riverpod
class CategoriesState extends _$CategoriesState {
  @override
  Future<List<Category>> build() async {
    return await _loadCategories();
  }

  Future<List<Category>> _loadCategories() async {
    try {
      final repo = ref.read(categoryRepositoryProvider);
      return await repo.getUserCategories();
    } catch (e) {
      return [];
    }
  }

  // Refrescar desde la UI
  Future<void> refresh() async {
    state = const AsyncLoading();
    final data = await _loadCategories();
    state = AsyncData(data);
  }

  // Crear una nueva categoría
  Future<bool> createCategory({
    required String nombre,
    required String tipo,
    int? categoriaPadreId,
    String? descripcion,
    required String icono,
    required String color,
    String? tipoNegocio,
  }) async {
    try {
      final repo = ref.read(categoryRepositoryProvider);
      final category = await repo.createCategory(
        nombre: nombre,
        tipo: tipo,
        categoriaPadreId: categoriaPadreId,
        descripcion: descripcion,
        icono: icono,
        color: color,
        tipoNegocio: tipoNegocio,
      );

      if (category != null) {
        // Volver a cargar la lista para que aparezca
        final updated = await _loadCategories();
        state = AsyncData(updated);
      }

      return category != null;
    } catch (e) {
      return false;
    }
  }

  // Actualizar datos de categoría
  Future<bool> updateCategory({
    required int categoryId,
    String? nombre,
    String? descripcion,
    String? icono,
    String? color,
    int? categoriaPadreId,
    bool? activa,
  }) async {
    try {
      final repo = ref.read(categoryRepositoryProvider);
      final success = await repo.updateCategory(
        categoryId: categoryId,
        nombre: nombre,
        descripcion: descripcion,
        icono: icono,
        color: color,
        categoriaPadreId: categoriaPadreId,
        activa: activa,
      );

      if (success) {
        final updated = await _loadCategories();
        state = AsyncData(updated);
      }

      return success;
    } catch (e) {
      return false;
    }
  }

  // Eliminar o desactivar si ya tiene movidas las categorías
  Future<bool> deleteCategory(int categoryId) async {
    try {
      final repo = ref.read(categoryRepositoryProvider);
      final success = await repo.deleteCategory(categoryId);

      if (success) {
        final updated = await _loadCategories();
        state = AsyncData(updated);
      }

      return success;
    } catch (e) {
      return false;
    }
  }

  // Reordenar categorías
  Future<bool> reorderCategories(List<int> categoryIds) async {
    try {
      final repo = ref.read(categoryRepositoryProvider);
      final success = await repo.reorderCategories(categoryIds);

      if (success) {
        final updated = await _loadCategories();
        state = AsyncData(updated);
      }

      return success;
    } catch (e) {
      return false;
    }
  }

  // Aplicar plantilla de negocio
  Future<bool> applyBusinessTemplate(String tipoNegocio) async {
    try {
      final repo = ref.read(categoryRepositoryProvider);
      final success = await repo.applyBusinessTemplate(tipoNegocio);

      if (success) {
        final updated = await _loadCategories();
        state = AsyncData(updated);
      }

      return success;
    } catch (e) {
      return false;
    }
  }
}

// Provider para categorías por tipo
@riverpod
Future<List<Category>> categoriesByType(Ref ref, String tipo) async {
  final categories = await ref.watch(categoriesStateProvider.future);
  return categories.where((cat) => cat.tipo == tipo).toList();
}

// Provider para categorías de ingreso
@riverpod
Future<List<Category>> incomeCategories(Ref ref) async {
  return ref.watch(categoriesByTypeProvider('ingreso').future);
}

// Provider para categorías de egreso
@riverpod
Future<List<Category>> expenseCategories(Ref ref) async {
  return ref.watch(categoriesByTypeProvider('egreso').future);
}

// Provider para buscar categorías
@riverpod
Future<List<Category>> searchCategories(Ref ref, String query) async {
  if (query.isEmpty) {
    return ref.watch(categoriesStateProvider.future);
  }
  final repo = ref.read(categoryRepositoryProvider);
  return await repo.searchCategories(query);
}

// Provider para estadísticas de uso
@riverpod
Future<Map<int, int>> categoryUsageStats(Ref ref) async {
  final repo = ref.read(categoryRepositoryProvider);
  return await repo.getCategoryUsageStats();
}

// Plantillas disponibles para rellenar rápido
@riverpod
List<BusinessTemplate> businessTemplates(Ref ref) {
  return [
    BusinessTemplate(
      id: 'bodega',
      nombre: 'Bodega / Tienda',
      descripcion: 'Categorías para negocios de venta al por menor',
      icono: 'store',
      color: '#4CAF50',
    ),
    BusinessTemplate(
      id: 'restaurante',
      nombre: 'Restaurante',
      descripcion: 'Categorías para negocios de comida',
      icono: 'restaurant',
      color: '#FF9800',
    ),
    BusinessTemplate(
      id: 'servicios',
      nombre: 'Servicios Profesionales',
      descripcion: 'Categorías para freelancers y consultores',
      icono: 'work',
      color: '#2196F3',
    ),
    BusinessTemplate(
      id: 'transporte',
      nombre: 'Transporte',
      descripcion: 'Categorías para taxis, delivery, etc.',
      icono: 'local_shipping',
      color: '#9C27B0',
    ),
    BusinessTemplate(
      id: 'taller',
      nombre: 'Taller / Mecánica',
      descripcion: 'Categorías para talleres y servicios técnicos',
      icono: 'construction',
      color: '#FF5722',
    ),
    BusinessTemplate(
      id: 'salon',
      nombre: 'Salón de Belleza',
      descripcion: 'Categorías para peluquerías y spa',
      icono: 'face',
      color: '#E91E63',
    ),
  ];
}

// Modelo para plantillas de negocio
class BusinessTemplate {
  final String id;
  final String nombre;
  final String descripcion;
  final String icono;
  final String color;

  BusinessTemplate({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.icono,
    required this.color,
  });
}

@riverpod
Future<List<Category>> pagedCategories(Ref ref, {int limit = 50, int offset = 0}) async {
  final repo = ref.read(categoryRepositoryProvider);
  return await repo.getUserCategoriesPaged(limit: limit, offset: offset);
}

@riverpod
Future<int> totalPrincipalCategories(Ref ref) async {
  final repo = ref.read(categoryRepositoryProvider);
  return await repo.countUserPrincipalCategories();
}

@riverpod
Future<List<Category>> subcategories(Ref ref, int parentId) async {
  final repo = ref.read(categoryRepositoryProvider);
  return await repo.getSubcategories(parentId);
}
