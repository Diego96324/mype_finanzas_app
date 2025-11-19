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

// Asegúrate de que estas importaciones sean correctas según tu estructura de carpetas
import '../../../../core/providers/providers.dart';
import '../../../shared/utils/currency_formatter.dart';
import '../../transactions/controllers/transactions_controller.dart';
import '../../auth/views/change_password_view.dart';
import '../../../../features/support/views/faq_assistant_view.dart';
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
    _loadPreferences();
  }

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
    _clearDesiredTimer?.cancel();
    const timeout = Duration(milliseconds: 6000);
    final deadline = DateTime.now().add(timeout + const Duration(milliseconds: 50));

    _clearDesiredTimer = Timer(timeout + const Duration(milliseconds: 50), () {
      if (!mounted) return;
      try {
        ref.read(shellDesiredIndexProvider.notifier).state = null;
        try {
          ref.read(routeSyncBlockProvider.notifier).state = false;
        } catch (_) {}
        debugPrint('➡️ [Profile] shellDesiredIndex cleared by scheduled timer (timeout)');
      } catch (_) {}
    });

    () async {
      try {
        if (!mounted) return;
        final provider = GoRouter.of(context).routeInformationProvider;
        while (DateTime.now().isBefore(deadline)) {
          if (!mounted) return;
          final loc = provider.value.uri.toString();
          if (loc.startsWith('/profile')) {
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
    // Capturar dependencias ANTES de operaciones asíncronas que puedan desmontar el widget.
    final authNotifier = ref.read(authStateProvider.notifier);
    final userId = ref.read(currentUserIdProvider);
    final ctx = context; // Capturar context

    // Realizar la operación de logout
    await authNotifier.logout();

    // Después de un 'await', el widget podría estar desmontado.
    // No usar 'ref' ni 'context' sin verificar si el widget sigue montado.
    if (!ctx.mounted) return;

    if (userId != null) {
      // Esta es otra operación asíncrona, pero no afecta al estado de autenticación.
      // Es seguro llamarla después de la verificación.
      await LastCategoryStorage().clearAllForUser(userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Nota: isDark se usa aquí para los widgets hijos que no extrajimos
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
                // ✅ WIDGET EXTRAÍDO: Evita reconstrucción masiva
                UserCardSection(onAvatarTap: _onAvatarTap),

                const SizedBox(height: 20),

                // ✅ WIDGET EXTRAÍDO: Aísla los cambios de transacciones
                const StatsSection(),

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

  // --- MÉTODOS HELPER PARA TARJETAS SIMPLES (Estos están bien aquí) ---

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
            color: Colors.black.withOpacity(0.2),
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
            color: Colors.black.withOpacity(0.2),
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
                  content: Text('Ojala existiera :)'),
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
            color: Colors.black.withOpacity(0.2),
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
            subtitle: 'Asistente virtual',
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const FaqAssistantView(),
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
          color: const Color(0xFF13BB67).withOpacity(0.2),
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
            color: Colors.redAccent.withOpacity(0.3),
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
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout, size: 24),
            SizedBox(width: 12),
            Text(
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
                    color: const Color(0xFF13BB67).withOpacity(0.2),
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
                  'Aplicación de gestión financiera para gastos personales y microempresas',
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

  // --- LÓGICA DE AVATAR ---

  Future<void> _onAvatarTap(User? user) async {
    if (user == null || user.id == null) return;
    final hasAvatar = user.avatarUri != null && user.avatarUri!.isNotEmpty;
    var externalActive = false;
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
        try {
          ref.read(routeSyncBlockProvider.notifier).state = true;
          externalActive = true;
        } catch (_) {}
        await _pickAndSaveAvatar(user.id!, ImageSource.gallery, authNotifier);
      } else if (choice == 'camera') {
        try {
          ref.read(routeSyncBlockProvider.notifier).state = true;
          externalActive = true;
        } catch (_) {}
        await _pickAndSaveAvatar(user.id!, ImageSource.camera, authNotifier);
      } else if (choice == 'delete') {
        await _deleteAvatar(user.id!);
      }
    } finally {
      if (externalActive) {
        try {
          ref.read(routeSyncBlockProvider.notifier).state = false;
        } catch (_) {}
      }
    }
  }

  Future<void> _pickAndSaveAvatar(int userId, ImageSource source, dynamic authNotifier) async {
    if (!mounted) return;
    final container = ProviderScope.containerOf(context);
    try {
      final picked = await ImagePicker().pickImage(source: source, preferredCameraDevice: CameraDevice.rear);
      if (picked == null) return;

      File? finalFile;
      try {
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
        debugPrint('⚠️ ImageCropper falló o no disponible: $e');
      }

      finalFile ??= File(picked.path);

      String? prevPath;
      try {
        final prevUser = container.read(currentUserProvider);
        prevPath = prevUser?.avatarUri;
      } catch (_) {
        prevPath = null;
      }

      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final targetPath = '${dir.path}/avatar_user_${userId}_$timestamp.jpg';
      await finalFile.copy(targetPath);
      final avatarUri = targetPath;

      await authNotifier.updateProfile(avatarUri: avatarUri);

      try {
        final updatedUser = container.read(currentUserProvider);
        if (updatedUser != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_json', jsonEncode(updatedUser.toMap()));
        }
      } catch (e) {
        debugPrint('⚠️ No se pudo persistir user_json: $e');
      }

      if (prevPath != null && prevPath.isNotEmpty && prevPath != targetPath) {
        unawaited(() async {
          try {
            final f = File(prevPath!);
            if (await f.exists()) await f.delete();
          } catch (e) {
            debugPrint('⚠️ Error deleting prev avatar: $e');
          }
        }());
      }
    } catch (e) {
      debugPrint('Error avatar: $e');
      _clearShellDesiredAfterGrace();
      try {
        ref.read(routeSyncBlockProvider.notifier).state = false;
      } catch (_) {}
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo procesar la imagen')));
      }
    }
  }

  Future<void> _deleteAvatar(int userId) async {
    try {
      if (!mounted) return;
      final container = ProviderScope.containerOf(context);
      String? prevPath;
      try {
        final prevUser = container.read(currentUserProvider);
        prevPath = prevUser?.avatarUri;
      } catch (_) {
        prevPath = null;
      }

      final authNotifier = container.read(authStateProvider.notifier);
      final deleted = await authNotifier.deleteAvatar();
      if (!deleted) return;

      if (prevPath != null && prevPath.isNotEmpty) {
        unawaited(() async {
          try {
            final f = File(prevPath!);
            if (await f.exists()) await f.delete();
          } catch (e) {
            debugPrint('⚠️ Error deleting file: $e');
          }
        }());
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Foto de perfil eliminada')));
      }
    } catch (e) {
      debugPrint('Error al eliminar avatar: $e');
    }
  }
}

// =================================================================
// WIDGETS EXTRAÍDOS (SOLUCIÓN DEL BUCLE)
// =================================================================

class UserCardSection extends ConsumerWidget {
  final Function(User?) onAvatarTap;

  const UserCardSection({super.key, required this.onAvatarTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ⚠️ MOVIMOS ESTE WATCH AQUÍ. Solo repinta esta tarjeta si cambia el usuario.
    final user = ref.watch(currentUserProvider);

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
            color: const Color(0xFF13BB67).withOpacity(0.3),
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
              onTap: () => onAvatarTap(user),
              borderRadius: BorderRadius.circular(999),
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
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
                        // 🔑 KEY AÑADIDA: Evita que Flutter redibuje si el path es el mismo
                        key: ValueKey('avatar-$avatarPath'),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stack) {
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
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: Colors.white.withOpacity(0.8),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Miembro desde $registrationDate',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.8),
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
}

class StatsSection extends ConsumerWidget {
  const StatsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ⚠️ MOVIMOS EL WATCH DE TRANSACCIONES AQUÍ.
    // Ahora, si se actualizan los $$$$, solo se repinta este widget, NO el avatar.
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
            color: Colors.black.withOpacity(0.2),
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
}
