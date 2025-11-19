/// Modelo que representa un logro disponible en el catálogo de gamificación.
/// 
/// Esta tabla define los logros que pueden ser desbloqueados.
/// El progreso del usuario se guarda en [UserAchievement].
class GamificationAchievement {
  final int? id;
  final String code;
  final String nombre;
  final String? descripcion;
  final int puntos;
  final double progresoObjetivo;
  final String tipo;
  final String iconName;
  final DateTime createdAt;
  final DateTime updatedAt;

  GamificationAchievement({
    this.id,
    required this.code,
    required this.nombre,
    this.descripcion,
    this.puntos = 0,
    this.progresoObjetivo = 1,
    required this.tipo,
    this.iconName = 'emoji_events',
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'code': code,
    'nombre': nombre,
    'descripcion': descripcion,
    'puntos': puntos,
    'progreso_objetivo': progresoObjetivo,
    'tipo': tipo,
    'icon_name': iconName,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  factory GamificationAchievement.fromMap(Map<String, dynamic> map) => GamificationAchievement(
    id: map['id'] as int?,
    code: map['code'] as String? ?? 'UNKNOWN',
    nombre: map['nombre'] as String,
    descripcion: map['descripcion'] as String?,
    puntos: (map['puntos'] as num?)?.toInt() ?? 0,
    progresoObjetivo: (map['progreso_objetivo'] as num?)?.toDouble() ?? 1,
    tipo: map['tipo'] as String,
    iconName: map['icon_name'] as String? ?? 'emoji_events',
    createdAt: DateTime.parse(map['created_at'] as String),
    updatedAt: DateTime.parse(map['updated_at'] as String),
  );

  // JSON-friendly aliases
  Map<String, dynamic> toJson() => toMap();
  factory GamificationAchievement.fromJson(Map<String, dynamic> json) => GamificationAchievement.fromMap(json);

  GamificationAchievement copyWith({
    int? id,
    String? code,
    String? nombre,
    String? descripcion,
    int? puntos,
    double? progresoObjetivo,
    String? tipo,
    String? iconName,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return GamificationAchievement(
      id: id ?? this.id,
      code: code ?? this.code,
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
      puntos: puntos ?? this.puntos,
      progresoObjetivo: progresoObjetivo ?? this.progresoObjetivo,
      tipo: tipo ?? this.tipo,
      iconName: iconName ?? this.iconName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() => 'GamificationAchievement(id: $id, code: $code, nombre: $nombre, puntos: $puntos)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is GamificationAchievement &&
              runtimeType == other.runtimeType &&
              id == other.id &&
              code == other.code;

  @override
  int get hashCode => id.hashCode ^ code.hashCode;
}