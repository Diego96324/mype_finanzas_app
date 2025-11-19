import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/dtos/account_model.dart';
import '../../controllers/accounts/accounts_controller.dart';

class EditAccountDialog extends ConsumerStatefulWidget {
  final Account account;
  final VoidCallback? onAccountUpdated;

  const EditAccountDialog({
    super.key,
    required this.account,
    this.onAccountUpdated,
  });

  @override
  ConsumerState<EditAccountDialog> createState() => _EditAccountDialogState();
}

class _EditAccountDialogState extends ConsumerState<EditAccountDialog> {
  late final GlobalKey<FormState> _formKey;
  late final TextEditingController _nombreController;
  late final TextEditingController _saldoController;
  late final TextEditingController _institucionController;
  late String _tipoSeleccionado;
  late String _monedaSeleccionada;

  @override
  void initState() {
    super.initState();
    _formKey = GlobalKey<FormState>();
    _nombreController = TextEditingController(text: widget.account.nombre);
    _saldoController = TextEditingController(text: widget.account.saldo.toStringAsFixed(2));
    _institucionController = TextEditingController(text: widget.account.institucion ?? '');
    _tipoSeleccionado = widget.account.tipo;
    _monedaSeleccionada = widget.account.moneda;
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _saldoController.dispose();
    _institucionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark().copyWith(
        dialogTheme: const DialogThemeData(
          backgroundColor: Color(0xFF2D2D2D),
        ),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF13BB67),
          surface: Color(0xFF2D2D2D),
        ),
      ),
      child: AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Editar Cuenta'),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nombreController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre de la cuenta *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'El nombre es obligatorio';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _tipoSeleccionado,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de cuenta *',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'efectivo', child: Text('Efectivo')),
                    DropdownMenuItem(value: 'debito', child: Text('Tarjeta de Débito')),
                    DropdownMenuItem(value: 'credito', child: Text('Tarjeta de Crédito')),
                    DropdownMenuItem(value: 'virtual', child: Text('Billetera Virtual')),
                    DropdownMenuItem(value: 'inversion', child: Text('Inversión')),
                    DropdownMenuItem(value: 'por_cobrar', child: Text('Por Cobrar')),
                    DropdownMenuItem(value: 'por_pagar', child: Text('Por Pagar')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _tipoSeleccionado = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _institucionController,
                  decoration: const InputDecoration(
                    labelText: 'Institución financiera',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _saldoController,
                        decoration: const InputDecoration(
                          labelText: 'Saldo actual *',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'El saldo es obligatorio';
                          }
                          if (double.tryParse(value.trim()) == null) {
                            return 'Ingrese un número válido';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _monedaSeleccionada,
                        decoration: const InputDecoration(
                          labelText: 'Moneda',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'PEN', child: Text('PEN')),
                          DropdownMenuItem(value: 'USD', child: Text('USD')),
                          DropdownMenuItem(value: 'EUR', child: Text('EUR')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _monedaSeleccionada = value!;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                final updatedAccount = widget.account.copyWith(
                  nombre: _nombreController.text.trim(),
                  tipo: _tipoSeleccionado,
                  saldo: double.parse(_saldoController.text.trim()),
                  moneda: _monedaSeleccionada,
                  institucion: _institucionController.text.trim().isEmpty
                      ? null
                      : _institucionController.text.trim(),
                );

                final result = await ref.read(accountsControllerProvider.notifier).updateAccount(updatedAccount);

                if (context.mounted) {
                  Navigator.pop(context, result.success);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(result.message),
                      backgroundColor: result.success ? const Color(0xFF13BB67) : Colors.red,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );

                  // Notificar que la cuenta fue actualizada
                  if (result.success && widget.onAccountUpdated != null) {
                    widget.onAccountUpdated!();
                  }
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF13BB67),
              foregroundColor: Colors.white,
            ),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}
