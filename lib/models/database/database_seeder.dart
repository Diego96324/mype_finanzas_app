import 'package:sqflite/sqflite.dart';

class DatabaseSeeder {

  static Future<void> seedAchievements(Database db) async {
    try {
      // Paso 1: ¿Existe la tabla?
      final tables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='gamification_achievements'"
      );
      if (tables.isEmpty) return;

      // Paso 2: ¿Ya tiene datos?
      final count = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM gamification_achievements')
      ) ?? 0;
      if (count > 0) return;

      // Paso 3: Insertamos los logros
      final now = DateTime.now().toIso8601String();

      final achievements = [
        {
          'code': 'FIRST_LOGIN',
          'nombre': 'Primer Inicio',
          'descripcion': 'Iniciaste sesión por primera vez en la app',
          'puntos': 10,
          'progreso_objetivo': 1.0,
          'tipo': 'login',
          'icon_name': 'login',
          'created_at': now,
          'updated_at': now,
        },
        {
          'code': 'FIRST_INCOME',
          'nombre': 'Primer Ingreso',
          'descripcion': 'Registraste tu primer ingreso',
          'puntos': 15,
          'progreso_objetivo': 1.0,
          'tipo': 'transaccion',
          'icon_name': 'arrow_downward',
          'created_at': now,
          'updated_at': now,
        },
        {
          'code': 'FIRST_EXPENSE',
          'nombre': 'Primer Gasto',
          'descripcion': 'Registraste tu primer gasto',
          'puntos': 15,
          'progreso_objetivo': 1.0,
          'tipo': 'transaccion',
          'icon_name': 'arrow_upward',
          'created_at': now,
          'updated_at': now,
        },
        {
          'code': 'STREAK_3_DAYS',
          'nombre': 'Racha de 3 Días',
          'descripcion': 'Usaste la app 3 días consecutivos',
          'puntos': 25,
          'progreso_objetivo': 3.0,
          'tipo': 'racha',
          'icon_name': 'local_fire_department',
          'created_at': now,
          'updated_at': now,
        },
        {
          'code': 'SAVER',
          'nombre': 'Ahorrador',
          'descripcion': 'Tus ingresos superaron tus gastos este mes',
          'puntos': 50,
          'progreso_objetivo': 1.0,
          'tipo': 'ahorro',
          'icon_name': 'savings',
          'created_at': now,
          'updated_at': now,
        },
      ];

      final batch = db.batch();
      for (final achievement in achievements) {
        batch.insert('gamification_achievements', achievement);
      }
      await batch.commit(noResult: true);

    } catch (_) {
    }
  }

  static Future<void> seedCategoryTemplates(Database db) async {
    try {
      // Verificar si la tabla existe
      final tables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='plantillas_categorias'"
      );
      if (tables.isEmpty) return;

      // Verificar si ya tiene datos
      final count = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM plantillas_categorias')
      ) ?? 0;
      if (count > 0) return;

      Map<String, dynamic> template({
        required String tipoNegocio,
        required String nombre,
        required String tipo, // 'ingreso' o 'egreso'
        String? descripcion,
        String icono = 'category',
        String color = '#4CAF50',
        bool esPrincipal = true,
        String? categoriaPadreNombre, // Para subcategorías
      }) {
        final now = DateTime.now().toIso8601String();
        return {
          'tipo_negocio': tipoNegocio,
          'nombre': nombre,
          'tipo': tipo,
          'descripcion': descripcion,
          'icono': icono,
          'color': color,
          'es_principal': esPrincipal ? 1 : 0,
          'categoria_padre_nombre': categoriaPadreNombre,
          'created_at': now,
          'updated_at': now,
        };
      }


      final templates = <Map<String, dynamic>>[

        // --- BODEGA: Categorías principales ---
        template(
          tipoNegocio: 'bodega',
          nombre: 'Ventas mostrador',
          tipo: 'ingreso',
          descripcion: 'Ingresos diarios por ventas en tienda',
          icono: 'store',
          color: '#4CAF50',
        ),
        template(
          tipoNegocio: 'bodega',
          nombre: 'Compras de inventario',
          tipo: 'egreso',
          descripcion: 'Reposición de mercadería para la tienda',
          icono: 'shopping_cart',
          color: '#FF7043',
        ),
        template(
          tipoNegocio: 'bodega',
          nombre: 'Gastos operativos',
          tipo: 'egreso',
          descripcion: 'Servicios, alquiler y sueldos del local',
          icono: 'payments',
          color: '#9E9E9E',
        ),

        // --- BODEGA: Subcategorías ---
        template(
          tipoNegocio: 'bodega',
          nombre: 'Ventas al contado',
          tipo: 'ingreso',
          categoriaPadreNombre: 'Ventas mostrador',
          esPrincipal: false,
          descripcion: 'Cobros inmediatos en efectivo o Yape',
          icono: 'point_of_sale',
          color: '#4CAF50',
        ),
        template(
          tipoNegocio: 'bodega',
          nombre: 'Ventas a crédito',
          tipo: 'ingreso',
          categoriaPadreNombre: 'Ventas mostrador',
          esPrincipal: false,
          descripcion: 'Ventas con pago diferido',
          icono: 'receipt_long',
          color: '#66BB6A',
        ),

        // PLANTILLAS PARA RESTAURANTE
        template(
          tipoNegocio: 'restaurante',
          nombre: 'Ventas restaurante',
          tipo: 'ingreso',
          descripcion: 'Ventas de platos y bebidas',
          icono: 'restaurant',
          color: '#FF9800',
        ),
        template(
          tipoNegocio: 'restaurante',
          nombre: 'Costos de cocina',
          tipo: 'egreso',
          descripcion: 'Ingredientes y suministros de cocina',
          icono: 'kitchen',
          color: '#EF6C00',
        ),
        template(
          tipoNegocio: 'restaurante',
          nombre: 'Gastos del local',
          tipo: 'egreso',
          descripcion: 'Servicios, alquiler y personal',
          icono: 'storefront',
          color: '#8D6E63',
        ),
        template(
          tipoNegocio: 'restaurante',
          nombre: 'Delivery y pedidos en apps',
          tipo: 'ingreso',
          categoriaPadreNombre: 'Ventas restaurante',
          esPrincipal: false,
          descripcion: 'Ventas por aplicativos o envíos propios',
          icono: 'delivery_dining',
          color: '#FFB74D',
        ),

        // PLANTILLAS PARA SERVICIOS PROFESIONALES

        template(
          tipoNegocio: 'servicios',
          nombre: 'Honorarios profesionales',
          tipo: 'ingreso',
          descripcion: 'Ingresos por servicios prestados',
          icono: 'work',
          color: '#2196F3',
        ),
        template(
          tipoNegocio: 'servicios',
          nombre: 'Gastos operativos',
          tipo: 'egreso',
          descripcion: 'Internet, oficina, materiales',
          icono: 'settings',
          color: '#9E9E9E',
        ),
        template(
          tipoNegocio: 'servicios',
          nombre: 'Marketing y ventas',
          tipo: 'egreso',
          descripcion: 'Publicidad y promoción',
          icono: 'campaign',
          color: '#9C27B0',
        ),

        // PLANTILLAS PARA TRANSPORTE

        template(
          tipoNegocio: 'transporte',
          nombre: 'Servicios de transporte',
          tipo: 'ingreso',
          descripcion: 'Carreras, envíos o traslados',
          icono: 'local_shipping',
          color: '#9C27B0',
        ),
        template(
          tipoNegocio: 'transporte',
          nombre: 'Combustible',
          tipo: 'egreso',
          descripcion: 'Gasolina, diésel o GLP',
          icono: 'local_gas_station',
          color: '#FF7043',
        ),
        template(
          tipoNegocio: 'transporte',
          nombre: 'Mantenimiento',
          tipo: 'egreso',
          descripcion: 'Reparaciones y repuestos del vehículo',
          icono: 'build',
          color: '#8D6E63',
        ),

        // PLANTILLAS PARA TALLER / MECÁNICA

        template(
          tipoNegocio: 'taller',
          nombre: 'Servicios de reparación',
          tipo: 'ingreso',
          descripcion: 'Ingresos por mano de obra y diagnósticos',
          icono: 'construction',
          color: '#FF5722',
        ),
        template(
          tipoNegocio: 'taller',
          nombre: 'Compra de repuestos',
          tipo: 'egreso',
          descripcion: 'Componentes y repuestos para trabajos',
          icono: 'car_repair',
          color: '#A1887F',
        ),
        template(
          tipoNegocio: 'taller',
          nombre: 'Gastos del taller',
          tipo: 'egreso',
          descripcion: 'Servicios, alquiler y marketing',
          icono: 'home_repair_service',
          color: '#795548',
        ),

        // PLANTILLAS PARA SALÓN DE BELLEZA

        template(
          tipoNegocio: 'salon',
          nombre: 'Servicios de belleza',
          tipo: 'ingreso',
          descripcion: 'Cortes, tintes y tratamientos',
          icono: 'face',
          color: '#E91E63',
        ),
        template(
          tipoNegocio: 'salon',
          nombre: 'Compra de productos',
          tipo: 'egreso',
          descripcion: 'Tinturas, cremas y utensilios',
          icono: 'shopping_bag',
          color: '#F48FB1',
        ),
        template(
          tipoNegocio: 'salon',
          nombre: 'Marketing y fidelización',
          tipo: 'egreso',
          descripcion: 'Publicidad, promociones y tarjetas',
          icono: 'loyalty',
          color: '#F06292',
        ),
      ];

      // Insertar todas las plantillas en batch
      final batch = db.batch();
      for (final row in templates) {
        batch.insert('plantillas_categorias', row);
      }
      await batch.commit(noResult: true);

    } catch (_) {
    }
  }
}