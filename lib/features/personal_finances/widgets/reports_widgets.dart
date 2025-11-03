import 'package:flutter/material.dart';
import '../../../core/utils/analytics_design_system.dart';

/// Widgets reutilizables para la pantalla de informes
/// Usa el sistema de diseño unificado AnalyticsDesignSystem
class ReportsWidgets {
  /// Construye el título de una sección
  static Widget buildSectionTitle(String title) {
    return AnalyticsDesignSystem.buildSectionTitle(title);
  }

  /// Construye un botón de período
  static Widget buildPeriodButton({
    required String label,
    required String period,
    required String selectedPeriod,
    required VoidCallback onTap,
  }) {
    return AnalyticsDesignSystem.buildFilterButton(
      label: label,
      isSelected: selectedPeriod == period,
      onTap: onTap,
    );
  }

  /// Construye una estadística compacta
  static Widget buildCompactStat(String label, double amount, IconData icon, Color color) {
    return AnalyticsDesignSystem.buildCompactKpiCard(
      label: label,
      value: amount,
      icon: icon,
      color: color,
    );
  }

  /// Construye información del presupuesto
  static Widget buildBudgetInfo(String label, double amount, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(AnalyticsDesignSystem.spacing8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AnalyticsDesignSystem.radiusSmall),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: AnalyticsDesignSystem.spacing12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AnalyticsDesignSystem.kpiLabel),
            const SizedBox(height: AnalyticsDesignSystem.spacing2),
            Text(
              'S/ ${amount.toStringAsFixed(2)}',
              style: AnalyticsDesignSystem.kpiSmall.copyWith(color: color),
            ),
          ],
        ),
      ],
    );
  }

  /// Construye una fila de comparación
  static Widget buildComparisonRow(String label, double current, double previous, Color color) {
    return AnalyticsDesignSystem.buildComparisonRow(
      label: label,
      currentValue: current,
      previousValue: previous,
      color: color,
    );
  }

  /// Construye un estado vacío
  static Widget buildEmptyState(String message) {
    return AnalyticsDesignSystem.buildEmptyState(message: message);
  }

  /// Muestra las opciones de exportación
  static void showExportOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AnalyticsDesignSystem.backgroundSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AnalyticsDesignSystem.radiusXLarge)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AnalyticsDesignSystem.spacing20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AnalyticsDesignSystem.textTertiary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: AnalyticsDesignSystem.spacing20),
                Text('Exportar Informe', style: AnalyticsDesignSystem.h3),
                const SizedBox(height: AnalyticsDesignSystem.spacing20),
                _buildExportOption(
                  context: context,
                  icon: Icons.picture_as_pdf,
                  title: 'Exportar como PDF',
                  subtitle: 'Documento completo con gráficos',
                  onTap: () {
                    Navigator.pop(context);
                    _showComingSoonSnackBar(context, 'PDF');
                  },
                ),
                const SizedBox(height: AnalyticsDesignSystem.spacing12),
                _buildExportOption(
                  context: context,
                  icon: Icons.table_chart,
                  title: 'Exportar como Excel',
                  subtitle: 'Datos en formato de hoja de cálculo',
                  onTap: () {
                    Navigator.pop(context);
                    _showComingSoonSnackBar(context, 'Excel');
                  },
                ),
                const SizedBox(height: 12),
                _buildExportOption(
                  context: context,
                  icon: Icons.code,
                  title: 'Exportar como CSV',
                  subtitle: 'Datos separados por comas',
                  onTap: () {
                    Navigator.pop(context);
                    _showComingSoonSnackBar(context, 'CSV');
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Construye una opción de exportación
  static Widget _buildExportOption({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AnalyticsDesignSystem.radiusMedium),
      child: Container(
        padding: const EdgeInsets.all(AnalyticsDesignSystem.spacing16),
        decoration: BoxDecoration(
          color: AnalyticsDesignSystem.backgroundPrimary,
          borderRadius: BorderRadius.circular(AnalyticsDesignSystem.radiusMedium),
          border: Border.all(
            color: AnalyticsDesignSystem.primary.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AnalyticsDesignSystem.spacing12),
              decoration: BoxDecoration(
                color: AnalyticsDesignSystem.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AnalyticsDesignSystem.radiusSmall),
              ),
              child: Icon(icon, color: AnalyticsDesignSystem.primary),
            ),
            const SizedBox(width: AnalyticsDesignSystem.spacing16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AnalyticsDesignSystem.h4),
                  const SizedBox(height: AnalyticsDesignSystem.spacing4),
                  Text(subtitle, style: AnalyticsDesignSystem.bodySecondary),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AnalyticsDesignSystem.textTertiary),
          ],
        ),
      ),
    );
  }

  /// Muestra un SnackBar de "próximamente"
  static void _showComingSoonSnackBar(BuildContext context, String format) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Exportación a $format próximamente'),
        backgroundColor: AnalyticsDesignSystem.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Construye el botón de exportar
  static Widget buildExportButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => showExportOptions(context),
        icon: const Icon(Icons.download),
        label: const Text('Exportar Informe'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AnalyticsDesignSystem.backgroundSecondary,
          foregroundColor: AnalyticsDesignSystem.primary,
          padding: const EdgeInsets.symmetric(vertical: AnalyticsDesignSystem.spacing16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AnalyticsDesignSystem.radiusMedium),
            side: BorderSide(
              color: AnalyticsDesignSystem.primary.withValues(alpha: 0.3),
            ),
          ),
          textStyle: AnalyticsDesignSystem.buttonPrimary,
        ),
      ),
    );
  }
}

