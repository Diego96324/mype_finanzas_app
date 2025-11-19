import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';

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
      version: 16, // bump para reestructurar gamification y agregar seed (v16)
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onOpen: _onOpen, // 🆕 Conectar seed en apertura
    );
  }

  // =========================================================================
  // 🆕 ON OPEN - Se ejecuta cada vez que se abre la BD
  // =========================================================================
  Future<void> _onOpen(Database db) async {
    await _seedAchievements(db);
  }

  // =========================================================================
  // 🆕 SEED ACHIEVEMENTS - Inserta logros por defecto si la tabla está vacía
  // =========================================================================
  Future<void> _seedAchievements(Database db) async {
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
      debugPrint('⚠️ Error en _seedAchievements: $e');
    }
  }

  // =========================================================================
  // ON CREATE - Crear todas las tablas desde cero
  // =========================================================================
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
        recurrence_interval_days INTEGER,
        recurrence_end_date TEXT,
        next_occurrence TEXT,
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

    // =========================================================================
    // --- TABLAS DE GAMIFICATION (v16 - Estructura corregida) ---
    // =========================================================================

    // Perfiles de gamificación por usuario
    await db.execute('''
      CREATE TABLE gamification_profiles(
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

    // Catálogo de logros disponibles (estructura corregida v16)
    await db.execute('''
      CREATE TABLE gamification_achievements(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT NOT NULL UNIQUE,
        nombre TEXT NOT NULL,
        descripcion TEXT,
        puntos INTEGER NOT NULL DEFAULT 0,
        progreso_objetivo REAL NOT NULL DEFAULT 1,
        tipo TEXT NOT NULL,
        icon_name TEXT NOT NULL DEFAULT 'emoji_events',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Historial de eventos de gamificación
    await db.execute('''
      CREATE TABLE gamification_events(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        usuario_id INTEGER NOT NULL,
        tipo_evento TEXT NOT NULL,
        descripcion TEXT,
        puntos_otorgados INTEGER NOT NULL DEFAULT 0,
        fecha TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY(usuario_id) REFERENCES usuarios(id) ON DELETE CASCADE
      )
    ''');

    // Tabla intermedia: progreso del usuario en cada logro
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

    // =========================================================================
    // --- ÍNDICES ---
    // =========================================================================

    // Índices de gamification
    await db.execute('CREATE INDEX idx_gamification_profiles_usuario ON gamification_profiles(usuario_id)');
    await db.execute('CREATE INDEX idx_gamification_achievements_tipo ON gamification_achievements(tipo)');
    await db.execute('CREATE INDEX idx_gamification_achievements_code ON gamification_achievements(code)');
    await db.execute('CREATE INDEX idx_gamification_events_usuario ON gamification_events(usuario_id)');
    await db.execute('CREATE INDEX idx_gamification_events_fecha ON gamification_events(fecha)');
    await db.execute('CREATE INDEX idx_user_achievements_user ON user_achievements(usuario_id)');
    await db.execute('CREATE INDEX idx_user_achievements_achievement ON user_achievements(achievement_id)');

    // Índices generales
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
    await db.execute('CREATE INDEX idx_transacciones_etiqueta ON transacciones(etiqueta)');
    await db.execute('CREATE INDEX idx_transacciones_nota ON transacciones(nota)');
    await db.execute('CREATE INDEX idx_transacciones_categoria ON transacciones(categoria_id)');
    await db.execute('CREATE INDEX idx_transacciones_monto ON transacciones(monto)');
    await db.execute('CREATE INDEX idx_presupuestos_usuario_periodo ON presupuestos(usuario_id, periodo, fecha_inicio)');
    await db.execute('CREATE INDEX idx_presupuestos_categoria_periodo ON presupuestos(categoria_id, periodo, fecha_inicio)');
    await db.execute('CREATE INDEX idx_accounts_usuario ON accounts(usuario_id)');
    await db.execute('CREATE INDEX idx_budgets_usuario_mes ON budgets(usuario_id, mes, anio)');
    await db.execute('CREATE INDEX idx_budget_periods_usuario ON budget_periods(usuario_id, periodo, mes, anio)');
    await db.execute('CREATE INDEX idx_cuentas_usuario ON cuentas(usuario_id)');

    // =========================================================================
    // --- DATOS INICIALES ---
    // =========================================================================

    final now = DateTime.now().toIso8601String();

    // Categorías por defecto
    final categoriasDefault = [
      {'nombre': 'Salario', 'tipo': 'ingreso', 'icono': 'salary', 'color': '#4CAF50'},
      {'nombre': 'Ventas', 'tipo': 'ingreso', 'icono': 'sales', 'color': '#8BC34A'},
      {'nombre': 'Inversiones', 'tipo': 'ingreso', 'icono': 'investment', 'color': '#2196F3'},
      {'nombre': 'Otros Ingresos', 'tipo': 'ingreso', 'icono': 'other', 'color': '#00BCD4'},
      {'nombre': 'Alimentación', 'tipo': 'egreso', 'icono': 'food', 'color': '#FF5722'},
      {'nombre': 'Transporte', 'tipo': 'egreso', 'icono': 'transport', 'color': '#FF9800'},
      {'nombre': 'Servicios', 'tipo': 'egreso', 'icono': 'services', 'color': '#FFC107'},
      {'nombre': 'Entretenimiento', 'tipo': 'egreso', 'icono': 'entertainment', 'color': '#9C27B0'},
      {'nombre': 'Salud', 'tipo': 'egreso', 'icono': 'health', 'color': '#E91E63'},
      {'nombre': 'Educación', 'tipo': 'egreso', 'icono': 'education', 'color': '#3F51B5'},
      {'nombre': 'Otros Gastos', 'tipo': 'egreso', 'icono': 'other', 'color': '#607D8B'},
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

    // Usuario administrador por defecto
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

    // Llamar al seed de achievements
    await _seedAchievements(db);
  }

  // =========================================================================
  // ON UPGRADE - Migraciones incrementales
  // =========================================================================
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
      try {
        await db.execute('ALTER TABLE transacciones ADD COLUMN es_apertura_cuenta INTEGER NOT NULL DEFAULT 0');
        debugPrint('✅ Columna es_apertura_cuenta agregada');
      } catch (e) {
        debugPrint('⚠️ Columna es_apertura_cuenta ya existe: $e');
      }

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

        debugPrint('✅ Tabla password_reset_tokens creada exitosamente');
      } catch (e) {
        debugPrint('⚠️ Error creando password_reset_tokens: $e');
      }
    }

    if (oldVersion < 9) {
      try {
        await db.execute('ALTER TABLE categorias ADD COLUMN categoria_padre_id INTEGER REFERENCES categorias(id) ON DELETE CASCADE');
      } catch (e) {
        debugPrint('⚠️ categoria_padre_id: $e');
      }
      try {
        await db.execute('ALTER TABLE categorias ADD COLUMN orden INTEGER DEFAULT 0');
      } catch (e) {
        debugPrint('⚠️ orden: $e');
      }
      try {
        await db.execute('ALTER TABLE categorias ADD COLUMN tipo_negocio TEXT');
      } catch (e) {
        debugPrint('⚠️ tipo_negocio: $e');
      }
      try {
        await db.execute('CREATE INDEX IF NOT EXISTS idx_categorias_padre ON categorias(categoria_padre_id)');
      } catch (e) {
        debugPrint('⚠️ idx_categorias_padre: $e');
      }

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
      } catch (e) {
        debugPrint('⚠️ plantillas_categorias: $e');
      }

      debugPrint('✅ Migración v9 (jerarquía y plantillas) aplicada');
    }

    if (oldVersion < 10) {
      try {
        await db.execute('ALTER TABLE transacciones ADD COLUMN recurrence_interval_days INTEGER');
      } catch (e) {
        debugPrint('⚠️ recurrence_interval_days: $e');
      }
      try {
        await db.execute('ALTER TABLE transacciones ADD COLUMN recurrence_end_date TEXT');
      } catch (e) {
        debugPrint('⚠️ recurrence_end_date: $e');
      }
      try {
        await db.execute('ALTER TABLE transacciones ADD COLUMN next_occurrence TEXT');
      } catch (e) {
        debugPrint('⚠️ next_occurrence: $e');
      }
      debugPrint('✅ Migración v10 (campos recurrencia) aplicada');
    }

    if (oldVersion < 11) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS presupuestos(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            usuario_id INTEGER NOT NULL,
            nombre TEXT NOT NULL,
            monto_limite REAL NOT NULL,
            periodo TEXT NOT NULL,
            fecha_inicio TEXT NOT NULL,
            fecha_fin TEXT NOT NULL,
            activo INTEGER NOT NULL DEFAULT 1,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            FOREIGN KEY(usuario_id) REFERENCES usuarios(id) ON DELETE CASCADE
          )
        ''');
      } catch (e) {
        debugPrint('⚠️ Error creando presupuestos: $e');
      }

      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS metas_financieras(
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
      } catch (e) {
        debugPrint('⚠️ Error creando metas_financieras: $e');
      }

      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS recordatorios(
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
      } catch (e) {
        debugPrint('⚠️ Error creando recordatorios: $e');
      }

      debugPrint('✅ Migración v11 (presupuestos, metas, recordatorios) aplicada');
    }

    if (oldVersion < 12) {
      try {
        await db.execute('ALTER TABLE presupuestos ADD COLUMN categoria_id INTEGER REFERENCES categorias(id) ON DELETE CASCADE');
      } catch (e) {
        debugPrint('⚠️ categoria_id ya existe: $e');
      }
      debugPrint('✅ Migración v12 (presupuestos.categoria_id) aplicada');
    }

    if (oldVersion < 13) {
      try {
        await db.execute('ALTER TABLE presupuestos ADD COLUMN alerta_thresholds TEXT NOT NULL DEFAULT \'75,90,100\'');
      } catch (e) {
        debugPrint('⚠️ alerta_thresholds ya existe: $e');
      }
      try {
        await db.execute('ALTER TABLE presupuestos ADD COLUMN alerta_emitida_hasta INTEGER NOT NULL DEFAULT 0');
      } catch (e) {
        debugPrint('⚠️ alerta_emitida_hasta ya existe: $e');
      }
      try {
        await db.execute('ALTER TABLE presupuestos ADD COLUMN auto_ajuste INTEGER NOT NULL DEFAULT 0');
      } catch (e) {
        debugPrint('⚠️ auto_ajuste ya existe: $e');
      }
      try {
        await db.execute('CREATE INDEX IF NOT EXISTS idx_presupuestos_usuario_periodo ON presupuestos(usuario_id, periodo, fecha_inicio)');
      } catch (e) {
        debugPrint('⚠️ índice idx_presupuestos_usuario_periodo: $e');
      }
      try {
        await db.execute('CREATE INDEX IF NOT EXISTS idx_presupuestos_categoria_periodo ON presupuestos(categoria_id, periodo, fecha_inicio)');
      } catch (e) {
        debugPrint('⚠️ índice idx_presupuestos_categoria_periodo: $e');
      }

      try {
        await db.execute('ALTER TABLE transacciones ADD COLUMN afecta_saldo INTEGER NOT NULL DEFAULT 1');
        debugPrint('✅ Columna afecta_saldo agregada a transacciones');
      } catch (e) {
        debugPrint('⚠️ Columna afecta_saldo ya existe o error al agregar: $e');
      }

      debugPrint('✅ Migración v13 presupuestos por categoría lista');
    }

    if (oldVersion < 14) {
      try {
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

      try {
        await db.execute('CREATE INDEX IF NOT EXISTS idx_gamification_profiles_usuario ON gamification_profiles(usuario_id)');
      } catch (e) {
        debugPrint('⚠️ idx_gamification_profiles_usuario: $e');
      }
      try {
        await db.execute('CREATE INDEX IF NOT EXISTS idx_gamification_achievements_tipo ON gamification_achievements(tipo)');
      } catch (e) {
        debugPrint('⚠️ idx_gamification_achievements_tipo: $e');
      }
      try {
        await db.execute('CREATE INDEX IF NOT EXISTS idx_gamification_events_usuario ON gamification_events(usuario_id)');
      } catch (e) {
        debugPrint('⚠️ idx_gamification_events_usuario: $e');
      }

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

    // =========================================================================
    // 🆕 MIGRACIÓN v16 - Reestructurar gamification_achievements
    // =========================================================================
    if (oldVersion < 16) {
      debugPrint('🔄 Migrando a v16: Reestructurando gamification_achievements');

      try {
        // Verificar si necesitamos agregar las nuevas columnas
        final tableInfo = await db.rawQuery('PRAGMA table_info(gamification_achievements)');
        final existingColumns = tableInfo.map((row) => row['name'] as String).toSet();

        // Agregar columna 'code' si no existe
        if (!existingColumns.contains('code')) {
          await db.execute('ALTER TABLE gamification_achievements ADD COLUMN code TEXT');
          // Generar codes únicos para registros existentes
          final existing = await db.query('gamification_achievements');
          for (var row in existing) {
            final id = row['id'] as int;
            final nombre = (row['nombre'] as String?)?.toUpperCase().replaceAll(' ', '_') ?? 'ACHIEVEMENT_$id';
            await db.execute('UPDATE gamification_achievements SET code = ? WHERE id = ?', [nombre, id]);
          }
          debugPrint('✅ Columna code agregada y poblada');
        }

        // Agregar columna 'puntos' si no existe
        if (!existingColumns.contains('puntos')) {
          await db.execute('ALTER TABLE gamification_achievements ADD COLUMN puntos INTEGER NOT NULL DEFAULT 0');
          debugPrint('✅ Columna puntos agregada');
        }

        // Agregar columna 'icon_name' si no existe
        if (!existingColumns.contains('icon_name')) {
          await db.execute('ALTER TABLE gamification_achievements ADD COLUMN icon_name TEXT NOT NULL DEFAULT \'emoji_events\'');
          debugPrint('✅ Columna icon_name agregada');
        }

        // Crear índice para code si no existe
        try {
          await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_gamification_achievements_code ON gamification_achievements(code)');
        } catch (e) {
          debugPrint('⚠️ Índice code ya existe: $e');
        }

        // Renombrar fecha_evento a fecha en gamification_events si es necesario
        final eventsInfo = await db.rawQuery('PRAGMA table_info(gamification_events)');
        final eventsColumns = eventsInfo.map((row) => row['name'] as String).toSet();

        if (eventsColumns.contains('fecha_evento') && !eventsColumns.contains('fecha')) {
          // SQLite no soporta RENAME COLUMN directamente en versiones antiguas
          // Creamos una tabla temporal y migramos
          try {
            await db.execute('''
              CREATE TABLE IF NOT EXISTS gamification_events_new(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                usuario_id INTEGER NOT NULL,
                tipo_evento TEXT NOT NULL,
                descripcion TEXT,
                puntos_otorgados INTEGER NOT NULL DEFAULT 0,
                fecha TEXT NOT NULL,
                created_at TEXT NOT NULL,
                FOREIGN KEY(usuario_id) REFERENCES usuarios(id) ON DELETE CASCADE
              )
            ''');

            await db.execute('''
              INSERT INTO gamification_events_new (id, usuario_id, tipo_evento, descripcion, puntos_otorgados, fecha, created_at)
              SELECT id, usuario_id, tipo_evento, descripcion, puntos_otorgados, fecha_evento, created_at
              FROM gamification_events
            ''');

            await db.execute('DROP TABLE gamification_events');
            await db.execute('ALTER TABLE gamification_events_new RENAME TO gamification_events');
            await db.execute('CREATE INDEX IF NOT EXISTS idx_gamification_events_usuario ON gamification_events(usuario_id)');
            await db.execute('CREATE INDEX IF NOT EXISTS idx_gamification_events_fecha ON gamification_events(fecha)');

            debugPrint('✅ Tabla gamification_events reestructurada');
          } catch (e) {
            debugPrint('⚠️ Error reestructurando gamification_events: $e');
          }
        }

        debugPrint('✅ Migración v16 completada');
      } catch (e) {
        debugPrint('⚠️ Error en migración v16: $e');
      }

      // Llamar al seed después de la migración
      await _seedAchievements(db);
    }
  }

  // =========================================================================
  // MÉODO PÚBLICO: Asegurar usuario seed
  // =========================================================================
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

        // Insertar perfil de gamification para el usuario seed
        try {
          final usuarioRow = await db.query('usuarios', where: 'email = ?', whereArgs: ['admin@mypefinanzas.com'], limit: 1);
          if (usuarioRow.isNotEmpty) {
            final usuarioId = usuarioRow.first['id'] as int;
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
          }
        } catch (e) {
          debugPrint('⚠️ No se pudo crear perfil gamification automáticamente: $e');
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