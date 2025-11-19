// filepath: lib/presentation/widgets/main_nav_bar.dart
import 'package:flutter/material.dart';

/// Barra de navegación inferior reutilizable para la app.
/// Integrada con FAB centrado (opcionalmente flotante).
class MainNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback? onAdd; // callback para el botón central

  const MainNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.onAdd,
  });

  Widget _buildNavButton(
      BuildContext context,
      IconData icon,
      String label,
      int index,
      ) {
    final isSelected = currentIndex == index;
    final colorScheme = Theme.of(context).colorScheme;
    final activeColor = colorScheme.onSurface;
    final inactiveColor = colorScheme.onSurface.withValues(alpha: 0.6);

    return Expanded(
      child: Semantics(
        button: true,
        label: label,
        selected: isSelected,
        child: Tooltip(
          message: label,
          child: InkWell(
            onTap: () => onTap(index),
            borderRadius: BorderRadius.circular(10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Indicador superior (animado) de pestaña activa
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  height: 3,
                  width: isSelected ? 28 : 0,
                  decoration: BoxDecoration(
                    color: activeColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 6),
                Icon(icon, color: isSelected ? colorScheme.primary : inactiveColor),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isSelected ? activeColor : inactiveColor,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return BottomAppBar(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest,
      surfaceTintColor: Colors.transparent,
      // Integrado: no usamos muesca del Scaffold ya que el botón está dentro
      shape: null,
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: kBottomNavigationBarHeight, // altura estándar y compacta
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavButton(context, Icons.list_alt, 'Inicio', 0),
            _buildNavButton(context, Icons.insights_rounded, 'Análisis', 1),
            // Botón central integrado (mantener el hueco equivalente)
            SizedBox(
              width: 64,
              child: Center(
                child: SizedBox(
                  width: 42,
                  height: 42,
                  child: Material(
                    color: colorScheme.secondaryContainer,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    child: InkWell(
                      onTap: onAdd,
                      borderRadius: BorderRadius.circular(8),
                      splashColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                      child: Center(
                        child: Icon(
                          Icons.add_rounded,
                          size: 22,
                          color: colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            _buildNavButton(context, Icons.assignment_rounded, 'Informes', 2),
            _buildNavButton(context, Icons.person_rounded, 'Perfil', 3),
          ],
        ),
      ),
    );
  }
}
