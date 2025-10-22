import 'dart:async';
import 'package:path/path.dart';
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

  // Solo para desarrollo, borra todo
  Future<void> resetDatabase() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = join(dir.path, 'mype_finanzas.db');
    await deleteDatabase(path);
    _db = null;
    _db = await database;
  }

  Future<Database> _initDb() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = join(dir.path, 'mype_finanzas.db');
    return openDatabase(
      path,
      version: 2,
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
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY(usuario_id) REFERENCES usuarios(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE transacciones(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        usuario_id INTEGER NOT NULL,
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
        frecuencia_recurrencia TEXT,
        sincronizado INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY(usuario_id) REFERENCES usuarios(id) ON DELETE CASCADE,
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

    // Indices pa' que las queries vuelen
    await db.execute('CREATE INDEX idx_usuarios_email ON usuarios(email)');
    await db.execute('CREATE INDEX idx_sesiones_usuario ON sesiones(usuario_id)');
    await db.execute('CREATE INDEX idx_sesiones_token ON sesiones(token)');
    await db.execute('CREATE INDEX idx_categorias_usuario ON categorias(usuario_id)');
    await db.execute('CREATE INDEX idx_transacciones_usuario ON transacciones(usuario_id)');
    await db.execute('CREATE INDEX idx_transacciones_fecha ON transacciones(fecha)');
    await db.execute('CREATE INDEX idx_transacciones_tipo ON transacciones(tipo)');
    await db.execute('CREATE INDEX idx_presupuestos_usuario ON presupuestos(usuario_id)');
    await db.execute('CREATE INDEX idx_metas_usuario ON metas_financieras(usuario_id)');

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
        'created_at': now,
        'updated_at': now,
      });
    }

    // Usuario de prueba - eliminar en producción
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
        print('Error en migración: $e');
        await _onCreate(db, newVersion);
      }
    }
  }

  // TODO: cambiar esto por bcrypt o argon2 en producción
  String _hashPassword(String password) {
    return 'hash_$password';
  }

  String getCurrentTimestamp() {
    return DateTime.now().toIso8601String();
  }
}
