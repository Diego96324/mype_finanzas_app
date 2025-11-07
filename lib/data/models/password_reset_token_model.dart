class PasswordResetToken {
  final int? id;
  final int usuarioId;
  final String email;
  final String token;
  final DateTime fechaCreacion;
  final DateTime fechaExpiracion;
  final bool usado;
  final String? ipAddress;

  PasswordResetToken({
    this.id,
    required this.usuarioId,
    required this.email,
    required this.token,
    required this.fechaCreacion,
    required this.fechaExpiracion,
    this.usado = false,
    this.ipAddress,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'usuario_id': usuarioId,
        'email': email,
        'token': token,
        'fecha_creacion': fechaCreacion.toIso8601String(),
        'fecha_expiracion': fechaExpiracion.toIso8601String(),
        'usado': usado ? 1 : 0,
        'ip_address': ipAddress,
      };

  factory PasswordResetToken.fromMap(Map<String, dynamic> map) =>
      PasswordResetToken(
        id: map['id'] as int?,
        usuarioId: map['usuario_id'] as int,
        email: map['email'] as String,
        token: map['token'] as String,
        fechaCreacion: DateTime.parse(map['fecha_creacion'] as String),
        fechaExpiracion: DateTime.parse(map['fecha_expiracion'] as String),
        usado: (map['usado'] as int) == 1,
        ipAddress: map['ip_address'] as String?,
      );

  PasswordResetToken copyWith({
    int? id,
    int? usuarioId,
    String? email,
    String? token,
    DateTime? fechaCreacion,
    DateTime? fechaExpiracion,
    bool? usado,
    String? ipAddress,
  }) {
    return PasswordResetToken(
      id: id ?? this.id,
      usuarioId: usuarioId ?? this.usuarioId,
      email: email ?? this.email,
      token: token ?? this.token,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      fechaExpiracion: fechaExpiracion ?? this.fechaExpiracion,
      usado: usado ?? this.usado,
      ipAddress: ipAddress ?? this.ipAddress,
    );
  }

  bool get isExpired => DateTime.now().isAfter(fechaExpiracion);
  bool get isValid => !usado && !isExpired;
}

