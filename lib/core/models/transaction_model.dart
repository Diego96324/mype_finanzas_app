class AppTransaction {
  final int? id;
  final int usuarioId;
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
  final String? frecuenciaRecurrencia;
  final bool sincronizado;
  final DateTime createdAt;
  final DateTime updatedAt;

  AppTransaction({
    this.id,
    required this.usuarioId,
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
    this.frecuenciaRecurrencia,
    this.sincronizado = false,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'usuario_id': usuarioId,
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
        'frecuencia_recurrencia': frecuenciaRecurrencia,
        'sincronizado': sincronizado ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory AppTransaction.fromMap(Map<String, dynamic> map) => AppTransaction(
        id: map['id'] as int?,
        usuarioId: map['usuario_id'] as int,
        categoriaId: map['categoria_id'] as int?,
        tipo: map['tipo'] as String,
        monto: (map['monto'] as num).toDouble(),
        fecha: DateTime.parse(map['fecha'] as String),
        etiqueta: map['etiqueta'] as String?,
        nota: map['nota'] as String?,
        descripcion: map['descripcion'] as String?,
        comprobanteUri: map['comprobante_uri'] as String?,
        ubicacion: map['ubicacion'] as String?,
        recurrente: (map['recurrente'] as int) == 1,
        frecuenciaRecurrencia: map['frecuencia_recurrencia'] as String?,
        sincronizado: (map['sincronizado'] as int) == 1,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );

  AppTransaction copyWith({
    int? id,
    int? usuarioId,
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
    String? frecuenciaRecurrencia,
    bool? sincronizado,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AppTransaction(
      id: id ?? this.id,
      usuarioId: usuarioId ?? this.usuarioId,
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
      frecuenciaRecurrencia: frecuenciaRecurrencia ?? this.frecuenciaRecurrencia,
      sincronizado: sincronizado ?? this.sincronizado,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
