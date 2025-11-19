import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import '../../../../core/providers/providers.dart';
import '../../../shared/utils/currency_formatter.dart';
import '../../transactions/controllers/transactions_controller.dart';
import '../../auth/views/change_password_view.dart';
import '../../../../features/transactions/data/last_category_storage.dart';
import '../../../../data/models/user_model.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  bool _notificationsEnabled = true;

  // Estadísticas se obtienen del TransactionsController ahora

  Timer? _clearDesiredTimer;

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
    final enabled = prefs.getBool('notifications_enabled') ?? true;
    if (!mounted) return;
    setState(() {
      _notificationsEnabled = enabled;
    });
  }

  Future<void> _savePreference(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  void _clearShellDesiredAfterGrace() {
    // Cancel previous timer
    _clearDesiredTimer?.cancel();
    // Usamos un timeout fijo razonable para el flujo externo.
    const timeout = Duration(milliseconds: 6000);
    final deadline = DateTime.now().add(timeout + const Duration(milliseconds: 50));

    // Timer de respaldo: limpiará al expirar el timeout
    _clearDesiredTimer = Timer(timeout + const Duration(milliseconds: 50), () {
      if (!mounted) return;
      try {
        ref.read(shellDesiredIndexProvider.notifier).state = null;
        try {
          ref.read(routeSyncBlockProvider.notifier).state = false;
        } catch (_) {}
      } catch (_) {}
      debugPrint('➡️ [Profile] shellDesiredIndex cleared by scheduled timer (timeout)');
    });

    // Tarea que comprueba periódicamente la ruta actual y limpia cuando esté en /profile
    () async {
      try {
        final provider = GoRouter.of(context).routeInformationProvider;
        while (DateTime.now().isBefore(deadline)) {
          if (!mounted) return;
          final loc = provider.value.uri.toString();
          if (loc.startsWith('/profile')) {
            // Ya estamos en /profile: limpiar y desactivar el flag reactivo
            try {
              ref.read(shellDesiredIndexProvider.notifier).state = null;
            } catch (_) {}
            try {
              ref.read(routeSyncBlockProvider.notifier).state = false;
            } catch (_) {}
            debugPrint('➡️ [Profile] shellDesiredIndex cleared because router is at /profile');
            _clearDesiredTimer?.cancel();
            return;
          }
          await Future.delayed(const Duration(milliseconds: 200));
        }
      } catch (e) {
        debugPrint('⚠️ [Profile] error while waiting for router to reach /profile: $e');
      }
    }();
  }

  @override
  void dispose() {
    _clearDesiredTimer?.cancel();
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
    // Limpieza de últimas categorías cuando se cierra sesión
    final userId = ref.read(currentUserIdProvider);
    if (userId != null) {
      await LastCategoryStorage().clearAllForUser(userId);
    }

    if (!ctx.mounted) return;
    // No invocamos ctx.go('/login') explícitamente: el router principal
    // detectará que authState es null y redirigirá automáticamente a /login.
    // Evitamos navegaciones manuales que puedan competir con la lógica del router.
  }

  @override
  Widget build(BuildContext context) {
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
                _buildUserCard(),
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

  Widget _buildUserCard() {
    return Consumer(
      builder: (context, ref, _) {
        final user = ref.watch(currentUserProvider);
        debugPrint('[ProfileAvatar] building... avatarUri=${user?.avatarUri}');
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
                InkWell(
                  onTap: () => _onAvatarTap(user),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
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
                    child: ClipOval(
                      child: Builder(builder: (ctx) {
                        final avatarPath = user?.avatarUri;
                        if (avatarPath != null && avatarPath.isNotEmpty) {
                          return Image.file(
                            File(avatarPath),
                            key: ValueKey('avatar-$avatarPath'),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stack) {
                              // If the file can't be loaded (deleted, permission), fallback to initial
                              return Center(
                                child: Text(
                                  user?.nombre.substring(0, 1).toUpperCase() ?? 'U',
                                  style: const TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              );
                            },
                          );
                        }
                        return Center(
                          child: Text(
                            user?.nombre.substring(0, 1).toUpperCase() ?? 'U',
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        );
                      }),
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
      },
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

  Future<void> _onAvatarTap(User? user) async {
    if (user == null || user.id == null) return;

    final hasAvatar = user.avatarUri != null && user.avatarUri!.isNotEmpty;
    // No activamos el bloqueo global por defecto. Solo lo haremos si el
    // usuario elige cámara/galería (actividades externas que abren otra app).
    var externalActive = false;
    // Capturamos el authNotifier ahora (antes de awaits) para no usar `ref` luego
    final container = ProviderScope.containerOf(context);
    final authNotifier = container.read(authStateProvider.notifier);

    try {
      final choice = await showModalBottomSheet<String>(
        context: context,
        builder: (ctx) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: const Text('Tomar foto'),
                  onTap: () => Navigator.pop(ctx, 'camera'),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: Text(hasAvatar ? 'Cambiar foto' : 'Agregar foto'),
                  onTap: () => Navigator.pop(ctx, 'pick'),
                ),
                if (hasAvatar)
                  ListTile(
                    leading: const Icon(Icons.delete_forever),
                    title: const Text('Eliminar foto'),
                    onTap: () => Navigator.pop(ctx, 'delete'),
                  ),
                ListTile(
                  leading: const Icon(Icons.close),
                  title: const Text('Cancelar'),
                  onTap: () => Navigator.pop(ctx, ''),
                ),
              ],
            ),
          );
        },
      );

      if (choice == 'pick') {
        debugPrint('➡️ [Profile] selecting image from gallery');
        // marcar que hay actividad externa
        try {
          ref.read(routeSyncBlockProvider.notifier).state = true;
          externalActive = true;
          debugPrint('➡️ [Profile] routeSyncBlockProvider set = true (gallery)');
        } catch (_) {}
        await _pickAndSaveAvatar(user.id!, ImageSource.gallery, authNotifier);
      } else if (choice == 'camera') {
        debugPrint('➡️ [Profile] taking image from camera');
        try {
          ref.read(routeSyncBlockProvider.notifier).state = true;
          externalActive = true;
          debugPrint('➡️ [Profile] routeSyncBlockProvider set = true (camera)');
        } catch (_) {}
        await _pickAndSaveAvatar(user.id!, ImageSource.camera, authNotifier);
      } else if (choice == 'delete') {
        debugPrint('➡️ [Profile] deleting avatar');
        await _deleteAvatar(user.id!);
      } else {
        debugPrint('➡️ [Profile] avatar selection cancelled');
      }
    } finally {
      // Limpiar la marca reactiva que indica actividad externa solo si la activamos
      if (externalActive) {
        try {
          ref.read(routeSyncBlockProvider.notifier).state = false;
        } catch (_) {}
        debugPrint('➡️ [Profile] external activity flag cleared');
      }
    }
  }

  Future<void> _pickAndSaveAvatar(int userId, ImageSource source, dynamic authNotifier) async {
    // Evitamos usar `ref` si el widget ya fue desmontado
    if (!mounted) return;
    final container = ProviderScope.containerOf(context);
    try {
      final picked = await ImagePicker().pickImage(source: source, preferredCameraDevice: CameraDevice.rear);
      if (picked == null) return;

      File? finalFile;
      try {
        // Intentar recortar la imagen
        final cropped = await ImageCropper().cropImage(
          sourcePath: picked.path,
          uiSettings: [
            AndroidUiSettings(toolbarTitle: 'Recortar', lockAspectRatio: false),
            IOSUiSettings(title: 'Recortar'),
          ],
        );
        if (cropped != null) {
          finalFile = File(cropped.path);
        }
      } catch (e) {
        // Si el recorte falla (ActivityNotFound o similar), logueamos y usamos el archivo original
        debugPrint('⚠️ ImageCropper falló o no disponible: $e');
      }

      // Si no se obtuvo archivo recortado, usamos el original
      finalFile ??= File(picked.path);

      // Capture previous avatar path to possibly delete later (background)
      String? prevPath;
      try {
        final prevUser = container.read(currentUserProvider);
        prevPath = prevUser?.avatarUri;
      } catch (_) {
        prevPath = null;
      }

      // Save to application documents directory. Use timestamp in filename to avoid cache collisions.
      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final targetPath = '${dir.path}/avatar_user_${userId}_$timestamp.jpg';
      await finalFile.copy(targetPath);

      final avatarUri = targetPath;

      // Indicar en logs que iniciamos la operación de actualización de perfil.
      debugPrint('➡️ [Profile] starting profile update (avatar)');
      // Persist via authNotifier (controller) which se encarga de escribir en DB
      await authNotifier.updateProfile(avatarUri: avatarUri);
      // Persistir user_json con la información fresca para evitar estados intermedios.
      try {
        final updatedUser = container.read(currentUserProvider);
        if (updatedUser != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_json', jsonEncode(updatedUser.toMap()));
          debugPrint('➡️ [Profile] user_json actualizado en SharedPreferences');
        }
      } catch (e) {
        debugPrint('⚠️ No se pudo persistir user_json tras updateProfile: $e');
      }

      // Delete previous file in background if it exists and is different from the new path
      if (prevPath != null && prevPath.isNotEmpty && prevPath != targetPath) {
        unawaited(() async {
          try {
            final f = File(prevPath!);
            if (await f.exists()) {
              await f.delete();
              debugPrint('➡️ [Profile] background deleted previous avatar file: $prevPath');
            }
          } catch (e) {
            debugPrint('⚠️ [Profile] could not delete previous avatar file in background: $e');
          }
        }());
      }
      // Terminó la operación crítica; dejamos que la UI y los providers se
      // actualicen naturalmente. No forzamos navegación ni tocamos shellDesiredIndex.
      const settleDelay = Duration(milliseconds: 1500);
      Future.delayed(settleDelay, () {
        debugPrint('➡️ [Profile] profile update settle delay elapsed (${settleDelay.inMilliseconds}ms)');
      });
    } catch (e) {
      debugPrint('Error al seleccionar/recortar avatar: $e');
      // En caso de error, limpiamos el desiredIndex después de un periodo de gracia
      _clearShellDesiredAfterGrace();
      try {
        ref.read(routeSyncBlockProvider.notifier).state = false;
      } catch (_) {}
      debugPrint('➡️ [Profile] error path: cleared reactive routeSyncBlock flag and scheduled shellDesired clear');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo procesar la imagen')),
        );
      }
    } finally {
      // No mantenemos estado estático; el flag reactivo se limpia en el caller.
      debugPrint('➡️ [Profile] finally after avatar flow');
    }
  }

  Future<void> _deleteAvatar(int userId) async {
    try {
      // Evitar usar `ref` si el widget fue desmontado
      if (!mounted) {
        // Si el widget fue desmontado, schedule clear as a fallback
        debugPrint('➡️ [Profile] widget unmounted during delete flow (delete aborted)');
        return;
      }
      // Use AuthController.deleteAvatar() to update DB + state
      final container = ProviderScope.containerOf(context);
      String? prevPath;
      try {
        final prevUser = container.read(currentUserProvider);
        prevPath = prevUser?.avatarUri;
      } catch (_) {
        prevPath = null;
      }

      // Call controller to clear avatar in DB and state
      final authNotifier = container.read(authStateProvider.notifier);
      final deleted = await authNotifier.deleteAvatar();
      if (!deleted) {
        debugPrint('⚠️ [Profile] deleteAvatar controller returned false');
        return;
      }

      // Delete previous file in background (if any)
      if (prevPath != null && prevPath.isNotEmpty) {
        unawaited(() async {
          try {
            final f = File(prevPath!);
            if (await f.exists()) {
              await f.delete();
              debugPrint('➡️ [Profile] background deleted avatar file: $prevPath');
            }
          } catch (e) {
            debugPrint('⚠️ [Profile] error deleting avatar file on disk (background): $e');
          }
        }());
      }
      // No llamar a setState: el provider actualiza la UI automáticamente.
      // Ya terminamos la operación: schedule clearing of desiredIndex if needed
      debugPrint('➡️ [Profile] delete done');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto de perfil eliminada')),
        );
      }
    } catch (e) {
      debugPrint('Error al eliminar avatar: $e');
    }
  }
}