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

  Future<Database> _initDb() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = join(dir.path, 'mype_finanzas.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE categoria(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            nombre TEXT NOT NULL,
            tipo TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE transaccion(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            fecha TEXT NOT NULL,
            tipo TEXT NOT NULL,
            monto REAL NOT NULL,
            categoria_id INTEGER,
            etiqueta TEXT,
            nota TEXT,
            comprobante_uri TEXT,
            FOREIGN KEY(categoria_id) REFERENCES categoria(id)
          )
        ''');

        await db.insert('categoria', {'nombre': 'Ventas', 'tipo': 'ingreso'});
        await db.insert('categoria', {'nombre': 'Compras', 'tipo': 'egreso'});
        await db.insert('categoria', {'nombre': 'Servicios', 'tipo': 'egreso'});
      },
    );
  }
}
