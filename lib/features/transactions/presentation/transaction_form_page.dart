import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../application/transaction_form_controller.dart';
import '../domain/transaction_form_state.dart';

class TransactionFormPage extends ConsumerStatefulWidget {
  final TransactionFormArgs args;
  const TransactionFormPage({super.key, required this.args});

  @override
  ConsumerState<TransactionFormPage> createState() => _TransactionFormPageState();
}

class _TransactionFormPageState extends ConsumerState<TransactionFormPage> {
  final _categoryFocus = FocusNode();
  final _amountFocus = FocusNode();
  final _notesFocus = FocusNode();
  final _tagsFocus = FocusNode();

  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  final _tagsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(transactionFormControllerProvider(widget.args).notifier).init();
    });
    ref.listen(transactionFormControllerProvider(widget.args), (prev, next) {
      _handleFocus(next.focusTarget);
      _syncControllers(next);
    });
  }

  void _syncControllers(TransactionFormState state) {
    // Mantener texto si viene de estado (solo si difiere para evitar loops)
    if (_notesController.text != state.notes) {
      _notesController.text = state.notes;
    }
    final tagsString = state.tags.join(', ');
    if (_tagsController.text != tagsString) {
      _tagsController.text = tagsString;
    }
  }

  @override
  void dispose() {
    _categoryFocus.dispose();
    _amountFocus.dispose();
    _notesFocus.dispose();
    _tagsFocus.dispose();
    _amountController.dispose();
    _notesController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(transactionFormControllerProvider(widget.args));

    return Scaffold(
      appBar: AppBar(title: Text(state.isEditing ? 'Editar transacción' : 'Nueva transacción')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Chip(label: Text(widget.args.tipo)),
                if (state.isCategoryAutofilled) ...[
                  const SizedBox(width: 8),
                  const Chip(label: Text('Autofill categoría')),
                ]
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              focusNode: _categoryFocus,
              decoration: const InputDecoration(labelText: 'Categoría'),
              initialValue: state.selectedCategoryId,
              items: const [
                DropdownMenuItem(value: 1, child: Text('Alimentos')),
                DropdownMenuItem(value: 2, child: Text('Transporte')),
                DropdownMenuItem(value: 3, child: Text('Servicios')),
              ],
              onChanged: (val) {
                ref.read(transactionFormControllerProvider(widget.args).notifier).onCategoryChanged(val);
              },
            ),
            const SizedBox(height: 16),

            TextFormField(
              focusNode: _amountFocus,
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Monto'),
              onChanged: (text) {
                final v = double.tryParse(text.replaceAll(',', '.'));
                ref.read(transactionFormControllerProvider(widget.args).notifier).onAmountChanged(v);
              },
              onFieldSubmitted: (_) {
                ref.read(transactionFormControllerProvider(widget.args).notifier).onAmountSubmitted();
              },
            ),
            const SizedBox(height: 16),

            TextFormField(
              focusNode: _notesFocus,
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Notas'),
              maxLines: 2,
              onChanged: (val) => ref.read(transactionFormControllerProvider(widget.args).notifier).onNotesChanged(val),
            ),
            const SizedBox(height: 16),

            TextFormField(
              focusNode: _tagsFocus,
              controller: _tagsController,
              decoration: const InputDecoration(labelText: 'Etiquetas (coma separada)'),
              onChanged: (val) => ref.read(transactionFormControllerProvider(widget.args).notifier).onTagsChanged(val),
            ),

            const Spacer(),
            ElevatedButton(
              onPressed: () async {
                final nav = Navigator.of(context);
                await ref.read(transactionFormControllerProvider(widget.args).notifier).onSubmitSuccess();
                if (!mounted) return;
                nav.pop(true);
              },
              child: const Text('Guardar'),
            )
          ],
        ),
      ),
    );
  }

  void _handleFocus(FocusTarget target) {
    switch (target) {
      case FocusTarget.categoria:
        _categoryFocus.requestFocus();
        break;
      case FocusTarget.monto:
        _amountFocus.requestFocus();
        break;
      case FocusTarget.notas:
        _notesFocus.requestFocus();
        break;
      case FocusTarget.etiquetas:
        _tagsFocus.requestFocus();
        break;
      case FocusTarget.none:
        break;
    }
  }
}
