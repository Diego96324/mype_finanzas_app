import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/models/transaction_model.dart';
import '../controllers/transactions_controller.dart';
import 'edit_transaction_view.dart';
import 'add_transaction_view.dart';

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

  String _fmtFecha(DateTime d) => DateFormat('dd/MM/yyyy', 'es_PE').format(d);
  String _fmtMoneda(num v) =>
      NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ').format(v);

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
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _refreshTx() async {
    await ref.read(transactionsControllerProvider.notifier).loadTransactions();

    _animationController.reset();
    _animationController.forward();
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
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  _buildInfoCard(
                    icon: Icons.calendar_today_rounded,
                    title: 'Fecha',
                    content: _fmtFecha(_tx.fecha),
                    color: Colors.blueAccent,
                  ),

                  const SizedBox(height: 12),
                  _buildInfoCard(
                    icon: Icons.label_rounded,
                    title: 'Etiqueta',
                    content: _tx.etiqueta != null && _tx.etiqueta!.trim().isNotEmpty
                        ? _tx.etiqueta!
                        : 'Sin etiqueta',
                    color: Colors.purpleAccent,
                  ),

                  const SizedBox(height: 12),
                  _buildInfoCard(
                    icon: Icons.note_rounded,
                    title: 'Nota',
                    content: _tx.nota != null && _tx.nota!.trim().isNotEmpty
                        ? _tx.nota!
                        : 'Sin nota',
                    color: Colors.orangeAccent,
                    isExpandable: true,
                  ),

                  const SizedBox(height: 32),

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

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String content,
    required Color color,
    bool isExpandable = false,
  }) {
    return Builder(
      builder: (context) {
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
                  child: Icon(
                    icon,
                    color: color,
                    size: 24,
                  ),
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
      },
    );
  }
}
