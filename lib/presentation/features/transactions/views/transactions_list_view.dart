import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../data/models/transaction_model.dart';
import '../../../../../data/models/account_model.dart';
import '../../../shared/utils/currency_formatter.dart';
import 'transaction_detail_view.dart';
import '../controllers/transactions_controller.dart';
import '../../../../core/providers/account_providers.dart' as account_providers;

class TransactionsListView extends ConsumerStatefulWidget {
  const TransactionsListView({super.key});

  @override
  ConsumerState<TransactionsListView> createState() => _TransactionsListViewState();
}

class _TransactionsListViewState extends ConsumerState<TransactionsListView> {
  final ScrollController _scrollController = ScrollController();
  Timer? _loadMoreDebounce;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final ctrl = _scrollController;
    if (!ctrl.hasClients) return;
    final max = ctrl.position.maxScrollExtent;
    final current = ctrl.position.pixels;
    if (max - current < 400) {
      if (_loadMoreDebounce?.isActive ?? false) return;
      _loadMoreDebounce = Timer(const Duration(milliseconds: 300), () {
        final hasMore = ref.read(transactionsControllerProvider).hasMore;
        if (hasMore) ref.read(transactionsControllerProvider.notifier).loadMore();
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _loadMoreDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final state = ref.watch(transactionsControllerProvider);

    final stats = state.stats ?? {};
    final egresos = stats['egresos'] ?? 0.0;
    final ingresos = stats['ingresos'] ?? 0.0;
    final saldo = ingresos - egresos;

    return SafeArea(
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [colorScheme.surfaceContainerHighest, colorScheme.surface],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              border: Border(bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5), width: 1.5)),
            ),
            child: Row(
              children: [
                Expanded(child: _buildEnhancedStatCard(context, 'Gastos', egresos, Icons.receipt_long_rounded, Colors.redAccent, false)),
                const SizedBox(width: 10),
                Expanded(flex: 2, child: _buildEnhancedStatCard(context, 'Saldo Total', saldo, Icons.account_balance_wallet_rounded, saldo >= 0 ? const Color(0xFF10A05B) : const Color(0xFFFF9800), true)),
                const SizedBox(width: 10),
                Expanded(child: _buildEnhancedStatCard(context, 'Ingresos', ingresos, Icons.attach_money_rounded, Colors.greenAccent, false)),
              ],
            ),
          ),

          // Lista
          Expanded(
            child: Builder(builder: (context) {
              if (state.isLoading && state.transactions.isEmpty) {
                return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(color: colorScheme.primary), const SizedBox(height: 12), Text('Cargando transacciones...', style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.7)))]));
              }

              if (state.error != null) {
                return Center(child: Text(state.error!, style: TextStyle(color: colorScheme.error)));
              }

              final transactions = state.transactions;
              if (transactions.isEmpty) {
                return Center(child: Text('No hay transacciones', style: TextStyle(color: colorScheme.onSurface)));
              }

              final grouped = _groupTransactionsByDate(transactions);
              final showFooter = state.hasMore;

              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: grouped.length + (showFooter ? 1 : 0),
                itemBuilder: (context, idx) {
                  if (showFooter && idx == grouped.length) return const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Center(child: SizedBox(width: 28, height: 28, child: CircularProgressIndicator())));
                  final group = grouped[idx];
                  final date = group['date'] as DateTime;
                  final txList = group['transactions'] as List<AppTransaction>;

                  double dayIngresos = 0, dayEgresos = 0;
                  for (var tx in txList) {
                    if (tx.tipo == 'ingreso') {
                      dayIngresos += tx.monto;
                    } else if (tx.tipo == 'egreso') {
                      dayEgresos += tx.monto;
                    }
                  }

                  // Construir lista de widgets del grupo (separador año, fecha y filas)
                  final children = <Widget>[];
                  if (idx > 0 && date.year != (grouped[idx - 1]['date'] as DateTime).year) {
                    children.add(_buildYearSeparator(context, date.year));
                  }
                  children.add(_buildDateSeparator(context, date, dayEgresos, dayIngresos));
                  children.addAll(txList.map((t) => _buildTransactionItem(context, t, theme, colorScheme)));

                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(BuildContext context, AppTransaction t, ThemeData theme, ColorScheme colorScheme) {
    // Intentar usar la lista cacheada de cuentas
    final accountsAsync = ref.watch(account_providers.accountsStateProvider);
    Account? cached;
    accountsAsync.maybeWhen(data: (list) { for (final a in list) { if (a.id == t.cuentaId) { cached = a; break; } } }, orElse: () {});

    if (cached != null) {
      final isPasivo = cached!.isPasivo == true;
      final meta = _decideVisuals(t, isPasivo);
      return _buildTransactionTile(context, t, theme, colorScheme, meta.typeColor, meta.icon, meta.prefix);
    }

    // Fallback: cargar cuenta
    final accountRepo = ref.read(account_providers.accountRepositoryProvider);
    return FutureBuilder<dynamic>(
      future: t.cuentaId != null ? accountRepo.getAccountById(t.cuentaId!) : Future.value(null),
      builder: (context, snap) {
        final acc = snap.data;
        final isPasivo = acc != null && (acc.isPasivo == true);
        final meta = _decideVisuals(t, isPasivo);
        return _buildTransactionTile(context, t, theme, colorScheme, meta.typeColor, meta.icon, meta.prefix);
      },
    );
  }

  // Visual decision helper
  _VisualMeta _decideVisuals(AppTransaction t, bool isPasivo) {
    if (t.esAperturaCuenta) return _VisualMeta(Colors.blueAccent, Icons.account_balance_wallet_rounded, '');
    if (isPasivo) return _VisualMeta(Colors.redAccent, Icons.trending_down_rounded, '-');
    switch (t.tipo) {
      case 'ingreso': return _VisualMeta(Colors.greenAccent, Icons.trending_up_rounded, '+');
      case 'egreso': return _VisualMeta(Colors.redAccent, Icons.trending_down_rounded, '-');
      case 'transferencia': return _VisualMeta(Colors.blueAccent, Icons.compare_arrows_rounded, '');
      default: return _VisualMeta(Colors.blueAccent, Icons.account_balance_wallet_rounded, '');
    }
  }

  Widget _buildTransactionTile(BuildContext context, AppTransaction t, ThemeData theme, ColorScheme colorScheme, Color typeColor, IconData leadingIcon, String amountPrefix) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: typeColor.withValues(alpha: 0.35), width: 1.5),
      ),
      child: ListTile(
        onTap: () async {
          if (t.esAperturaCuenta && t.cuentaId != null) {
            await _navigateToAccountSettings(context, t.cuentaId!);
          } else {
            await Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(builder: (_) => TransactionDetailScreen(tx: t)));
          }
        },
        leading: CircleAvatar(backgroundColor: typeColor.withValues(alpha: 0.15), child: Icon(t.esAperturaCuenta ? Icons.account_balance_wallet_rounded : leadingIcon, color: typeColor)),
        title: Text(t.etiqueta ?? 'Sin etiqueta', style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w600)),
        subtitle: t.nota != null && t.nota!.isNotEmpty ? Text(t.nota!, style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.6))) : null,
        trailing: Text('${amountPrefix}S/. ${CurrencyFormatter.formatAmount(t.monto)}', style: TextStyle(color: typeColor, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // Helpers UI
  Widget _buildEnhancedStatCard(BuildContext context, String label, double amount, IconData icon, Color color, bool isHighlighted) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: EdgeInsets.all(isHighlighted ? 14 : 12),
      decoration: BoxDecoration(
        color: isHighlighted ? null : colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withValues(alpha: isHighlighted ? 0.35 : 0.25),
          width: isHighlighted ? 2 : 1.5,
        ),
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
            child: Icon(icon, color: color, size: isHighlighted ? 28 : 20),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: colorScheme.onSurface.withValues(alpha: 0.65),
              fontSize: isHighlighted ? 11 : 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'S/. ${CurrencyFormatter.formatAmount(amount)}',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
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
      grouped.putIfAbsent(dateKey, () => []).add(tx);
    }
    final result = grouped.entries.map((e) => {'date': DateTime.parse(e.key), 'transactions': e.value}).toList();
    result.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));
    return result;
  }

  Widget _buildYearSeparator(BuildContext context, int year) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(margin: const EdgeInsets.symmetric(vertical: 12), child: Center(child: Text(year.toString(), style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.4)))));
  }

  Widget _buildDateSeparator(BuildContext context, DateTime date, double dayEgresos, double dayIngresos) {
    final colorScheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
    final isYesterday = date.year == now.year && date.month == now.month && date.day == now.day - 1;
    final dateStr = isToday ? 'Hoy' : (isYesterday ? 'Ayer' : '${date.day}/${date.month}');
    return Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), child: Row(children: [Expanded(child: Text(dateStr, style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold))), if (dayEgresos > 0) Text('S/. ${CurrencyFormatter.formatAmount(dayEgresos)}', style: TextStyle(color: Colors.redAccent)), if (dayIngresos > 0) Padding(padding: const EdgeInsets.only(left: 8), child: Text('S/. ${CurrencyFormatter.formatAmount(dayIngresos)}', style: TextStyle(color: Colors.greenAccent))) ]));
  }

  Future<void> _navigateToAccountSettings(BuildContext context, int accountId) async {
    final accountRepo = ref.read(account_providers.accountRepositoryProvider);
    final account = await accountRepo.getAccountById(accountId);
    if (account == null || !context.mounted) return;
    await showDialog(context: context, builder: (_) => AlertDialog(title: Text(account.nombre), content: Text('Saldo: ${account.saldo}'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar'))]));
  }
}

class _VisualMeta {
  final Color typeColor;
  final IconData icon;
  final String prefix;
  _VisualMeta(this.typeColor, this.icon, this.prefix);
}
