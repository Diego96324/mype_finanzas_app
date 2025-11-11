class GamificationAchievement {
  final int? id;
  final String tipo;
  final String nombre;
  final String? descripcion;
  final double progresoActual;
  final double progresoObjetivo;
  final String estado; // locked|unlocked|in_progress
  final DateTime? ultimaActualizacion;
  final DateTime createdAt;
  final DateTime updatedAt;

  GamificationAchievement({
    this.id,
    required this.tipo,
    required this.nombre,
    this.descripcion,
    this.progresoActual = 0,
    this.progresoObjetivo = 1,
    this.estado = 'locked',
    this.ultimaActualizacion,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'tipo': tipo,
        'nombre': nombre,
        'descripcion': descripcion,
        'progreso_actual': progresoActual,
        'progreso_objetivo': progresoObjetivo,
        'estado': estado,
        'ultima_actualizacion': ultimaActualizacion?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory GamificationAchievement.fromMap(Map<String, dynamic> map) => GamificationAchievement(
        id: map['id'] as int?,
        tipo: map['tipo'] as String,
        nombre: map['nombre'] as String,
        descripcion: map['descripcion'] as String?,
        progresoActual: (map['progreso_actual'] as num?)?.toDouble() ?? 0,
        progresoObjetivo: (map['progreso_objetivo'] as num?)?.toDouble() ?? 1,
        estado: map['estado'] as String? ?? 'locked',
        ultimaActualizacion: (map['ultima_actualizacion'] as String?) != null ? DateTime.parse(map['ultima_actualizacion'] as String) : null,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );

  // JSON-friendly aliases
  Map<String, dynamic> toJson() => toMap();
  factory GamificationAchievement.fromJson(Map<String, dynamic> json) => GamificationAchievement.fromMap(json);

  GamificationAchievement copyWith({
    int? id,
    String? tipo,
    String? nombre,
    String? descripcion,
    double? progresoActual,
    double? progresoObjetivo,
    String? estado,
    DateTime? ultimaActualizacion,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return GamificationAchievement(
      id: id ?? this.id,
      tipo: tipo ?? this.tipo,
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
      progresoActual: progresoActual ?? this.progresoActual,
      progresoObjetivo: progresoObjetivo ?? this.progresoObjetivo,
      estado: estado ?? this.estado,
      ultimaActualizacion: ultimaActualizacion ?? this.ultimaActualizacion,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

