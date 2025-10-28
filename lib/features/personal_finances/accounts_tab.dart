import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/models/account_model.dart';
import '../../core/repos/account_repo.dart';
import '../../core/services/auth_service.dart';

class AccountsTab extends StatefulWidget {
  const AccountsTab({super.key});

  @override
  State<AccountsTab> createState() => _AccountsTabState();
}

class _AccountsTabState extends State<AccountsTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<Account> _accounts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    setState(() => _isLoading = true);

    try {
      final authService = AuthService();
      final userId = authService.currentUserId;

      if (userId != null) {
        final accountRepo = AccountRepo();
        final accounts = await accountRepo.list(usuarioId: userId);

        setState(() {
          _accounts = accounts;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return RefreshIndicator(
      onRefresh: _loadAccounts,
      color: const Color(0xFF13BB67),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildNetWorthCard(),
              const SizedBox(height: 24),
              _buildSectionTitle('Balance General'),
              const SizedBox(height: 12),
              _buildAssetsLiabilitiesChart(),
              const SizedBox(height: 24),
              _buildAddAccountButton(),
              const SizedBox(height: 16),
              _buildSectionTitle('Mis Cuentas'),
              const SizedBox(height: 12),
              _isLoading ? _buildLoadingState() : _buildAccountsList(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(
        color: Color(0xFF13BB67),
      ),
    );
  }

  Widget _buildNetWorthCard() {
    double activos = 0;
    double pasivos = 0;

    for (var account in _accounts) {
      if (account.isPasivo) {
        pasivos += account.saldo.abs();
      } else {
        activos += account.saldo;
      }
    }

    final double netWorth = activos - pasivos;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF13BB67), Color(0xFF0F9654)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF13BB67).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              Text(
                'Patrimonio Total',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'S/ ${netWorth.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _buildNetWorthItem('Activos', activos, Icons.trending_up)),
              const SizedBox(width: 16),
              Expanded(child: _buildNetWorthItem('Pasivos', pasivos, Icons.trending_down)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNetWorthItem(String label, double amount, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 11,
                  ),
                ),
                Text(
                  'S/ ${amount.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssetsLiabilitiesChart() {
    double activos = 0;
    double pasivos = 0;

    for (var account in _accounts) {
      if (account.isPasivo) {
        pasivos += account.saldo.abs();
      } else {
        activos += account.saldo;
      }
    }

    final double total = activos + pasivos;

    if (total == 0) {
      return _buildEmptyState('No hay datos para mostrar');
    }

    return Container(
      height: 200,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D2D),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 40,
                sections: [
                  PieChartSectionData(
                    color: const Color(0xFF13BB67),
                    value: activos,
                    title: '${((activos / total) * 100).toStringAsFixed(0)}%',
                    radius: 50,
                    titleStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  PieChartSectionData(
                    color: Colors.orangeAccent,
                    value: pasivos,
                    title: '${((pasivos / total) * 100).toStringAsFixed(0)}%',
                    radius: 50,
                    titleStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            flex: 1,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLegendItem('Activos', const Color(0xFF13BB67)),
                const SizedBox(height: 8),
                _buildLegendItem('Pasivos', Colors.orangeAccent),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildAddAccountButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _showAddAccountDialog,
        icon: const Icon(Icons.add_circle_outline),
        label: const Text('Añadir Nueva Cuenta'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF13BB67),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildAccountsList() {
    if (_accounts.isEmpty) {
      return _buildEmptyState('No hay cuentas registradas');
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D2D),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _accounts.length,
        separatorBuilder: (context, index) => Divider(
          height: 1,
          color: Colors.white.withValues(alpha: 0.1),
        ),
        itemBuilder: (context, index) {
          final account = _accounts[index];
          final isLiability = account.isPasivo;
          final color = isLiability ? Colors.orangeAccent : const Color(0xFF13BB67);

          return ListTile(
            leading: Container(
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _getAccountIcon(account.tipo),
                color: color,
                size: 24,
              ),
            ),
            title: Text(
              account.nombre,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              account.tipo.toUpperCase(),
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 12,
              ),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${account.moneda} ${account.saldo.abs().toStringAsFixed(2)}',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (isLiability)
                  Text(
                    'Pasivo',
                    style: TextStyle(
                      color: Colors.orangeAccent.withValues(alpha: 0.7),
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
            onTap: () => _showAccountDetails(account),
          );
        },
      ),
    );
  }

  IconData _getAccountIcon(String type) {
    switch (type.toLowerCase()) {
      case 'efectivo':
        return Icons.money;
      case 'débito':
      case 'debito':
        return Icons.credit_card;
      case 'crédito':
      case 'credito':
        return Icons.credit_score;
      case 'virtual':
        return Icons.account_balance_wallet;
      case 'inversión':
      case 'inversion':
        return Icons.trending_up;
      case 'por cobrar':
        return Icons.attach_money;
      case 'por pagar':
        return Icons.payment;
      default:
        return Icons.account_balance;
    }
  }

  void _showAddAccountDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Theme(
          data: ThemeData.dark().copyWith(
            dialogTheme: const DialogThemeData(
              backgroundColor: Color(0xFF2D2D2D),
            ),
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF13BB67),
              surface: Color(0xFF2D2D2D),
            ),
          ),
          child: AlertDialog(
            title: const Text('Añadir Nueva Cuenta'),
            content: const SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    decoration: InputDecoration(
                      labelText: 'Nombre de la cuenta',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    decoration: InputDecoration(
                      labelText: 'Importe inicial',
                      border: OutlineInputBorder(),
                      prefixText: 'S/ ',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Funcionalidad próximamente'),
                      backgroundColor: Color(0xFF13BB67),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF13BB67),
                ),
                child: const Text('Guardar'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAccountDetails(Account account) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2D2D2D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        account.nombre,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildDetailRow('Tipo', account.tipo),
                _buildDetailRow('Moneda', account.moneda),
                _buildDetailRow('Balance', '${account.moneda} ${account.saldo.toStringAsFixed(2)}'),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _showComingSoonSnackBar('Editar cuenta');
                        },
                        icon: const Icon(Icons.edit),
                        label: const Text('Editar'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF13BB67),
                          side: const BorderSide(color: Color(0xFF13BB67)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _showComingSoonSnackBar('Eliminar cuenta');
                        },
                        icon: const Icon(Icons.delete),
                        label: const Text('Eliminar'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: const BorderSide(color: Colors.redAccent),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D2D),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.insert_chart_outlined,
              size: 48,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showComingSoonSnackBar(String format) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Funcionalidad de $format próximamente'),
        backgroundColor: const Color(0xFF13BB67),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

