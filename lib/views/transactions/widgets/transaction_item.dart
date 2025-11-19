import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/dtos/transaction_model.dart';

class TransactionItem extends ConsumerWidget {
  final AppTransaction tx;
  final VoidCallback? onTap;
  const TransactionItem({super.key, required this.tx, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = tx.tipo == 'ingreso' ? Colors.greenAccent : Colors.redAccent;
    final isRecurrent = tx.recurrente || tx.esRecurrente;
    final recurrenceInfo = _buildRecurrenceInfo(tx);
    final recurColor = Theme.of(context).colorScheme.primary;

    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 2),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                tx.tipo == 'ingreso' ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                color: color,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: tx.etiqueta ?? (tx.tipo == 'ingreso' ? 'Ingreso' : 'Egreso'),
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              if (isRecurrent)
                                WidgetSpan(
                                  alignment: PlaceholderAlignment.middle,
                                  child: Tooltip(
                                    message: recurrenceInfo,
                                    child: Padding(
                                      padding: const EdgeInsets.only(left: 6),
                                      child: Icon(
                                        Icons.autorenew_rounded,
                                        size: 14,
                                        color: recurColor.withValues(alpha: 0.85),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.left,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tx.monto.toStringAsFixed(2),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${tx.fecha.day.toString().padLeft(2, '0')}/${tx.fecha.month.toString().padLeft(2, '0')}',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _buildRecurrenceInfo(AppTransaction tx) {
    final parts = <String>['Recurrente'];
    if (tx.frecuenciaRecurrencia != null && tx.frecuenciaRecurrencia!.isNotEmpty) {
      parts.add('• ${tx.frecuenciaRecurrencia}');
    }
    if (tx.recurrenceEndDate != null) {
      final d = tx.recurrenceEndDate!;
      parts.add('hasta ${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}');
    }
    return parts.join(' ');
  }
}
