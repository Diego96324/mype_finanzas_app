import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/analytics_design_system.dart';
import '../controllers/budget_period_controller.dart';

class DynamicBudgetSection extends ConsumerStatefulWidget {
  final String selectedPeriod;
  final int currentMonth;
  final int currentYear;
  final Map<String, double> summary;
  final VoidCallback onBudgetChanged;

  const DynamicBudgetSection({
    super.key,
    required this.selectedPeriod,
    required this.currentMonth,
    required this.currentYear,
    required this.summary,
    required this.onBudgetChanged,
  });

  @override
  ConsumerState<DynamicBudgetSection> createState() => _DynamicBudgetSectionState();
}

class _DynamicBudgetSectionState extends ConsumerState<DynamicBudgetSection> {
  // Creamos una key única para este presupuesto
  late BudgetPeriodKey _budgetKey;

  @override
  void initState() {
    super.initState();
    debugPrint('🔵 [DynamicBudgetSection] initState - selectedPeriod=${widget.selectedPeriod}, mes=${widget.currentMonth}, anio=${widget.currentYear}');

    // Creamos la key inicial
    _budgetKey = _createBudgetKey();
    debugPrint('   budgetKey=$_budgetKey');
  }

  @override
  void didUpdateWidget(DynamicBudgetSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedPeriod != widget.selectedPeriod ||
        oldWidget.currentMonth != widget.currentMonth ||
        oldWidget.currentYear != widget.currentYear) {
      debugPrint('🔵 [DynamicBudgetSection] didUpdateWidget - Cambio detectado');
      debugPrint('   Old: periodo=${oldWidget.selectedPeriod}, mes=${oldWidget.currentMonth}, anio=${oldWidget.currentYear}');
      debugPrint('   New: periodo=${widget.selectedPeriod}, mes=${widget.currentMonth}, anio=${widget.currentYear}');

      setState(() {
        _budgetKey = _createBudgetKey();
        debugPrint('   Nueva budgetKey=$_budgetKey');
      });
    }
  }

  BudgetPeriodKey _createBudgetKey() {
    final periodType = _getPeriodType();
    return BudgetPeriodKey(
      periodo: periodType,
      mes: widget.currentMonth,
      anio: widget.currentYear,
    );
  }

  String _getPeriodType() {
    switch (widget.selectedPeriod) {
      case 'trimestre':
        return 'trimestral';
      case 'año':
        return 'anual';
      default:
        return 'mensual';
    }
  }

  String _getBudgetTitle() {
    switch (_getPeriodType()) {
      case 'trimestral':
        return 'Presupuesto Trimestral';
      case 'anual':
        return 'Presupuesto Anual';
      default:
        return 'Presupuesto Mensual';
    }
  }

  @override
  Widget build(BuildContext context) {
    final budgetState = ref.watch(budgetPeriodControllerProvider(_budgetKey));

    debugPrint('🔍 [DynamicBudgetSection] build - key=$_budgetKey, isLoading=${budgetState.isLoading}, currentBudget=${budgetState.currentBudget?.monto ?? "null"}, error=${budgetState.error}');

    if (budgetState.isLoading) {
      debugPrint('   → Mostrando loading');
      return AnalyticsDesignSystem.buildCard(
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(AnalyticsDesignSystem.spacing32),
            child: CircularProgressIndicator(
              color: AnalyticsDesignSystem.primary,
            ),
          ),
        ),
      );
    }

    // Si hay error, mostrarlo
    if (budgetState.error != null) {
      debugPrint('   → Mostrando error: ${budgetState.error}');
      return AnalyticsDesignSystem.buildCard(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AnalyticsDesignSystem.spacing32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                const SizedBox(height: 16),
                Text(
                  budgetState.error!,
                  style: const TextStyle(color: Colors.redAccent),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    debugPrint('   → Renderizando presupuesto');
    final double budgetAmount = budgetState.currentBudget?.monto ?? 0.0;
    final double spent = widget.summary['gastos'] ?? 0.0;
    final double remaining = budgetAmount - spent;
    final double percentage = budgetAmount > 0 ? (spent / budgetAmount * 100).clamp(0, 100) : 0;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.0, 0.05),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          ),
        );
      },
      child: Container(
        key: ValueKey('budget_${_getPeriodType()}_${budgetAmount}_${widget.currentMonth}_${widget.currentYear}'),
        padding: const EdgeInsets.all(AnalyticsDesignSystem.spacing20),
        decoration: BoxDecoration(
          color: AnalyticsDesignSystem.backgroundSecondary,
          borderRadius: BorderRadius.circular(AnalyticsDesignSystem.radiusMedium),
          border: Border.all(
            color: budgetAmount > 0
                ? (remaining >= 0
                    ? AnalyticsDesignSystem.primary.withValues(alpha: 0.3)
                    : AnalyticsDesignSystem.danger.withValues(alpha: 0.3))
                : AnalyticsDesignSystem.primary.withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: AnalyticsDesignSystem.shadowMedium,
        ),
        child: budgetAmount > 0
            ? _buildConfiguredBudget(budgetAmount, spent, remaining, percentage)
            : _buildNoBudgetState(),
      ),
    );
  }

  Widget _buildConfiguredBudget(double budgetAmount, double spent, double remaining, double percentage) {
    final isOverBudget = remaining < 0;
    final statusColor = isOverBudget ? AnalyticsDesignSystem.danger : AnalyticsDesignSystem.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              _getBudgetTitle(),
              style: AnalyticsDesignSystem.h3.copyWith(fontSize: 16),
            ),

            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildActionButton(
                  icon: Icons.edit_outlined,
                  color: AnalyticsDesignSystem.primary,
                  onPressed: _showSetBudgetDialog,
                  tooltip: 'Editar',
                ),
                const SizedBox(width: AnalyticsDesignSystem.spacing8),
                _buildActionButton(
                  icon: Icons.delete_outline,
                  color: AnalyticsDesignSystem.danger,
                  onPressed: _showDeleteBudgetDialog,
                  tooltip: 'Eliminar',
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: AnalyticsDesignSystem.spacing20),

        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'S/ ${budgetAmount.toStringAsFixed(2)}',
            style: AnalyticsDesignSystem.kpiLarge.copyWith(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: AnalyticsDesignSystem.textPrimary,
              letterSpacing: -1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: AnalyticsDesignSystem.spacing20),

        Stack(
          alignment: Alignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AnalyticsDesignSystem.radiusMedium),
              child: LinearProgressIndicator(
                value: (percentage / 100).clamp(0.0, 1.0),
                minHeight: 28,
                backgroundColor: AnalyticsDesignSystem.backgroundPrimary,
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              ),
            ),
            Text(
              '${percentage.toStringAsFixed(0)}%',
              style: AnalyticsDesignSystem.h4.copyWith(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    offset: const Offset(0, 1),
                    blurRadius: 2,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AnalyticsDesignSystem.spacing20),

        Row(
          children: [
            Expanded(
              child: _buildStatBox(
                label: 'Gastado',
                amount: spent,
                icon: Icons.trending_down,
                color: AnalyticsDesignSystem.danger,
              ),
            ),
            const SizedBox(width: AnalyticsDesignSystem.spacing12),
            Expanded(
              child: _buildStatBox(
                label: isOverBudget ? 'Excedido' : 'Disponible',
                amount: remaining.abs(),
                icon: isOverBudget ? Icons.warning_amber : Icons.account_balance_wallet,
                color: statusColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AnalyticsDesignSystem.radiusSmall),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: IconButton(
        icon: Icon(icon, color: color, size: 18),
        onPressed: onPressed,
        tooltip: tooltip,
        padding: const EdgeInsets.all(AnalyticsDesignSystem.spacing8),
        constraints: const BoxConstraints(
          minWidth: 36,
          minHeight: 36,
        ),
      ),
    );
  }

  Widget _buildStatBox({
    required String label,
    required double amount,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(AnalyticsDesignSystem.spacing16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AnalyticsDesignSystem.radiusMedium),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: AnalyticsDesignSystem.spacing6),
              Expanded(
                child: Text(
                  label,
                  style: AnalyticsDesignSystem.kpiLabel.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AnalyticsDesignSystem.spacing8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              'S/ ${amount.toStringAsFixed(2)}',
              style: AnalyticsDesignSystem.kpiMedium.copyWith(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildNoBudgetState() {
    return Column(
      children: [
        Icon(
          Icons.account_balance_wallet_outlined,
          size: 64,
          color: AnalyticsDesignSystem.primary.withValues(alpha: 0.5),
        ),
        const SizedBox(height: AnalyticsDesignSystem.spacing16),
        Text(
          'Sin presupuesto configurado',
          style: AnalyticsDesignSystem.h4,
        ),
        const SizedBox(height: AnalyticsDesignSystem.spacing8),
        Text(
          'Establece un presupuesto ${_getBudgetTitle().toLowerCase()} para controlar tus gastos',
          textAlign: TextAlign.center,
          style: AnalyticsDesignSystem.bodySecondary,
        ),
        const SizedBox(height: AnalyticsDesignSystem.spacing24),
        ElevatedButton.icon(
          onPressed: _showSetBudgetDialog,
          icon: const Icon(Icons.add),
          label: const Text('Configurar Presupuesto'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AnalyticsDesignSystem.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(
              horizontal: AnalyticsDesignSystem.spacing24,
              vertical: AnalyticsDesignSystem.spacing12,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AnalyticsDesignSystem.radiusSmall),
            ),
          ),
        ),
      ],
    );
  }

  void _showSetBudgetDialog() {
    final budgetState = ref.read(budgetPeriodControllerProvider(_budgetKey));
    final bool hasExistingBudget = budgetState.currentBudget != null && budgetState.currentBudget!.monto > 0;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        final TextEditingController budgetController = TextEditingController(
          text: hasExistingBudget ? budgetState.currentBudget!.monto.toStringAsFixed(0) : '',
        );

        return AlertDialog(
          backgroundColor: const Color(0xFF2D2D2D),
          title: Text(
            hasExistingBudget ? 'Editar ${_getBudgetTitle()}' : 'Configurar ${_getBudgetTitle()}',
            style: const TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: budgetController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Monto del presupuesto ${_getPeriodType()}',
              labelStyle: const TextStyle(color: Colors.grey),
              hintText: _getHintText(),
              hintStyle: TextStyle(color: Colors.grey[600]),
              prefixText: 'S/ ',
              prefixStyle: const TextStyle(color: Colors.white),
              suffixIcon: budgetController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey),
                      onPressed: () {
                        budgetController.clear();
                      },
                    )
                  : null,
              enabledBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF13BB67)),
              ),
              focusedBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF13BB67), width: 2),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final text = budgetController.text.trim();
                final monto = double.tryParse(text);

                if (monto != null && monto > 0) {
                  // Usamos el controlador con la key única
                  final controller = ref.read(budgetPeriodControllerProvider(_budgetKey).notifier);

                  try {
                    final success = await controller.saveBudget(
                      monto: monto,
                      periodo: _budgetKey.periodo,
                      mes: _budgetKey.mes,
                      anio: _budgetKey.anio,
                    );

                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext);

                      if (success) {
                        widget.onBudgetChanged();

                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              hasExistingBudget
                                  ? 'Presupuesto actualizado correctamente'
                                  : 'Presupuesto configurado correctamente',
                            ),
                            backgroundColor: const Color(0xFF13BB67),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      } else {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Error al guardar el presupuesto'),
                            backgroundColor: Colors.redAccent,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    }
                  } catch (e) {
                    if (dialogContext.mounted) {
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Error al guardar el presupuesto'),
                          backgroundColor: Colors.redAccent,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  }
                } else {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Por favor ingresa un monto válido'),
                      backgroundColor: Colors.redAccent,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF13BB67)),
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  String _getHintText() {
    switch (_getPeriodType()) {
      case 'trimestral':
        return 'Ej: 15000 (para 3 meses)';
      case 'anual':
        return 'Ej: 60000 (para 12 meses)';
      default:
        return 'Ej: 5000';
    }
  }

  void _showDeleteBudgetDialog() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF2D2D2D),
        title: Text('Eliminar ${_getBudgetTitle()}', style: const TextStyle(color: Colors.white)),
        content: Text(
          '¿Estás seguro de que deseas eliminar el presupuesto ${_getPeriodType()}?',
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
      ),
    );

    if (confirm == true) {
      // Usamos el controlador con la key única
      final controller = ref.read(budgetPeriodControllerProvider(_budgetKey).notifier);

      try {
        final success = await controller.deleteBudget(
          periodo: _budgetKey.periodo,
          mes: _budgetKey.mes,
          anio: _budgetKey.anio,
        );

        if (mounted) {
          widget.onBudgetChanged();

          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Presupuesto eliminado correctamente'),
                backgroundColor: Color(0xFF13BB67),
                behavior: SnackBarBehavior.floating,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Error al eliminar el presupuesto'),
                backgroundColor: Colors.redAccent,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error al eliminar el presupuesto'),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }
}
