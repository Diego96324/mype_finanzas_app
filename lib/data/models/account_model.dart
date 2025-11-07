class Account {
  final int? id;
  final int usuarioId;
  final String nombre;
  final String tipo; // efectivo, debito, credito, virtual, inversion, por_cobrar, por_pagar
  final String moneda; // PEN, USD, EUR
  final double saldo;
  final String? institucion;
  final String? nota;
  final DateTime fechaCreacion;
  final DateTime? fechaActualizacion;
  final bool activa;

  Account({
    this.id,
    required this.usuarioId,
    required this.nombre,
    required this.tipo,
    required this.moneda,
    required this.saldo,
    this.institucion,
    this.nota,
    DateTime? fechaCreacion,
    this.fechaActualizacion,
    this.activa = true,
  }) : fechaCreacion = fechaCreacion ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'usuario_id': usuarioId,
      'nombre': nombre,
      'tipo': tipo,
      'moneda': moneda,
      'saldo': saldo,
      'institucion': institucion,
      'nota': nota,
      'fecha_creacion': fechaCreacion.toIso8601String(),
      'fecha_actualizacion': fechaActualizacion?.toIso8601String(),
      'activa': activa ? 1 : 0,
    };
  }

  factory Account.fromMap(Map<String, dynamic> map) {
    return Account(
      id: map['id'],
      usuarioId: map['usuario_id'],
      nombre: map['nombre'],
      tipo: map['tipo'],
      moneda: map['moneda'],
      saldo: (map['saldo'] as num).toDouble(),
      institucion: map['institucion'],
      nota: map['nota'],
      fechaCreacion: DateTime.parse(map['fecha_creacion']),
      fechaActualizacion: map['fecha_actualizacion'] != null
          ? DateTime.parse(map['fecha_actualizacion'])
          : null,
      activa: map['activa'] == 1,
    );
  }

  Account copyWith({
    int? id,
    int? usuarioId,
    String? nombre,
    String? tipo,
    String? moneda,
    double? saldo,
    String? institucion,
    String? nota,
    DateTime? fechaCreacion,
    DateTime? fechaActualizacion,
    bool? activa,
  }) {
    return Account(
      id: id ?? this.id,
      usuarioId: usuarioId ?? this.usuarioId,
      nombre: nombre ?? this.nombre,
      tipo: tipo ?? this.tipo,
      moneda: moneda ?? this.moneda,
      saldo: saldo ?? this.saldo,
      institucion: institucion ?? this.institucion,
      nota: nota ?? this.nota,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      fechaActualizacion: fechaActualizacion ?? this.fechaActualizacion,
      activa: activa ?? this.activa,
    );
  }

  bool get isPasivo => tipo == 'credito' || tipo == 'por_pagar';
  bool get isActivo => !isPasivo;

  String get tipoDisplay {
    final tipos = {
      'efectivo': 'Efectivo',
      'debito': 'Débito',
      'credito': 'Crédito',
      'virtual': 'Virtual',
      'inversion': 'Inversión',
      'por_cobrar': 'Por Cobrar',
      'por_pagar': 'Por Pagar',
    };
    return tipos[tipo] ?? tipo;
  }
}

