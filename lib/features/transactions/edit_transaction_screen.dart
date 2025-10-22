import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/models/transaction_model.dart';
import '../../core/repos/transaction_repo.dart';

class EditTransactionScreen extends StatefulWidget {
  final AppTransaction tx;
  const EditTransactionScreen({super.key, required this.tx});

  @override
  State<EditTransactionScreen> createState() => _EditTransactionScreenState();
}

class _EditTransactionScreenState extends State<EditTransactionScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _repo = TransactionRepo();

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
    _tipo = widget.tx.tipo;
    _fecha = widget.tx.fecha;
    _montoCtrl.text = widget.tx.monto.toStringAsFixed(2);
    _etiquetaCtrl.text = widget.tx.etiqueta ?? '';
    _notaCtrl.text = widget.tx.nota ?? '';

    // Configurar animaciones
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
    final picked = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2010),
      lastDate: DateTime(2100),
      helpText: 'Selecciona la fecha',
      locale: const Locale('es', 'PE'),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: _tipo == 'ingreso' ? Colors.greenAccent : Colors.redAccent,
              surface: const Color(0xFF2A2A2A),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _fecha = picked);
  }

  Future<void> _guardar() async {
    if (_formKey.currentState?.validate() != true) return;
    final monto = double.tryParse(_montoCtrl.text.replaceAll(',', '.')) ?? 0;
    final updated = AppTransaction(
      id: widget.tx.id,
      usuarioId: widget.tx.usuarioId,
      categoriaId: widget.tx.categoriaId,
      fecha: _fecha,
      tipo: _tipo,
      monto: monto,
      etiqueta: _etiquetaCtrl.text.trim().isEmpty ? null : _etiquetaCtrl.text.trim(),
      nota: _notaCtrl.text.trim().isEmpty ? null : _notaCtrl.text.trim(),
      descripcion: widget.tx.descripcion,
      comprobanteUri: widget.tx.comprobanteUri,
      ubicacion: widget.tx.ubicacion,
      recurrente: widget.tx.recurrente,
      frecuenciaRecurrencia: widget.tx.frecuenciaRecurrencia,
      sincronizado: widget.tx.sincronizado,
      createdAt: widget.tx.createdAt,
      updatedAt: DateTime.now(),
    );
    await _repo.update(updated);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final typeColor = _tipo == 'ingreso' ? Colors.greenAccent : Colors.redAccent;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.grey[900],
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Editar transacción',
          style: TextStyle(
            color: Colors.white,
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
                  // Selector de tipo con diseño mejorado
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
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
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTypeButton(
                                'Ingreso',
                                Icons.arrow_upward_rounded,
                                Colors.greenAccent,
                                _tipo == 'ingreso',
                                () => setState(() => _tipo = 'ingreso'),
                              ),
                            ),
                            Expanded(
                              child: _buildTypeButton(
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

                  // Campo de monto
                  _buildTextField(
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

                  // Campo de etiqueta
                  _buildTextField(
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

                  // Campo de nota
                  _buildTextField(
                    controller: _notaCtrl,
                    label: 'Nota (opcional)',
                    hint: 'Detalles adicionales...',
                    icon: Icons.note_rounded,
                    color: Colors.orangeAccent,
                    maxLines: null,
                  ),

                  const SizedBox(height: 20),

                  // Selector de fecha
                  InkWell(
                    onTap: _pickFecha,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
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
                                    color: Colors.white.withValues(alpha: 0.6),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_fecha.day.toString().padLeft(2, '0')}/${_fecha.month.toString().padLeft(2, '0')}/${_fecha.year}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Botón de guardar cambios
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
                        child: const Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.save_rounded, color: Colors.black),
                              SizedBox(width: 8),
                              Text(
                                'Guardar cambios',
                                style: TextStyle(
                                  color: Colors.black,
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
    String label,
    IconData icon,
    Color color,
    bool isSelected,
    VoidCallback onTap,
  ) {
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
              color: isSelected ? color : Colors.white.withValues(alpha: 0.4),
              size: 28,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : Colors.white.withValues(alpha: 0.6),
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
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
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
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
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  labelText: label,
                  labelStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                  hintText: hint,
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3),
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
