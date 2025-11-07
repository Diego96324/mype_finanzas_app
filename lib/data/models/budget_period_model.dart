/// Modelo para representar un presupuesto con período específico
class BudgetPeriod {
  final int? id;
  final int usuarioId;
  final double monto;
  final String periodo; // 'mensual', 'trimestral', 'anual'
  final int mes;
  final int anio;

  BudgetPeriod({
    this.id,
    required this.usuarioId,
    required this.monto,
    required this.periodo,
    required this.mes,
    required this.anio,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'usuario_id': usuarioId,
      'monto': monto,
      'periodo': periodo,
      'mes': mes,
      'anio': anio,
    };
  }

  factory BudgetPeriod.fromMap(Map<String, dynamic> map) {
    return BudgetPeriod(
      id: map['id'],
      usuarioId: map['usuario_id'],
      monto: map['monto'],
      periodo: map['periodo'],
      mes: map['mes'],
      anio: map['anio'],
    );
  }

  BudgetPeriod copyWith({
    int? id,
    int? usuarioId,
    double? monto,
    String? periodo,
    int? mes,
    int? anio,
  }) {
    return BudgetPeriod(
      id: id ?? this.id,
      usuarioId: usuarioId ?? this.usuarioId,
      monto: monto ?? this.monto,
      periodo: periodo ?? this.periodo,
      mes: mes ?? this.mes,
      anio: anio ?? this.anio,
    );
  }
}

