// Sentinel to detect omitted parameters in copyWith
const _noValue = Object();

class AppTransaction {
  final int? id;
  final int usuarioId;
  final int? cuentaId;
  final int? cuentaDestinoId;
  final int? categoriaId;
  final String tipo;
  final double monto;
  final DateTime fecha;
  final String? etiqueta;
  final String? nota;
  final String? descripcion;
  final String? comprobanteUri;
  final String? ubicacion;
  final bool recurrente;
  final bool esRecurrente;
  final bool esAperturaCuenta;
  final bool confirmada;
  final String? frecuenciaRecurrencia;
  final int? recurrenceIntervalDays; // intervalo personalizado en días
  final DateTime? recurrenceEndDate; // fecha fin de recurrencia
  final DateTime? nextOccurrence;    // próxima generación programada
  final bool sincronizado;
  final bool afectaSaldo; // si esta transacción afecta los totales (ej: tarjetas crédito y cuentas por pagar/cobrar NO afectan)
  final DateTime createdAt;
  final DateTime updatedAt;

  AppTransaction({
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
    this.comprobanteUri,
    this.ubicacion,
    this.recurrente = false,
    this.esRecurrente = false,
    this.esAperturaCuenta = false,
    this.confirmada = true,
    this.frecuenciaRecurrencia,
    this.recurrenceIntervalDays,
    this.recurrenceEndDate,
    this.nextOccurrence,
    this.sincronizado = false,
    this.afectaSaldo = true,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'usuario_id': usuarioId,
        'cuenta_id': cuentaId,
        'cuenta_destino_id': cuentaDestinoId,
        'categoria_id': categoriaId,
        'tipo': tipo,
        'monto': monto,
        'fecha': fecha.toIso8601String(),
        'etiqueta': etiqueta,
        'nota': nota,
        'descripcion': descripcion,
        'comprobante_uri': comprobanteUri,
        'ubicacion': ubicacion,
        'recurrente': recurrente ? 1 : 0,
        'es_recurrente': esRecurrente ? 1 : 0,
        'es_apertura_cuenta': esAperturaCuenta ? 1 : 0,
        'confirmada': confirmada ? 1 : 0,
        'afecta_saldo': afectaSaldo ? 1 : 0,
        'frecuencia_recurrencia': frecuenciaRecurrencia,
        'recurrence_interval_days': recurrenceIntervalDays,
        'recurrence_end_date': recurrenceEndDate?.toIso8601String(),
        'next_occurrence': nextOccurrence?.toIso8601String(),
        'sincronizado': sincronizado ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory AppTransaction.fromMap(Map<String, dynamic> map) => AppTransaction(
        id: map['id'] as int?,
        usuarioId: map['usuario_id'] as int,
        cuentaId: map['cuenta_id'] as int?,
        cuentaDestinoId: map['cuenta_destino_id'] as int?,
        categoriaId: map['categoria_id'] as int?,
        tipo: map['tipo'] as String,
        monto: (map['monto'] as num).toDouble(),
        fecha: DateTime.parse(map['fecha'] as String),
        etiqueta: map['etiqueta'] as String?,
        nota: map['nota'] as String?,
        descripcion: map['descripcion'] as String?,
        comprobanteUri: map['comprobante_uri'] as String?,
        ubicacion: map['ubicacion'] as String?,
        recurrente: (map['recurrente'] as int?) == 1,
        esRecurrente: (map['es_recurrente'] as int?) == 1,
        esAperturaCuenta: (map['es_apertura_cuenta'] as int?) == 1,
        confirmada: (map['confirmada'] as int?) == 1,
        afectaSaldo: (map['afecta_saldo'] as int?) == 1 || map['afecta_saldo'] == null,
        frecuenciaRecurrencia: map['frecuencia_recurrencia'] as String?,
        recurrenceIntervalDays: map['recurrence_interval_days'] as int?,
        recurrenceEndDate: (map['recurrence_end_date'] as String?) != null ? DateTime.parse(map['recurrence_end_date'] as String) : null,
        nextOccurrence: (map['next_occurrence'] as String?) != null ? DateTime.parse(map['next_occurrence'] as String) : null,
        sincronizado: (map['sincronizado'] as int?) == 1,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );

  AppTransaction copyWith({
    Object? id = _noValue,
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
    String? comprobanteUri,
    String? ubicacion,
    bool? recurrente,
    bool? esRecurrente,
    bool? esAperturaCuenta,
    bool? confirmada,
    String? frecuenciaRecurrencia,
    int? recurrenceIntervalDays,
    DateTime? recurrenceEndDate,
    DateTime? nextOccurrence,
    bool? sincronizado,
    bool? afectaSaldo,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AppTransaction(
      id: identical(id, _noValue) ? this.id : id as int?,
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
      comprobanteUri: comprobanteUri ?? this.comprobanteUri,
      ubicacion: ubicacion ?? this.ubicacion,
      recurrente: recurrente ?? this.recurrente,
      esRecurrente: esRecurrente ?? this.esRecurrente,
      esAperturaCuenta: esAperturaCuenta ?? this.esAperturaCuenta,
      confirmada: confirmada ?? this.confirmada,
      frecuenciaRecurrencia: frecuenciaRecurrencia ?? this.frecuenciaRecurrencia,
      recurrenceIntervalDays: recurrenceIntervalDays ?? this.recurrenceIntervalDays,
      recurrenceEndDate: recurrenceEndDate ?? this.recurrenceEndDate,
      nextOccurrence: nextOccurrence ?? this.nextOccurrence,
      sincronizado: sincronizado ?? this.sincronizado,
      afectaSaldo: afectaSaldo ?? this.afectaSaldo,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
