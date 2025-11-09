import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TransactionsQuickMenu extends ConsumerWidget {
  final String currentMode; // 'transacciones' | 'presupuestos'
  final void Function(String mode) onSelectMode;
  const TransactionsQuickMenu({super.key, required this.currentMode, required this.onSelectMode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.dashboard_customize_rounded, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text('Modo de vista', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 16),
            _ModeTile(
              icon: Icons.list_alt_rounded,
              title: 'Transacciones',
              subtitle: 'Lista de movimientos y estadísticas',
              selected: currentMode == 'transacciones',
              onTap: () {
                onSelectMode('transacciones');
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 8),
            _ModeTile(
              icon: Icons.account_balance_wallet_rounded,
              title: 'Presupuestos por categoría',
              subtitle: 'Configura y revisa ejecución mensual/trimestral',
              selected: currentMode == 'presupuestos',
              onTap: () {
                onSelectMode('presupuestos');
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.close),
                label: const Text('Cerrar'),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  const _ModeTile({required this.icon, required this.title, required this.subtitle, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Card(
      elevation: selected ? 4 : 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: selected ? colorScheme.primary.withValues(alpha: 0.12) : colorScheme.surfaceVariant.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected ? colorScheme.primary : colorScheme.outlineVariant.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Icon(icon, color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.55)),
                    ),
                  ],
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: selected
                    ? Icon(Icons.check_circle, key: const ValueKey('selected'), color: colorScheme.primary)
                    : Icon(Icons.chevron_right_rounded, key: const ValueKey('chevron'), color: colorScheme.onSurface.withValues(alpha: 0.6)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
