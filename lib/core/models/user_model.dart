class User {
  final int? id;
  final String email;
  final String passwordHash;
  final String nombre;
  final String? apellido;
  final String? telefono;
  final DateTime fechaRegistro;
  final DateTime? ultimaConexion;
  final bool activo;
  final String rol;
  final String? avatarUri;
  final DateTime createdAt;
  final DateTime updatedAt;

  User({
    this.id,
    required this.email,
    required this.passwordHash,
    required this.nombre,
    this.apellido,
    this.telefono,
    required this.fechaRegistro,
    this.ultimaConexion,
    this.activo = true,
    this.rol = 'usuario',
    this.avatarUri,
    required this.createdAt,
    required this.updatedAt,
  });

  String get nombreCompleto => apellido != null ? '$nombre $apellido' : nombre;

  Map<String, dynamic> toMap() => {
        'id': id,
        'email': email,
        'password_hash': passwordHash,
        'nombre': nombre,
        'apellido': apellido,
        'telefono': telefono,
        'fecha_registro': fechaRegistro.toIso8601String(),
        'ultima_conexion': ultimaConexion?.toIso8601String(),
        'activo': activo ? 1 : 0,
        'rol': rol,
        'avatar_uri': avatarUri,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory User.fromMap(Map<String, dynamic> map) => User(
        id: map['id'] as int?,
        email: map['email'] as String,
        passwordHash: map['password_hash'] as String,
        nombre: map['nombre'] as String,
        apellido: map['apellido'] as String?,
        telefono: map['telefono'] as String?,
        fechaRegistro: DateTime.parse(map['fecha_registro'] as String),
        ultimaConexion: map['ultima_conexion'] != null
            ? DateTime.parse(map['ultima_conexion'] as String)
            : null,
        activo: (map['activo'] as int) == 1,
        rol: map['rol'] as String,
        avatarUri: map['avatar_uri'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );

  User copyWith({
    int? id,
    String? email,
    String? passwordHash,
    String? nombre,
    String? apellido,
    String? telefono,
    DateTime? fechaRegistro,
    DateTime? ultimaConexion,
    bool? activo,
    String? rol,
    String? avatarUri,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      passwordHash: passwordHash ?? this.passwordHash,
      nombre: nombre ?? this.nombre,
      apellido: apellido ?? this.apellido,
      telefono: telefono ?? this.telefono,
      fechaRegistro: fechaRegistro ?? this.fechaRegistro,
      ultimaConexion: ultimaConexion ?? this.ultimaConexion,
      activo: activo ?? this.activo,
      rol: rol ?? this.rol,
      avatarUri: avatarUri ?? this.avatarUri,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

