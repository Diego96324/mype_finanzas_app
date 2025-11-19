class Session {
  final int? id;
  final int usuarioId;
  final String token;
  final String? dispositivo;
  final String? ipAddress;
  final DateTime fechaInicio;
  final DateTime fechaExpiracion;
  final bool activa;
  final DateTime createdAt;

  Session({
    this.id,
    required this.usuarioId,
    required this.token,
    this.dispositivo,
    this.ipAddress,
    required this.fechaInicio,
    required this.fechaExpiracion,
    this.activa = true,
    required this.createdAt,
  });

  bool get isExpired => DateTime.now().isAfter(fechaExpiracion);

  Map<String, dynamic> toMap() => {
        'id': id,
        'usuario_id': usuarioId,
        'token': token,
        'dispositivo': dispositivo,
        'ip_address': ipAddress,
        'fecha_inicio': fechaInicio.toIso8601String(),
        'fecha_expiracion': fechaExpiracion.toIso8601String(),
        'activa': activa ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
      };

  factory Session.fromMap(Map<String, dynamic> map) => Session(
        id: map['id'] as int?,
        usuarioId: map['usuario_id'] as int,
        token: map['token'] as String,
        dispositivo: map['dispositivo'] as String?,
        ipAddress: map['ip_address'] as String?,
        fechaInicio: DateTime.parse(map['fecha_inicio'] as String),
        fechaExpiracion: DateTime.parse(map['fecha_expiracion'] as String),
        activa: (map['activa'] as int) == 1,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}

