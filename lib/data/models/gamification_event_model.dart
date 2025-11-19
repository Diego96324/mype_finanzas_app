/// Modelo que representa un evento de gamificación en el historial.
/// 
/// Registra cada acción que otorga puntos al usuario.
class GamificationEvent {
  final int? id;
  final int usuarioId;
  final String tipoEvento;
  final String? descripcion;
  final int puntosOtorgados;
  final DateTime fecha;
  final DateTime createdAt;

  GamificationEvent({
    this.id,
    required this.usuarioId,
    required this.tipoEvento,
    this.descripcion,
    this.puntosOtorgados = 0,
    required this.fecha,
    required this.createdAt,
  });

  // =========================================================================
  // Serialización
  // =========================================================================

  Map<String, dynamic> toMap() => {
    'id': id,
    'usuario_id': usuarioId,
    'tipo_evento': tipoEvento,
    'descripcion': descripcion,
    'puntos_otorgados': puntosOtorgados,
    'fecha': fecha.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
  };

  factory GamificationEvent.fromMap(Map<String, dynamic> map) => GamificationEvent(
    id: map['id'] as int?,
    usuarioId: map['usuario_id'] as int,
    tipoEvento: map['tipo_evento'] as String,
    descripcion: map['descripcion'] as String?,
    puntosOtorgados: (map['puntos_otorgados'] as num?)?.toInt() ?? 0,
    fecha: DateTime.parse(map['fecha'] as String),
    createdAt: DateTime.parse(map['created_at'] as String),
  );

  // JSON-friendly aliases
  Map<String, dynamic> toJson() => toMap();
  factory GamificationEvent.fromJson(Map<String, dynamic> json) => GamificationEvent.fromMap(json);

  // =========================================================================
  // copyWith
  // =========================================================================

  GamificationEvent copyWith({
    int? id,
    int? usuarioId,
    String? tipoEvento,
    String? descripcion,
    int? puntosOtorgados,
    DateTime? fecha,
    DateTime? createdAt,
  }) {
    return GamificationEvent(
      id: id ?? this.id,
      usuarioId: usuarioId ?? this.usuarioId,
      tipoEvento: tipoEvento ?? this.tipoEvento,
      descripcion: descripcion ?? this.descripcion,
      puntosOtorgados: puntosOtorgados ?? this.puntosOtorgados,
      fecha: fecha ?? this.fecha,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // =========================================================================
  // Debugging & Equality
  // =========================================================================

  @override
  String toString() =>
      'GamificationEvent(id: $id, oderId: $usuarioId, tipo: $tipoEvento, '
          'puntos: $puntosOtorgados, fecha: $fecha)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is GamificationEvent &&
              runtimeType == other.runtimeType &&
              id == other.id;

  @override
  int get hashCode => id.hashCode;
}