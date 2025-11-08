import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../data/models/transaction_model.dart';
import '../../accounts/widgets/edit_account_dialog.dart';
import '../../../shared/utils/currency_formatter.dart';
import 'transaction_detail_view.dart';
import '../controllers/transactions_controller.dart';

class TransactionsListView extends ConsumerStatefulWidget {
  const TransactionsListView({super.key});

  @override
  ConsumerState<TransactionsListView> createState() => _TransactionsListViewState();
}

class _TransactionsListViewState extends ConsumerState<TransactionsListView> {
  @override
  void initState() {
    super.initState();
    // El controlador ya carga las transacciones automáticamente

    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('🔍 [TransactionsListView] Página cargada');
    });
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final state = ref.watch(transactionsControllerProvider);

    ref.listen<TransactionsState>(
      transactionsControllerProvider,
      (previous, next) {
        debugPrint('🔍 [TransactionsListView] Estado cambió:');
        debugPrint('   - loading: ${next.isLoading}');
        debugPrint('   - transacciones: ${next.transactions.length}');
        debugPrint('   - error: ${next.error}');
      },
    );

    final stats = state.stats ?? {};
    final egresos = stats['egresos'] ?? 0.0;
    final ingresos = stats['ingresos'] ?? 0.0;
    final saldo = ingresos - egresos;

    return SafeArea(
      child: Container(
        color: theme.scaffoldBackgroundColor,
        child: Column(
          children: [
            // Header con estadísticas
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colorScheme.surfaceContainerHighest,
                    colorScheme.surface,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                border: Border(
                  bottom: BorderSide(
                    color: theme.dividerColor.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildEnhancedStatCard(
                      context,
                      'Gastos',
                      egresos,
                      Icons.receipt_long_rounded,
                      Colors.redAccent,
                      false,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: _buildEnhancedStatCard(
                      context,
                      'Saldo Total',
                      saldo,
                      Icons.account_balance_wallet_rounded,
                      saldo >= 0 ? const Color(0xFF10A05B) : const Color(0xFFFF9800),
                      true,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildEnhancedStatCard(
                      context,
                      'Ingresos',
                      ingresos,
                      Icons.attach_money_rounded,
                      Colors.greenAccent,
                      false,
                    ),
                  ),
                ],
              ),
            ),

            // Lista de transacciones
            Expanded(
              child: Container(
                color: theme.scaffoldBackgroundColor,
                child: Builder(
                  builder: (context) {
                    // Si está cargando y no hay datos, mostramos el loading
                    if (state.isLoading && state.transactions.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 40,
                              height: 40,
                              child: CircularProgressIndicator(
                                color: colorScheme.primary,
                                strokeWidth: 3,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Cargando transacciones...',
                              style: TextStyle(
                                color: colorScheme.onSurface.withValues(alpha: 0.7),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    // Si hay error, lo mostramos
                    if (state.error != null) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline_rounded,
                              color: colorScheme.error,
                              size: 48,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Error al cargar',
                              style: TextStyle(
                                color: colorScheme.onSurface,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              state.error!,
                              style: TextStyle(
                                color: colorScheme.onSurface.withValues(alpha: 0.6),
                                fontSize: 13,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }

                    final transactions = state.transactions;

                    // Si no hay transacciones, mostramos el estado vacío
                    if (transactions.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: colorScheme.primary.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.receipt_long_rounded,
                                size: 40,
                                color: colorScheme.primary.withValues(alpha: 0.5),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No hay transacciones',
                              style: TextStyle(
                                color: colorScheme.onSurface,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Toca el botón + para agregar una',
                              style: TextStyle(
                                color: colorScheme.onSurface.withValues(alpha: 0.6),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final groupedTransactions = _groupTransactionsByDate(transactions);

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      itemCount: groupedTransactions.length,
                      itemBuilder: (context, groupIndex) {
                        final group = groupedTransactions[groupIndex];
                        final date = group['date'] as DateTime;
                        final txList = group['transactions'] as List<AppTransaction>;

                        // Verificamos si hay cambio de año
                        final showYearSeparator = groupIndex > 0 &&
                            date.year != (groupedTransactions[groupIndex - 1]['date'] as DateTime).year;

                        double dayIngresos = 0;
                        double dayEgresos = 0;
                        for (var tx in txList) {
                          if (tx.tipo == 'ingreso') {
                            dayIngresos += tx.monto;
                          } else if (tx.tipo == 'egreso') {
                            dayEgresos += tx.monto;
                          }
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Separador de año si cambia
                            if (showYearSeparator)
                              _buildYearSeparator(context, date.year),

                            _buildDateSeparator(context, date, dayEgresos, dayIngresos),

                            ...txList.map((t) => _buildTransactionItem(context, t, theme, colorScheme)),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionItem(
    BuildContext context,
    AppTransaction t,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    // Si es una transacción de apertura de cuenta, usar color azul
    final Color typeColor;

    if (t.esAperturaCuenta) {
      typeColor = Colors.blueAccent;
    } else {
      switch (t.tipo) {
        case 'ingreso':
          typeColor = Colors.greenAccent;
          break;
        case 'egreso':
          typeColor = Colors.redAccent;
          break;
        default:
          typeColor = Colors.blueAccent;
      }
    }

    return Dismissible(
      key: Key('transaction_${t.id}'),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          // Verificar si es una transacción de apertura de cuenta
          if (t.esAperturaCuenta && t.cuentaId != null) {
            // Mostrar diálogo especial para transacciones de apertura
            final result = await _showDeleteAccountOpeningDialog(context, t);
            if (result == true && context.mounted) {
              final controller = ref.read(transactionsControllerProvider.notifier);
              final success = await controller.deleteAccountWithTransaction(t.cuentaId!);

              if (success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Cuenta y transacciones eliminadas'),
                    backgroundColor: Color(0xFF13BB67),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            }
            return false;
          }

          // Diálogo normal para transacciones regulares
          final confirm = await showDialog<bool>(
            context: context,
            builder: (BuildContext dialogContext) {
              return AlertDialog(
                backgroundColor: const Color(0xFF2D2D2D),
                title: const Text(
                  '¿Eliminar transacción?',
                  style: TextStyle(color: Colors.white),
                ),
                content: Text(
                  '¿Estás seguro de que deseas eliminar "${t.etiqueta ?? 'esta transacción'}"?',
                  style: const TextStyle(color: Colors.grey),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                    child: const Text('Eliminar'),
                  ),
                ],
              );
            },
          );

          if (confirm == true) {
            final controller = ref.read(transactionsControllerProvider.notifier);
            final success = await controller.deleteTransaction(t.id!);

            if (success && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Transacción eliminada'),
                  backgroundColor: Color(0xFF13BB67),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          }
          return false;
        } else if (direction == DismissDirection.startToEnd) {
          // Si es una transacción de apertura, ir a la configuración de la cuenta
          if (t.esAperturaCuenta && t.cuentaId != null) {
            await _navigateToAccountSettings(context, t.cuentaId!);
          } else {
            // Para transacciones normales, ir a los detalles de la transacción
            await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (_) => TransactionDetailScreen(tx: t),
              ),
            );
          }
          // El controlador se actualiza automáticamente
          return false;
        }
        return false;
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.blueAccent,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.edit_rounded, color: Colors.white, size: 28),
            SizedBox(height: 4),
            Text(
              'Editar',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      secondaryBackground: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.redAccent,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_rounded, color: Colors.white, size: 28),
            SizedBox(height: 4),
            Text(
              'Eliminar',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: typeColor.withValues(alpha: 0.35),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                // Si es una transacción de apertura, ir a la configuración de la cuenta
                if (t.esAperturaCuenta && t.cuentaId != null) {
                  await _navigateToAccountSettings(context, t.cuentaId!);
                } else {
                  // Para transacciones normales, ir a los detalles
                  await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TransactionDetailScreen(tx: t),
                    ),
                  );
                }
                // El controlador se actualiza automáticamente
              },
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: typeColor.withValues(alpha: 0.35),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        t.esAperturaCuenta
                            ? Icons.account_balance_wallet_rounded
                            : t.tipo == 'ingreso'
                                ? Icons.trending_up_rounded
                                : Icons.trending_down_rounded,
                        color: typeColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: t.etiqueta ?? 'Sin etiqueta',
                                        style: TextStyle(
                                          color: colorScheme.onSurface,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.1,
                                        ),
                                      ),
                                      if (t.esRecurrente || t.recurrente)
                                        WidgetSpan(
                                          alignment: PlaceholderAlignment.middle,
                                          child: Tooltip(
                                            message: _recurrenceTooltip(t),
                                            child: Padding(
                                              padding: const EdgeInsets.only(left: 6),
                                              child: Icon(
                                                Icons.autorenew_rounded,
                                                color: colorScheme.primary.withValues(alpha: 0.85),
                                                size: 14,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.left,
                                  softWrap: false,
                                ),
                              ),
                            ],
                          ),
                          if (t.nota != null && t.nota!.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              t.nota!,
                              style: TextStyle(
                                color: colorScheme.onSurface.withValues(alpha: 0.55),
                                fontSize: 12,
                                height: 1.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          'S/. ${CurrencyFormatter.formatAmount(t.monto)}',
                          style: TextStyle(
                            color: typeColor,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: colorScheme.onSurface.withValues(alpha: 0.45),
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedStatCard(
    BuildContext context,
    String label,
    double amount,
    IconData icon,
    Color color,
    bool isHighlighted,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: EdgeInsets.all(isHighlighted ? 14 : 12),
      decoration: BoxDecoration(
        gradient: isHighlighted
            ? LinearGradient(
                colors: [
                  color.withValues(alpha: 0.08),
                  color.withValues(alpha: 0.04),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isHighlighted ? null : colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withValues(alpha: isHighlighted ? 0.35 : 0.25),
          width: isHighlighted ? 2 : 1.5,
        ),
        boxShadow: isHighlighted
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.15),
                  blurRadius: 12,
                  spreadRadius: 1,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(isHighlighted ? 10 : 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: isHighlighted ? 28 : 20,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: colorScheme.onSurface.withValues(alpha: 0.65),
              fontSize: isHighlighted ? 11 : 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'S/. ${CurrencyFormatter.formatAmount(amount)}',
              style: TextStyle(
                color: color,
                fontSize: isHighlighted ? 16 : 13,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _groupTransactionsByDate(List<AppTransaction> transactions) {
    final Map<String, List<AppTransaction>> grouped = {};

    for (var tx in transactions) {
      final dateKey = '${tx.fecha.year}-${tx.fecha.month.toString().padLeft(2, '0')}-${tx.fecha.day.toString().padLeft(2, '0')}';
      if (!grouped.containsKey(dateKey)) {
        grouped[dateKey] = [];
      }
      grouped[dateKey]!.add(tx);
    }

    final result = grouped.entries.map((entry) {
      return {
        'date': DateTime.parse(entry.key),
        'transactions': entry.value,
      };
    }).toList();

    result.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));

    return result;
  }

  Widget _buildYearSeparator(BuildContext context, int year) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 0.5,
              color: colorScheme.onSurface.withValues(alpha: 0.15),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              year.toString(),
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.4),
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 0.5,
              color: colorScheme.onSurface.withValues(alpha: 0.15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSeparator(BuildContext context, DateTime date, double dayEgresos, double dayIngresos) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final now = DateTime.now();
    final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
    final isYesterday = date.year == now.year && date.month == now.month && date.day == now.day - 1;

    final months = [
      'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic'
    ];
    final weekdays = [
      'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'
    ];

    final dateStr = isToday
        ? 'Hoy'
        : isYesterday
            ? 'Ayer'
            : '${date.day} ${months[date.month - 1]} • ${weekdays[date.weekday - 1]}';

    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colorScheme.primaryContainer.withValues(alpha: 0.25),
                colorScheme.surface.withValues(alpha: 0.95),
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.15),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.calendar_today_rounded,
                  color: colorScheme.primary,
                  size: 14,
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                flex: 2,
                child: Text(
                  dateStr,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                    height: 1.0,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                ),
              ),
              if (dayEgresos > 0 || dayIngresos > 0) ...[
                const SizedBox(width: 8),
                Flexible(
                  flex: 3,
                  fit: FlexFit.loose,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (dayEgresos > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: Colors.redAccent.withValues(alpha: 0.15),
                                width: 0.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.arrow_downward_rounded,
                                  color: Colors.redAccent.withValues(alpha: 0.7),
                                  size: 10,
                                ),
                                const SizedBox(width: 2),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 70),
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      'S/. ${CurrencyFormatter.formatAmount(dayEgresos)}',
                                      style: TextStyle(
                                        color: Colors.redAccent.withValues(alpha: 0.85),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: -0.1,
                                        height: 1.0,
                                      ),
                                      maxLines: 1,
                                      softWrap: false,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (dayEgresos > 0 && dayIngresos > 0) const SizedBox(width: 4),
                        if (dayIngresos > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.greenAccent.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: Colors.greenAccent.withValues(alpha: 0.15),
                                width: 0.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.arrow_upward_rounded,
                                  color: Colors.greenAccent.withValues(alpha: 0.7),
                                  size: 10,
                                ),
                                const SizedBox(width: 2),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 70),
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      'S/. ${CurrencyFormatter.formatAmount(dayIngresos)}',
                                      style: TextStyle(
                                        color: Colors.greenAccent.withValues(alpha: 0.85),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: -0.1,
                                        height: 1.0,
                                      ),
                                      maxLines: 1,
                                      softWrap: false,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _navigateToAccountSettings(BuildContext context, int accountId) async {
    // Obtener la cuenta del repositorio
    final accountRepo = ref.read(accountRepositoryProvider);
    final account = await accountRepo.getAccountById(accountId);

    if (account == null || !context.mounted) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo cargar la cuenta'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    // Navegar a la pantalla de cuentas mostrando el detalle de esta cuenta
    // Necesitamos importar AccountsTab o la vista de cuentas
    // Por ahora, mostramos un diálogo con los detalles de la cuenta
    await showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2D2D2D),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.account_balance_wallet,
                  color: Colors.blue,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  account.nombre,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAccountDetailRow('Tipo', account.tipoDisplay),
              _buildAccountDetailRow('Saldo', '${account.moneda} ${CurrencyFormatter.formatAmount(account.saldo)}'),
              _buildAccountDetailRow('Saldo Inicial', '${account.moneda} ${CurrencyFormatter.formatAmount(account.saldoInicial)}'),
              if (account.institucion != null && account.institucion!.isNotEmpty)
                _buildAccountDetailRow('Institución', account.institucion!),
              if (account.numeroFin != null && account.numeroFin!.isNotEmpty)
                _buildAccountDetailRow('Número', account.numeroEnmascarado ?? ''),
              _buildAccountDetailRow('Incluir en Total', account.incluirEnTotal ? 'Sí' : 'No'),
              _buildAccountDetailRow('Estado', account.activa ? 'Activa' : 'Inactiva'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(
                'Cerrar',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(dialogContext);
                // Abrir el diálogo de edición de cuenta
                final result = await showDialog<bool>(
                  context: context,
                  builder: (_) => EditAccountDialog(
                    account: account,
                    onAccountUpdated: () {
                      // Recargar las transacciones cuando se actualice la cuenta
                      ref.read(transactionsControllerProvider.notifier).reloadAfterAccountUpdate();
                    },
                  ),
                );

                if (result == true && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Cuenta actualizada correctamente'),
                      backgroundColor: Color(0xFF13BB67),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.edit_rounded, size: 18),
              label: const Text('Editar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAccountDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showDeleteAccountOpeningDialog(BuildContext context, AppTransaction transaction) async {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2D2D2D),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.warning_rounded,
                  color: Colors.orange,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Cuenta Vinculada',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.blue.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.account_balance_wallet,
                      color: Colors.blue,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        transaction.etiqueta ?? 'Cuenta sin nombre',
                        style: const TextStyle(
                          color: Colors.blue,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Esta transacción representa la apertura de una cuenta.',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Al eliminarla, se borrará la cuenta y TODAS sus transacciones asociadas.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '¿Deseas continuar?',
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          actions: [
            // Botón para ir a la cuenta
            TextButton.icon(
              onPressed: () async {
                Navigator.pop(dialogContext, false);
                // Navegar a la configuración de la cuenta
                await _navigateToAccountSettings(context, transaction.cuentaId!);
              },
              icon: const Icon(Icons.visibility_rounded, size: 18),
              label: const Text('Ver Cuenta'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.blueAccent,
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.delete_rounded, size: 18),
              label: const Text('Eliminar Cuenta'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ],
        );
      },
    );
  }

  String _recurrenceTooltip(AppTransaction t) {
    final parts = <String>['Recurrente'];
    if (t.frecuenciaRecurrencia != null && t.frecuenciaRecurrencia!.isNotEmpty) {
      parts.add('• ${t.frecuenciaRecurrencia}');
    }
    if (t.recurrenceEndDate != null) {
      final d = t.recurrenceEndDate!;
      parts.add('hasta ${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}');
    }
    return parts.join(' ');
  }
}

