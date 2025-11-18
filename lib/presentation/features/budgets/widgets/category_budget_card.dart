import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../../data/models/category_model.dart';
import '../controllers/category_budget_controller.dart';
import '../../../../domain/services/category_budget_service.dart' as budget_service;
import '../../../../domain/services/auth_service.dart';

class CategoryBudgetCard extends ConsumerWidget {
  final Category category;
  final String periodo; // 'mensual' | 'trimestral'
  final DateTime referencia;
  const CategoryBudgetCard({super.key, required this.category, required this.periodo, required this.referencia});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = CategoryBudgetKey(categoriaId: category.id!, periodo: periodo, referencia: referencia);

    // Nota: eliminada la llamada a GlobalAlertService desde este listener para evitar
    // duplicar la notificación global (SnackBar). La tarjeta sigue mostrando
    // internamente el texto de alerta cuando `nuevoUmbralEmitido` está presente.

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
            // Si no hay uso (0) o no hay presupuesto, sugerir categorías con mayor gasto en el periodo
            if (state.summary == null || (state.summary != null && state.summary!.realAcumulado == 0.0)) ...[
              const SizedBox(height: 8),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: (() async {
                  final uid = AuthService().currentUserId;
                  if (uid == null) return <Map<String, dynamic>>[];
                  // Calcular rango según periodo
                  DateTime from;
                  DateTime to;
                  if (periodo == 'mensual') {
                    from = DateTime(referencia.year, referencia.month, 1);
                    to = DateTime(referencia.year, referencia.month + 1, 0, 23, 59, 59, 999);
                  } else {
                    // trimestral
                    final quarterStart = ((referencia.month - 1) ~/ 3) * 3 + 1;
                    from = DateTime(referencia.year, quarterStart, 1);
                    to = DateTime(referencia.year, quarterStart + 3, 0, 23, 59, 59, 999);
                  }
                  final res = await budget_service.CategoryBudgetService().getCategorySumsInRange(usuarioId: uid, from: from, to: to, rootCategoryId: category.id);
                  return res;
                })(),
                builder: (context, snap) {
                  if (!snap.hasData) return const SizedBox();
                  final list = snap.data!;
                  if (list.isEmpty) return const SizedBox();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Text('Sugerencias: categorías con más gasto en este periodo', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      ...list.take(3).map((m) {
                        final targetId = m['categoriaId'] as int;
                        final amount = state.summary?.budget.montoLimite ?? (m['monto'] as double);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6.0),
                          child: Row(
                            children: [
                              Expanded(child: Text(m['nombre'] ?? '—', style: Theme.of(context).textTheme.bodyMedium)),
                              Text('S/ ${ (m['monto'] as double).toStringAsFixed(2) }', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                              const SizedBox(width: 8),
                              TextButton(
                                onPressed: () async {
                                  final uid = AuthService().currentUserId;
                                  if (uid == null) {
                                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Usuario no autenticado'), backgroundColor: Colors.red));
                                    return;
                                  }
                                  final service = budget_service.CategoryBudgetService();
                                  final nombre = 'Presupuesto $periodo';
                                  final success = await service.saveBudget(
                                    usuarioId: uid,
                                    categoriaId: targetId,
                                    nombre: nombre,
                                    montoLimite: amount,
                                    periodo: periodo,
                                    referencia: referencia,
                                  );
                                  if (context.mounted) {
                                    if (success > 0) {
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Presupuesto creado/actualizado para ${m['nombre']}'), backgroundColor: const Color(0xFF13BB67)));
                                      // Invalidar providers para refrescar
                                      try {
                                        final newKey = CategoryBudgetKey(categoriaId: targetId, periodo: periodo, referencia: referencia);
                                        ref.invalidate(categoryBudgetControllerProvider(newKey));
                                        // invalidar el key actual para que se actualice
                                        final currentKey = CategoryBudgetKey(categoriaId: category.id!, periodo: periodo, referencia: referencia);
                                        ref.invalidate(categoryBudgetControllerProvider(currentKey));
                                      } catch (_) {}
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error creando presupuesto'), backgroundColor: Colors.red));
                                    }
                                  }
                                },
                                child: const Text('Asignar'),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 6),
                      Text('Si quieres que el presupuesto controle estos gastos, edita el presupuesto y selecciona la categoría correcta.', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  );
                },
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
  final budget_service.CategoryBudgetSummary summary;
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
