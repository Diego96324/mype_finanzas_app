import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/dtos/transaction_model.dart';
import '../../models/dtos/account_model.dart';
import '../../core/utils/currency_formatter.dart';
import 'transaction_detail_view.dart';
import '../../controllers/transactions/transactions_controller.dart';
import '../../core/providers/account_providers.dart' as account_providers;

class TransactionsListView extends ConsumerStatefulWidget {
  const TransactionsListView({super.key});

  @override
  ConsumerState<TransactionsListView> createState() => _TransactionsListViewState();
}

class _TransactionsListViewState extends ConsumerState<TransactionsListView> {
  final ScrollController _scrollController = ScrollController();
  late final PageController _statsPageController;
  Timer? _loadMoreDebounce;
  double _currentStatsPage = 0;

  @override
  void initState() {
    super.initState();

    const initialVirtualPage = 1000; // grande para simular loop infinito

    _statsPageController = PageController(
      viewportFraction: 0.55, // ≈ 3 tarjetas visibles
      initialPage: initialVirtualPage,
    )..addListener(() {
        setState(() {
          _currentStatsPage = _statsPageController.page ?? 0;
        });
      });

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
    _statsPageController.dispose();
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

    final statCards = [
      _StatCardData(
        'Gastos',
        egresos,
        Icons.trending_down_rounded,
        const Color(0xFFE74C3C), // rojo
        false,
      ),
      _StatCardData(
        'Saldo Total',
        saldo,
        Icons.account_balance_wallet_rounded,
        const Color(0xFF00B894), // verde turquesa
        true,
      ),
      _StatCardData(
        'Ingresos',
        ingresos,
        Icons.trending_up_rounded,
        const Color(0xFF2ECC71), // verde
        false,
      ),
    ];


    return SafeArea(
      child: Column(
        children: [
          // HEADER PREMIUM
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(bottom: 8, top: 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colorScheme.surfaceContainerHighest,
                  colorScheme.surface,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Carrusel
                SizedBox(
                  height: 130, // más compacto
                  child: PageView.builder(
                    controller: _statsPageController,
                    physics: const BouncingScrollPhysics(),
                    // itemCount SIN límite para simular infinito
                    itemBuilder: (context, index) {
                      // índice real (0,1,2) -> gastos / saldo / ingresos
                      final realIndex = index % statCards.length;
                      final card = statCards[realIndex];

                      // página actual (puede ser 999.2, 1000.7, etc)
                      final currentPage = _currentStatsPage;

                      // distancia de esta página al centro
                      final delta = index - currentPage; // centro ≈ 0, lados ≈ -1 / +1
                      final clamped = delta.clamp(-1.0, 1.0);

                      // SOLO la tarjeta central se ve plana
                      const maxAngle = 0.25; // rad ≈ 20°
                      final isCenter = clamped.abs() < 0.001;

                      final rotationY = isCenter ? 0.0 : clamped.sign * maxAngle;
                      final scale = isCenter ? 1.0 : 0.85;
                      final opacity = isCenter ? 1.0 : 0.65;

                      return AnimatedOpacity(
                        duration: const Duration(milliseconds: 150),
                        opacity: opacity,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, 0.001) // perspectiva
                              ..multiply(Matrix4.diagonal3Values(scale, scale, scale))
                              ..rotateY(rotationY),
                            child: FractionallySizedBox(
                              widthFactor: 0.9, // más angostas de los costados
                              child: GestureDetector(
                                onTap: () {
                                  // animar a la página virtual tocada
                                  _statsPageController.animateToPage(
                                    index,
                                    duration: const Duration(milliseconds: 260),
                                    curve: Curves.easeOut,
                                  );
                                },
                                child: _buildEnhancedStatCard(
                                  context,
                                  card.label,
                                  card.amount,
                                  card.icon,
                                  card.color,
                                  card.isHighlighted,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 10),

                // Indicadores (premium)
                _buildCarouselIndicators(context, statCards.length),

                const SizedBox(height: 10),
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
    // Observar la cuenta asociada en tiempo real (si existe)
    final accAsync = t.cuentaId != null ? ref.watch(account_providers.accountByIdProvider(t.cuentaId!)) : null;

    if (accAsync != null) {
      return accAsync.when(
        data: (acc) {
          final isPasivo = acc != null && (acc.isPasivo == true);
          final meta = _decideVisuals(t, isPasivo);
          // Si la transacción es de apertura de cuenta, mostrar el saldo actual de la cuenta
          final displayAmount = (t.esAperturaCuenta && acc != null) ? acc.saldo : t.monto;
          // Crear un onTap que abra el diálogo de cuenta solo si la cuenta existe;
          // si no existe, abrir el detalle de la transacción en su lugar.
          void onTap() async {
            if (t.esAperturaCuenta && t.cuentaId != null && acc != null) {
              await showDialog(
                context: context,
                useRootNavigator: false,
                builder: (_) => AccountDetailDialog(accountId: t.cuentaId!),
              );
            } else {
              await Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(builder: (_) => TransactionDetailScreen(tx: t)));
            }
          }

          return _buildTransactionTile(context, t, theme, colorScheme, meta.typeColor, meta.icon, meta.prefix, displayAmount, onTap: onTap);
        },
        loading: () {
          // Mientras carga, mostrar la info basada en la transacción (evitar bloqueos)
          final meta = _decideVisuals(t, false);
          return _buildTransactionTile(context, t, theme, colorScheme, meta.typeColor, meta.icon, meta.prefix, t.monto);
        },
        error: (e, st) {
          final meta = _decideVisuals(t, false);
          return _buildTransactionTile(context, t, theme, colorScheme, meta.typeColor, meta.icon, meta.prefix, t.monto);
        },
      );
    }

    // Si no hay cuenta asociada, presentar por tipo de transacción
    final meta = _decideVisuals(t, false);
    return _buildTransactionTile(context, t, theme, colorScheme, meta.typeColor, meta.icon, meta.prefix, t.monto);
  }

  // Visual decision helper
  _VisualMeta _decideVisuals(AppTransaction t, bool isPasivo) {
    // Diferenciar transacción de apertura (cuentas) con color y prefijo específico
    if (t.esAperturaCuenta) return _VisualMeta(const Color(0xFF1565C0), Icons.account_balance_rounded, '');
    // Las cuentas pasivas (por pagar/credito) deben mostrarse como egresos: color naranja oscuro y prefijo '-'
    if (isPasivo) return _VisualMeta(const Color(0xFFD84315), Icons.trending_down_rounded, '-');
    switch (t.tipo) {
      case 'ingreso': return _VisualMeta(Colors.greenAccent, Icons.trending_up_rounded, '+');
      case 'egreso': return _VisualMeta(Colors.redAccent, Icons.trending_down_rounded, '-');
      case 'transferencia': return _VisualMeta(Colors.blueAccent, Icons.compare_arrows_rounded, '');
      default: return _VisualMeta(Colors.blueAccent, Icons.account_balance_wallet_rounded, '');
    }
  }

  Widget _buildTransactionTile(BuildContext context, AppTransaction t, ThemeData theme, ColorScheme colorScheme, Color typeColor, IconData leadingIcon, String amountPrefix, double displayAmount, {VoidCallback? onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: typeColor.withValues(alpha: 0.35),
          width: 1.5,
        ),
      ),
      child: ListTile(
        onTap: onTap ?? () async {
          // Comportamiento por defecto: si es apertura de cuenta intentamos abrir la cuenta;
          // si la cuenta ya no existe, el caller debería pasar un onTap alternativo.
          if (t.esAperturaCuenta && t.cuentaId != null) {
            await showDialog(
              context: context,
              useRootNavigator: false,
              builder: (_) => AccountDetailDialog(accountId: t.cuentaId!),
            );
          } else {
            await Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(builder: (_) => TransactionDetailScreen(tx: t)));
          }
        },
        leading: CircleAvatar(backgroundColor: typeColor.withValues(alpha: 0.15), child: Icon(t.esAperturaCuenta ? Icons.account_balance_wallet_rounded : leadingIcon, color: typeColor)),
        title: Text(t.etiqueta ?? 'Sin etiqueta', style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w600)),
        subtitle: t.nota != null && t.nota!.isNotEmpty ? Text(t.nota!, style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.6))) : null,
        trailing: Text('${amountPrefix}S/. ${CurrencyFormatter.formatAmount(displayAmount)}', style: TextStyle(color: typeColor, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // Helpers UI
  Widget _buildEnhancedStatCard(
    BuildContext context,
    String label,
    double amount,
    IconData icon,
    Color color,        // color propio de la tarjeta (gastos, saldo, ingresos)
    bool isHighlighted, // lo dejamos por si quieres usarlo luego
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF25262C),
            Color(0xFF18191D),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.9),
          width: 1.2,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // ICONO (más chico)
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme.onSurface.withValues(alpha: 0.06),
            ),
            child: Icon(
              icon,
              size: 20,
              color: colorScheme.onSurface.withValues(alpha: 0.9),
            ),
          ),

          // LABEL (un poco más chico)
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface.withValues(alpha: 0.9),
            ),
          ),

          // MONTO (compacto pero claro)
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'S/. ${CurrencyFormatter.formatAmount(amount)}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCarouselIndicators(BuildContext context, int length) {
    final colorScheme = Theme.of(context).colorScheme;

    // página actual real (0..length-1)
    final raw = _currentStatsPage.round();
    final currentIndex = ((raw % length) + length) % length;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(length, (index) {
        final isActive = index == currentIndex;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          height: 6,
          width: isActive ? 22 : 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: isActive
                ? colorScheme.primary
                : colorScheme.outlineVariant.withValues(alpha: 0.7),
          ),
        );
      }),
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
} // <-- cierre de _TransactionsListViewState

// Widget de diálogo que muestra y permite editar la cuenta en tiempo real usando providers
class AccountDetailDialog extends ConsumerStatefulWidget {
  final int accountId;
  const AccountDetailDialog({super.key, required this.accountId});

  @override
  ConsumerState<AccountDetailDialog> createState() => _AccountDetailDialogState();
}

class _AccountDetailDialogState extends ConsumerState<AccountDetailDialog> {
  TextEditingController? _nombreC;
  TextEditingController? _saldoC;
  TextEditingController? _numeroFinC;
  TextEditingController? _institucionC;
  String? _tipoSelected;
  bool _saving = false;

  // Tipos oficiales de cuentas con etiqueta amigable (coinciden con los usados en la pantalla de Cuentas)
  static const Map<String, String> _accountTypeLabels = {
    'efectivo': 'Efectivo',
    'debito': 'Tarjeta de Débito',
    'credito': 'Tarjeta de Crédito',
    'virtual': 'Billetera Virtual',
    'inversion': 'Inversión',
    'por_cobrar': 'Por Cobrar',
    'por_pagar': 'Por Pagar',
  };

  @override
  void dispose() {
    _nombreC?.dispose();
    _saldoC?.dispose();
    _numeroFinC?.dispose();
    _institucionC?.dispose();
    super.dispose();
  }

  void _initControllersIfNeeded(Account account) {
    if (_nombreC != null) return;
    _nombreC = TextEditingController(text: account.nombre);
    _saldoC = TextEditingController(text: account.saldo.toStringAsFixed(2));
    _numeroFinC = TextEditingController(text: account.numeroFin ?? '');
    _institucionC = TextEditingController(text: account.institucion ?? '');
    _tipoSelected = account.tipo;
  }

  Future<void> _onSave(Account account) async {
    if (_saving) return;
    setState(() => _saving = true);
    final nombre = _nombreC?.text.trim();
    final saldo = double.tryParse(_saldoC?.text.replaceAll(',', '') ?? '') ?? account.saldo;
    final numeroFin = _numeroFinC?.text.trim();
    final institucion = _institucionC?.text.trim();
    final tipo = _tipoSelected ?? account.tipo;

    final success = await ref.read(account_providers.accountsStateProvider.notifier).updateAccount(
      accountId: account.id!,
      nombre: nombre,
      tipo: tipo,
      saldo: saldo,
      numeroFin: numeroFin != '' ? numeroFin : null,
      institucion: institucion != '' ? institucion : null,
    );

    setState(() => _saving = false);

    if (success) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cuenta actualizada')));
      Navigator.of(context).pop();
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al actualizar la cuenta'), backgroundColor: Colors.redAccent));
    }
  }

  Future<void> _onDelete(Account account) async {
    // Capturar messenger antes de awaits
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar cuenta'),
        content: const Text('¿Estás seguro de eliminar esta cuenta? Si tiene transacciones asociadas, se desactivará.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Eliminar', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );

    if (confirmed != true) return;
    final success = await ref.read(account_providers.accountsStateProvider.notifier).deleteAccount(account.id!);
    if (success) {
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Cuenta eliminada')));
      // Cerrar el diálogo de detalle (si aún está montado)
      if (Navigator.of(context, rootNavigator: false).canPop()) Navigator.of(context).pop();
      // Invalidar provider de transacciones para forzar recarga en la lista
      try {
        ref.invalidate(transactionsControllerProvider);
      } catch (_) {}
    } else {
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Error al eliminar cuenta'), backgroundColor: Colors.redAccent));
    }
  }

  @override
  Widget build(BuildContext context) {
    final accAsync = ref.watch(account_providers.accountByIdProvider(widget.accountId));

    return accAsync.when(
      data: (account) {
        if (account == null) return AlertDialog(title: const Text('Cuenta no encontrada'), actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cerrar'))]);
        _initControllersIfNeeded(account);

        return AlertDialog(
          title: Text('Cuenta: ${account.nombre}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: _nombreC, decoration: const InputDecoration(labelText: 'Nombre')),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _tipoSelected,
                  items: _accountTypeLabels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                  onChanged: (v) => setState(() => _tipoSelected = v),
                  decoration: const InputDecoration(labelText: 'Tipo'),
                ),
                const SizedBox(height: 8),
                TextField(controller: _saldoC, decoration: const InputDecoration(labelText: 'Saldo'), keyboardType: TextInputType.numberWithOptions(decimal: true)),
                const SizedBox(height: 8),
                TextField(controller: _numeroFinC, decoration: const InputDecoration(labelText: 'Número/Referencia')),
                const SizedBox(height: 8),
                TextField(controller: _institucionC, decoration: const InputDecoration(labelText: 'Institución')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
            TextButton(onPressed: () => _onDelete(account), child: const Text('Eliminar', style: TextStyle(color: Colors.redAccent))),
            TextButton(
              onPressed: _saving ? null : () => _onSave(account),
              child: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Guardar'),
            ),

          ],
        );
      },
      loading: () => AlertDialog(content: SizedBox(height: 100, child: Center(child: CircularProgressIndicator()))),
      error: (e, st) => AlertDialog(title: const Text('Error'), content: Text(e.toString()), actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cerrar'))]),
    );
  }
}

class _VisualMeta {
  final Color typeColor;
  final IconData icon;
  final String prefix;
  _VisualMeta(this.typeColor, this.icon, this.prefix);
}


class _StatCardData {
  final String label;
  final double amount;
  final IconData icon;
  final Color color;
  final bool isHighlighted;

  _StatCardData(this.label, this.amount, this.icon, this.color, this.isHighlighted);
}
