class AppTransaction {
  final int? id;
  final DateTime fecha;
  final String tipo;
  final double monto;
  final int? categoriaId;
  final String? etiqueta;
  final String? nota;
  final String? comprobanteUri;

  AppTransaction({
    this.id,
    required this.fecha,
    required this.tipo,
    required this.monto,
    this.categoriaId,
    this.etiqueta,
    this.nota,
    this.comprobanteUri,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'fecha': fecha.toIso8601String(),
    'tipo': tipo,
    'monto': monto,
    'categoria_id': categoriaId,
    'etiqueta': etiqueta,
    'nota': nota,
    'comprobante_uri': comprobanteUri,
  };

  factory AppTransaction.fromMap(Map<String, dynamic> map) => AppTransaction(
    id: map['id'] as int?,
    fecha: DateTime.parse(map['fecha'] as String),
    tipo: map['tipo'] as String,
    monto: (map['monto'] as num).toDouble(),
    categoriaId: map['categoria_id'] as int?,
    etiqueta: map['etiqueta'] as String?,
    nota: map['nota'] as String?,
    comprobanteUri: map['comprobante_uri'] as String?,
  );
}
