import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/models/transaction_model.dart';
import '../../core/repos/transaction_repo.dart';
import 'edit_transaction_screen.dart';
import 'add_transaction_screen.dart';

class TransactionDetailScreen extends StatefulWidget {
  final AppTransaction tx;
  const TransactionDetailScreen({super.key, required this.tx});

  @override
  State<TransactionDetailScreen> createState() => _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  late AppTransaction _tx;
  final _repo = TransactionRepo();
  bool _dirty = false; // 👈 hubo cambios (editar/duplicar/eliminar)

  String _fmtFecha(DateTime d) => DateFormat('dd/MM/yyyy', 'es_PE').format(d);
  String _fmtMoneda(num v) =>
      NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ').format(v);

  @override
  void initState() {
    super.initState();
    _tx = widget.tx;
  }

  Future<void> _refreshTx() async {
    if (_tx.id == null) return;
    final updated = await _repo.getById(_tx.id!);
    if (updated != null) {
      setState(() {
        _tx = updated;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _tx.tipo == 'ingreso' ? Colors.green : Colors.red;

    return PopScope(
      canPop: false, // 👈 desactivamos el pop automático
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.pop(context, _dirty);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Detalle de transacción'),
          actions: [
            // Botón EDITAR
            IconButton(
              tooltip: 'Editar',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () async {
                final changed = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => EditTransactionScreen(tx: _tx)),
                );
                if (changed == true) {
                  _dirty = true;     // 👈 marca que hubo cambios
                  await _refreshTx(); // 👈 recarga el detalle, permaneciendo en esta pantalla
                }
              },
            ),

            // Botón DUPLICAR
            IconButton(
              tooltip: 'Duplicar',
              icon: const Icon(Icons.copy_outlined),
              onPressed: () async {
                final saved = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddTransactionScreen(baseTx: _tx),
                  ),
                );
                if (saved == true && context.mounted) {
                  _dirty = true; // 👈 hubo cambios
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ Transacción duplicada correctamente')),
                  );
                  // Volvemos a la lista para que refresque
                  Navigator.pop(context, true);
                }
              },
            ),

            // Botón ELIMINAR
            IconButton(
              tooltip: 'Eliminar',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Eliminar transacción'),
                    content: const Text('¿Seguro que deseas eliminarla?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancelar'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Eliminar'),
                      ),
                    ],
                  ),
                );
                if (ok == true && _tx.id != null) {
                  await _repo.delete(_tx.id!);
                  if (context.mounted) Navigator.pop(context, true); // -> Home refresca
                }
              },
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                leading: Icon(
                  _tx.tipo == 'ingreso' ? Icons.arrow_upward : Icons.arrow_downward,
                  color: color,
                ),
                title: Text(
                  _fmtMoneda(_tx.monto),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                subtitle: Text('Tipo: ${_tx.tipo.toUpperCase()}'),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.calendar_today),
                title: Text(_fmtFecha(_tx.fecha)),
                subtitle: const Text('Fecha'),
              ),
            ),
            if (_tx.etiqueta != null && _tx.etiqueta!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.label_outline),
                  title: Text(_tx.etiqueta!),
                  subtitle: const Text('Etiqueta'),
                ),
              ),
            ],
            if (_tx.nota != null && _tx.nota!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Nota', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      SelectableText(_tx.nota!),
                    ],
                  ),
                ),
              ),
            ],
            if (_tx.id != null) ...[
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'ID: ${_tx.id}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.grey[600]),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
