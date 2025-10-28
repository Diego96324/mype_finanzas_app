import 'package:flutter/material.dart';

/// Widgets reutilizables para la pantalla de informes
class ReportsWidgets {
  /// Construye el título de una sección
  static Widget buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  /// Construye un botón de período
  static Widget buildPeriodButton({
    required String label,
    required String period,
    required String selectedPeriod,
    required VoidCallback onTap,
  }) {
    final isSelected = selectedPeriod == period;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF13BB67) : const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[400],
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  /// Construye una estadística compacta
  static Widget buildCompactStat(String label, double amount, IconData icon, Color color) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'S/ ${amount.toStringAsFixed(2)}',
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  /// Construye información del presupuesto
  static Widget buildBudgetInfo(String label, double amount, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 12)),
            Text('S/ ${amount.toStringAsFixed(2)}',
                style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }

  /// Construye una fila de comparación
  static Widget buildComparisonRow(String label, double current, double previous, Color color) {
    final difference = current - previous;
    final percentChange = previous != 0 ? (difference / previous) * 100 : 0;
    final isPositive = difference >= 0;

    return Row(
      children: [
        Expanded(flex: 2, child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
        Expanded(flex: 2, child: Text('S/ ${current.toStringAsFixed(0)}', style: TextStyle(color: color, fontWeight: FontWeight.bold))),
        Expanded(flex: 2, child: Text('S/ ${previous.toStringAsFixed(0)}', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold))),
        Expanded(
          flex: 2,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Icon(isPositive ? Icons.arrow_upward : Icons.arrow_downward, size: 14, color: isPositive ? const Color(0xFF13BB67) : Colors.redAccent),
              const SizedBox(width: 4),
              Text('${percentChange.abs().toStringAsFixed(0)}%', style: TextStyle(color: isPositive ? const Color(0xFF13BB67) : Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }

  /// Construye un estado vacío
  static Widget buildEmptyState(String message) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D2D),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.insert_chart_outlined,
              size: 48,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Muestra las opciones de exportación
  static void showExportOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2D2D2D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[600],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Exportar Informe',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
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
                const SizedBox(height: 12),
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
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF13BB67).withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF13BB67).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: const Color(0xFF13BB67)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
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
        backgroundColor: const Color(0xFF13BB67),
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
          backgroundColor: const Color(0xFF2D2D2D),
          foregroundColor: const Color(0xFF13BB67),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: const Color(0xFF13BB67).withValues(alpha: 0.3)),
          ),
        ),
      ),
    );
  }
}

