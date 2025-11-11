class GamificationEvent {
  final int? id;
  final int? usuarioId;
  final String tipoEvento;
  final String? descripcion;
  final int puntosOtorgados;
  final DateTime fechaEvento;
  final DateTime createdAt;

  GamificationEvent({
    this.id,
    this.usuarioId,
    required this.tipoEvento,
    this.descripcion,
    this.puntosOtorgados = 0,
    required this.fechaEvento,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'usuario_id': usuarioId,
        'tipo_evento': tipoEvento,
        'descripcion': descripcion,
        'puntos_otorgados': puntosOtorgados,
        'fecha_evento': fechaEvento.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      };

  factory GamificationEvent.fromMap(Map<String, dynamic> map) => GamificationEvent(
        id: map['id'] as int?,
        usuarioId: map['usuario_id'] as int?,
        tipoEvento: map['tipo_evento'] as String,
        descripcion: map['descripcion'] as String?,
        puntosOtorgados: (map['puntos_otorgados'] as num?)?.toInt() ?? 0,
        fechaEvento: DateTime.parse(map['fecha_evento'] as String),
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  // JSON-friendly aliases
  Map<String, dynamic> toJson() => toMap();
  factory GamificationEvent.fromJson(Map<String, dynamic> json) => GamificationEvent.fromMap(json);

  GamificationEvent copyWith({
    int? id,
    int? usuarioId,
    String? tipoEvento,
    String? descripcion,
    int? puntosOtorgados,
    DateTime? fechaEvento,
    DateTime? createdAt,
  }) {
    return GamificationEvent(
      id: id ?? this.id,
      usuarioId: usuarioId ?? this.usuarioId,
      tipoEvento: tipoEvento ?? this.tipoEvento,
      descripcion: descripcion ?? this.descripcion,
      puntosOtorgados: puntosOtorgados ?? this.puntosOtorgados,
      fechaEvento: fechaEvento ?? this.fechaEvento,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

