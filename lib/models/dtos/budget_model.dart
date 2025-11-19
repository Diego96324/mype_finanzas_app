class Budget {
  final int? id;
  final int usuarioId;
  final double monto;
  final int mes;
  final int anio;
  final DateTime fechaCreacion;

  Budget({
    this.id,
    required this.usuarioId,
    required this.monto,
    required this.mes,
    required this.anio,
    DateTime? fechaCreacion,
  }) : fechaCreacion = fechaCreacion ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'usuario_id': usuarioId,
      'monto': monto,
      'mes': mes,
      'anio': anio,
      'fecha_creacion': fechaCreacion.toIso8601String(),
    };
  }

  factory Budget.fromMap(Map<String, dynamic> map) {
    return Budget(
      id: map['id'],
      usuarioId: map['usuario_id'],
      monto: map['monto'],
      mes: map['mes'],
      anio: map['anio'],
      fechaCreacion: DateTime.parse(map['fecha_creacion']),
    );
  }
}

