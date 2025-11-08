import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../../data/models/category_model.dart';
import '../../../../../data/models/transaction_model.dart';
import '../../../../core/providers/category_providers.dart';
import '../../../../core/theme/components/date_picker_theme.dart';
import '../../../../core/utils/attachments_helper.dart';
import '../../../../core/utils/form_validators.dart';
import '../controllers/transactions_controller.dart';

class EditTransactionScreen extends ConsumerStatefulWidget {
  final AppTransaction tx;
  const EditTransactionScreen({super.key, required this.tx});

  @override
  ConsumerState<EditTransactionScreen> createState() => _EditTransactionScreenState();
}

class _EditTransactionScreenState extends ConsumerState<EditTransactionScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  late String _tipo;
  late DateTime _fecha;
  final _montoCtrl = TextEditingController();
  final _etiquetaCtrl = TextEditingController();
  final _notaCtrl = TextEditingController();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  bool _recurrente = false;
  String _frecuencia = 'una_vez';
  final _intervaloCtrl = TextEditingController();
  DateTime? _fechaFinRecurrencia;

  String? _comprobantePath;
  bool _isPicking = false;

  int? _categoriaId;

  @override
  void initState() {
    super.initState();
    _tipo = widget.tx.tipo;
    _fecha = widget.tx.fecha;
    _montoCtrl.text = widget.tx.monto.toStringAsFixed(2);
    _etiquetaCtrl.text = widget.tx.etiqueta ?? '';
    _notaCtrl.text = widget.tx.nota ?? '';
    _categoriaId = widget.tx.categoriaId;

    // Inicializar recurrencia desde la transacción
    _recurrente = widget.tx.recurrente;
    _frecuencia = widget.tx.frecuenciaRecurrencia ?? 'una_vez';
    if (widget.tx.recurrenceIntervalDays != null) {
      _intervaloCtrl.text = widget.tx.recurrenceIntervalDays.toString();
    }
    _fechaFinRecurrencia = widget.tx.recurrenceEndDate;

    _comprobantePath = widget.tx.comprobanteUri;

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
    _intervaloCtrl.dispose();
    super.dispose();
  }

  DateTime? _computeNextOccurrence(DateTime base) {
    switch (_frecuencia) {
      case 'semanal':
        return base.add(const Duration(days: 7));
      case 'quincenal':
        return base.add(const Duration(days: 15));
      case 'mensual':
        return DateTime(base.year, base.month + 1, base.day, base.hour, base.minute, base.second);
      case 'personalizada':
        final n = int.tryParse(_intervaloCtrl.text.trim());
        if (n == null || n <= 0) return null;
        return base.add(Duration(days: n));
      default:
        return null;
    }
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
          data: AppDatePickerTheme.darkDatePickerTheme(context),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _fecha = picked);
  }

  Future<void> _pickComprobante(ImageSource source) async {
    if (_isPicking) return;
    setState(() => _isPicking = true);
    final old = _comprobantePath;
    final path = await AttachmentsHelper.pickAndSave(source: source);
    if (mounted) {
      setState(() {
        _comprobantePath = path;
        _isPicking = false;
      });
    }
    if (path != null && old != null && old != path) {
      await AttachmentsHelper.deleteAttachment(old);
    }
  }

  void _removeComprobante() async {
    final old = _comprobantePath;
    setState(() => _comprobantePath = null);
    await AttachmentsHelper.deleteAttachment(old);
  }

  Future<void> _guardar() async {
    if (_formKey.currentState?.validate() != true) return;
    final monto = double.tryParse(_montoCtrl.text.replaceAll(',', '.')) ?? 0;

    final frecuencia = _recurrente && _frecuencia != 'una_vez' ? _frecuencia : null;
    final int? intervalo = (_recurrente && _frecuencia == 'personalizada')
        ? int.tryParse(_intervaloCtrl.text.trim())
        : null;
    final next = (_recurrente && frecuencia != null) ? _computeNextOccurrence(_fecha) : null;

    final updated = AppTransaction(
      id: widget.tx.id,
      usuarioId: widget.tx.usuarioId,
      categoriaId: _categoriaId,
      fecha: _fecha,
      tipo: _tipo,
      monto: monto,
      etiqueta: _etiquetaCtrl.text.trim().isEmpty ? null : _etiquetaCtrl.text.trim(),
      nota: _notaCtrl.text.trim().isEmpty ? null : _notaCtrl.text.trim(),
      descripcion: widget.tx.descripcion,
      comprobanteUri: _comprobantePath,
      ubicacion: widget.tx.ubicacion,
      recurrente: _recurrente,
      esRecurrente: widget.tx.esRecurrente,
      frecuenciaRecurrencia: frecuencia,
      recurrenceIntervalDays: intervalo,
      recurrenceEndDate: _fechaFinRecurrencia,
      nextOccurrence: next,
      sincronizado: widget.tx.sincronizado,
      createdAt: widget.tx.createdAt,
      updatedAt: DateTime.now(),
    );

    final success = await ref.read(transactionsControllerProvider.notifier).updateTransaction(updated);

    if (mounted) {
      if (success) {
        Navigator.pop(context, true);
      } else {
        final errorMessage = ref.read(transactionsControllerProvider).error ?? 'Error al actualizar transacción';
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
          'Editar transacción',
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
                    maxLength: 40,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(40),
                    ],
                    validator: FormValidators.validateTag,
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
                    validator: FormValidators.validateNote,
                  ),

                  const SizedBox(height: 20),

                  _buildComprobanteSection(context),

                  const SizedBox(height: 20),
                  // Fecha de la transacción
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

                  const SizedBox(height: 20),

                  // Categoría
                  _buildCategoryPicker(context),

                  const SizedBox(height: 20),

                  // Sección de recurrencia
                  _buildRecurrenceSection(context),

                  const SizedBox(height: 20),

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
                              Icon(Icons.save_rounded, color: typeColor == Colors.greenAccent ? Colors.black : Colors.white),
                              const SizedBox(width: 8),
                              Text(
                                'Guardar cambios',
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

  Widget _buildRecurrenceSection(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor, width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.autorenew_rounded, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Transacción recurrente',
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Switch(
                value: _recurrente,
                onChanged: (v) => setState(() {
                  _recurrente = v;
                  if (!v) {
                    _frecuencia = 'una_vez';
                    _intervaloCtrl.clear();
                    _fechaFinRecurrencia = null;
                  }
                }),
              ),
            ],
          ),

          if (_recurrente) const SizedBox(height: 12),

          if (_recurrente)
            DropdownButtonFormField<String>(
              initialValue: _frecuencia,
              decoration: const InputDecoration(
                labelText: 'Frecuencia',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'una_vez', child: Text('Una vez')),
                DropdownMenuItem(value: 'semanal', child: Text('Semanal')),
                DropdownMenuItem(value: 'quincenal', child: Text('Quincenal')),
                DropdownMenuItem(value: 'mensual', child: Text('Mensual')),
                DropdownMenuItem(value: 'personalizada', child: Text('Personalizada (en días)')),
              ],
              onChanged: (val) => setState(() => _frecuencia = val ?? 'una_vez'),
            ),

          if (_recurrente && _frecuencia == 'personalizada') const SizedBox(height: 12),

          if (_recurrente && _frecuencia == 'personalizada')
            TextFormField(
              controller: _intervaloCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Intervalo (días)',
                border: OutlineInputBorder(),
              ),
              validator: (val) {
                if (!_recurrente || _frecuencia != 'personalizada') return null;
                return FormValidators.validateRecurrenceInterval(val);
              },
            ),

          if (_recurrente) const SizedBox(height: 12),

          if (_recurrente)
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _fechaFinRecurrencia ?? _fecha,
                  firstDate: _fecha,
                  lastDate: DateTime(2100),
                  helpText: 'Fecha fin (opcional)',
                );
                if (picked != null) setState(() => _fechaFinRecurrencia = picked);
              },
              child: Row(
                children: [
                  Icon(Icons.event, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Fecha fin (opcional)',
                          style: TextStyle(
                            color: colorScheme.onSurface.withValues(alpha: 0.6),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _fechaFinRecurrencia == null
                              ? 'Sin fecha fin'
                              : '${_fechaFinRecurrencia!.day.toString().padLeft(2, '0')}/${_fechaFinRecurrencia!.month.toString().padLeft(2, '0')}/${_fechaFinRecurrencia!.year}',
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_fechaFinRecurrencia != null)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _fechaFinRecurrencia = null),
                    ),
                ],
              ),
            ),

          if (_recurrente)
            Builder(
              builder: (context) {
                final err = FormValidators.validateRecurrenceEnd(_fecha, _fechaFinRecurrencia);
                if (err == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    err,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildComprobanteSection(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor, width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.receipt_long, color: colorScheme.primary),
              const SizedBox(width: 8),
              const Text('Comprobante', style: TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              if (_comprobantePath != null)
                IconButton(
                  icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
                  tooltip: 'Eliminar',
                  onPressed: _removeComprobante,
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (_comprobantePath == null)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickComprobante(ImageSource.camera),
                    icon: const Icon(Icons.photo_camera),
                    label: const Text('Cámara'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickComprobante(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Galería'),
                  ),
                ),
              ],
            )
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  Image.file(
                    File(_comprobantePath!),
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.white),
                        onPressed: () => _pickComprobante(ImageSource.gallery),
                        tooltip: 'Reemplazar',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (_isPicking) const Padding(
            padding: EdgeInsets.only(top: 12.0),
            child: LinearProgressIndicator(minHeight: 3),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryPicker(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final categoriesAsync = ref.watch(categoriesStateProvider);
    String label;
    if (_categoriaId == null) {
      label = 'Sin categoría';
    } else {
      label = categoriesAsync.maybeWhen(
        data: (list) {
          final found = _findCategoryIn(list, _categoriaId!);
          return found?.nombre ?? 'Categoría no disponible';
        },
        orElse: () => '—',
      );
    }

    return InkWell(
      onTap: () => _openCategorySheet(context),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.dividerColor, width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.tealAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.category_rounded,
                color: Colors.tealAccent,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Categoría',
                    style: TextStyle(
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
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
    );
  }

  void _openCategorySheet(BuildContext context) async {
    final categoriesAsync = ref.read(categoriesStateProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    await showModalBottomSheet<int?>(
      context: context,
      backgroundColor: theme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: categoriesAsync.when(
              data: (list) {
                return ListView(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.clear, color: Colors.grey),
                      title: const Text('Sin categoría'),
                      onTap: () => Navigator.pop(ctx, null),
                    ),
                    const Divider(),
                    ...list.map((cat) => _buildCategoryTile(ctx, cat, colorScheme)),
                  ],
                );
              },
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
              error: (error, stack) => const Center(child: Padding(padding: EdgeInsets.all(16), child: Text('No se pudieron cargar las categorías'))),
            ),
          ),
        );
      },
    ).then((selectedId) {
      if (!mounted) return;
      setState(() => _categoriaId = selectedId);
    });
  }

  Widget _buildCategoryTile(BuildContext ctx, Category cat, ColorScheme colorScheme) {
    return ExpansionTile(
      leading: const Icon(Icons.folder_rounded, color: Colors.tealAccent),
      title: Text(cat.nombre, style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w600)),
      children: [
        ListTile(
          leading: const Icon(Icons.label_rounded, color: Colors.tealAccent),
          title: Text(cat.nombre),
          onTap: () => Navigator.pop(ctx, cat.id),
        ),
        if ((cat.subcategorias ?? []).isNotEmpty)
          ...cat.subcategorias!.map(
            (sub) => ListTile(
              leading: const Icon(Icons.subdirectory_arrow_right_rounded, color: Colors.tealAccent),
              title: Text(sub.nombre),
              onTap: () => Navigator.pop(ctx, sub.id),
            ),
          ),
      ],
    );
  }

  Category? _findCategoryIn(List<Category> list, int id) {
    for (final c in list) {
      if (c.id == id) return c;
      for (final s in c.subcategorias ?? []) {
        if (s.id == id) return s;
      }
    }
    return null;
  }
}
