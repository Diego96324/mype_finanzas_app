import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/providers.dart';
import '../../../shared/utils/currency_formatter.dart';
import '../../transactions/controllers/transactions_controller.dart';
import '../../auth/views/change_password_view.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  bool _notificationsEnabled = true;
  bool _biometricsEnabled = false;

  // Estadísticas se obtienen del TransactionsController ahora

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();

    // Ya no necesitamos _loadUserStats porque usaremos el controlador
    _loadPreferences();
  }

  // Eliminamos _loadUserStats - ahora usamos el controlador

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _biometricsEnabled = prefs.getBool('biometrics_enabled') ?? false;
    });
  }

  Future<void> _savePreference(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _confirmLogout() async {
    final result = await showDialog<bool>(
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
            title: const Text('Cerrar sesión'),
            content: const Text('¿Estás seguro de que deseas cerrar sesión?'),
            actions: [
              TextButton(
                onPressed: () => context.pop(false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => context.pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF13BB67),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Cerrar sesión'),
              ),
            ],
          ),
        );
      },
    );

    if (result == true) {
      await _logout();
    }
  }

  Future<void> _logout() async {
    final ctx = context;

    // Usar el provider para hacer logout
    await ref.read(authStateProvider.notifier).logout();

    if (!ctx.mounted) return;

    // GoRouter redirigirá automáticamente a login al detectar que no hay usuario
    ctx.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    // Usar providers en lugar de singletons
    final user = ref.watch(currentUserProvider);
    final isDark = ref.watch(isDarkModeProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        leading: const SizedBox(width: 48),
        title: const Text(
          'Mi Perfil',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF2D2D2D),
        elevation: 0,
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildUserCard(user),
                const SizedBox(height: 20),
                _buildStatsSection(),
                const SizedBox(height: 20),
                _buildSectionTitle('Configuración'),
                const SizedBox(height: 12),
                _buildSettingsCard(isDark),
                const SizedBox(height: 20),
                _buildSectionTitle('Cuenta'),
                const SizedBox(height: 12),
                _buildAccountCard(),
                const SizedBox(height: 20),
                _buildSectionTitle('Información'),
                const SizedBox(height: 12),
                _buildInfoCard(),
                const SizedBox(height: 20),
                _buildLogoutButton(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserCard(dynamic user) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final registrationDate = user?.fechaRegistro != null
        ? dateFormat.format(user!.fechaRegistro)
        : 'N/A';

    return Container(
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
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Row(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 3,
                ),
              ),
              child: Center(
                child: Text(
                  user?.nombre.substring(0, 1).toUpperCase() ?? 'U',
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user?.nombreCompleto ?? 'Usuario',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?.email ?? '',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Miembro desde $registrationDate',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection() {
    // Obtenemos datos del TransactionsController
    final transactionsState = ref.watch(transactionsControllerProvider);
    final stats = transactionsState.stats ?? {};

    final totalTransactions = transactionsState.transactions.length;
    final ingresos = stats['ingresos'] ?? 0.0;
    final gastos = stats['egresos'] ?? 0.0;
    final balance = ingresos - gastos;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D2D),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Estadísticas',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  icon: Icons.receipt_long,
                  label: 'Transacciones',
                  value: totalTransactions.toString(),
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatItem(
                  icon: Icons.trending_up,
                  label: 'Ingresos',
                  value: 'S/ ${CurrencyFormatter.formatAmount(ingresos)}',
                  color: const Color(0xFF13BB67),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  icon: Icons.trending_down,
                  label: 'Gastos',
                  value: 'S/ ${CurrencyFormatter.formatAmount(gastos)}',
                  color: Colors.redAccent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatItem(
                  icon: Icons.account_balance_wallet,
                  label: 'Balance',
                  value: 'S/ ${CurrencyFormatter.formatAmount(balance)}',
                  color: balance >= 0
                      ? const Color(0xFF13BB67)
                      : Colors.redAccent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.grey[400],
      ),
    );
  }

  Widget _buildSettingsCard(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D2D),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSettingTile(
            icon: Icons.dark_mode,
            title: 'Tema oscuro',
            subtitle: 'Activar modo nocturno',
            trailing: Switch(
              value: isDark,
              onChanged: (value) {
                ref.read(themeStateProvider.notifier).toggle();
              },
              activeTrackColor: const Color(0xFF13BB67),
            ),
          ),
          const Divider(height: 1, color: Color(0xFF3D3D3D)),
          _buildSettingTile(
            icon: Icons.notifications,
            title: 'Notificaciones',
            subtitle: 'Recibir alertas de transacciones',
            trailing: Switch(
              value: _notificationsEnabled,
              onChanged: (value) {
                setState(() => _notificationsEnabled = value);
                _savePreference('notifications_enabled', value);
              },
              activeTrackColor: const Color(0xFF13BB67),
            ),
          ),
          const Divider(height: 1, color: Color(0xFF3D3D3D)),
          _buildSettingTile(
            icon: Icons.fingerprint,
            title: 'Biometría',
            subtitle: 'Desbloqueo con huella digital',
            trailing: Switch(
              value: _biometricsEnabled,
              onChanged: (value) {
                setState(() => _biometricsEnabled = value);
                _savePreference('biometrics_enabled', value);
              },
              activeTrackColor: const Color(0xFF13BB67),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D2D),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSettingTile(
            icon: Icons.category,
            title: 'Gestionar Categorías',
            subtitle: 'Organiza tus ingresos y gastos',
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () {
              context.push('/categories');
            },
          ),
          const Divider(height: 1, color: Color(0xFF3D3D3D)),
          _buildSettingTile(
            icon: Icons.edit,
            title: 'Editar perfil',
            subtitle: 'Actualizar información personal',
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Funcionalidad en desarrollo'),
                  backgroundColor: Color(0xFF13BB67),
                ),
              );
            },
          ),
          const Divider(height: 1, color: Color(0xFF3D3D3D)),
          _buildSettingTile(
            icon: Icons.lock,
            title: 'Cambiar contraseña',
            subtitle: 'Actualizar tu contraseña',
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ChangePasswordScreen(),
                ),
              );
            },
          ),
          const Divider(height: 1, color: Color(0xFF3D3D3D)),
          _buildSettingTile(
            icon: Icons.backup,
            title: 'Copia de seguridad',
            subtitle: 'Respaldar tus datos',
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Funcionalidad en desarrollo'),
                  backgroundColor: Color(0xFF13BB67),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D2D),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSettingTile(
            icon: Icons.help_outline,
            title: 'Ayuda y soporte',
            subtitle: 'Obtener ayuda',
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Funcionalidad en desarrollo'),
                  backgroundColor: Color(0xFF13BB67),
                ),
              );
            },
          ),
          const Divider(height: 1, color: Color(0xFF3D3D3D)),
          _buildSettingTile(
            icon: Icons.privacy_tip,
            title: 'Privacidad',
            subtitle: 'Política de privacidad',
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Funcionalidad en desarrollo'),
                  backgroundColor: Color(0xFF13BB67),
                ),
              );
            },
          ),
          const Divider(height: 1, color: Color(0xFF3D3D3D)),
          _buildSettingTile(
            icon: Icons.info_outline,
            title: 'Acerca de',
            subtitle: 'Versión 1.0.0',
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () {
              _showAboutDialog();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF13BB67).withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: const Color(0xFF13BB67), size: 24),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 13,
          color: Colors.grey[400],
        ),
      ),
      trailing: trailing,
      onTap: onTap,
    );
  }

  Widget _buildLogoutButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.redAccent.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _confirmLogout,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.redAccent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.logout, size: 24),
            const SizedBox(width: 12),
            const Text(
              'Cerrar sesión',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAboutDialog() {
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
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF13BB67).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet,
                    color: Color(0xFF13BB67),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                const Text('MYPE Finanzas'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Versión: 1.0.0'),
                const SizedBox(height: 8),
                Text(
                  'Aplicación de gestión financiera para micro y pequeñas empresas.',
                  style: TextStyle(color: Colors.grey[400]),
                ),
                const SizedBox(height: 16),
                Text(
                  '© 2025 MYPE Finanzas',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => context.pop(),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        );
      },
    );
  }
}
