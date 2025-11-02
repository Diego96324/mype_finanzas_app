import 'package:flutter/material.dart';
import '../../../core/models/budget_period_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/budget_period_service.dart';

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
    // Cargando por primera vez
    if (_isLoading && _previousBudget == null) {
      return Container(
        key: const ValueKey('loading'),
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: const Color(0xFF2D2D2D),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF13BB67),
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
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF2D2D2D),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: budgetAmount > 0
                ? (remaining >= 0
                    ? const Color(0xFF13BB67).withValues(alpha: 0.3)
                    : Colors.redAccent.withValues(alpha: 0.3))
                : const Color(0xFF13BB67).withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: budgetAmount > 0
            ? _buildConfiguredBudget(budgetAmount, spent, remaining, percentage)
            : _buildNoBudgetState(),
      ),
    );
  }

  Widget _buildConfiguredBudget(double budgetAmount, double spent, double remaining, double percentage) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _getBudgetTitle(),
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
                  onPressed: _showDeleteBudgetDialog,
                  tooltip: 'Eliminar presupuesto',
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.edit, color: Color(0xFF13BB67), size: 22),
                  onPressed: _showSetBudgetDialog,
                  tooltip: 'Editar presupuesto',
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'S/ ${budgetAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: remaining >= 0
                    ? const Color(0xFF13BB67).withValues(alpha: 0.2)
                    : Colors.redAccent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${percentage.toStringAsFixed(0)}% usado',
                style: TextStyle(
                  color: remaining >= 0 ? const Color(0xFF13BB67) : Colors.redAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: percentage / 100,
            minHeight: 12,
            backgroundColor: const Color(0xFF1E1E1E),
            valueColor: AlwaysStoppedAnimation<Color>(
              remaining >= 0 ? const Color(0xFF13BB67) : Colors.redAccent,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _buildBudgetInfo('Gastado', spent, Icons.shopping_cart, Colors.redAccent),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildBudgetInfo(
                'Disponible',
                remaining,
                Icons.account_balance_wallet,
                remaining >= 0 ? const Color(0xFF13BB67) : Colors.redAccent,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBudgetInfo(String label, double amount, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              'S/ ${amount.toStringAsFixed(2)}',
              style: TextStyle(
                color: color,
                fontSize: 18,
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _getBudgetTitle(),
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, color: Color(0xFF13BB67), size: 26),
              onPressed: _showSetBudgetDialog,
              padding: const EdgeInsets.all(8),
              tooltip: 'Configurar presupuesto',
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'No configurado',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF13BB67).withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.info_outline,
                color: Color(0xFF13BB67),
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Configura un presupuesto ${_getPeriodType()} para controlar mejor tus gastos y alcanzar tus metas financieras.',
                  style: TextStyle(
                    color: Colors.grey[300],
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _showSetBudgetDialog,
            icon: const Icon(Icons.add),
            label: const Text('Configurar Presupuesto'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF13BB67),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
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
    // Capturar messenger antes de cualquier operación asíncrona
    final messenger = ScaffoldMessenger.of(context);

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

            messenger.showSnackBar(
              const SnackBar(
                content: Text('Presupuesto eliminado correctamente'),
                backgroundColor: Color(0xFF13BB67),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            messenger.showSnackBar(
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

