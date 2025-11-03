import 'package:flutter/material.dart';

/// Sistema de diseño unificado para Reportes y Analítica
/// Define tipografía, espaciados, colores y componentes reutilizables
class AnalyticsDesignSystem {
  // ========== COLORES ==========

  /// Color primario - Verde (éxito/positivo)
  static const Color primary = Color(0xFF13BB67);

  /// Color secundario - Rojo (alerta/negativo)
  static const Color danger = Color(0xFFFF5252);

  /// Color de advertencia - Naranja
  static const Color warning = Color(0xFFFF9800);

  /// Color de información - Azul
  static const Color info = Color(0xFF2196F3);

  /// Fondos
  static const Color backgroundPrimary = Color(0xFF1E1E1E);
  static const Color backgroundSecondary = Color(0xFF2D2D2D);
  static const Color backgroundTertiary = Color(0xFF3A3A3A);

  /// Textos
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFB0B0B0);
  static const Color textTertiary = Color(0xFF808080);
  static const Color textDisabled = Color(0xFF666666);

  /// Divisores y bordes
  static Color get divider => Colors.white.withValues(alpha: 0.1);
  static Color get border => Colors.white.withValues(alpha: 0.15);

  // ========== TIPOGRAFÍA ==========

  /// Títulos principales (H1) - Para encabezados de pantalla
  static const TextStyle h1 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: textPrimary,
    height: 1.2,
    letterSpacing: -0.5,
  );

  /// Títulos de sección (H2) - Para secciones principales
  static const TextStyle h2 = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: textPrimary,
    height: 1.3,
    letterSpacing: -0.3,
  );

  /// Títulos de tarjeta (H3) - Para títulos dentro de tarjetas
  static const TextStyle h3 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: textPrimary,
    height: 1.4,
  );

  /// Subtítulos (H4)
  static const TextStyle h4 = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    height: 1.4,
  );

  /// KPIs - Valores numéricos destacados (grandes)
  static const TextStyle kpiLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: textPrimary,
    height: 1.1,
    letterSpacing: -1,
  );

  /// KPIs - Valores numéricos destacados (medianos)
  static const TextStyle kpiMedium = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: textPrimary,
    height: 1.2,
    letterSpacing: -0.5,
  );

  /// KPIs - Valores numéricos destacados (pequeños)
  static const TextStyle kpiSmall = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: textPrimary,
    height: 1.3,
  );

  /// Etiquetas de KPIs
  static const TextStyle kpiLabel = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: textSecondary,
    height: 1.3,
    letterSpacing: 0.5,
  );

  /// Texto del cuerpo (normal)
  static const TextStyle bodyNormal = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: textPrimary,
    height: 1.5,
  );

  /// Texto del cuerpo (destacado)
  static const TextStyle bodyBold = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    height: 1.5,
  );

  /// Texto secundario
  static const TextStyle bodySecondary = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.normal,
    color: textSecondary,
    height: 1.4,
  );

  /// Texto pequeño (caption)
  static const TextStyle caption = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.normal,
    color: textTertiary,
    height: 1.3,
  );

  /// Botones principales
  static const TextStyle buttonPrimary = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    letterSpacing: 0.3,
  );

  /// Botones secundarios
  static const TextStyle buttonSecondary = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: textSecondary,
    letterSpacing: 0.2,
  );

  // ========== ESPACIADOS ==========

  static const double spacing2 = 2.0;
  static const double spacing4 = 4.0;
  static const double spacing6 = 6.0;
  static const double spacing8 = 8.0;
  static const double spacing10 = 10.0;
  static const double spacing12 = 12.0;
  static const double spacing16 = 16.0;
  static const double spacing20 = 20.0;
  static const double spacing24 = 24.0;
  static const double spacing32 = 32.0;
  static const double spacing40 = 40.0;
  static const double spacing48 = 48.0;

  // ========== BORDES Y RADIOS ==========

  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusXLarge = 20.0;

  // ========== SOMBRAS ==========

  static List<BoxShadow> shadowSoft = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.1),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> shadowMedium = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.2),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> shadowStrong = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.3),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];

  static List<BoxShadow> shadowGlow(Color color) => [
    BoxShadow(
      color: color.withValues(alpha: 0.4),
      blurRadius: 20,
      spreadRadius: 2,
      offset: const Offset(0, 4),
    ),
  ];

  // ========== MÉTODOS HELPER PARA WIDGETS ==========

  /// Construye un título de sección
  static Widget buildSectionTitle(String title, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: spacing12),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: primary, size: 20),
            const SizedBox(width: spacing8),
          ],
          Text(title, style: h3),
        ],
      ),
    );
  }

  /// Construye un botón de filtro
  static Widget buildFilterButton({
    required String label,
    VoidCallback? onPressed,
    VoidCallback? onTap,
    bool isActive = false,
    bool isSelected = false,
  }) {
    final bool active = isActive || isSelected;
    final callback = onPressed ?? onTap;

    return ElevatedButton(
      onPressed: callback,
      style: ElevatedButton.styleFrom(
        backgroundColor: active ? primary : backgroundSecondary,
        foregroundColor: active ? Colors.black : textPrimary,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: spacing16, vertical: spacing8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
        ),
      ),
      child: Text(label, style: buttonSecondary),
    );
  }

  /// Construye un estado vacío
  static Widget buildEmptyState({
    required String message,
    IconData icon = Icons.inbox_outlined,
    Widget? action,
    double? minHeight,
  }) {
    final content = Padding(
      padding: const EdgeInsets.all(spacing32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: textSecondary),
          const SizedBox(height: spacing16),
          Text(message, style: bodySecondary, textAlign: TextAlign.center),
          if (action != null) ...[
            const SizedBox(height: spacing24),
            action,
          ],
        ],
      ),
    );

    if (minHeight != null) {
      return Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: minHeight),
          child: content,
        ),
      );
    }

    return Center(child: content);
  }

  /// Construye un contenedor de gráfico
  static Widget buildChartContainer({
    required String title,
    required Widget child,
    Widget? headerAction,
    double? height,
    double? minHeight,
  }) {
    final effectiveHeight = height ?? minHeight;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: spacing8),
      padding: const EdgeInsets.all(spacing16),
      decoration: BoxDecoration(
        color: backgroundSecondary,
        borderRadius: BorderRadius.circular(radiusMedium),
        boxShadow: shadowSoft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: h4),
              if (headerAction != null) headerAction,
            ],
          ),
          const SizedBox(height: spacing16),
          if (effectiveHeight != null)
            SizedBox(height: effectiveHeight, child: child)
          else
            child,
        ],
      ),
    );
  }

  /// Construye una insignia/badge
  static Widget buildBadge({
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: spacing8, vertical: spacing4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(radiusSmall),
      ),
      child: Text(
        label,
        style: caption.copyWith(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }

  /// Construye una tarjeta KPI compacta
  static Widget buildCompactKpiCard({
    required String label,
    required double value,
    required Color color,
    IconData? icon,
  }) {
    return Flexible(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, color: color, size: 20),
            const SizedBox(height: spacing4),
          ],
          Text(
            label,
            style: kpiLabel,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: spacing4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'S/ ${value.toStringAsFixed(2)}',
              style: kpiSmall.copyWith(color: color),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  /// Construye una fila de comparación
  static Widget buildComparisonRow({
    required String label,
    double? value,
    double? currentValue,
    double? previousValue,
    required Color color,
  }) {
    final displayValue = value ?? currentValue ?? 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: spacing8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: bodyNormal),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'S/ ${displayValue.toStringAsFixed(2)}',
                style: bodyBold.copyWith(color: color),
              ),
              if (previousValue != null && currentValue != null) ...[
                const SizedBox(height: spacing2),
                Text(
                  previousValue > 0
                      ? '${((currentValue - previousValue) / previousValue * 100).toStringAsFixed(1)}%'
                      : '0%',
                  style: caption.copyWith(
                    color: currentValue >= previousValue ? primary : danger,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// Construye una tarjeta genérica
  static Widget buildCard({
    required Widget child,
    Color? color,
    EdgeInsetsGeometry? padding,
  }) {
    return Container(
      padding: padding ?? const EdgeInsets.all(spacing16),
      decoration: BoxDecoration(
        color: color ?? backgroundSecondary,
        borderRadius: BorderRadius.circular(radiusMedium),
        boxShadow: shadowSoft,
      ),
      child: child,
    );
  }

  /// Construye un divisor
  static Widget buildDivider() {
    return Divider(
      color: divider,
      height: spacing16,
      thickness: 1,
    );
  }
}

