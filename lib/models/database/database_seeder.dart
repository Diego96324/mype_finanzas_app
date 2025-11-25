import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseSeeder {
  // Seed de logros por defecto si la tabla está vacía
  static Future<void> seedAchievements(Database db) async {
    try {
      // Verificar si la tabla existe
      final tables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='gamification_achievements'"
      );
      if (tables.isEmpty) {
        debugPrint('⚠️ Tabla gamification_achievements no existe, omitiendo seed');
        return;
      }

      // Verificar si ya hay logros
      final count = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM gamification_achievements')
      ) ?? 0;

      if (count > 0) {
        debugPrint('✅ Achievements ya poblados ($count registros)');
        return;
      }

      // Insertar logros por defecto
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

      debugPrint('🎮 ${achievements.length} logros seed insertados correctamente');
    } catch (e) {
      debugPrint('⚠️ Error en seedAchievements: $e');
    }
  }

  static Future<void> seedCategoryTemplates(Database db) async {
    try {
      final tables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='plantillas_categorias'"
      );
      if (tables.isEmpty) {
        debugPrint('⚠️ Tabla plantillas_categorias no existe, omitiendo seed');
        return;
      }

      final count = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM plantillas_categorias')
      ) ?? 0;

      if (count > 0) {
        debugPrint('✅ Plantillas de categorías ya pobladas ($count registros)');
        return;
      }

      Map<String, dynamic> template({
        required String tipoNegocio,
        required String nombre,
        required String tipo,
        String? descripcion,
        String icono = 'category',
        String color = '#4CAF50',
        bool esPrincipal = true,
        String? categoriaPadreNombre,
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
        // Bodega / Tienda
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
        template(
          tipoNegocio: 'bodega',
          nombre: 'Compras proveedores locales',
          tipo: 'egreso',
          categoriaPadreNombre: 'Compras de inventario',
          esPrincipal: false,
          descripcion: 'Compras en mercados mayoristas cercanos',
          icono: 'local_mall',
          color: '#FF7043',
        ),
        template(
          tipoNegocio: 'bodega',
          nombre: 'Compras mayoristas',
          tipo: 'egreso',
          categoriaPadreNombre: 'Compras de inventario',
          esPrincipal: false,
          descripcion: 'Reposición en distribuidores grandes',
          icono: 'inventory',
          color: '#FF8A65',
        ),
        template(
          tipoNegocio: 'bodega',
          nombre: 'Servicios básicos',
          tipo: 'egreso',
          categoriaPadreNombre: 'Gastos operativos',
          esPrincipal: false,
          descripcion: 'Agua, luz e internet del local',
          icono: 'lightbulb',
          color: '#9E9E9E',
        ),
        template(
          tipoNegocio: 'bodega',
          nombre: 'Sueldos y comisiones',
          tipo: 'egreso',
          categoriaPadreNombre: 'Gastos operativos',
          esPrincipal: false,
          descripcion: 'Pago al personal de atención',
          icono: 'groups',
          color: '#BDBDBD',
        ),
        template(
          tipoNegocio: 'bodega',
          nombre: 'Alquiler del local',
          tipo: 'egreso',
          categoriaPadreNombre: 'Gastos operativos',
          esPrincipal: false,
          descripcion: 'Pago mensual del espacio',
          icono: 'home_work',
          color: '#A1887F',
        ),

        // Restaurante
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
        template(
          tipoNegocio: 'restaurante',
          nombre: 'Ventas en salón',
          tipo: 'ingreso',
          categoriaPadreNombre: 'Ventas restaurante',
          esPrincipal: false,
          descripcion: 'Consumo dentro del local',
          icono: 'local_dining',
          color: '#FF9800',
        ),
        template(
          tipoNegocio: 'restaurante',
          nombre: 'Insumos frescos',
          tipo: 'egreso',
          categoriaPadreNombre: 'Costos de cocina',
          esPrincipal: false,
          descripcion: 'Carnes, verduras y frutas',
          icono: 'grass',
          color: '#AED581',
        ),
        template(
          tipoNegocio: 'restaurante',
          nombre: 'Descartables y empaques',
          tipo: 'egreso',
          categoriaPadreNombre: 'Costos de cocina',
          esPrincipal: false,
          descripcion: 'Envases para delivery y take-out',
          icono: 'takeout_dining',
          color: '#FFD54F',
        ),
        template(
          tipoNegocio: 'restaurante',
          nombre: 'Personal y propinas',
          tipo: 'egreso',
          categoriaPadreNombre: 'Gastos del local',
          esPrincipal: false,
          descripcion: 'Sueldos de cocina y atención',
          icono: 'badge',
          color: '#F06292',
        ),
        template(
          tipoNegocio: 'restaurante',
          nombre: 'Servicios y alquiler',
          tipo: 'egreso',
          categoriaPadreNombre: 'Gastos del local',
          esPrincipal: false,
          descripcion: 'Agua, luz, gas y renta del local',
          icono: 'home_work',
          color: '#8D6E63',
        ),

        // Servicios profesionales
        template(
          tipoNegocio: 'servicios',
          nombre: 'Servicios facturados',
          tipo: 'ingreso',
          descripcion: 'Ingresos por consultorías o asesorías',
          icono: 'work',
          color: '#2196F3',
        ),
        template(
          tipoNegocio: 'servicios',
          nombre: 'Gastos operativos',
          tipo: 'egreso',
          descripcion: 'Herramientas, coworking y software',
          icono: 'devices',
          color: '#546E7A',
        ),
        template(
          tipoNegocio: 'servicios',
          nombre: 'Marketing y ventas',
          tipo: 'egreso',
          descripcion: 'Publicidad y comisiones comerciales',
          icono: 'campaign',
          color: '#AB47BC',
        ),
        template(
          tipoNegocio: 'servicios',
          nombre: 'Servicios mensuales',
          tipo: 'egreso',
          categoriaPadreNombre: 'Gastos operativos',
          esPrincipal: false,
          descripcion: 'Internet, coworking y transporte',
          icono: 'router',
          color: '#78909C',
        ),
        template(
          tipoNegocio: 'servicios',
          nombre: 'Herramientas digitales',
          tipo: 'egreso',
          categoriaPadreNombre: 'Gastos operativos',
          esPrincipal: false,
          descripcion: 'Software, licencias y apps',
          icono: 'app_shortcut',
          color: '#42A5F5',
        ),
        template(
          tipoNegocio: 'servicios',
          nombre: 'Publicidad online',
          tipo: 'egreso',
          categoriaPadreNombre: 'Marketing y ventas',
          esPrincipal: false,
          descripcion: 'Campañas en redes y Google',
          icono: 'ads_click',
          color: '#BA68C8',
        ),
        template(
          tipoNegocio: 'servicios',
          nombre: 'Comisiones comerciales',
          tipo: 'egreso',
          categoriaPadreNombre: 'Marketing y ventas',
          esPrincipal: false,
          descripcion: 'Pagos a aliados o referidos',
          icono: 'handshake',
          color: '#CE93D8',
        ),

        // Transporte
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
        template(
          tipoNegocio: 'transporte',
          nombre: 'Carreras por app',
          tipo: 'ingreso',
          categoriaPadreNombre: 'Servicios de transporte',
          esPrincipal: false,
          descripcion: 'Ingresos de Uber, InDriver, etc.',
          icono: 'smartphone',
          color: '#BA68C8',
        ),
        template(
          tipoNegocio: 'transporte',
          nombre: 'Servicios corporativos',
          tipo: 'ingreso',
          categoriaPadreNombre: 'Servicios de transporte',
          esPrincipal: false,
          descripcion: 'Contratos fijos con empresas',
          icono: 'business_center',
          color: '#AB47BC',
        ),
        template(
          tipoNegocio: 'transporte',
          nombre: 'Lubricantes y lavados',
          tipo: 'egreso',
          categoriaPadreNombre: 'Mantenimiento',
          esPrincipal: false,
          descripcion: 'Cambios de aceite, lavado y detailing',
          icono: 'water_drop',
          color: '#8D6E63',
        ),
        template(
          tipoNegocio: 'transporte',
          nombre: 'Repuestos y reparaciones',
          tipo: 'egreso',
          categoriaPadreNombre: 'Mantenimiento',
          esPrincipal: false,
          descripcion: 'Llantas, frenos y partes mecánicas',
          icono: 'build_circle',
          color: '#795548',
        ),

        // Taller / Mecánica
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
        template(
          tipoNegocio: 'taller',
          nombre: 'Servicios eléctricos',
          tipo: 'ingreso',
          categoriaPadreNombre: 'Servicios de reparación',
          esPrincipal: false,
          descripcion: 'Instalaciones y arreglos eléctricos',
          icono: 'bolt',
          color: '#FFB74D',
        ),
        template(
          tipoNegocio: 'taller',
          nombre: 'Mecánica general',
          tipo: 'ingreso',
          categoriaPadreNombre: 'Servicios de reparación',
          esPrincipal: false,
          descripcion: 'Mantenimiento y reparaciones generales',
          icono: 'handyman',
          color: '#FF7043',
        ),
        template(
          tipoNegocio: 'taller',
          nombre: 'Herramientas y equipos',
          tipo: 'egreso',
          categoriaPadreNombre: 'Gastos del taller',
          esPrincipal: false,
          descripcion: 'Compra y mantenimiento de herramientas',
          icono: 'precision_manufacturing',
          color: '#8D6E63',
        ),
        template(
          tipoNegocio: 'taller',
          nombre: 'Servicios básicos y alquiler',
          tipo: 'egreso',
          categoriaPadreNombre: 'Gastos del taller',
          esPrincipal: false,
          descripcion: 'Agua, luz y renta del local',
          icono: 'home_work',
          color: '#BCAAA4',
        ),

        // Salón de Belleza
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
        template(
          tipoNegocio: 'salon',
          nombre: 'Servicios premium',
          tipo: 'ingreso',
          categoriaPadreNombre: 'Servicios de belleza',
          esPrincipal: false,
          descripcion: 'Keratinas, alisados o spa',
          icono: 'spa',
          color: '#F48FB1',
        ),
        template(
          tipoNegocio: 'salon',
          nombre: 'Manicure y pedicure',
          tipo: 'ingreso',
          categoriaPadreNombre: 'Servicios de belleza',
          esPrincipal: false,
          descripcion: 'Servicios para manos y pies',
          icono: 'content_cut',
          color: '#F06292',
        ),
        template(
          tipoNegocio: 'salon',
          nombre: 'Productos retail',
          tipo: 'egreso',
          categoriaPadreNombre: 'Compra de productos',
          esPrincipal: false,
          descripcion: 'Stock para venta a clientes',
          icono: 'shopping_cart',
          color: '#F8BBD0',
        ),
        template(
          tipoNegocio: 'salon',
          nombre: 'Desechables y bioseguridad',
          tipo: 'egreso',
          categoriaPadreNombre: 'Compra de productos',
          esPrincipal: false,
          descripcion: 'Guantes, mascarillas y toallas',
          icono: 'medical_services',
          color: '#F48FB1',
        ),
        template(
          tipoNegocio: 'salon',
          nombre: 'Publicidad digital',
          tipo: 'egreso',
          categoriaPadreNombre: 'Marketing y fidelización',
          esPrincipal: false,
          descripcion: 'Instagram, Facebook y TikTok',
          icono: 'ads_click',
          color: '#F06292',
        ),
        template(
          tipoNegocio: 'salon',
          nombre: 'Promociones y membresías',
          tipo: 'egreso',
          categoriaPadreNombre: 'Marketing y fidelización',
          esPrincipal: false,
          descripcion: 'Tarjetas de puntos y descuentos',
          icono: 'card_giftcard',
          color: '#EC407A',
        ),
      ];

      final batch = db.batch();
      for (final row in templates) {
        batch.insert('plantillas_categorias', row);
      }
      await batch.commit(noResult: true);

      debugPrint('🏗️ ${templates.length} registros de plantillas de categorías seed insertados');
    } catch (e) {
      debugPrint('⚠️ Error en seedCategoryTemplates: $e');
    }
  }

}