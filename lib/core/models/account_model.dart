class Account {
  final int? id;
  final int usuarioId;
  final String nombre;
  final String tipo; // efectivo, debito, credito, virtual, inversion, por_cobrar, por_pagar
  final String moneda; // PEN, USD, EUR
  final double saldo;
  final String? nota;
  final DateTime fechaCreacion;

  Account({
    this.id,
    required this.usuarioId,
    required this.nombre,
    required this.tipo,
    required this.moneda,
    required this.saldo,
    this.nota,
    DateTime? fechaCreacion,
  }) : fechaCreacion = fechaCreacion ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'usuario_id': usuarioId,
      'nombre': nombre,
      'tipo': tipo,
      'moneda': moneda,
      'saldo': saldo,
      'nota': nota,
      'fecha_creacion': fechaCreacion.toIso8601String(),
    };
  }

  factory Account.fromMap(Map<String, dynamic> map) {
    return Account(
      id: map['id'],
      usuarioId: map['usuario_id'],
      nombre: map['nombre'],
      tipo: map['tipo'],
      moneda: map['moneda'],
      saldo: map['saldo'],
      nota: map['nota'],
      fechaCreacion: DateTime.parse(map['fecha_creacion']),
    );
  }

  bool get isPasivo => tipo == 'credito' || tipo == 'por_pagar';
}

