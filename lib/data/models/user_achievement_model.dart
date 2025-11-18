class UserAchievement {
  final int? id;
  final int usuarioId;
  final int achievementId;
  final double progresoActual;
  final String estado; // locked|unlocked|in_progress
  final DateTime? ultimaActualizacion;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserAchievement({
    this.id,
    required this.usuarioId,
    required this.achievementId,
    this.progresoActual = 0,
    this.estado = 'locked',
    this.ultimaActualizacion,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'usuario_id': usuarioId,
        'achievement_id': achievementId,
        'progreso_actual': progresoActual,
        'estado': estado,
        'ultima_actualizacion': ultimaActualizacion?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory UserAchievement.fromMap(Map<String, dynamic> map) => UserAchievement(
        id: map['id'] as int?,
        usuarioId: map['usuario_id'] as int,
        achievementId: map['achievement_id'] as int,
        progresoActual: (map['progreso_actual'] as num?)?.toDouble() ?? 0,
        estado: map['estado'] as String? ?? 'locked',
        ultimaActualizacion: (map['ultima_actualizacion'] as String?) != null ? DateTime.parse(map['ultima_actualizacion'] as String) : null,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );

  Map<String, dynamic> toJson() => toMap();
  factory UserAchievement.fromJson(Map<String, dynamic> json) => UserAchievement.fromMap(json);

  UserAchievement copyWith({
    int? id,
    int? usuarioId,
    int? achievementId,
    double? progresoActual,
    String? estado,
    DateTime? ultimaActualizacion,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserAchievement(
      id: id ?? this.id,
      usuarioId: usuarioId ?? this.usuarioId,
      achievementId: achievementId ?? this.achievementId,
      progresoActual: progresoActual ?? this.progresoActual,
      estado: estado ?? this.estado,
      ultimaActualizacion: ultimaActualizacion ?? this.ultimaActualizacion,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

