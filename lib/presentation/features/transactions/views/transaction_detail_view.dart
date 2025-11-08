import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/providers/category_providers.dart';
import '../../../../../data/models/transaction_model.dart';
import '../../../../../data/models/category_model.dart';
import '../controllers/transactions_controller.dart';
import 'edit_transaction_view.dart';
import 'add_transaction_view.dart';
import '../../../shared/utils/currency_formatter.dart';

class TransactionDetailScreen extends ConsumerStatefulWidget {
  final AppTransaction tx;
  const TransactionDetailScreen({super.key, required this.tx});

  @override
  ConsumerState<TransactionDetailScreen> createState() => _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends ConsumerState<TransactionDetailScreen> with SingleTickerProviderStateMixin {
  late AppTransaction _tx;
  bool _dirty = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  ProviderSubscription<TransactionsState>? _txSubscription;

  String _fmtFecha(DateTime d) => DateFormat('dd/MM/yyyy', 'es_PE').format(d);
  String _fmtMoneda(num v) => 'S/ ${CurrencyFormatter.formatAmount(v.toDouble())}';

  @override
  void initState() {
    super.initState();
    _tx = widget.tx;
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    
    _animationController.forward();

    // Escucha reactiva segura fuera de build
    _txSubscription = ref.listenManual<TransactionsState>(
      transactionsControllerProvider,
      (previous, next) {
        if (_tx.id == null) return;
        final found = next.transactions
            .where((t) => t.id == _tx.id)
            .cast<AppTransaction?>()
            .firstWhere(
              (t) => t != null,
              orElse: () => null,
            );
        if (found != null && found.updatedAt != _tx.updatedAt) {
          if (mounted) {
            setState(() {
              _tx = found;
            });
          }
        }
      },
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _txSubscription?.close();
    super.dispose();
  }

  Future<void> _refreshTx() async {
    await ref.read(transactionsControllerProvider.notifier).loadTransactions();

    // Buscar la transacción actualizada en el estado
    final transactionsState = ref.read(transactionsControllerProvider);
    final updatedTx = transactionsState.transactions.firstWhere(
      (t) => t.id == _tx.id,
      orElse: () => _tx,
    );

    setState(() {
      _tx = updatedTx;
    });

    _animationController.reset();
    _animationController.forward();
  }

  bool get _isRecurrent => (_tx.recurrente || _tx.esRecurrente) && (_tx.frecuenciaRecurrencia != null && _tx.frecuenciaRecurrencia != 'una_vez');
  String _recurrenceSummary() {
    final parts = <String>['Recurrente'];
    final freq = _displayFrequency(_tx.frecuenciaRecurrencia);
    if (freq != null && freq.isNotEmpty && freq != '—') {
      parts.add('• $freq');
    }
    if (_tx.recurrenceEndDate != null) {
      final d = _tx.recurrenceEndDate!;
      parts.add('hasta ${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}');
    }
    return parts.join(' ');
  }

  String? _displayFrequency(String? f) {
    if (f == null || f.trim().isEmpty) return null;
    final lower = f.toLowerCase();
    switch (lower) {
      case 'diaria':
        return 'Diaria';
      case 'semanal':
        return 'Semanal';
      case 'mensual':
        return 'Mensual';
      case 'anual':
        return 'Anual';
      case 'una_vez':
        return 'Una vez';
      case 'personalizado':
        return 'personalizado'; // excepción: mantener como definido
      default:
        // capitalizar primera letra como fallback
        return f[0].toUpperCase() + f.substring(1);
    }
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

  @override
  Widget build(BuildContext context) {
    final Color typeColor;
    final IconData typeIcon;
    final String typeLabel;
    
    switch (_tx.tipo) {
      case 'ingreso':
        typeColor = Colors.greenAccent;
        typeIcon = Icons.arrow_upward_rounded;
        typeLabel = 'INGRESO';
        break;
      case 'egreso':
        typeColor = Colors.redAccent;
        typeIcon = Icons.arrow_downward_rounded;
        typeLabel = 'EGRESO';
        break;
      default:
        typeColor = Colors.blueAccent;
        typeIcon = Icons.swap_horiz_rounded;
        typeLabel = 'TRANSFERENCIA';
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final categoriesAsync = ref.watch(categoriesStateProvider);
    String categoryContent;
    if (_tx.categoriaId == null) {
      categoryContent = 'Sin categoría';
    } else {
      categoryContent = categoriesAsync.maybeWhen(
        data: (list) => _findCategoryIn(list, _tx.categoriaId!)?.nombre ?? 'Categoría no disponible',
        orElse: () => '—',
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.pop(context, _dirty);
        }
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: theme.appBarTheme.backgroundColor,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
            onPressed: () => Navigator.pop(context, _dirty),
          ),
          title: Text(
            'Detalle de transacción',
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              tooltip: 'Editar',
              icon: Icon(Icons.edit_outlined, color: colorScheme.onSurface),
              onPressed: () async {
                final changed = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => EditTransactionScreen(tx: _tx)),
                );
                if (changed == true) {
                  _dirty = true;
                  await _refreshTx();
                }
              },
            ),

            IconButton(
              tooltip: 'Duplicar',
              icon: Icon(Icons.copy_outlined, color: colorScheme.onSurface),
              onPressed: () async {
                final saved = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddTransactionScreen(baseTx: _tx),
                  ),
                );
                if (saved == true && context.mounted) {
                  _dirty = true;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ Transacción duplicada correctamente')),
                  );
                  Navigator.pop(context, true);
                }
              },
            ),

            IconButton(
              tooltip: 'Eliminar',
              icon: Icon(Icons.delete_outline, color: colorScheme.onSurface),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    backgroundColor: theme.cardColor,
                    title: Text(
                      'Eliminar transacción',
                      style: TextStyle(color: colorScheme.onSurface),
                    ),
                    content: Text(
                      '¿Seguro que deseas eliminarla?',
                      style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.7)),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancelar'),
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                        ),
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Eliminar'),
                      ),
                    ],
                  ),
                );
                if (ok == true && _tx.id != null) {
                  final controller = ref.read(transactionsControllerProvider.notifier);
                  final success = await controller.deleteTransaction(_tx.id!);

                  if (context.mounted && success) {
                    Navigator.pop(context, true);
                  }
                }
              },
            ),
          ],
        ),
        body: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Resumen tipo/monto
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          typeColor.withValues(alpha: 0.3),
                          typeColor.withValues(alpha: 0.1),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: typeColor.withValues(alpha: 0.5),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: typeColor.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            typeIcon,
                            color: typeColor,
                            size: 30,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          typeLabel,
                          style: TextStyle(
                            color: typeColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _fmtMoneda(_tx.monto),
                          style: TextStyle(
                            color: typeColor,
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Chips de estado
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (_isRecurrent)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.35),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.autorenew_rounded, size: 16, color: Theme.of(context).colorScheme.primary),
                                    const SizedBox(width: 6),
                                    Text(
                                      _recurrenceSummary(),
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.primary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (!_tx.confirmada)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.orange.withValues(alpha: 0.35)),
                                ),
                                child: const Text(
                                  'Pendiente',
                                  style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Fecha
                  _buildInfoCard(
                    icon: Icons.calendar_today_rounded,
                    title: 'Fecha',
                    content: _fmtFecha(_tx.fecha),
                    color: Colors.blueAccent,
                  ),

                  const SizedBox(height: 12),

                  // Cuentas (para transferencias u operaciones con cuenta)
                  if (_tx.cuentaId != null)
                    _buildAccountCard(context, title: 'Cuenta origen', accountId: _tx.cuentaId!, color: Colors.lightBlueAccent),

                  if (_tx.cuentaId != null) const SizedBox(height: 12),

                  if (_tx.cuentaDestinoId != null)
                    _buildAccountCard(context, title: 'Cuenta destino', accountId: _tx.cuentaDestinoId!, color: Colors.indigoAccent),

                  if (_tx.cuentaDestinoId != null) const SizedBox(height: 12),

                  // Categoría
                  _buildInfoCard(
                    icon: Icons.category_rounded,
                    title: 'Categoría',
                    content: categoryContent,
                    color: Colors.tealAccent,
                  ),

                  const SizedBox(height: 12),
                  // Etiqueta
                  _buildLabelCard(context, colorScheme),

                  const SizedBox(height: 12),
                  // Nota
                  _buildInfoCard(
                    icon: Icons.note_rounded,
                    title: 'Nota',
                    content: _tx.nota != null && _tx.nota!.trim().isNotEmpty
                        ? _tx.nota!
                        : 'Sin nota',
                    color: Colors.orangeAccent,
                    isExpandable: true,
                  ),

                  const SizedBox(height: 12),

                  // Sección de recurrencia detallada
                  if (_isRecurrent) _buildRecurrenceSection(context),

                  const SizedBox(height: 12),

                  // Comprobante
                  if (_tx.comprobanteUri != null) _buildComprobanteSection(context, _tx.comprobanteUri!),

                  const SizedBox(height: 24),

                  if (_tx.id != null)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: colorScheme.onSurface.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: theme.dividerColor,
                          ),
                        ),
                        child: Text(
                          'ID: ${_tx.id}',
                          style: TextStyle(
                            color: colorScheme.onSurface.withValues(alpha: 0.4),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabelCard(BuildContext context, ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).dividerColor,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.purpleAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.label_rounded,
                color: Colors.purpleAccent,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Etiqueta',
                    style: TextStyle(
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: _tx.etiqueta != null && _tx.etiqueta!.trim().isNotEmpty ? _tx.etiqueta! : 'Sin etiqueta',
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        // Se elimina el icono de recurrencia en la etiqueta para evitar duplicar el indicador
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.left,
                    softWrap: false,
                  ),
                ],
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
            children: [
              Icon(Icons.autorenew_rounded, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Recurrencia',
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _rowInfo('Frecuencia', _displayFrequency(_tx.frecuenciaRecurrencia) ?? '—'),
          if (_tx.recurrenceIntervalDays != null) _rowInfo('Intervalo (días)', '${_tx.recurrenceIntervalDays}'),
          _rowInfo('Próxima ocurrencia', _tx.nextOccurrence != null ? _fmtFecha(_tx.nextOccurrence!) : '—'),
          _rowInfo('Fecha fin', _tx.recurrenceEndDate != null ? _fmtFecha(_tx.recurrenceEndDate!) : 'Sin límite'),
        ],
      ),
    );
  }

  Widget _rowInfo(String label, String value) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComprobanteSection(BuildContext context, String path) {
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
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (_) => Dialog(
                    backgroundColor: Colors.transparent,
                    child: InteractiveViewer(
                      panEnabled: true,
                      minScale: 0.5,
                      maxScale: 3,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(path),
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                );
              },
              child: Image.file(
                File(path),
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String content,
    required Color color,
    bool isExpandable = false,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: isExpandable ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    content,
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: isExpandable ? null : 1,
                    overflow: isExpandable ? null : TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountCard(BuildContext context, {required String title, required int accountId, required Color color}) {
    final repo = ref.read(accountRepositoryProvider);
    return FutureBuilder< dynamic /* Account? */ >(
      future: repo.getAccountById(accountId),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _buildInfoCard(
            icon: Icons.account_balance_wallet_rounded,
            title: title,
            content: 'Cargando...',
            color: color,
          );
        }
        final account = snapshot.data; // puede ser null si no existe
        final nombre = account != null ? account.nombre : 'No disponible';
        return _buildInfoCard(
          icon: Icons.account_balance_wallet_rounded,
          title: title,
          content: nombre,
          color: color,
        );
      },
    );
  }
}
