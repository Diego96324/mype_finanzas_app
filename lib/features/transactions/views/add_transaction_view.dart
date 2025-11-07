import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/transaction_model.dart';
import '../../../core/theme/date_picker_theme.dart';
import '../controllers/transactions_controller.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  final AppTransaction? baseTx;
  final DateTime? initialDate;
  final DateTimeRange? allowedDateRange;

  const AddTransactionScreen({
    super.key,
    this.baseTx,
    this.initialDate,
    this.allowedDateRange,
  });

  @override
  ConsumerState<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  late String _tipo;
  late DateTime _fecha;
  final _montoCtrl = TextEditingController();
  final _etiquetaCtrl = TextEditingController();
  final _notaCtrl = TextEditingController();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    final base = widget.baseTx;
    _tipo = base?.tipo ?? 'egreso';
    _fecha = widget.initialDate ?? DateTime.now();
    _montoCtrl.text = base?.monto.toStringAsFixed(2) ?? '';
    _etiquetaCtrl.text = base?.etiqueta ?? '';
    _notaCtrl.text = base?.nota ?? '';

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _montoCtrl.dispose();
    _etiquetaCtrl.dispose();
    _notaCtrl.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _pickFecha() async {
    final firstDate = widget.allowedDateRange?.start ?? DateTime(2010);
    final lastDate = widget.allowedDateRange?.end ?? DateTime(2100);

    final picked = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: widget.allowedDateRange != null
          ? 'Selecciona fecha del período'
          : 'Selecciona la fecha',
      locale: const Locale('es', 'PE'),
      builder: (context, child) {
        return Theme(
          data: AppDatePickerTheme.darkDatePickerTheme(context),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _fecha = picked);
  }

  Future<void> _guardar() async {
    if (_formKey.currentState?.validate() != true) return;

    final monto = double.tryParse(_montoCtrl.text.replaceAll(',', '.')) ?? 0;

    final transaction = AppTransaction(
      usuarioId: 0, // El controlador asignará el ID correcto
      fecha: _fecha,
      tipo: _tipo,
      monto: monto,
      etiqueta: _etiquetaCtrl.text.trim().isEmpty ? null : _etiquetaCtrl.text.trim(),
      nota: _notaCtrl.text.trim().isEmpty ? null : _notaCtrl.text.trim(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final success = await ref.read(transactionsControllerProvider.notifier).saveTransaction(transaction);

    if (mounted) {
      if (success) {
        Navigator.pop(context, true);
      } else {
        final errorMessage = ref.read(transactionsControllerProvider).error ?? 'Error al guardar transacción';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final typeColor = _tipo == 'ingreso' ? Colors.greenAccent : Colors.redAccent;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Registrar transacción',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: typeColor.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Text(
                            'Tipo de transacción',
                            style: TextStyle(
                              color: colorScheme.onSurface.withValues(alpha: 0.7),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTypeButton(
                                context,
                                'Ingreso',
                                Icons.arrow_upward_rounded,
                                Colors.greenAccent,
                                _tipo == 'ingreso',
                                () => setState(() => _tipo = 'ingreso'),
                              ),
                            ),
                            Expanded(
                              child: _buildTypeButton(
                                context,
                                'Egreso',
                                Icons.arrow_downward_rounded,
                                Colors.redAccent,
                                _tipo == 'egreso',
                                () => setState(() => _tipo = 'egreso'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  _buildTextField(
                    context,
                    controller: _montoCtrl,
                    label: 'Monto',
                    hint: '0.00',
                    icon: Icons.attach_money_rounded,
                    color: typeColor,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Ingrese un monto';
                      final num? parsed = num.tryParse(v.replaceAll(',', '.'));
                      if (parsed == null || parsed <= 0) return 'Ingrese un monto válido';
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  _buildTextField(
                    context,
                    controller: _etiquetaCtrl,
                    label: 'Etiqueta (opcional)',
                    hint: 'Ej: Ventas, Compras, Delivery…',
                    icon: Icons.label_rounded,
                    color: Colors.purpleAccent,
                    maxLength: 30,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(30),
                    ],
                  ),

                  const SizedBox(height: 16),

                  _buildTextField(
                    context,
                    controller: _notaCtrl,
                    label: 'Nota (opcional)',
                    hint: 'Detalles adicionales...',
                    icon: Icons.note_rounded,
                    color: Colors.orangeAccent,
                    maxLines: null,
                  ),

                  const SizedBox(height: 20),

                  InkWell(
                    onTap: _pickFecha,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: theme.dividerColor,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.blueAccent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.calendar_today_rounded,
                              color: Colors.blueAccent,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Fecha',
                                  style: TextStyle(
                                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_fecha.day.toString().padLeft(2, '0')}/${_fecha.month.toString().padLeft(2, '0')}/${_fecha.year}',
                                  style: TextStyle(
                                    color: colorScheme.onSurface,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: colorScheme.onSurface.withValues(alpha: 0.4),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  Container(
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          typeColor,
                          typeColor.withValues(alpha: 0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: typeColor.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _guardar,
                        borderRadius: BorderRadius.circular(16),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_rounded, color: typeColor == Colors.greenAccent ? Colors.black : Colors.white),
                              const SizedBox(width: 8),
                              Text(
                                'Agregar Transacción',
                                style: TextStyle(
                                  color: typeColor == Colors.greenAccent ? Colors.black : Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeButton(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    bool isSelected,
    VoidCallback onTap,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? color : colorScheme.onSurface.withValues(alpha: 0.4),
              size: 28,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    BuildContext context, {
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required Color color,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    int? maxLines,
    int? maxLength,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.dividerColor,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          crossAxisAlignment: (maxLines ?? 1) > 1 ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: TextFormField(
                controller: controller,
                keyboardType: keyboardType,
                inputFormatters: inputFormatters,
                validator: validator,
                maxLines: maxLines,
                maxLength: maxLength,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  labelText: label,
                  labelStyle: TextStyle(
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                  hintText: hint,
                  hintStyle: TextStyle(
                    color: colorScheme.onSurface.withValues(alpha: 0.3),
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  counterText: '',
                  errorStyle: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

