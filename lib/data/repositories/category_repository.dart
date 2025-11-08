import 'package:flutter/foundation.dart';
import '../../core/database/app_database.dart';
import '../../domain/services/auth_service.dart';
import '../models/category_model.dart' as models;

class CategoryRepository {
  final AppDatabase _db = AppDatabase();
  final AuthService _auth = AuthService();

  // Obtener todas las categorías del usuario (con jerarquía)
  Future<List<models.Category>> getUserCategories({bool incluirInactivas = false}) async {
    try {
      final userId = _auth.currentUserId;
      final database = await _db.database;

      // Primero obtener categorías principales (sin padre)
      final whereClause = incluirInactivas
          ? '(usuario_id = ? OR usuario_id IS NULL) AND categoria_padre_id IS NULL'
          : '(usuario_id = ? OR usuario_id IS NULL) AND activa = 1 AND categoria_padre_id IS NULL';

      final principales = await database.query(
        'categorias',
        where: whereClause,
        whereArgs: [userId],
        orderBy: 'tipo, orden, nombre',
      );

      List<models.Category> categorias = [];

      for (var catMap in principales) {
        final categoria = models.Category.fromMap(catMap);

        // Buscar subcategorías
        final subcatsWhere = incluirInactivas
            ? 'categoria_padre_id = ?'
            : 'categoria_padre_id = ? AND activa = 1';

        final subcats = await database.query(
          'categorias',
          where: subcatsWhere,
          whereArgs: [categoria.id],
          orderBy: 'orden, nombre',
        );

        final subcategorias = subcats.map((s) => models.Category.fromMap(s)).toList();

        categorias.add(categoria.copyWith(subcategorias: subcategorias));
      }

      return categorias;
    } catch (e) {
      debugPrint('❌ Error al obtener categorías: $e');
      return [];
    }
  }

  // Obtener categorías por tipo (ingreso/egreso)
  Future<List<models.Category>> getCategoriesByType(String tipo, {bool incluirSubcategorias = true}) async {
    try {
      final userId = _auth.currentUserId;
      final database = await _db.database;

      final categories = await database.query(
        'categorias',
        where: '(usuario_id = ? OR usuario_id IS NULL) AND tipo = ? AND activa = 1',
        whereArgs: [userId, tipo],
        orderBy: 'orden, nombre',
      );

      List<models.Category> result = [];

      for (var catMap in categories) {
        final categoria = models.Category.fromMap(catMap);

        if (incluirSubcategorias && categoria.esPrincipal) {
          final subcats = await database.query(
            'categorias',
            where: 'categoria_padre_id = ? AND activa = 1',
            whereArgs: [categoria.id],
            orderBy: 'orden, nombre',
          );

          final subcategorias = subcats.map((s) => models.Category.fromMap(s)).toList();
          result.add(categoria.copyWith(subcategorias: subcategorias));
        } else {
          result.add(categoria);
        }
      }

      return result;
    } catch (e) {
      debugPrint('❌ Error al obtener categorías por tipo: $e');
      return [];
    }
  }

  // Crear nueva categoría
  Future<models.Category?> createCategory({
    required String nombre,
    required String tipo,
    int? categoriaPadreId,
    String? descripcion,
    required String icono,
    required String color,
    String? tipoNegocio,
  }) async {
    try {
      final userId = _auth.currentUserId;
      if (userId == null) {
        debugPrint('❌ No hay usuario autenticado');
        return null;
      }

      final database = await _db.database;
      final now = DateTime.now();

      // Validación de duplicados dentro del mismo padre y tipo (case-insensitive)
      String duplicateWhere;
      List<dynamic> duplicateArgs;
      if (categoriaPadreId == null) {
        duplicateWhere = 'usuario_id = ? AND tipo = ? AND categoria_padre_id IS NULL AND LOWER(nombre) = LOWER(?) AND activa = 1';
        duplicateArgs = [userId, tipo, nombre];
      } else {
        duplicateWhere = 'usuario_id = ? AND tipo = ? AND categoria_padre_id = ? AND LOWER(nombre) = LOWER(?) AND activa = 1';
        duplicateArgs = [userId, tipo, categoriaPadreId, nombre];
      }
      final existingDup = await database.query(
        'categorias',
        where: duplicateWhere,
        whereArgs: duplicateArgs,
        limit: 1,
      );
      if (existingDup.isNotEmpty) {
        debugPrint('❌ Ya existe una categoría con ese nombre en el mismo nivel');
        return null;
      }

      // Obtener el siguiente orden entre hermanos
      String ordenWhere;
      List<dynamic> ordenArgs;
      if (categoriaPadreId == null) {
        ordenWhere = 'usuario_id = ? AND categoria_padre_id IS NULL';
        ordenArgs = [userId];
      } else {
        ordenWhere = 'usuario_id = ? AND categoria_padre_id = ?';
        ordenArgs = [userId, categoriaPadreId];
      }
      final maxOrden = await database.rawQuery(
        'SELECT MAX(orden) as max_orden FROM categorias WHERE $ordenWhere',
        ordenArgs,
      );
      final orden = ((maxOrden.first['max_orden'] as int?) ?? -1) + 1;

      final categoryId = await database.insert('categorias', {
        'usuario_id': userId,
        'categoria_padre_id': categoriaPadreId,
        'nombre': nombre,
        'tipo': tipo,
        'descripcion': descripcion,
        'icono': icono,
        'color': color,
        'activa': 1,
        'es_predeterminada': 0,
        'orden': orden,
        'tipo_negocio': tipoNegocio,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      return models.Category(
        id: categoryId,
        usuarioId: userId,
        categoriaPadreId: categoriaPadreId,
        nombre: nombre,
        tipo: tipo,
        descripcion: descripcion,
        icono: icono,
        color: color,
        orden: orden,
        tipoNegocio: tipoNegocio,
        createdAt: now,
        updatedAt: now,
      );
    } catch (e) {
      debugPrint('❌ Error al crear categoría: $e');
      return null;
    }
  }

  // Actualizar categoría
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
      final userId = _auth.currentUserId;
      if (userId == null) return false;

      final database = await _db.database;

      // Verificar que la categoría pertenece al usuario
      final existing = await database.query(
        'categorias',
        where: 'id = ? AND usuario_id = ?',
        whereArgs: [categoryId, userId],
      );

      if (existing.isEmpty) {
        debugPrint('❌ Categoría no encontrada o no pertenece al usuario');
        return false;
      }

      final updateData = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (nombre != null) updateData['nombre'] = nombre;
      if (descripcion != null) updateData['descripcion'] = descripcion;
      if (icono != null) updateData['icono'] = icono;
      if (color != null) updateData['color'] = color;
      if (categoriaPadreId != null) updateData['categoria_padre_id'] = categoriaPadreId;
      if (activa != null) updateData['activa'] = activa ? 1 : 0;

      final rowsAffected = await database.update(
        'categorias',
        updateData,
        where: 'id = ?',
        whereArgs: [categoryId],
      );

      return rowsAffected > 0;
    } catch (e) {
      debugPrint('❌ Error al actualizar categoría: $e');
      return false;
    }
  }

  // Eliminar categoría
  Future<bool> deleteCategory(int categoryId) async {
    try {
      final userId = _auth.currentUserId;
      if (userId == null) return false;

      final database = await _db.database;

      // Verificar que la categoría pertenece al usuario y no es predeterminada
      final existing = await database.query(
        'categorias',
        where: 'id = ? AND usuario_id = ? AND es_predeterminada = 0',
        whereArgs: [categoryId, userId],
      );

      if (existing.isEmpty) {
        debugPrint('❌ No se puede eliminar esta categoría');
        return false;
      }

      // Verificar si tiene subcategorías
      final subcategorias = await database.query(
        'categorias',
        where: 'categoria_padre_id = ?',
        whereArgs: [categoryId],
        limit: 1,
      );

      if (subcategorias.isNotEmpty) {
        debugPrint('❌ No se puede eliminar una categoría con subcategorías');
        return false;
      }

      // Verificar si tiene transacciones asociadas
      final transacciones = await database.query(
        'transacciones',
        where: 'categoria_id = ?',
        whereArgs: [categoryId],
        limit: 1,
      );

      if (transacciones.isNotEmpty) {
        // Si tiene transacciones, solo desactivar
        final rowsAffected = await database.update(
          'categorias',
          {
            'activa': 0,
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [categoryId],
        );
        return rowsAffected > 0;
      } else {
        // Si no tiene transacciones, eliminar permanentemente
        final rowsAffected = await database.delete(
          'categorias',
          where: 'id = ?',
          whereArgs: [categoryId],
        );
        return rowsAffected > 0;
      }
    } catch (e) {
      debugPrint('❌ Error al eliminar categoría: $e');
      return false;
    }
  }

  // Reordenar categorías
  Future<bool> reorderCategories(List<int> categoryIds) async {
    try {
      final userId = _auth.currentUserId;
      if (userId == null) return false;

      final database = await _db.database;

      return await database.transaction((txn) async {
        for (int i = 0; i < categoryIds.length; i++) {
          await txn.update(
            'categorias',
            {'orden': i},
            where: 'id = ? AND usuario_id = ?',
            whereArgs: [categoryIds[i], userId],
          );
        }
        return true;
      });
    } catch (e) {
      debugPrint('❌ Error al reordenar categorías: $e');
      return false;
    }
  }

  // Obtener plantillas de categorías por tipo de negocio
  Future<List<Map<String, dynamic>>> getCategoryTemplates(String tipoNegocio) async {
    try {
      final database = await _db.database;

      final templates = await database.query(
        'plantillas_categorias',
        where: 'tipo_negocio = ?',
        whereArgs: [tipoNegocio],
        orderBy: 'es_principal DESC, tipo, nombre',
      );

      return templates;
    } catch (e) {
      debugPrint('❌ Error al obtener plantillas: $e');
      return [];
    }
  }

  // Aplicar plantilla de categorías
  Future<bool> applyBusinessTemplate(String tipoNegocio) async {
    try {
      final userId = _auth.currentUserId;
      if (userId == null) return false;

      final database = await _db.database;
      final templates = await getCategoryTemplates(tipoNegocio);

      if (templates.isEmpty) {
        debugPrint('❌ No hay plantillas para el tipo de negocio: $tipoNegocio');
        return false;
      }

      return await database.transaction((txn) async {
        // PASO 1: Eliminar todas las categorías del usuario (no las del sistema)
        // Primero eliminamos subcategorías
        await txn.delete(
          'categorias',
          where: 'usuario_id = ? AND categoria_padre_id IS NOT NULL',
          whereArgs: [userId],
        );

        // Luego eliminamos categorías principales del usuario
        await txn.delete(
          'categorias',
          where: 'usuario_id = ? AND categoria_padre_id IS NULL AND es_predeterminada = 0',
          whereArgs: [userId],
        );

        debugPrint('✅ Categorías anteriores del usuario eliminadas');

        // PASO 2: Crear las nuevas categorías desde la plantilla
        final now = DateTime.now().toIso8601String();
        Map<String, int> categoriasPadre = {};

        // Primero crear las categorías principales
        for (var template in templates.where((t) => t['es_principal'] == 1)) {
          final categoryId = await txn.insert('categorias', {
            'usuario_id': userId,
            'categoria_padre_id': null,
            'nombre': template['nombre'],
            'tipo': template['tipo'],
            'descripcion': template['descripcion'],
            'icono': template['icono'],
            'color': template['color'],
            'activa': 1,
            'es_predeterminada': 0,
            'orden': 0,
            'tipo_negocio': tipoNegocio,
            'created_at': now,
            'updated_at': now,
          });

          categoriasPadre[template['nombre'] as String] = categoryId;
        }

        // Luego crear las subcategorías
        for (var template in templates.where((t) => t['es_principal'] == 0)) {
          final padreNombre = template['categoria_padre_nombre'] as String?;
          final padreId = padreNombre != null ? categoriasPadre[padreNombre] : null;

          await txn.insert('categorias', {
            'usuario_id': userId,
            'categoria_padre_id': padreId,
            'nombre': template['nombre'],
            'tipo': template['tipo'],
            'descripcion': template['descripcion'],
            'icono': template['icono'],
            'color': template['color'],
            'activa': 1,
            'es_predeterminada': 0,
            'orden': 0,
            'tipo_negocio': tipoNegocio,
            'created_at': now,
            'updated_at': now,
          });
        }

        debugPrint('✅ Plantilla "$tipoNegocio" aplicada exitosamente');
        return true;
      });
    } catch (e) {
      debugPrint('❌ Error al aplicar plantilla: $e');
      return false;
    }
  }

  // Obtener estadísticas de uso por categoría
  Future<Map<int, int>> getCategoryUsageStats() async {
    try {
      final userId = _auth.currentUserId;
      if (userId == null) return {};

      final database = await _db.database;

      final result = await database.rawQuery('''
        SELECT categoria_id, COUNT(*) as count
        FROM transacciones
        WHERE usuario_id = ?
        GROUP BY categoria_id
      ''', [userId]);

      Map<int, int> stats = {};
      for (var row in result) {
        final categoryId = row['categoria_id'] as int?;
        final count = row['count'] as int;
        if (categoryId != null) {
          stats[categoryId] = count;
        }
      }

      return stats;
    } catch (e) {
      debugPrint('❌ Error al obtener estadísticas: $e');
      return {};
    }
  }

  // Buscar categorías
  Future<List<models.Category>> searchCategories(String query) async {
    try {
      final userId = _auth.currentUserId;
      final database = await _db.database;

      final categories = await database.query(
        'categorias',
        where: '(usuario_id = ? OR usuario_id IS NULL) AND nombre LIKE ? AND activa = 1',
        whereArgs: [userId, '%$query%'],
        orderBy: 'nombre',
      );

      return categories.map((c) => models.Category.fromMap(c)).toList();
    } catch (e) {
      debugPrint('❌ Error al buscar categorías: $e');
      return [];
    }
  }

  // Obtener categorías paginadas (solo principales, sin subcategorías)
  Future<List<models.Category>> getUserCategoriesPaged({
    int limit = 50,
    int offset = 0,
    bool incluirInactivas = false,
  }) async {
    try {
      final userId = _auth.currentUserId;
      final database = await _db.database;
      final whereClause = incluirInactivas
          ? '(usuario_id = ? OR usuario_id IS NULL) AND categoria_padre_id IS NULL'
          : '(usuario_id = ? OR usuario_id IS NULL) AND activa = 1 AND categoria_padre_id IS NULL';
      final result = await database.query(
        'categorias',
        where: whereClause,
        whereArgs: [userId],
        orderBy: 'tipo, orden, nombre',
        limit: limit,
        offset: offset,
      );
      return result.map((m) => models.Category.fromMap(m)).toList();
    } catch (e) {
      debugPrint('❌ Error en paginación de categorías: $e');
      return [];
    }
  }

  // Contar categorías principales del usuario (para paginación)
  Future<int> countUserPrincipalCategories({bool incluirInactivas = false}) async {
    try {
      final userId = _auth.currentUserId;
      final database = await _db.database;
      final whereClause = incluirInactivas
          ? '(usuario_id = ? OR usuario_id IS NULL) AND categoria_padre_id IS NULL'
          : '(usuario_id = ? OR usuario_id IS NULL) AND activa = 1 AND categoria_padre_id IS NULL';
      final result = await database.rawQuery('SELECT COUNT(*) as total FROM categorias WHERE $whereClause', [userId]);
      return (result.first['total'] as int?) ?? 0;
    } catch (e) {
      debugPrint('❌ Error contando categorías: $e');
      return 0;
    }
  }

  // Obtener subcategorías de una categoría padre
  Future<List<models.Category>> getSubcategories(int parentId, {bool incluirInactivas = false}) async {
    try {
      final database = await _db.database;
      final whereClause = incluirInactivas ? 'categoria_padre_id = ?' : 'categoria_padre_id = ? AND activa = 1';
      final rows = await database.query(
        'categorias',
        where: whereClause,
        whereArgs: [parentId],
        orderBy: 'orden, nombre',
      );
      return rows.map((m) => models.Category.fromMap(m)).toList();
    } catch (e) {
      debugPrint('❌ Error obteniendo subcategorías: $e');
      return [];
    }
  }
}