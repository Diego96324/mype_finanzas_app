import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../core/models/transaction_model.dart';
import '../../core/repos/transaction_repo.dart';

class EditTransactionScreen extends StatefulWidget {
  final AppTransaction tx;
  const EditTransactionScreen({super.key, required this.tx});

  @override
  State<EditTransactionScreen> createState() => _EditTransactionScreenState();
}

class _EditTransactionScreenState extends State<EditTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repo = TransactionRepo();

  late String _tipo;
  late DateTime _fecha;
  final _montoCtrl = TextEditingController();
  final _etiquetaCtrl = TextEditingController();
  final _notaCtrl = TextEditingController();

  String _fmtFecha(DateTime d) => DateFormat('dd/MM/yyyy', 'es_PE').format(d);

  @override
  void initState() {
    super.initState();
    _tipo = widget.tx.tipo;
    _fecha = widget.tx.fecha;
    _montoCtrl.text = widget.tx.monto.toStringAsFixed(2);
    _etiquetaCtrl.text = widget.tx.etiqueta ?? '';
    _notaCtrl.text = widget.tx.nota ?? '';
  }

  @override
  void dispose() {
    _montoCtrl.dispose();
    _etiquetaCtrl.dispose();
    _notaCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2010),
      lastDate: DateTime(2100),
      helpText: 'Selecciona la fecha',
      locale: const Locale('es', 'PE'),
    );
    if (picked != null) setState(() => _fecha = picked);
  }

  Future<void> _guardar() async {
    if (_formKey.currentState?.validate() != true) return;
    final monto = double.tryParse(_montoCtrl.text.replaceAll(',', '.')) ?? 0;
    final updated = AppTransaction(
      id: widget.tx.id,
      fecha: _fecha,
      tipo: _tipo,
      monto: monto,
      etiqueta: _etiquetaCtrl.text.trim().isEmpty ? null : _etiquetaCtrl.text.trim(),
      nota: _notaCtrl.text.trim().isEmpty ? null : _notaCtrl.text.trim(),
    );
    await _repo.update(updated);
    if (mounted) Navigator.pop(context, true); // devuelve true para refrescar
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Editar transacción')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                initialValue: _tipo,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: const [
                  DropdownMenuItem(value: 'ingreso', child: Text('Ingreso')),
                  DropdownMenuItem(value: 'egreso', child: Text('Egreso')),
                ],
                onChanged: (v) => setState(() => _tipo = v ?? 'egreso'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _montoCtrl,
                decoration: const InputDecoration(labelText: 'Monto (S/.)', hintText: '0.00'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Ingrese un monto';
                  final num? parsed = num.tryParse(v.replaceAll(',', '.'));
                  if (parsed == null || parsed <= 0) return 'Ingrese un monto válido';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _etiquetaCtrl,
                decoration: const InputDecoration(labelText: 'Etiqueta (opcional)'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notaCtrl,
                decoration: const InputDecoration(labelText: 'Nota (opcional)'),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickFecha,
                      icon: const Icon(Icons.calendar_today),
                      label: Text(_fmtFecha(_fecha)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _guardar,
                icon: const Icon(Icons.save),
                label: const Text('Guardar cambios'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
