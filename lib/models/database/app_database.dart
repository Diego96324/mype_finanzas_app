import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'database_seeder.dart';

class AppDatabase {

  static final AppDatabase _instance = AppDatabase._internal();
  factory AppDatabase() => _instance;
  AppDatabase._internal();
  Database? _db;

  Future<Database> get database async {
    // Si ya tenemos una conexión, la devolvemos
    if (_db != null) return _db!;

    // Si no, inicializamos la BD y guardamos la conexión
    _db = await _initDb();
    return _db!;
  }

  Future<void> resetDatabase() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'mype_finanzas.db');

    // Eliminamos el archivo de la BD
    await deleteDatabase(path);

    // Limpiamos la referencia y volvemos a crear
    _db = null;
    _db = await database;
  }

  Future<Database> _initDb() async {
    final dir = await getApplicationDocumentsDirectory();

    final path = p.join(dir.path, 'mype_finanzas.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,   // Se ejecuta SOLO la primera vez
      onOpen: _onOpen,       // Se ejecuta CADA vez que abrimos la app
    );
  }

  Future<void> _onOpen(Database db) async {
    // Insertamos datos iniciales si no existen
    await DatabaseSeeder.seedAchievements(db);
    await DatabaseSeeder.seedCategoryTemplates(db);
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

    // Índices de usuarios y autenticación
    await db.execute('CREATE INDEX idx_usuarios_email ON usuarios(email)');
    await db.execute('CREATE INDEX idx_sesiones_usuario ON sesiones(usuario_id)');
    await db.execute('CREATE INDEX idx_sesiones_token ON sesiones(token)');
    await db.execute('CREATE INDEX idx_password_reset_tokens_usuario ON password_reset_tokens(usuario_id)');
    await db.execute('CREATE INDEX idx_password_reset_tokens_token ON password_reset_tokens(token)');
    await db.execute('CREATE INDEX idx_password_reset_tokens_email ON password_reset_tokens(email)');

    // Índices de categorías
    await db.execute('CREATE INDEX idx_categorias_usuario ON categorias(usuario_id)');
    await db.execute('CREATE INDEX idx_categorias_tipo ON categorias(tipo)');
    await db.execute('CREATE INDEX idx_categorias_padre ON categorias(categoria_padre_id)');

    // Índices de transacciones (los más importantes por volumen de datos)
    await db.execute('CREATE INDEX idx_transacciones_usuario ON transacciones(usuario_id)');
    await db.execute('CREATE INDEX idx_transacciones_cuenta ON transacciones(cuenta_id)');
    await db.execute('CREATE INDEX idx_transacciones_fecha ON transacciones(fecha)');
    await db.execute('CREATE INDEX idx_transacciones_tipo ON transacciones(tipo)');
    await db.execute('CREATE INDEX idx_transacciones_categoria ON transacciones(categoria_id)');
    await db.execute('CREATE INDEX idx_transacciones_monto ON transacciones(monto)');
    await db.execute('CREATE INDEX idx_transacciones_etiqueta ON transacciones(etiqueta)');

    // Índices de presupuestos
    await db.execute('CREATE INDEX idx_presupuestos_usuario_periodo ON presupuestos(usuario_id, periodo, fecha_inicio)');
    await db.execute('CREATE INDEX idx_presupuestos_categoria_periodo ON presupuestos(categoria_id, periodo, fecha_inicio)');

    // Índices de cuentas
    await db.execute('CREATE INDEX idx_cuentas_usuario ON cuentas(usuario_id)');
    await db.execute('CREATE INDEX idx_accounts_usuario ON accounts(usuario_id)');
    await db.execute('CREATE INDEX idx_budgets_usuario_mes ON budgets(usuario_id, mes, anio)');
    await db.execute('CREATE INDEX idx_budget_periods_usuario ON budget_periods(usuario_id, periodo, mes, anio)');

    // Índices de gamificación
    await db.execute('CREATE INDEX idx_gamification_profiles_usuario ON gamification_profiles(usuario_id)');
    await db.execute('CREATE INDEX idx_gamification_achievements_tipo ON gamification_achievements(tipo)');
    await db.execute('CREATE INDEX idx_gamification_achievements_code ON gamification_achievements(code)');
    await db.execute('CREATE INDEX idx_gamification_events_usuario ON gamification_events(usuario_id)');
    await db.execute('CREATE INDEX idx_gamification_events_fecha ON gamification_events(fecha)');
    await db.execute('CREATE INDEX idx_user_achievements_user ON user_achievements(usuario_id)');
    await db.execute('CREATE INDEX idx_user_achievements_achievement ON user_achievements(achievement_id)');

    final now = DateTime.now().toIso8601String();

    final categoriasDefault = [
      // Ingresos
      {'nombre': 'Salario', 'tipo': 'ingreso', 'icono': 'salary', 'color': '#4CAF50'},
      {'nombre': 'Ventas', 'tipo': 'ingreso', 'icono': 'sales', 'color': '#8BC34A'},
      {'nombre': 'Inversiones', 'tipo': 'ingreso', 'icono': 'investment', 'color': '#2196F3'},
      {'nombre': 'Otros Ingresos', 'tipo': 'ingreso', 'icono': 'other', 'color': '#00BCD4'},
      // Egresos
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

    // Usuario administrador de prueba
    await db.insert('usuarios', {
      'email': 'admin@gmail.com',
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

  /// Crea el usuario admin si no existe
  Future<void> ensureSeedUser() async {
    try {
      final db = await database;
      final count = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM usuarios')
      ) ?? 0;

      if (count == 0) {
        final now = DateTime.now().toIso8601String();

        // Crear usuario admin
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

        // Crear su perfil de gamificación
        final usuarioRow = await db.query(
          'usuarios',
          where: 'email = ?',
          whereArgs: ['admin@mypefinanzas.com'],
          limit: 1,
        );

        if (usuarioRow.isNotEmpty) {
          final usuarioId = usuarioRow.first['id'] as int;
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
        }
      }
    } catch (_) {
    }
  }

  String _hashPassword(String password) {
    return 'hash_$password';
  }

  String getCurrentTimestamp() {
    return DateTime.now().toIso8601String();
  }
}