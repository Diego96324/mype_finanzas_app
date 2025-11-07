import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../data/models/account_model.dart';
import '../controllers/accounts_controller.dart';

class AccountsTab extends ConsumerStatefulWidget {
  const AccountsTab({super.key});

  @override
  ConsumerState<AccountsTab> createState() => _AccountsTabState();
}

class _AccountsTabState extends ConsumerState<AccountsTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Future<void> _loadAccounts() async {
    await ref.read(accountsControllerProvider.notifier).loadAccounts();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final state = ref.watch(accountsControllerProvider);
    final accounts = state.accounts;
    final groupedAccounts = state.groupedAccounts;
    final isLoading = state.isLoading;

    // Mostrar error si existe
    if (state.error != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.error!),
              backgroundColor: Colors.red,
            ),
          );
        }
      });
    }

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
              _buildNetWorthCard(accounts),
              const SizedBox(height: 24),
              _buildSectionTitle('Balance General'),
              const SizedBox(height: 12),
              _buildAssetsLiabilitiesChart(groupedAccounts),
              const SizedBox(height: 24),
              _buildAddAccountButton(),
              const SizedBox(height: 16),
              _buildSectionTitle('Mis Cuentas'),
              const SizedBox(height: 12),
              isLoading ? _buildLoadingState() : _buildAccountsList(accounts),
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

  Widget _buildNetWorthCard(List<Account> accounts) {
    double activos = 0;
    double pasivos = 0;

    for (var account in accounts) {
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

  Widget _buildAssetsLiabilitiesChart(Map<String, List<Account>> groupedAccounts) {
    final activos = groupedAccounts['activos'] ?? [];
    final pasivos = groupedAccounts['pasivos'] ?? [];

    if (activos.isEmpty && pasivos.isEmpty) {
      return _buildEmptyState('No hay datos para mostrar');
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D2D),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (activos.isNotEmpty) ...[
            _buildGroupHeader('Activos', const Color(0xFF13BB67), activos),
            const SizedBox(height: 12),
            ...activos.map((account) => _buildAccountGroupItem(account, true)),
            if (pasivos.isNotEmpty) const SizedBox(height: 20),
          ],
          if (pasivos.isNotEmpty) ...[
            _buildGroupHeader('Pasivos', Colors.orangeAccent, pasivos),
            const SizedBox(height: 12),
            ...pasivos.map((account) => _buildAccountGroupItem(account, false)),
          ],
        ],
      ),
    );
  }

  Widget _buildGroupHeader(String title, Color color, List<Account> accounts) {
    double total = 0;
    for (var account in accounts) {
      total += account.saldo.abs();
    }

    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        Text(
          'S/ ${total.toStringAsFixed(2)}',
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildAccountGroupItem(Account account, bool isAsset) {
    final color = isAsset ? const Color(0xFF13BB67) : Colors.orangeAccent;

    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 8),
      child: Row(
        children: [
          Icon(
            _getAccountIcon(account.tipo),
            color: Colors.grey[400],
            size: 18,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.nombre,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
                if (account.institucion != null)
                  Text(
                    account.institucion!,
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            '${account.moneda} ${account.saldo.abs().toStringAsFixed(2)}',
            style: TextStyle(
              color: color.withValues(alpha: 0.8),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
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

  Widget _buildAccountsList(List<Account> accounts) {
    if (accounts.isEmpty) {
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
        itemCount: accounts.length,
        separatorBuilder: (context, index) => Divider(
          height: 1,
          color: Colors.white.withValues(alpha: 0.1),
        ),
        itemBuilder: (context, index) {
          final account = accounts[index];
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
              account.tipo.toUpperCase().replaceAll('_', ' '),
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
                Text(
                  isLiability ? 'PASIVO' : 'ACTIVO',
                  style: TextStyle(
                    color: color.withValues(alpha: 0.7),
                    fontSize: 9,
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
    final formKey = GlobalKey<FormState>();
    final nombreController = TextEditingController();
    final saldoController = TextEditingController(text: '0');
    final institucionController = TextEditingController();
    final notaController = TextEditingController();

    String tipoSeleccionado = 'efectivo';
    String monedaSeleccionada = 'PEN';
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final dialogPrimaryColor = const Color(0xFF13BB67);

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
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: dialogPrimaryColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.account_balance_wallet,
                        color: dialogPrimaryColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text('Añadir Nueva Cuenta'),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: nombreController,
                          autofocus: true,
                          decoration: InputDecoration(
                            labelText: 'Nombre de la cuenta *',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: dialogPrimaryColor,
                                width: 2,
                              ),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Colors.redAccent,
                                width: 1,
                              ),
                            ),
                            hintText: 'Ej: Cuenta Corriente BCP',
                            prefixIcon: Icon(Icons.edit, color: dialogPrimaryColor),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'El nombre es obligatorio';
                            }
                            if (value.length > 100) {
                              return 'Máximo 100 caracteres';
                            }
                            return null;
                          },
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                        ),
                        const SizedBox(height: 16),

                        DropdownButtonFormField<String>(
                          initialValue: tipoSeleccionado,
                          decoration: InputDecoration(
                            labelText: 'Tipo de cuenta *',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: dialogPrimaryColor,
                                width: 2,
                              ),
                            ),
                            prefixIcon: Icon(
                              _getAccountIcon(tipoSeleccionado),
                              color: dialogPrimaryColor,
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'efectivo',
                              child: Text('Efectivo'),
                            ),
                            DropdownMenuItem(
                              value: 'debito',
                              child: Text('Tarjeta de Débito'),
                            ),
                            DropdownMenuItem(
                              value: 'credito',
                              child: Text('Tarjeta de Crédito'),
                            ),
                            DropdownMenuItem(
                              value: 'virtual',
                              child: Text('Billetera Virtual'),
                            ),
                            DropdownMenuItem(
                              value: 'inversion',
                              child: Text('Inversión'),
                            ),
                            DropdownMenuItem(
                              value: 'por_cobrar',
                              child: Text('Por Cobrar'),
                            ),
                            DropdownMenuItem(
                              value: 'por_pagar',
                              child: Text('Por Pagar'),
                            ),
                          ],
                          onChanged: (value) {
                            setDialogState(() {
                              tipoSeleccionado = value!;
                            });
                          },
                        ),
                        const SizedBox(height: 16),

                        // Institución opcional
                        TextFormField(
                          controller: institucionController,
                          decoration: InputDecoration(
                            labelText: 'Institución financiera',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: dialogPrimaryColor,
                                width: 2,
                              ),
                            ),
                            hintText: 'Ej: Banco de Crédito del Perú',
                            prefixIcon: Icon(Icons.business, color: dialogPrimaryColor),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Saldo y Moneda
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: saldoController,
                                decoration: InputDecoration(
                                  labelText: 'Saldo inicial *',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: dialogPrimaryColor,
                                      width: 2,
                                    ),
                                  ),
                                  errorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Colors.redAccent,
                                      width: 1,
                                    ),
                                  ),
                                  prefixIcon: Icon(Icons.attach_money, color: dialogPrimaryColor),
                                ),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'El saldo es obligatorio';
                                  }
                                  final saldo = double.tryParse(value.trim());
                                  if (saldo == null) {
                                    return 'Ingrese un número válido';
                                  }
                                  final esPasivo = tipoSeleccionado == 'credito' ||
                                      tipoSeleccionado == 'por_pagar';
                                  if (!esPasivo && saldo < 0) {
                                    return 'Los activos no pueden ser negativos';
                                  }
                                  return null;
                                },
                                autovalidateMode: AutovalidateMode.onUserInteraction,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: monedaSeleccionada,
                                decoration: InputDecoration(
                                  labelText: 'Moneda',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: dialogPrimaryColor,
                                      width: 2,
                                    ),
                                  ),
                                ),
                                items: const [
                                  DropdownMenuItem(value: 'PEN', child: Text('PEN')),
                                  DropdownMenuItem(value: 'USD', child: Text('USD')),
                                  DropdownMenuItem(value: 'EUR', child: Text('EUR')),
                                ],
                                onChanged: (value) {
                                  setDialogState(() {
                                    monedaSeleccionada = value!;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Nota opcional
                        TextFormField(
                          controller: notaController,
                          decoration: InputDecoration(
                            labelText: 'Nota (opcional)',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: dialogPrimaryColor,
                                width: 2,
                              ),
                            ),
                            hintText: 'Agregar alguna observación...',
                            prefixIcon: Icon(Icons.note, color: dialogPrimaryColor),
                          ),
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: isLoading ? null : () => Navigator.pop(dialogContext),
                    child: const Text('Cancelar'),
                  ),
                  ElevatedButton.icon(
                    onPressed: isLoading
                        ? null
                        : () async {
                            if (formKey.currentState!.validate()) {
                              setDialogState(() => isLoading = true);

                              await _createAccount(
                                nombre: nombreController.text.trim(),
                                tipo: tipoSeleccionado,
                                saldo: double.parse(saldoController.text.trim()),
                                moneda: monedaSeleccionada,
                                institucion: institucionController.text.trim().isEmpty
                                    ? null
                                    : institucionController.text.trim(),
                                nota: notaController.text.trim().isEmpty
                                    ? null
                                    : notaController.text.trim(),
                              );

                              if (dialogContext.mounted) {
                                Navigator.pop(dialogContext);
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: dialogPrimaryColor,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey,
                    ),
                    icon: isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save),
                    label: Text(isLoading ? 'Guardando...' : 'Guardar'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _createAccount({
    required String nombre,
    required String tipo,
    required double saldo,
    required String moneda,
    String? institucion,
    String? nota,
  }) async {
    try {
      final result = await ref.read(accountsControllerProvider.notifier).createAccount(
        nombre: nombre,
        tipo: tipo,
        saldo: saldo,
        moneda: moneda,
        institucion: institucion,
        nota: nota,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: result.success ? const Color(0xFF13BB67) : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
                _buildDetailRow('Tipo', account.tipoDisplay),
                _buildDetailRow('Moneda', account.moneda),
                _buildDetailRow('Balance', '${account.moneda} ${account.saldo.toStringAsFixed(2)}'),
                if (account.institucion != null)
                  _buildDetailRow('Institución', account.institucion!),
                if (account.nota != null)
                  _buildDetailRow('Nota', account.nota!),
                _buildDetailRow(
                  'Última actualización',
                  account.fechaActualizacion != null
                      ? _formatDate(account.fechaActualizacion!)
                      : 'Sin actualizar'
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _showEditAccountDialog(account);
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
                          _confirmDeleteAccount(account);
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Hoy';
    } else if (difference.inDays == 1) {
      return 'Ayer';
    } else if (difference.inDays < 7) {
      return 'Hace ${difference.inDays} días';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  void _showEditAccountDialog(Account account) {
    final formKey = GlobalKey<FormState>();
    final nombreController = TextEditingController(text: account.nombre);
    final saldoController = TextEditingController(text: account.saldo.toStringAsFixed(2));
    final institucionController = TextEditingController(text: account.institucion ?? '');
    final notaController = TextEditingController(text: account.nota ?? '');

    String tipoSeleccionado = account.tipo;
    String monedaSeleccionada = account.moneda;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
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
                title: const Text('Editar Cuenta'),
                content: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: nombreController,
                          decoration: const InputDecoration(
                            labelText: 'Nombre de la cuenta *',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'El nombre es obligatorio';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: tipoSeleccionado,
                          decoration: const InputDecoration(
                            labelText: 'Tipo de cuenta *',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'efectivo', child: Text('Efectivo')),
                            DropdownMenuItem(value: 'debito', child: Text('Tarjeta de Débito')),
                            DropdownMenuItem(value: 'credito', child: Text('Tarjeta de Crédito')),
                            DropdownMenuItem(value: 'virtual', child: Text('Billetera Virtual')),
                            DropdownMenuItem(value: 'inversion', child: Text('Inversión')),
                            DropdownMenuItem(value: 'por_cobrar', child: Text('Por Cobrar')),
                            DropdownMenuItem(value: 'por_pagar', child: Text('Por Pagar')),
                          ],
                          onChanged: (value) {
                            setDialogState(() {
                              tipoSeleccionado = value!;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: institucionController,
                          decoration: const InputDecoration(
                            labelText: 'Institución financiera',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: saldoController,
                                decoration: const InputDecoration(
                                  labelText: 'Saldo actual *',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'El saldo es obligatorio';
                                  }
                                  if (double.tryParse(value.trim()) == null) {
                                    return 'Ingrese un número válido';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: monedaSeleccionada,
                                decoration: const InputDecoration(
                                  labelText: 'Moneda',
                                  border: OutlineInputBorder(),
                                ),
                                items: const [
                                  DropdownMenuItem(value: 'PEN', child: Text('PEN')),
                                  DropdownMenuItem(value: 'USD', child: Text('USD')),
                                  DropdownMenuItem(value: 'EUR', child: Text('EUR')),
                                ],
                                onChanged: (value) {
                                  setDialogState(() {
                                    monedaSeleccionada = value!;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: notaController,
                          decoration: const InputDecoration(
                            labelText: 'Nota (opcional)',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Cancelar'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      if (formKey.currentState!.validate()) {
                        Navigator.pop(dialogContext);
                        await _updateAccount(
                          account: account.copyWith(
                            nombre: nombreController.text,
                            tipo: tipoSeleccionado,
                            saldo: double.parse(saldoController.text),
                            moneda: monedaSeleccionada,
                            institucion: institucionController.text.trim().isEmpty
                                ? null
                                : institucionController.text,
                            nota: notaController.text.trim().isEmpty
                                ? null
                                : notaController.text,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF13BB67),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Guardar'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _updateAccount({required Account account}) async {
    try {
      final result = await ref.read(accountsControllerProvider.notifier).updateAccount(account);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: result.success ? const Color(0xFF13BB67) : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  void _confirmDeleteAccount(Account account) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2D2D2D),
          title: const Text('Confirmar eliminación', style: TextStyle(color: Colors.white)),
          content: Text(
            '¿Está seguro que desea eliminar la cuenta "${account.nombre}"?',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _deleteAccount(account.id!);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteAccount(int accountId) async {
    try {
      final result = await ref.read(accountsControllerProvider.notifier).deleteAccount(accountId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: result.success ? const Color(0xFF13BB67) : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
}

