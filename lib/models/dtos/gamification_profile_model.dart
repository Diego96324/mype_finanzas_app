class GamificationProfile {
  final int usuarioId;
  final int puntos;
  final int nivel;
  final int rachaActual;
  final int rachaMaxima;
  final DateTime? ultimaFechaEvento;
  final DateTime createdAt;
  final DateTime updatedAt;

  GamificationProfile({
    required this.usuarioId,
    this.puntos = 0,
    this.nivel = 1,
    this.rachaActual = 0,
    this.rachaMaxima = 0,
    this.ultimaFechaEvento,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'usuario_id': usuarioId,
        'puntos': puntos,
        'nivel': nivel,
        'racha_actual': rachaActual,
        'racha_maxima': rachaMaxima,
        'ultima_fecha_evento': ultimaFechaEvento?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory GamificationProfile.fromMap(Map<String, dynamic> map) => GamificationProfile(
        usuarioId: map['usuario_id'] as int,
        puntos: (map['puntos'] as num?)?.toInt() ?? 0,
        nivel: (map['nivel'] as num?)?.toInt() ?? 1,
        rachaActual: (map['racha_actual'] as num?)?.toInt() ?? 0,
        rachaMaxima: (map['racha_maxima'] as num?)?.toInt() ?? 0,
        ultimaFechaEvento: (map['ultima_fecha_evento'] as String?) != null ? DateTime.parse(map['ultima_fecha_evento'] as String) : null,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );

  // JSON-friendly aliases
  Map<String, dynamic> toJson() => toMap();
  factory GamificationProfile.fromJson(Map<String, dynamic> json) => GamificationProfile.fromMap(json);

  GamificationProfile copyWith({
    int? puntos,
    int? nivel,
    int? rachaActual,
    int? rachaMaxima,
    DateTime? ultimaFechaEvento,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return GamificationProfile(
      usuarioId: usuarioId,
      puntos: puntos ?? this.puntos,
      nivel: nivel ?? this.nivel,
      rachaActual: rachaActual ?? this.rachaActual,
      rachaMaxima: rachaMaxima ?? this.rachaMaxima,
      ultimaFechaEvento: ultimaFechaEvento ?? this.ultimaFechaEvento,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
