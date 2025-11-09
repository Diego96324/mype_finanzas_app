import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../../core/services/global_alert_service.dart';
import '../../../../../../data/models/category_model.dart';
import '../controllers/category_budget_controller.dart';
import '../../../../domain/services/category_budget_service.dart';

class CategoryBudgetCard extends ConsumerWidget {
  final Category category;
  final String periodo; // 'mensual' | 'trimestral'
  final DateTime referencia;
  const CategoryBudgetCard({super.key, required this.category, required this.periodo, required this.referencia});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = CategoryBudgetKey(categoriaId: category.id!, periodo: periodo, referencia: referencia);

    // Notificación visual cuando se alcanza un nuevo umbral
    ref.listen(categoryBudgetControllerProvider(key), (prev, next) {
      final prevUmbral = prev?.summary?.nuevoUmbralEmitido;
      final currUmbral = next.summary?.nuevoUmbralEmitido;
      if (currUmbral != null && currUmbral != prevUmbral && next.summary != null) {
        GlobalAlertService().showBudgetThresholdAlert(
          categoriaId: category.id!,
          categoriaNombre: category.nombre,
          porcentaje: currUmbral.toDouble(),
            limite: next.summary!.budget.montoLimite,
            periodo: periodo,
            referencia: referencia,
        );
      }
    });

    final state = ref.watch(categoryBudgetControllerProvider(key));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(category.nombre, style: Theme.of(context).textTheme.titleMedium),
                IconButton(
                  icon: const Icon(Icons.edit),
                  tooltip: 'Configurar presupuesto',
                  onPressed: () async {
                    await showDialog(
                      context: context,
                      builder: (_) => _EditCategoryBudgetDialog(budgetKey: key),
                    );
                    ref.invalidate(categoryBudgetControllerProvider(key));
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (state.isLoading)
              const LinearProgressIndicator()
            else if (state.summary == null)
              Text('Sin presupuesto configurado para este $periodo', style: Theme.of(context).textTheme.bodySmall)
            else ...[
              _BudgetProgress(summary: state.summary!),
              if (state.summary!.nuevoUmbralEmitido != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    'Alerta: alcanzado ${state.summary!.nuevoUmbralEmitido}% del presupuesto',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.orange),
                  ),
                ),
              if (state.summary!.sugerenciaAjuste != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text('Sugerencia de ajuste: S/ ${state.summary!.sugerenciaAjuste!.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.bodySmall),
                ),
            ],
            if (state.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(state.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
          ],
        ),
      ),
    );
  }
}

class _BudgetProgress extends StatelessWidget {
  final CategoryBudgetSummary summary;
  const _BudgetProgress({required this.summary});

  @override
  Widget build(BuildContext context) {
    final pct = summary.porcentaje.clamp(0.0, 150.0);
    final color = pct >= 100
        ? Colors.red
        : pct >= 90
            ? Colors.orange
            : pct >= 75
                ? Colors.amber
                : Colors.green;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(value: (pct / 100).clamp(0.0, 1.0), color: color, backgroundColor: color.withValues(alpha: 0.15)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            Text('Objetivo: S/ ${summary.budget.montoLimite.toStringAsFixed(2)}'),
            Text('Acumulado: S/ ${summary.realAcumulado.toStringAsFixed(2)}'),
            Text('Restante: S/ ${summary.restante.toStringAsFixed(2)}'),
            Text('Uso: ${summary.porcentaje.toStringAsFixed(1)}%'),
          ],
        )
      ],
    );
  }
}

class _EditCategoryBudgetDialog extends ConsumerStatefulWidget {
  final CategoryBudgetKey budgetKey;
  const _EditCategoryBudgetDialog({required this.budgetKey});

  @override
  ConsumerState<_EditCategoryBudgetDialog> createState() => _EditCategoryBudgetDialogState();
}

class _EditCategoryBudgetDialogState extends ConsumerState<_EditCategoryBudgetDialog> {
  final _formKey = GlobalKey<FormState>();
  final _montoCtrl = TextEditingController();
  bool _autoAjuste = false;

  @override
  void dispose() {
    _montoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Configurar presupuesto de categoría'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _montoCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: 'Monto límite (${widget.budgetKey.periodo})'),
                validator: (v) {
                  final parsed = double.tryParse(v ?? '');
                  if (parsed == null || parsed <= 0) return 'Ingresa un monto válido';
                  return null;
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Ajuste automático sugerido'),
                value: _autoAjuste,
                onChanged: (val) => setState(() => _autoAjuste = val),
              )
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () async {
            if (!_formKey.currentState!.validate()) return;
            final monto = double.parse(_montoCtrl.text);
            final controller = ref.read(categoryBudgetControllerProvider(widget.budgetKey).notifier);
            final ok = await controller.save(nombre: 'Presupuesto ${widget.budgetKey.periodo}', montoLimite: monto, autoAjuste: _autoAjuste);
            if (ok && context.mounted) Navigator.pop(context);
          },
          child: const Text('Guardar'),
        )
      ],
    );
  }
}
