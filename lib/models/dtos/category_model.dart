import 'package:flutter/material.dart';

class Category {
  final int? id;
  final int? usuarioId;
  final int? categoriaPadreId;
  final String nombre;
  final String tipo; // ingreso, egreso, transferencia
  final String? descripcion;
  final String icono;
  final String color;
  final bool activa;
  final bool esPredeterminada;
  final int orden;
  final String? tipoNegocio;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Subcategorías (se llena cuando se consulta con jerarquía)
  final List<Category>? subcategorias;

  Category({
    this.id,
    this.usuarioId,
    this.categoriaPadreId,
    required this.nombre,
    required this.tipo,
    this.descripcion,
    required this.icono,
    required this.color,
    this.activa = true,
    this.esPredeterminada = false,
    this.orden = 0,
    this.tipoNegocio,
    required this.createdAt,
    required this.updatedAt,
    this.subcategorias,
  });

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as int?,
      usuarioId: map['usuario_id'] as int?,
      categoriaPadreId: map['categoria_padre_id'] as int?,
      nombre: map['nombre'] as String,
      tipo: map['tipo'] as String,
      descripcion: map['descripcion'] as String?,
      icono: map['icono'] as String? ?? 'category',
      color: map['color'] as String? ?? '#757575',
      activa: (map['activa'] as int? ?? 1) == 1,
      esPredeterminada: (map['es_predeterminada'] as int? ?? 0) == 1,
      orden: map['orden'] as int? ?? 0,
      tipoNegocio: map['tipo_negocio'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      subcategorias: null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'usuario_id': usuarioId,
      'categoria_padre_id': categoriaPadreId,
      'nombre': nombre,
      'tipo': tipo,
      'descripcion': descripcion,
      'icono': icono,
      'color': color,
      'activa': activa ? 1 : 0,
      'es_predeterminada': esPredeterminada ? 1 : 0,
      'orden': orden,
      'tipo_negocio': tipoNegocio,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Category copyWith({
    int? id,
    int? usuarioId,
    int? categoriaPadreId,
    String? nombre,
    String? tipo,
    String? descripcion,
    String? icono,
    String? color,
    bool? activa,
    bool? esPredeterminada,
    int? orden,
    String? tipoNegocio,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<Category>? subcategorias,
  }) {
    return Category(
      id: id ?? this.id,
      usuarioId: usuarioId ?? this.usuarioId,
      categoriaPadreId: categoriaPadreId ?? this.categoriaPadreId,
      nombre: nombre ?? this.nombre,
      tipo: tipo ?? this.tipo,
      descripcion: descripcion ?? this.descripcion,
      icono: icono ?? this.icono,
      color: color ?? this.color,
      activa: activa ?? this.activa,
      esPredeterminada: esPredeterminada ?? this.esPredeterminada,
      orden: orden ?? this.orden,
      tipoNegocio: tipoNegocio ?? this.tipoNegocio,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      subcategorias: subcategorias ?? this.subcategorias,
    );
  }

  // Helpers
  bool get esPrincipal => categoriaPadreId == null;
  bool get esSubcategoria => categoriaPadreId != null;

  Color get colorAsColor {
    try {
      return Color(int.parse(color.replaceAll('#', '0xFF')));
    } catch (e) {
      return Colors.grey;
    }
  }

  IconData get iconAsIconData {
    return CategoryIcons.getIcon(icono);
  }

  String get tipoDisplay {
    switch (tipo) {
      case 'ingreso':
        return 'Ingreso';
      case 'egreso':
        return 'Gasto';
      case 'transferencia':
        return 'Transferencia';
      default:
        return tipo;
    }
  }

  @override
  String toString() {
    return 'Category(id: $id, nombre: $nombre, tipo: $tipo, padre: $categoriaPadreId)';
  }
}

// Clase helper para manejar iconos
class CategoryIcons {
  static const Map<String, IconData> _iconMap = {
    // General
    'category': Icons.category,
    'other': Icons.more_horiz,
    'default': Icons.label,

    // Ingresos
    'salary': Icons.account_balance_wallet,
    'sales': Icons.point_of_sale,
    'investment': Icons.trending_up,
    'freelance': Icons.work_outline,
    'rental': Icons.home_work,
    'bonus': Icons.card_giftcard,
    'shopping_cart': Icons.shopping_cart,
    'local_drink': Icons.local_drink,
    'kitchen': Icons.kitchen,
    'restaurant': Icons.restaurant,
    'delivery_dining': Icons.delivery_dining,
    'table_restaurant': Icons.table_restaurant,
    'work': Icons.work,
    'support_agent': Icons.support_agent,
    'assignment': Icons.assignment,

    // Egresos
    'food': Icons.restaurant_menu,
    'transport': Icons.directions_car,
    'home': Icons.home,
    'services': Icons.receipt,
    'entertainment': Icons.movie,
    'health': Icons.local_hospital,
    'education': Icons.school,
    'shopping': Icons.shopping_bag,
    'shopping_basket': Icons.shopping_basket,
    'inventory': Icons.inventory,
    'store': Icons.store,
    'receipt': Icons.receipt_long,
    'set_meal': Icons.set_meal,
    'eco': Icons.eco,
    'groups': Icons.groups,
    'description': Icons.description,
    'computer': Icons.computer,
    'campaign': Icons.campaign,

    // Transferencias
    'transfer': Icons.swap_horiz,
    'bank': Icons.account_balance,
    'cash': Icons.payments,

    // Negocios
    'business': Icons.business,
    'inventory_2': Icons.inventory_2,
    'local_shipping': Icons.local_shipping,
    'construction': Icons.construction,
    'cleaning': Icons.cleaning_services,
    'design': Icons.design_services,
    'medical': Icons.medical_services,
  };

  static IconData getIcon(String iconName) {
    return _iconMap[iconName] ?? Icons.category;
  }

  static List<String> getAllIconNames() {
    return _iconMap.keys.toList();
  }

  static Map<String, IconData> getIconsByCategory(String category) {
    switch (category) {
      case 'ingreso':
        return {
          'salary': Icons.account_balance_wallet,
          'sales': Icons.point_of_sale,
          'investment': Icons.trending_up,
          'work': Icons.work,
          'bonus': Icons.card_giftcard,
          'restaurant': Icons.restaurant,
          'shopping_cart': Icons.shopping_cart,
        };
      case 'egreso':
        return {
          'food': Icons.restaurant_menu,
          'transport': Icons.directions_car,
          'home': Icons.home,
          'services': Icons.receipt,
          'shopping': Icons.shopping_bag,
          'health': Icons.local_hospital,
          'education': Icons.school,
          'inventory': Icons.inventory,
        };
      default:
        return {'default': Icons.category};
    }
  }
}

// Paleta de colores predefinida para categorías
class CategoryColors {
  static const List<String> colors = [
    '#F44336', // Red
    '#E91E63', // Pink
    '#9C27B0', // Purple
    '#673AB7', // Deep Purple
    '#3F51B5', // Indigo
    '#2196F3', // Blue
    '#03A9F4', // Light Blue
    '#00BCD4', // Cyan
    '#009688', // Teal
    '#4CAF50', // Green
    '#8BC34A', // Light Green
    '#CDDC39', // Lime
    '#FFEB3B', // Yellow
    '#FFC107', // Amber
    '#FF9800', // Orange
    '#FF5722', // Deep Orange
    '#795548', // Brown
    '#607D8B', // Blue Grey
  ];

  static Color getColorFromHex(String hex) {
    try {
      return Color(int.parse(hex.replaceAll('#', '0xFF')));
    } catch (e) {
      return Colors.grey;
    }
  }
}