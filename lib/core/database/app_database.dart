import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  static final AppDatabase _instance = AppDatabase._internal();
  factory AppDatabase() => _instance;
  AppDatabase._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  // NO TOCAR
  Future<void> resetDatabase() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'mype_finanzas.db');
    await deleteDatabase(path);
    _db = null;
    _db = await database;
  }

  Future<Database> _initDb() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'mype_finanzas.db');
    return openDatabase(
      path,
      version: 15, // bump para añadir tablas de gamification (v15)
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE usuarios(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        email TEXT NOT NULL UNIQUE,
        password_hash TEXT NOT NULL,
        nombre TEXT NOT NULL,
        apellido TEXT,
        telefono TEXT,
        fecha_registro TEXT NOT NULL,
        ultima_conexion TEXT,
        activo INTEGER NOT NULL DEFAULT 1,
        rol TEXT NOT NULL DEFAULT 'usuario',
        avatar_uri TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE sesiones(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        usuario_id INTEGER NOT NULL,
        token TEXT NOT NULL UNIQUE,
        dispositivo TEXT,
        ip_address TEXT,
        fecha_inicio TEXT NOT NULL,
        fecha_expiracion TEXT NOT NULL,
        activa INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        FOREIGN KEY(usuario_id) REFERENCES usuarios(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE password_reset_tokens(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        usuario_id INTEGER NOT NULL,
        email TEXT NOT NULL,
        token TEXT NOT NULL UNIQUE,
        fecha_creacion TEXT NOT NULL,
        fecha_expiracion TEXT NOT NULL,
        usado INTEGER NOT NULL DEFAULT 0,
        ip_address TEXT,
        FOREIGN KEY(usuario_id) REFERENCES usuarios(id) ON DELETE CASCADE
      )
    ''');

    // Tabla categorias ya con soporte de jerarquía y plantillas (versión 9 consolidada)
    await db.execute('''
      CREATE TABLE categorias(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        usuario_id INTEGER,
        nombre TEXT NOT NULL,
        tipo TEXT NOT NULL,
        descripcion TEXT,
        icono TEXT,
        color TEXT,
        activa INTEGER NOT NULL DEFAULT 1,
        es_predeterminada INTEGER NOT NULL DEFAULT 0,
        categoria_padre_id INTEGER REFERENCES categorias(id) ON DELETE CASCADE,
        orden INTEGER DEFAULT 0,
        tipo_negocio TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY(usuario_id) REFERENCES usuarios(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE transacciones(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        usuario_id INTEGER NOT NULL,
        cuenta_id INTEGER,
        cuenta_destino_id INTEGER,
        categoria_id INTEGER,
        tipo TEXT NOT NULL,
        monto REAL NOT NULL,
        fecha TEXT NOT NULL,
        etiqueta TEXT,
        nota TEXT,
        descripcion TEXT,
        comprobante_uri TEXT,
        ubicacion TEXT,
        recurrente INTEGER NOT NULL DEFAULT 0,
        es_recurrente INTEGER NOT NULL DEFAULT 0,
        es_apertura_cuenta INTEGER NOT NULL DEFAULT 0,
        confirmada INTEGER NOT NULL DEFAULT 1,
        afecta_saldo INTEGER NOT NULL DEFAULT 1,
        frecuencia_recurrencia TEXT,
        recurrence_interval_days INTEGER,          -- intervalo para personalizada (en días)
        recurrence_end_date TEXT,                  -- fecha fin de recurrencia
        next_occurrence TEXT,                      -- próxima generación programada
        sincronizado INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY(usuario_id) REFERENCES usuarios(id) ON DELETE CASCADE,
        FOREIGN KEY(cuenta_id) REFERENCES cuentas(id) ON DELETE CASCADE,
        FOREIGN KEY(cuenta_destino_id) REFERENCES cuentas(id) ON DELETE SET NULL,
        FOREIGN KEY(categoria_id) REFERENCES categorias(id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE presupuestos(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        usuario_id INTEGER NOT NULL,
        categoria_id INTEGER,
        nombre TEXT NOT NULL,
        monto_limite REAL NOT NULL,
        periodo TEXT NOT NULL,
        fecha_inicio TEXT NOT NULL,
        fecha_fin TEXT NOT NULL,
        activo INTEGER NOT NULL DEFAULT 1,
        alerta_thresholds TEXT NOT NULL DEFAULT '75,90,100',
        alerta_emitida_hasta INTEGER NOT NULL DEFAULT 0,
        auto_ajuste INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY(usuario_id) REFERENCES usuarios(id) ON DELETE CASCADE,
        FOREIGN KEY(categoria_id) REFERENCES categorias(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE metas_financieras(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        usuario_id INTEGER NOT NULL,
        nombre TEXT NOT NULL,
        descripcion TEXT,
        monto_objetivo REAL NOT NULL,
        monto_actual REAL NOT NULL DEFAULT 0,
        fecha_inicio TEXT NOT NULL,
        fecha_objetivo TEXT NOT NULL,
        completada INTEGER NOT NULL DEFAULT 0,
        activa INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY(usuario_id) REFERENCES usuarios(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE recordatorios(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        usuario_id INTEGER NOT NULL,
        titulo TEXT NOT NULL,
        descripcion TEXT,
        fecha_recordatorio TEXT NOT NULL,
        tipo TEXT NOT NULL,
        completado INTEGER NOT NULL DEFAULT 0,
        activo INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY(usuario_id) REFERENCES usuarios(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE accounts(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        usuario_id INTEGER NOT NULL,
        nombre TEXT NOT NULL,
        tipo TEXT NOT NULL,
        moneda TEXT NOT NULL DEFAULT 'PEN',
        saldo REAL NOT NULL DEFAULT 0,
        institucion TEXT,
        nota TEXT,
        fecha_creacion TEXT NOT NULL,
        fecha_actualizacion TEXT,
        activa INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY(usuario_id) REFERENCES usuarios(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE cuentas(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        usuario_id INTEGER NOT NULL,
        nombre TEXT NOT NULL,
        tipo TEXT NOT NULL,
        saldo REAL NOT NULL DEFAULT 0,
        saldo_inicial REAL NOT NULL DEFAULT 0,
        numero_fin TEXT,
        institucion TEXT,
        moneda TEXT NOT NULL DEFAULT 'PEN',
        color TEXT NOT NULL,
        icono TEXT NOT NULL,
        activa INTEGER NOT NULL DEFAULT 1,
        incluir_en_total INTEGER NOT NULL DEFAULT 1,
        orden INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY(usuario_id) REFERENCES usuarios(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE budgets(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        usuario_id INTEGER NOT NULL,
        monto REAL NOT NULL,
        mes INTEGER NOT NULL,
        anio INTEGER NOT NULL,
        fecha_creacion TEXT NOT NULL,
        FOREIGN KEY(usuario_id) REFERENCES usuarios(id) ON DELETE CASCADE,
        UNIQUE(usuario_id, mes, anio)
      )
    ''');

    await db.execute('''
      CREATE TABLE budget_periods(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        usuario_id INTEGER NOT NULL,
        monto REAL NOT NULL,
        periodo TEXT NOT NULL,
        mes INTEGER NOT NULL,
        anio INTEGER NOT NULL,
        FOREIGN KEY(usuario_id) REFERENCES usuarios(id) ON DELETE CASCADE,
        UNIQUE(usuario_id, periodo, mes, anio)
      )
    ''');

    // Tabla de plantillas de categorías por tipo de negocio (versión 9)
    await db.execute('''
      CREATE TABLE plantillas_categorias(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tipo_negocio TEXT NOT NULL,
        nombre TEXT NOT NULL,
        tipo TEXT NOT NULL,
        descripcion TEXT,
        icono TEXT,
        color TEXT,
        es_principal INTEGER NOT NULL DEFAULT 1,
        categoria_padre_nombre TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // --- Tablas de gamification (v14) ---
    await db.execute('''
      CREATE TABLE IF NOT EXISTS gamification_profiles(
        usuario_id INTEGER PRIMARY KEY,
        puntos INTEGER NOT NULL DEFAULT 0,
        nivel INTEGER NOT NULL DEFAULT 1,
        racha_actual INTEGER NOT NULL DEFAULT 0,
        racha_maxima INTEGER NOT NULL DEFAULT 0,
        ultima_fecha_evento TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY(usuario_id) REFERENCES usuarios(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS gamification_achievements(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tipo TEXT NOT NULL,
        nombre TEXT NOT NULL,
        descripcion TEXT,
        progreso_actual REAL NOT NULL DEFAULT 0,
        progreso_objetivo REAL NOT NULL DEFAULT 1,
        estado TEXT NOT NULL DEFAULT 'locked', -- locked|unlocked|in_progress
        ultima_actualizacion TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS gamification_events(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        usuario_id INTEGER,
        tipo_evento TEXT NOT NULL,
        descripcion TEXT,
        puntos_otorgados INTEGER NOT NULL DEFAULT 0,
        fecha_evento TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY(usuario_id) REFERENCES usuarios(id) ON DELETE CASCADE
      )
    ''');
    // 👇 AGREGA ESTO:
    await db.execute('''
      CREATE TABLE user_achievements(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        usuario_id INTEGER NOT NULL,
        achievement_id INTEGER NOT NULL,
        progreso_actual REAL NOT NULL DEFAULT 0,
        estado TEXT NOT NULL DEFAULT 'locked',
        ultima_actualizacion TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY(usuario_id) REFERENCES usuarios(id) ON DELETE CASCADE,
        FOREIGN KEY(achievement_id) REFERENCES gamification_achievements(id) ON DELETE CASCADE,
        UNIQUE(usuario_id, achievement_id)
      )
    ''');

    await db.execute('CREATE INDEX IF NOT EXISTS idx_gamification_profiles_usuario ON gamification_profiles(usuario_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_gamification_achievements_tipo ON gamification_achievements(tipo)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_gamification_events_usuario ON gamification_events(usuario_id)');
    await db.execute('CREATE INDEX idx_user_achievements_user ON user_achievements(usuario_id)');

    // --- fin gamification ---

    await db.execute('CREATE INDEX idx_usuarios_email ON usuarios(email)');
    await db.execute('CREATE INDEX idx_sesiones_usuario ON sesiones(usuario_id)');
    await db.execute('CREATE INDEX idx_sesiones_token ON sesiones(token)');
    await db.execute('CREATE INDEX idx_password_reset_tokens_usuario ON password_reset_tokens(usuario_id)');
    await db.execute('CREATE INDEX idx_password_reset_tokens_token ON password_reset_tokens(token)');
    await db.execute('CREATE INDEX idx_password_reset_tokens_email ON password_reset_tokens(email)');
    await db.execute('CREATE INDEX idx_categorias_usuario ON categorias(usuario_id)');
    await db.execute('CREATE INDEX idx_categorias_tipo ON categorias(tipo)');
    await db.execute('CREATE INDEX idx_categorias_padre ON categorias(categoria_padre_id)');
    await db.execute('CREATE INDEX idx_transacciones_usuario ON transacciones(usuario_id)');
    await db.execute('CREATE INDEX idx_transacciones_cuenta ON transacciones(cuenta_id)');
    await db.execute('CREATE INDEX idx_transacciones_fecha ON transacciones(fecha)');
    await db.execute('CREATE INDEX idx_transacciones_tipo ON transacciones(tipo)');
    // Nuevos índices para filtros avanzados
    await db.execute('CREATE INDEX idx_transacciones_etiqueta ON transacciones(etiqueta)');
    await db.execute('CREATE INDEX idx_transacciones_nota ON transacciones(nota)');
    await db.execute('CREATE INDEX idx_transacciones_categoria ON transacciones(categoria_id)');
    await db.execute('CREATE INDEX idx_transacciones_monto ON transacciones(monto)');
    await db.execute('CREATE INDEX idx_presupuestos_usuario_periodo ON presupuestos(usuario_id, periodo, fecha_inicio)');
    await db.execute('CREATE INDEX idx_presupuestos_categoria_periodo ON presupuestos(categoria_id, periodo, fecha_inicio)');

    final now = DateTime.now().toIso8601String();

    final categoriasDefault = [
      {'nombre': 'Salario', 'tipo': 'ingreso', 'icono': 'salary', 'color': '#4CAF50'},
      {'nombre': 'Ventas', 'tipo': 'ingreso', 'icono': 'sales', 'color': '#8BC34A'},
      {'nombre': 'Inversiones', 'tipo': 'ingreso', 'icono': 'investment', 'color': '#2196F3'},
      {'nombre': 'Otros Ingresos', 'tipo': 'ingreso', 'icono': 'other', 'color': '#00BCD4'},
      {'nombre': 'Alimentación', 'tipo': 'egreso', 'icono': 'food', 'color': '#FF5722'},
      {'nombre': 'Transporte', 'tipo': 'egreso', 'icono': 'transport', 'color': '#FF9800'},
      {'nombre': 'Vivienda', 'tipo': 'egreso', 'icono': 'home', 'color': '#F44336'},
      {'nombre': 'Servicios', 'tipo': 'egreso', 'icono': 'services', 'color': '#E91E63'},
      {'nombre': 'Entretenimiento', 'tipo': 'egreso', 'icono': 'entertainment', 'color': '#9C27B0'},
      {'nombre': 'Salud', 'tipo': 'egreso', 'icono': 'health', 'color': '#673AB7'},
      {'nombre': 'Educación', 'tipo': 'egreso', 'icono': 'education', 'color': '#3F51B5'},
      {'nombre': 'Compras', 'tipo': 'egreso', 'icono': 'shopping', 'color': '#FF5252'},
      {'nombre': 'Otros Gastos', 'tipo': 'egreso', 'icono': 'other', 'color': '#607D8B'},
      {'nombre': 'Transferencia', 'tipo': 'transferencia', 'icono': 'transfer', 'color': '#FFC107'},
    ];

    for (var cat in categoriasDefault) {
      await db.insert('categorias', {
        'usuario_id': null,
        'nombre': cat['nombre'],
        'tipo': cat['tipo'],
        'descripcion': 'Categoría predeterminada',
        'icono': cat['icono'],
        'color': cat['color'],
        'activa': 1,
        'es_predeterminada': 1,
        'categoria_padre_id': null,
        'orden': 0,
        'tipo_negocio': null,
        'created_at': now,
        'updated_at': now,
      });
    }

    // Insertar plantillas de categorías por tipo de negocio (versión 9 consolidada)
    final plantillasBodega = [
      {'tipo_negocio': 'bodega', 'nombre': 'Venta de Productos', 'tipo': 'ingreso', 'icono': 'shopping_cart', 'color': '#4CAF50', 'es_principal': 1, 'categoria_padre': null},
      {'tipo_negocio': 'bodega', 'nombre': 'Venta de Bebidas', 'tipo': 'ingreso', 'icono': 'local_drink', 'color': '#8BC34A', 'es_principal': 0, 'categoria_padre': 'Venta de Productos'},
      {'tipo_negocio': 'bodega', 'nombre': 'Venta de Abarrotes', 'tipo': 'ingreso', 'icono': 'kitchen', 'color': '#8BC34A', 'es_principal': 0, 'categoria_padre': 'Venta de Productos'},
      {'tipo_negocio': 'bodega', 'nombre': 'Compra de Mercadería', 'tipo': 'egreso', 'icono': 'inventory', 'color': '#FF5722', 'es_principal': 1, 'categoria_padre': null},
      {'tipo_negocio': 'bodega', 'nombre': 'Alquiler de Local', 'tipo': 'egreso', 'icono': 'store', 'color': '#F44336', 'es_principal': 1, 'categoria_padre': null},
      {'tipo_negocio': 'bodega', 'nombre': 'Servicios Básicos', 'tipo': 'egreso', 'icono': 'receipt', 'color': '#E91E63', 'es_principal': 1, 'categoria_padre': null},
    ];

    final plantillasRestaurante = [
      {'tipo_negocio': 'restaurante', 'nombre': 'Ventas del Día', 'tipo': 'ingreso', 'icono': 'restaurant', 'color': '#4CAF50', 'es_principal': 1, 'categoria_padre': null},
      {'tipo_negocio': 'restaurante', 'nombre': 'Delivery', 'tipo': 'ingreso', 'icono': 'delivery_dining', 'color': '#8BC34A', 'es_principal': 0, 'categoria_padre': 'Ventas del Día'},
      {'tipo_negocio': 'restaurante', 'nombre': 'Mesa', 'tipo': 'ingreso', 'icono': 'table_restaurant', 'color': '#8BC34A', 'es_principal': 0, 'categoria_padre': 'Ventas del Día'},
      {'tipo_negocio': 'restaurante', 'nombre': 'Compra de Ingredientes', 'tipo': 'egreso', 'icono': 'shopping_basket', 'color': '#FF5722', 'es_principal': 1, 'categoria_padre': null},
      {'tipo_negocio': 'restaurante', 'nombre': 'Carnes y Pescados', 'tipo': 'egreso', 'icono': 'set_meal', 'color': '#FF9800', 'es_principal': 0, 'categoria_padre': 'Compra de Ingredientes'},
      {'tipo_negocio': 'restaurante', 'nombre': 'Verduras', 'tipo': 'egreso', 'icono': 'eco', 'color': '#FF9800', 'es_principal': 0, 'categoria_padre': 'Compra de Ingredientes'},
      {'tipo_negocio': 'restaurante', 'nombre': 'Sueldos Personal', 'tipo': 'egreso', 'icono': 'groups', 'color': '#9C27B0', 'es_principal': 1, 'categoria_padre': null},
    ];

    final plantillasServicios = [
      {'tipo_negocio': 'servicios', 'nombre': 'Honorarios', 'tipo': 'ingreso', 'icono': 'work', 'color': '#4CAF50', 'es_principal': 1, 'categoria_padre': null},
      {'tipo_negocio': 'servicios', 'nombre': 'Consultoría', 'tipo': 'ingreso', 'icono': 'support_agent', 'color': '#8BC34A', 'es_principal': 0, 'categoria_padre': 'Honorarios'},
      {'tipo_negocio': 'servicios', 'nombre': 'Proyectos', 'tipo': 'ingreso', 'icono': 'assignment', 'color': '#2196F3', 'es_principal': 1, 'categoria_padre': null},
      {'tipo_negocio': 'servicios', 'nombre': 'Material de Oficina', 'tipo': 'egreso', 'icono': 'description', 'color': '#FF5722', 'es_principal': 1, 'categoria_padre': null},
      {'tipo_negocio': 'servicios', 'nombre': 'Software y Licencias', 'tipo': 'egreso', 'icono': 'computer', 'color': '#673AB7', 'es_principal': 1, 'categoria_padre': null},
      {'tipo_negocio': 'servicios', 'nombre': 'Marketing', 'tipo': 'egreso', 'icono': 'campaign', 'color': '#E91E63', 'es_principal': 1, 'categoria_padre': null},
    ];

    for (var plantilla in [...plantillasBodega, ...plantillasRestaurante, ...plantillasServicios]) {
      await db.insert('plantillas_categorias', {
        'tipo_negocio': plantilla['tipo_negocio'],
        'nombre': plantilla['nombre'],
        'tipo': plantilla['tipo'],
        'descripcion': 'Plantilla para ${plantilla['tipo_negocio']}',
        'icono': plantilla['icono'],
        'color': plantilla['color'],
        'es_principal': plantilla['es_principal'],
        'categoria_padre_nombre': plantilla['categoria_padre'],
        'created_at': now,
        'updated_at': now,
      });
    }

    // usuario de prueba
    await db.insert('usuarios', {
      'email': 'admin@mypefinanzas.com',
      'password_hash': _hashPassword('admin123'),
      'nombre': 'Administrador',
      'apellido': 'Sistema',
      'telefono': null,
      'fecha_registro': now,
      'ultima_conexion': null,
      'activo': 1,
      'rol': 'admin',
      'avatar_uri': null,
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        final transaccionesAntiguas = await db.query('transaccion');
        final categoriasAntiguas = await db.query('categoria');

        await db.execute('DROP TABLE IF EXISTS transaccion');
        await db.execute('DROP TABLE IF EXISTS categoria');

        await _onCreate(db, newVersion);

        final usuarios = await db.query('usuarios', limit: 1);
        if (usuarios.isNotEmpty) {
          final usuarioId = usuarios.first['id'] as int;
          final now = DateTime.now().toIso8601String();

          for (var catAntigua in categoriasAntiguas) {
            await db.insert('categorias', {
              'usuario_id': usuarioId,
              'nombre': catAntigua['nombre'],
              'tipo': catAntigua['tipo'],
              'descripcion': 'Migrada desde versión anterior',
              'icono': 'default',
              'color': '#757575',
              'activa': 1,
              'es_predeterminada': 0,
              'created_at': now,
              'updated_at': now,
            });
          }

          for (var transAntigua in transaccionesAntiguas) {
            await db.insert('transacciones', {
              'usuario_id': usuarioId,
              'categoria_id': transAntigua['categoria_id'],
              'tipo': transAntigua['tipo'],
              'monto': transAntigua['monto'],
              'fecha': transAntigua['fecha'],
              'etiqueta': transAntigua['etiqueta'],
              'nota': transAntigua['nota'],
              'descripcion': null,
              'comprobante_uri': transAntigua['comprobante_uri'],
              'ubicacion': null,
              'recurrente': 0,
              'frecuencia_recurrencia': null,
              'sincronizado': 0,
              'created_at': now,
              'updated_at': now,
            });
          }
        }
      } catch (e) {
        await _onCreate(db, newVersion);
        rethrow;
      }
    }

    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS accounts(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          usuario_id INTEGER NOT NULL,
          nombre TEXT NOT NULL,
          tipo TEXT NOT NULL,
          moneda TEXT NOT NULL DEFAULT 'PEN',
          saldo REAL NOT NULL DEFAULT 0,
          nota TEXT,
          fecha_creacion TEXT NOT NULL,
          FOREIGN KEY(usuario_id) REFERENCES usuarios(id) ON DELETE CASCADE
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS budgets(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          usuario_id INTEGER NOT NULL,
          monto REAL NOT NULL,
          mes INTEGER NOT NULL,
          anio INTEGER NOT NULL,
          fecha_creacion TEXT NOT NULL,
          FOREIGN KEY(usuario_id) REFERENCES usuarios(id) ON DELETE CASCADE,
          UNIQUE(usuario_id, mes, anio)
        )
      ''');

      await db.execute('CREATE INDEX IF NOT EXISTS idx_accounts_usuario ON accounts(usuario_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_budgets_usuario_mes ON budgets(usuario_id, mes, anio)');
    }

    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS budget_periods(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          usuario_id INTEGER NOT NULL,
          monto REAL NOT NULL,
          periodo TEXT NOT NULL,
          mes INTEGER NOT NULL,
          anio INTEGER NOT NULL,
          FOREIGN KEY(usuario_id) REFERENCES usuarios(id) ON DELETE CASCADE,
          UNIQUE(usuario_id, periodo, mes, anio)
        )
      ''');

      await db.execute('CREATE INDEX IF NOT EXISTS idx_budget_periods_usuario ON budget_periods(usuario_id, periodo, mes, anio)');
    }

    if (oldVersion < 5) {
      try {
        await db.execute('ALTER TABLE accounts ADD COLUMN institucion TEXT');
      } catch (e) {
        debugPrint('⚠️ Columna institucion ya existe o error al agregar: $e');
      }
      try {
        await db.execute('ALTER TABLE accounts ADD COLUMN fecha_actualizacion TEXT');
      } catch (e) {
        debugPrint('⚠️ Columna fecha_actualizacion ya existe o error al agregar: $e');
      }
      try {
        await db.execute('ALTER TABLE accounts ADD COLUMN activa INTEGER NOT NULL DEFAULT 1');
      } catch (e) {
        debugPrint('⚠️ Columna activa ya existe o error al agregar: $e');
      }
    }

    if (oldVersion < 6) {
      // Crear la nueva tabla cuentas con todas las columnas necesarias
      await db.execute('''
        CREATE TABLE IF NOT EXISTS cuentas(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          usuario_id INTEGER NOT NULL,
          nombre TEXT NOT NULL,
          tipo TEXT NOT NULL,
          saldo REAL NOT NULL DEFAULT 0,
          saldo_inicial REAL NOT NULL DEFAULT 0,
          numero_fin TEXT,
          institucion TEXT,
          moneda TEXT NOT NULL DEFAULT 'PEN',
          color TEXT NOT NULL,
          icono TEXT NOT NULL,
          activa INTEGER NOT NULL DEFAULT 1,
          incluir_en_total INTEGER NOT NULL DEFAULT 1,
          orden INTEGER NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          FOREIGN KEY(usuario_id) REFERENCES usuarios(id) ON DELETE CASCADE
        )
      ''');

      await db.execute('CREATE INDEX IF NOT EXISTS idx_cuentas_usuario ON cuentas(usuario_id)');

      // Agregar columnas a transacciones para soportar cuentas
      try {
        await db.execute('ALTER TABLE transacciones ADD COLUMN cuenta_id INTEGER');
      } catch (e) {
        debugPrint('⚠️ Columna cuenta_id ya existe: $e');
      }

      try {
        await db.execute('ALTER TABLE transacciones ADD COLUMN cuenta_destino_id INTEGER');
      } catch (e) {
        debugPrint('⚠️ Columna cuenta_destino_id ya existe: $e');
      }

      try {
        await db.execute('ALTER TABLE transacciones ADD COLUMN es_recurrente INTEGER NOT NULL DEFAULT 0');
      } catch (e) {
        debugPrint('⚠️ Columna es_recurrente ya existe: $e');
      }

      try {
        await db.execute('ALTER TABLE transacciones ADD COLUMN confirmada INTEGER NOT NULL DEFAULT 1');
      } catch (e) {
        debugPrint('⚠️ Columna confirmada ya existe: $e');
      }

      debugPrint('✅ Tabla cuentas creada exitosamente');
    }

    if (oldVersion < 7) {
      // Agregar columna para identificar transacciones de apertura de cuenta
      try {
        await db.execute('ALTER TABLE transacciones ADD COLUMN es_apertura_cuenta INTEGER NOT NULL DEFAULT 0');
        debugPrint('✅ Columna es_apertura_cuenta agregada');
      } catch (e) {
        debugPrint('⚠️ Columna es_apertura_cuenta ya existe: $e');
      }

      // Marcar las transacciones existentes de "Saldo inicial" como apertura de cuenta
      try {
        await db.execute('''
          UPDATE transacciones 
          SET es_apertura_cuenta = 1 
          WHERE descripcion = 'Saldo inicial'
        ''');
        debugPrint('✅ Transacciones de apertura marcadas');
      } catch (e) {
        debugPrint('⚠️ Error al marcar transacciones de apertura: $e');
      }
    }

    // Versión 8: Agregar tabla de tokens de recuperación de contraseña
    if (oldVersion < 8) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS password_reset_tokens(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            usuario_id INTEGER NOT NULL,
            email TEXT NOT NULL,
            token TEXT NOT NULL UNIQUE,
            fecha_creacion TEXT NOT NULL,
            fecha_expiracion TEXT NOT NULL,
            usado INTEGER NOT NULL DEFAULT 0,
            ip_address TEXT,
            FOREIGN KEY(usuario_id) REFERENCES usuarios(id) ON DELETE CASCADE
          )
        ''');

        await db.execute('CREATE INDEX IF NOT EXISTS idx_password_reset_tokens_usuario ON password_reset_tokens(usuario_id)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_password_reset_tokens_token ON password_reset_tokens(token)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_password_reset_tokens_email ON password_reset_tokens(email)');

        debugPrint('✅ Tabla password_reset_tokens creada');
      } catch (e) {
        debugPrint('⚠️ Error al crear tabla password_reset_tokens: $e');
      }
    }

    // Versión 9: Agregar soporte de subcategorías y plantillas por tipo de negocio
    if (oldVersion < 9) {
      try {
        // Agregar campos para subcategorías en la tabla categorias
        await db.execute('ALTER TABLE categorias ADD COLUMN categoria_padre_id INTEGER REFERENCES categorias(id) ON DELETE CASCADE');
        debugPrint('✅ Columna categoria_padre_id agregada');
      } catch (e) {
        debugPrint('⚠️ Columna categoria_padre_id ya existe o error al agregar: $e');
      }

      try {
        await db.execute('ALTER TABLE categorias ADD COLUMN orden INTEGER DEFAULT 0');
        debugPrint('✅ Columna orden agregada a categorias');
      } catch (e) {
        debugPrint('⚠️ Columna orden ya existe en categorias: $e');
      }

      try {
        await db.execute('ALTER TABLE categorias ADD COLUMN tipo_negocio TEXT');
        debugPrint('✅ Columna tipo_negocio agregada');
      } catch (e) {
        debugPrint('⚠️ Columna tipo_negocio ya existe: $e');
      }

      // Crear índice para mejorar consultas de subcategorías
      try {
        await db.execute('CREATE INDEX idx_categorias_padre ON categorias(categoria_padre_id)');
        debugPrint('✅ Índice idx_categorias_padre creado');
      } catch (e) {
        debugPrint('⚠️ Índice idx_categorias_padre ya existe: $e');
      }

      // Crear tabla para plantillas de categorías por tipo de negocio
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS plantillas_categorias(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            tipo_negocio TEXT NOT NULL,
            nombre TEXT NOT NULL,
            tipo TEXT NOT NULL,
            descripcion TEXT,
            icono TEXT,
            color TEXT,
            es_principal INTEGER NOT NULL DEFAULT 1,
            categoria_padre_nombre TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
        debugPrint('✅ Tabla plantillas_categorias creada');
      } catch (e) {
        debugPrint('⚠️ Error al crear tabla plantillas_categorias: $e');
      }

      // Insertar plantillas de categorías por tipo de negocio
      final now = DateTime.now().toIso8601String();

      // Plantillas para Bodega/Tienda
      final plantillasBodega = [
        {'tipo_negocio': 'bodega', 'nombre': 'Venta de Productos', 'tipo': 'ingreso', 'icono': 'shopping_cart', 'color': '#4CAF50', 'es_principal': 1, 'categoria_padre': null},
        {'tipo_negocio': 'bodega', 'nombre': 'Venta de Bebidas', 'tipo': 'ingreso', 'icono': 'local_drink', 'color': '#8BC34A', 'es_principal': 0, 'categoria_padre': 'Venta de Productos'},
        {'tipo_negocio': 'bodega', 'nombre': 'Venta de Abarrotes', 'tipo': 'ingreso', 'icono': 'kitchen', 'color': '#8BC34A', 'es_principal': 0, 'categoria_padre': 'Venta de Productos'},
        {'tipo_negocio': 'bodega', 'nombre': 'Compra de Mercadería', 'tipo': 'egreso', 'icono': 'inventory', 'color': '#FF5722', 'es_principal': 1, 'categoria_padre': null},
        {'tipo_negocio': 'bodega', 'nombre': 'Alquiler de Local', 'tipo': 'egreso', 'icono': 'store', 'color': '#F44336', 'es_principal': 1, 'categoria_padre': null},
        {'tipo_negocio': 'bodega', 'nombre': 'Servicios Básicos', 'tipo': 'egreso', 'icono': 'receipt', 'color': '#E91E63', 'es_principal': 1, 'categoria_padre': null},
      ];

      // Plantillas para Restaurante
      final plantillasRestaurante = [
        {'tipo_negocio': 'restaurante', 'nombre': 'Ventas del Día', 'tipo': 'ingreso', 'icono': 'restaurant', 'color': '#4CAF50', 'es_principal': 1, 'categoria_padre': null},
        {'tipo_negocio': 'restaurante', 'nombre': 'Delivery', 'tipo': 'ingreso', 'icono': 'delivery_dining', 'color': '#8BC34A', 'es_principal': 0, 'categoria_padre': 'Ventas del Día'},
        {'tipo_negocio': 'restaurante', 'nombre': 'Mesa', 'tipo': 'ingreso', 'icono': 'table_restaurant', 'color': '#8BC34A', 'es_principal': 0, 'categoria_padre': 'Ventas del Día'},
        {'tipo_negocio': 'restaurante', 'nombre': 'Compra de Ingredientes', 'tipo': 'egreso', 'icono': 'shopping_basket', 'color': '#FF5722', 'es_principal': 1, 'categoria_padre': null},
        {'tipo_negocio': 'restaurante', 'nombre': 'Carnes y Pescados', 'tipo': 'egreso', 'icono': 'set_meal', 'color': '#FF9800', 'es_principal': 0, 'categoria_padre': 'Compra de Ingredientes'},
        {'tipo_negocio': 'restaurante', 'nombre': 'Verduras', 'tipo': 'egreso', 'icono': 'eco', 'color': '#FF9800', 'es_principal': 0, 'categoria_padre': 'Compra de Ingredientes'},
        {'tipo_negocio': 'restaurante', 'nombre': 'Sueldos Personal', 'tipo': 'egreso', 'icono': 'groups', 'color': '#9C27B0', 'es_principal': 1, 'categoria_padre': null},
      ];

      // Plantillas para Servicios Profesionales
      final plantillasServicios = [
        {'tipo_negocio': 'servicios', 'nombre': 'Honorarios', 'tipo': 'ingreso', 'icono': 'work', 'color': '#4CAF50', 'es_principal': 1, 'categoria_padre': null},
        {'tipo_negocio': 'servicios', 'nombre': 'Consultoría', 'tipo': 'ingreso', 'icono': 'support_agent', 'color': '#8BC34A', 'es_principal': 0, 'categoria_padre': 'Honorarios'},
        {'tipo_negocio': 'servicios', 'nombre': 'Proyectos', 'tipo': 'ingreso', 'icono': 'assignment', 'color': '#2196F3', 'es_principal': 1, 'categoria_padre': null},
        {'tipo_negocio': 'servicios', 'nombre': 'Material de Oficina', 'tipo': 'egreso', 'icono': 'description', 'color': '#FF5722', 'es_principal': 1, 'categoria_padre': null},
        {'tipo_negocio': 'servicios', 'nombre': 'Software y Licencias', 'tipo': 'egreso', 'icono': 'computer', 'color': '#673AB7', 'es_principal': 1, 'categoria_padre': null},
        {'tipo_negocio': 'servicios', 'nombre': 'Marketing', 'tipo': 'egreso', 'icono': 'campaign', 'color': '#E91E63', 'es_principal': 1, 'categoria_padre': null},
      ];

      // Insertar todas las plantillas
      try {
        for (var plantilla in [...plantillasBodega, ...plantillasRestaurante, ...plantillasServicios]) {
          await db.insert('plantillas_categorias', {
            'tipo_negocio': plantilla['tipo_negocio'],
            'nombre': plantilla['nombre'],
            'tipo': plantilla['tipo'],
            'descripcion': 'Plantilla para ${plantilla['tipo_negocio']}',
            'icono': plantilla['icono'],
            'color': plantilla['color'],
            'es_principal': plantilla['es_principal'],
            'categoria_padre_nombre': plantilla['categoria_padre'],
            'created_at': now,
            'updated_at': now,
          });
        }
        debugPrint('✅ Plantillas de categorías insertadas exitosamente');
      } catch (e) {
        debugPrint('⚠️ Error al insertar plantillas: $e');
      }
    }

    if (oldVersion < 10) {
      // Versión 10: columnas adicionales para recurrencia avanzada
      try {
        await db.execute('ALTER TABLE transacciones ADD COLUMN recurrence_interval_days INTEGER');
        debugPrint('✅ Columna recurrence_interval_days agregada');
      } catch (e) {
        debugPrint('⚠️ Columna recurrence_interval_days ya existe: $e');
      }
      try {
        await db.execute('ALTER TABLE transacciones ADD COLUMN recurrence_end_date TEXT');
        debugPrint('✅ Columna recurrence_end_date agregada');
      } catch (e) {
        debugPrint('⚠️ Columna recurrence_end_date ya existe: $e');
      }
      try {
        await db.execute('ALTER TABLE transacciones ADD COLUMN next_occurrence TEXT');
        debugPrint('✅ Columna next_occurrence agregada');
      } catch (e) {
        debugPrint('⚠️ Columna next_occurrence ya existe: $e');
      }
    }

    if (oldVersion < 13) {
      try {
        await db.execute("ALTER TABLE presupuestos ADD COLUMN alerta_thresholds TEXT NOT NULL DEFAULT '75,90,100'");
      } catch (e) { debugPrint('⚠️ alerta_thresholds ya existe: $e'); }
      try {
        await db.execute('ALTER TABLE presupuestos ADD COLUMN alerta_emitida_hasta INTEGER NOT NULL DEFAULT 0');
      } catch (e) { debugPrint('⚠️ alerta_emitida_hasta ya existe: $e'); }
      try {
        await db.execute('ALTER TABLE presupuestos ADD COLUMN auto_ajuste INTEGER NOT NULL DEFAULT 0');
      } catch (e) { debugPrint('⚠️ auto_ajuste ya existe: $e'); }
      try {
        await db.execute('CREATE INDEX IF NOT EXISTS idx_presupuestos_usuario_periodo ON presupuestos(usuario_id, periodo, fecha_inicio)');
      } catch (e) { debugPrint('⚠️ índice idx_presupuestos_usuario_periodo: $e'); }
      try {
        await db.execute('CREATE INDEX IF NOT EXISTS idx_presupuestos_categoria_periodo ON presupuestos(categoria_id, periodo, fecha_inicio)');
      } catch (e) { debugPrint('⚠️ índice idx_presupuestos_categoria_periodo: $e'); }
      debugPrint('✅ Migración v13 presupuestos por categoría lista');
    }

    // Asegurar migración para agregar columna afecta_saldo en transacciones si no existe (version bump)
    if (oldVersion < 13) {
      try {
        await db.execute('ALTER TABLE transacciones ADD COLUMN afecta_saldo INTEGER NOT NULL DEFAULT 1');
        debugPrint('✅ Columna afecta_saldo agregada a transacciones');
      } catch (e) {
        debugPrint('⚠️ Columna afecta_saldo ya existe o error al agregar: $e');
      }
    }

    // Versión 14: Añadir tablas de gamification (perfiles, logros y eventos)
    if (oldVersion < 14) {
      try {
        // Crear tablas si no existen (compatible con instalaciones antiguas)
        await db.execute('''
          CREATE TABLE IF NOT EXISTS gamification_profiles(
            usuario_id INTEGER PRIMARY KEY,
            puntos INTEGER NOT NULL DEFAULT 0,
            nivel INTEGER NOT NULL DEFAULT 1,
            racha_actual INTEGER NOT NULL DEFAULT 0,
            racha_maxima INTEGER NOT NULL DEFAULT 0,
            ultima_fecha_evento TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            FOREIGN KEY(usuario_id) REFERENCES usuarios(id) ON DELETE CASCADE
          )
        ''');
      } catch (e) {
        debugPrint('⚠️ Error creando tabla gamification_profiles: $e');
      }

      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS gamification_achievements(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            tipo TEXT NOT NULL,
            nombre TEXT NOT NULL,
            descripcion TEXT,
            progreso_actual REAL NOT NULL DEFAULT 0,
            progreso_objetivo REAL NOT NULL DEFAULT 1,
            estado TEXT NOT NULL DEFAULT 'locked',
            ultima_actualizacion TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
      } catch (e) {
        debugPrint('⚠️ Error creando tabla gamification_achievements: $e');
      }

      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS gamification_events(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            usuario_id INTEGER,
            tipo_evento TEXT NOT NULL,
            descripcion TEXT,
            puntos_otorgados INTEGER NOT NULL DEFAULT 0,
            fecha_evento TEXT NOT NULL,
            created_at TEXT NOT NULL,
            FOREIGN KEY(usuario_id) REFERENCES usuarios(id) ON DELETE CASCADE
          )
        ''');
      } catch (e) {
        debugPrint('⚠️ Error creando tabla gamification_events: $e');
      }

      // Crear índices para consultas rápidas
      try { await db.execute('CREATE INDEX IF NOT EXISTS idx_gamification_profiles_usuario ON gamification_profiles(usuario_id)'); } catch (e) { debugPrint('⚠️ idx_gamification_profiles_usuario: $e'); }
      try { await db.execute('CREATE INDEX IF NOT EXISTS idx_gamification_achievements_tipo ON gamification_achievements(tipo)'); } catch (e) { debugPrint('⚠️ idx_gamification_achievements_tipo: $e'); }
      try { await db.execute('CREATE INDEX IF NOT EXISTS idx_gamification_events_usuario ON gamification_events(usuario_id)'); } catch (e) { debugPrint('⚠️ idx_gamification_events_usuario: $e'); }

      debugPrint('✅ Migración v14 (gamification) aplicada');
    }

    if (oldVersion < 15) {
      debugPrint('🔄 Migrando a v15: Creando tabla user_achievements');
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS user_achievements(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            usuario_id INTEGER NOT NULL,
            achievement_id INTEGER NOT NULL,
            progreso_actual REAL NOT NULL DEFAULT 0,
            estado TEXT NOT NULL DEFAULT 'locked',
            ultima_actualizacion TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            FOREIGN KEY(usuario_id) REFERENCES usuarios(id) ON DELETE CASCADE,
            FOREIGN KEY(achievement_id) REFERENCES gamification_achievements(id) ON DELETE CASCADE,
            UNIQUE(usuario_id, achievement_id)
          )
        ''');

        await db.execute('CREATE INDEX IF NOT EXISTS idx_user_achievements_user ON user_achievements(usuario_id)');
        debugPrint('✅ Tabla user_achievements creada correctamente');
      } catch (e) {
        debugPrint('⚠️ Error creando user_achievements: $e');
      }
    }
  }

  Future<void> ensureSeedUser() async {
    try {
      final db = await database;
      final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM usuarios')) ?? 0;
      if (count == 0) {
        final now = DateTime.now().toIso8601String();
        await db.insert('usuarios', {
          'email': 'admin@mypefinanzas.com',
          'password_hash': _hashPassword('admin123'),
          'nombre': 'Administrador',
          'apellido': 'Sistema',
          'telefono': null,
          'fecha_registro': now,
          'ultima_conexion': null,
          'activo': 1,
          'rol': 'admin',
          'avatar_uri': null,
          'created_at': now,
          'updated_at': now,
        });
        debugPrint('🧪 Usuario seed admin reinsertado');

        // Insertar perfil de gamification para el usuario seed (si la tabla existe)
        try {
          final usuarioRow = await db.query('usuarios', where: 'email = ?', whereArgs: ['admin@mypefinanzas.com'], limit: 1);
          if (usuarioRow.isNotEmpty) {
            final usuarioId = usuarioRow.first['id'] as int;
            // Crear perfil base solo si la tabla existe y no hay perfil previo
            try {
              final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='gamification_profiles'");
              if (tables.isNotEmpty) {
                final existing = await db.query('gamification_profiles', where: 'usuario_id = ?', whereArgs: [usuarioId], limit: 1);
                if (existing.isEmpty) {
                  await db.insert('gamification_profiles', {
                    'usuario_id': usuarioId,
                    'puntos': 0,
                    'nivel': 1,
                    'racha_actual': 0,
                    'racha_maxima': 0,
                    'ultima_fecha_evento': null,
                    'created_at': now,
                    'updated_at': now,
                  });
                  debugPrint('🧪 Perfil gamification para usuario seed creado');
                }
              }
            } catch (e) {
              debugPrint('⚠️ No se pudo crear perfil gamification automáticamente: $e');
            }
          }
        } catch (e) {
          debugPrint('⚠️ Error buscando usuario seed tras inserción: $e');
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error al asegurar usuario seed: $e');
    }
  }

  String _hashPassword(String password) {
    return 'hash_$password';
  }

  String getCurrentTimestamp() {
    return DateTime.now().toIso8601String();
  }
}
