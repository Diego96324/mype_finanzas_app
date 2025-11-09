class CategoryBudget {
  final int? id;
  final int usuarioId;
  final int categoriaId; // nivel principal inicialmente
  final String nombre;
  final double montoLimite;
  final String periodo; // 'mensual' | 'trimestral'
  final DateTime fechaInicio;
  final DateTime fechaFin;
  final bool activo;
  final List<int> alertaThresholds; // ej: [75,90,100]
  final int alertaEmitidaHasta; // 0, 75, 90, 100
  final bool autoAjuste;
  final DateTime createdAt;
  final DateTime updatedAt;

  CategoryBudget({
    this.id,
    required this.usuarioId,
    required this.categoriaId,
    required this.nombre,
    required this.montoLimite,
    required this.periodo,
    required this.fechaInicio,
    required this.fechaFin,
    this.activo = true,
    this.alertaThresholds = const [75, 90, 100],
    this.alertaEmitidaHasta = 0,
    this.autoAjuste = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'usuario_id': usuarioId,
        'categoria_id': categoriaId,
        'nombre': nombre,
        'monto_limite': montoLimite,
        'periodo': periodo,
        'fecha_inicio': fechaInicio.toIso8601String(),
        'fecha_fin': fechaFin.toIso8601String(),
        'activo': activo ? 1 : 0,
        'alerta_thresholds': alertaThresholds.join(','),
        'alerta_emitida_hasta': alertaEmitidaHasta,
        'auto_ajuste': autoAjuste ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory CategoryBudget.fromMap(Map<String, dynamic> map) => CategoryBudget(
        id: map['id'] as int?,
        usuarioId: map['usuario_id'] as int,
        categoriaId: map['categoria_id'] as int,
        nombre: map['nombre'] as String,
        montoLimite: (map['monto_limite'] as num).toDouble(),
        periodo: map['periodo'] as String,
        fechaInicio: DateTime.parse(map['fecha_inicio'] as String),
        fechaFin: DateTime.parse(map['fecha_fin'] as String),
        activo: (map['activo'] as int?) == 1,
        alertaThresholds: ((map['alerta_thresholds'] as String?) ?? '75,90,100')
            .split(',')
            .where((e) => e.trim().isNotEmpty)
            .map((e) => int.tryParse(e.trim()) ?? 0)
            .where((v) => v > 0)
            .toList(),
        alertaEmitidaHasta: (map['alerta_emitida_hasta'] as int?) ?? 0,
        autoAjuste: (map['auto_ajuste'] as int?) == 1,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );

  CategoryBudget copyWith({
    int? id,
    int? usuarioId,
    int? categoriaId,
    String? nombre,
    double? montoLimite,
    String? periodo,
    DateTime? fechaInicio,
    DateTime? fechaFin,
    bool? activo,
    List<int>? alertaThresholds,
    int? alertaEmitidaHasta,
    bool? autoAjuste,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => CategoryBudget(
        id: id ?? this.id,
        usuarioId: usuarioId ?? this.usuarioId,
        categoriaId: categoriaId ?? this.categoriaId,
        nombre: nombre ?? this.nombre,
        montoLimite: montoLimite ?? this.montoLimite,
        periodo: periodo ?? this.periodo,
        fechaInicio: fechaInicio ?? this.fechaInicio,
        fechaFin: fechaFin ?? this.fechaFin,
        activo: activo ?? this.activo,
        alertaThresholds: alertaThresholds ?? this.alertaThresholds,
        alertaEmitidaHasta: alertaEmitidaHasta ?? this.alertaEmitidaHasta,
        autoAjuste: autoAjuste ?? this.autoAjuste,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

