// Entidad pura de dominio para transacciones
class TransactionEntity {
  final int? id;
  final int usuarioId;
  final int? cuentaId;
  final int? cuentaDestinoId;
  final int? categoriaId;
  final String tipo; // ingreso | egreso | transferencia
  final double monto;
  final DateTime fecha;
  final String? etiqueta; // etiquetas libres (una por ahora)
  final String? nota;     // notas libres multilinea
  final String? descripcion;
  final bool confirmada;
  final bool esAperturaCuenta;

  // Recurrencia
  final bool esRecurrente; // marca si esta instancia fue generada por una recurrencia
  final String? frecuenciaRecurrencia; // semanal | quincenal | mensual | personalizada
  final int? recurrenceIntervalDays; // solo si personalizada
  final DateTime? recurrenceEndDate; // fin de la serie
  final DateTime? nextOccurrence; // próxima instancia a generar

  const TransactionEntity({
    this.id,
    required this.usuarioId,
    this.cuentaId,
    this.cuentaDestinoId,
    this.categoriaId,
    required this.tipo,
    required this.monto,
    required this.fecha,
    this.etiqueta,
    this.nota,
    this.descripcion,
    this.confirmada = true,
    this.esAperturaCuenta = false,
    this.esRecurrente = false,
    this.frecuenciaRecurrencia,
    this.recurrenceIntervalDays,
    this.recurrenceEndDate,
    this.nextOccurrence,
  });

  TransactionEntity copyWith({
    int? id,
    int? usuarioId,
    int? cuentaId,
    int? cuentaDestinoId,
    int? categoriaId,
    String? tipo,
    double? monto,
    DateTime? fecha,
    String? etiqueta,
    String? nota,
    String? descripcion,
    bool? confirmada,
    bool? esAperturaCuenta,
    bool? esRecurrente,
    String? frecuenciaRecurrencia,
    int? recurrenceIntervalDays,
    DateTime? recurrenceEndDate,
    DateTime? nextOccurrence,
  }) {
    return TransactionEntity(
      id: id ?? this.id,
      usuarioId: usuarioId ?? this.usuarioId,
      cuentaId: cuentaId ?? this.cuentaId,
      cuentaDestinoId: cuentaDestinoId ?? this.cuentaDestinoId,
      categoriaId: categoriaId ?? this.categoriaId,
      tipo: tipo ?? this.tipo,
      monto: monto ?? this.monto,
      fecha: fecha ?? this.fecha,
      etiqueta: etiqueta ?? this.etiqueta,
      nota: nota ?? this.nota,
      descripcion: descripcion ?? this.descripcion,
      confirmada: confirmada ?? this.confirmada,
      esAperturaCuenta: esAperturaCuenta ?? this.esAperturaCuenta,
      esRecurrente: esRecurrente ?? this.esRecurrente,
      frecuenciaRecurrencia: frecuenciaRecurrencia ?? this.frecuenciaRecurrencia,
      recurrenceIntervalDays: recurrenceIntervalDays ?? this.recurrenceIntervalDays,
      recurrenceEndDate: recurrenceEndDate ?? this.recurrenceEndDate,
      nextOccurrence: nextOccurrence ?? this.nextOccurrence,
    );
  }

  bool get tieneRecurrencia => frecuenciaRecurrencia != null;

  DateTime? calcularProximaOcurrencia() {
    if (frecuenciaRecurrencia == null) return null;
    final base = nextOccurrence ?? fecha;
    switch (frecuenciaRecurrencia) {
      case 'semanal':
        return base.add(const Duration(days: 7));
      case 'quincenal':
        return base.add(const Duration(days: 15));
      case 'mensual':
        return DateTime(base.year, base.month + 1, base.day, base.hour, base.minute, base.second);
      case 'personalizada':
        final interval = recurrenceIntervalDays ?? 0;
        if (interval <= 0) return null;
        return base.add(Duration(days: interval));
      default:
        return null;
    }
  }

  bool get recurrenciaActiva {
    if (!tieneRecurrencia) return false;
    if (recurrenceEndDate != null) {
      return DateTime.now().isBefore(recurrenceEndDate!) || DateTime.now().isAtSameMomentAs(recurrenceEndDate!);
    }
    return true; // sin fecha fin => activa
  }
}

