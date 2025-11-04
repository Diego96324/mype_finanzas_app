import 'package:flutter/material.dart';
import '../../../core/models/budget_period_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/budget_period_service.dart';
import '../../../core/utils/analytics_design_system.dart';

class DynamicBudgetSection extends StatefulWidget {
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
  State<DynamicBudgetSection> createState() => _DynamicBudgetSectionState();
}

class _DynamicBudgetSectionState extends State<DynamicBudgetSection> {
  final BudgetPeriodService _budgetService = BudgetPeriodService();
  BudgetPeriod? _currentBudget;
  bool _isLoading = true;
  BudgetPeriod? _previousBudget;

  @override
  void initState() {
    super.initState();
    _loadBudget();
  }

  @override
  void didUpdateWidget(DynamicBudgetSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedPeriod != widget.selectedPeriod ||
        oldWidget.currentMonth != widget.currentMonth ||
        oldWidget.currentYear != widget.currentYear) {
      _previousBudget = _currentBudget;
      _loadBudget();
    }
  }

  Future<void> _loadBudget() async {
    if (_previousBudget == null) {
      setState(() => _isLoading = true);
    }

    try {
      final authService = AuthService();
      final userId = authService.currentUserId;

      if (userId != null) {
        final budget = await _budgetService.getBudgetForPeriod(
          usuarioId: userId,
          periodo: _getPeriodType(),
          mes: widget.currentMonth,
          anio: widget.currentYear,
        );

        if (mounted) {
          setState(() {
            _currentBudget = budget;
            _isLoading = false;
            _previousBudget = null;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _previousBudget = null;
        });
      }
    }
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
    return _budgetService.getPeriodName(_getPeriodType());
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _previousBudget == null) {
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

    final double budgetAmount = _currentBudget?.monto ?? 0.0;
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
    final bool hasExistingBudget = _currentBudget != null && _currentBudget!.monto > 0;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        final TextEditingController budgetController = TextEditingController(
          text: hasExistingBudget ? _currentBudget!.monto.toStringAsFixed(0) : '',
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
                  final authService = AuthService();
                  final userId = authService.currentUserId;

                  if (userId != null) {
                    try {
                      final periodType = _getPeriodType();
                      if (periodType == 'mensual') {
                        await _budgetService.saveMonthlyBudget(
                          usuarioId: userId,
                          monto: monto,
                          mes: widget.currentMonth,
                          anio: widget.currentYear,
                        );
                      } else if (periodType == 'trimestral') {
                        await _budgetService.saveQuarterlyBudget(
                          usuarioId: userId,
                          monto: monto,
                          mes: widget.currentMonth,
                          anio: widget.currentYear,
                        );
                      } else if (periodType == 'anual') {
                        await _budgetService.saveYearlyBudget(
                          usuarioId: userId,
                          monto: monto,
                          anio: widget.currentYear,
                        );
                      }

                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext);
                        _loadBudget();
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
      final authService = AuthService();
      final userId = authService.currentUserId;

      if (userId != null) {
        try {
          await _budgetService.deleteBudget(
            usuarioId: userId,
            periodo: _getPeriodType(),
            mes: widget.currentMonth,
            anio: widget.currentYear,
            syncToOthers: true,
          );

          if (mounted) {
            _loadBudget();
            widget.onBudgetChanged();

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Presupuesto eliminado correctamente'),
                backgroundColor: Color(0xFF13BB67),
                behavior: SnackBarBehavior.floating,
              ),
            );
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
}

