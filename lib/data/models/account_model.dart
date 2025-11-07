class Account {
  final int? id;
  final int usuarioId;
  final String nombre;
  final String tipo; // efectivo, banco, tarjeta_credito, tarjeta_debito, ahorros, inversion
  final double saldo;
  final double saldoInicial;
  final String? numeroFin; // últimos 4 dígitos
  final String? institucion;
  final String moneda;
  final String color;
  final String icono;
  final bool activa;
  final bool incluirEnTotal;
  final int orden;
  final DateTime createdAt;
  final DateTime updatedAt;

  Account({
    this.id,
    required this.usuarioId,
    required this.nombre,
    required this.tipo,
    required this.saldo,
    required this.saldoInicial,
    this.numeroFin,
    this.institucion,
    this.moneda = 'PEN',
    required this.color,
    required this.icono,
    this.activa = true,
    this.incluirEnTotal = true,
    this.orden = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Account.fromMap(Map<String, dynamic> map) {
    return Account(
      id: map['id'] as int?,
      usuarioId: map['usuario_id'] as int,
      nombre: map['nombre'] as String,
      tipo: map['tipo'] as String,
      saldo: (map['saldo'] as num).toDouble(),
      saldoInicial: (map['saldo_inicial'] as num).toDouble(),
      numeroFin: map['numero_fin'] as String?,
      institucion: map['institucion'] as String?,
      moneda: map['moneda'] as String? ?? 'PEN',
      color: map['color'] as String,
      icono: map['icono'] as String,
      activa: (map['activa'] as int) == 1,
      incluirEnTotal: (map['incluir_en_total'] as int) == 1,
      orden: map['orden'] as int? ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'usuario_id': usuarioId,
      'nombre': nombre,
      'tipo': tipo,
      'saldo': saldo,
      'saldo_inicial': saldoInicial,
      'numero_fin': numeroFin,
      'institucion': institucion,
      'moneda': moneda,
      'color': color,
      'icono': icono,
      'activa': activa ? 1 : 0,
      'incluir_en_total': incluirEnTotal ? 1 : 0,
      'orden': orden,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Account copyWith({
    int? id,
    int? usuarioId,
    String? nombre,
    String? tipo,
    double? saldo,
    double? saldoInicial,
    String? numeroFin,
    String? institucion,
    String? moneda,
    String? color,
    String? icono,
    bool? activa,
    bool? incluirEnTotal,
    int? orden,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Account(
      id: id ?? this.id,
      usuarioId: usuarioId ?? this.usuarioId,
      nombre: nombre ?? this.nombre,
      tipo: tipo ?? this.tipo,
      saldo: saldo ?? this.saldo,
      saldoInicial: saldoInicial ?? this.saldoInicial,
      numeroFin: numeroFin ?? this.numeroFin,
      institucion: institucion ?? this.institucion,
      moneda: moneda ?? this.moneda,
      color: color ?? this.color,
      icono: icono ?? this.icono,
      activa: activa ?? this.activa,
      incluirEnTotal: incluirEnTotal ?? this.incluirEnTotal,
      orden: orden ?? this.orden,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Helpers útiles
  String get tipoDisplay {
    switch (tipo) {
      case 'efectivo':
        return 'Efectivo';
      case 'banco':
        return 'Cuenta Bancaria';
      case 'debito':
      case 'tarjeta_debito':
        return 'Tarjeta de Débito';
      case 'credito':
      case 'tarjeta_credito':
        return 'Tarjeta de Crédito';
      case 'virtual':
        return 'Billetera Virtual';
      case 'ahorros':
        return 'Ahorros';
      case 'inversion':
        return 'Inversión';
      case 'por_cobrar':
        return 'Por Cobrar';
      case 'por_pagar':
        return 'Por Pagar';
      default:
        return 'Otra';
    }
  }

  String get saldoFormateado {
    final simbolo = moneda == 'PEN' ? 'S/' :
    moneda == 'USD' ? '\$' : moneda;
    return '$simbolo ${saldo.toStringAsFixed(2)}';
  }

  String? get numeroEnmascarado {
    if (numeroFin == null) return null;
    return '•••• $numeroFin';
  }

  bool get isPasivo {
    return tipo == 'credito' || tipo == 'tarjeta_credito' || tipo == 'por_pagar';
  }

  @override
  String toString() {
    return 'Account(id: $id, nombre: $nombre, tipo: $tipo, saldo: $saldo)';
  }
}