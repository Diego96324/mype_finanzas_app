import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/providers.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _oldPasswordCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _loading = false;

  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;
  late final AnimationController _successController;
  late final Animation<double> _successAnimation;

  @override
  void initState() {
    super.initState();

    // Animación de sacudida para errores
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 10).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );

    // Animación de éxito
    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _successAnimation = CurvedAnimation(
      parent: _successController,
      curve: Curves.elasticOut,
    );
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) {
      _shakeController.forward().then((_) => _shakeController.reverse());
      return;
    }

    setState(() => _loading = true);

    // Usar el provider en lugar del singleton
    final authNotifier = ref.read(authStateProvider.notifier);
    final result = await authNotifier.changePassword(
      oldPassword: _oldPasswordCtrl.text.trim(),
      newPassword: _newPasswordCtrl.text.trim(),
    );

    if (!mounted) return;

    setState(() => _loading = false);

    if (result['success'] == true) {
      // Mostrar animación de éxito
      _successController.forward();
      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text('✅ ${result['message']}'),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 3),
        ),
      );

      // Esperar un momento antes de cerrar
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      Navigator.pop(context);
    } else {
      _shakeController.forward().then((_) => _shakeController.reverse());

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text('❌ ${result['message']}'),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _oldPasswordCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    _shakeController.dispose();
    _successController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Usar provider en lugar de singleton
    final isDark = ref.watch(isDarkModeProvider);
    final bgColor = isDark ? const Color(0xFF121212) : Colors.grey.shade50;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final primaryColor = isDark ? Colors.greenAccent : Colors.green.shade700;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: cardColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Cambiar Contraseña',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: AnimatedBuilder(
          animation: _shakeAnimation,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(_shakeAnimation.value, 0),
              child: child,
            );
          },
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Icono principal con animación de éxito
                ScaleTransition(
                  scale: _successAnimation,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _successController.isCompleted
                          ? Icons.check_circle_rounded
                          : Icons.lock_reset_rounded,
                      size: 80,
                      color: primaryColor,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Título y descripción
                Text(
                  'Actualiza tu contraseña',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Por seguridad, ingresa tu contraseña actual para confirmar el cambio',
                  style: TextStyle(
                    fontSize: 14,
                    color: textColor.withValues(alpha: 0.6),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Contraseña actual
                _buildPasswordField(
                  controller: _oldPasswordCtrl,
                  label: 'Contraseña Actual',
                  hint: 'Ingresa tu contraseña actual',
                  icon: Icons.lock_outline_rounded,
                  obscureText: _obscureOld,
                  cardColor: cardColor,
                  textColor: textColor,
                  primaryColor: primaryColor,
                  onToggleVisibility: () =>
                      setState(() => _obscureOld = !_obscureOld),
                  validator: (v) => v == null || v.isEmpty
                      ? 'Ingrese su contraseña actual'
                      : null,
                ),
                const SizedBox(height: 20),

                // Nueva contraseña
                _buildPasswordField(
                  controller: _newPasswordCtrl,
                  label: 'Nueva Contraseña',
                  hint: 'Ingresa tu nueva contraseña',
                  icon: Icons.lock_rounded,
                  obscureText: _obscureNew,
                  cardColor: cardColor,
                  textColor: textColor,
                  primaryColor: primaryColor,
                  onToggleVisibility: () =>
                      setState(() => _obscureNew = !_obscureNew),
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'Ingrese su nueva contraseña';
                    }
                    if (v == _oldPasswordCtrl.text) {
                      return 'La nueva contraseña debe ser diferente';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Confirmar contraseña
                _buildPasswordField(
                  controller: _confirmPasswordCtrl,
                  label: 'Confirmar Nueva Contraseña',
                  hint: 'Confirma tu nueva contraseña',
                  icon: Icons.lock_clock_rounded,
                  obscureText: _obscureConfirm,
                  cardColor: cardColor,
                  textColor: textColor,
                  primaryColor: primaryColor,
                  onToggleVisibility: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'Confirme su nueva contraseña';
                    }
                    if (v != _newPasswordCtrl.text) {
                      return 'Las contraseñas no coinciden';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Medidor de fortaleza de contraseña
                AnimatedBuilder(
                  animation: _newPasswordCtrl,
                  builder: (context, _) {
                    if (_newPasswordCtrl.text.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: _PasswordStrengthMeter(
                        passwordController: _newPasswordCtrl,
                        textColor: textColor,
                        cardColor: cardColor,
                        isDark: isDark,
                      ),
                    );
                  },
                ),

                // Botón de cambiar contraseña
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: isDark ? Colors.black : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                      shadowColor: primaryColor.withValues(alpha: 0.5),
                    ),
                    onPressed: _loading ? null : _changePassword,
                    child: _loading
                        ? SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: isDark ? Colors.black : Colors.white,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.check_circle_rounded,
                                color: isDark ? Colors.black : Colors.white,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Actualizar Contraseña',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.black : Colors.white,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 16),

                // Consejo de seguridad
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.blue.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_rounded,
                        color: Colors.blue.shade700,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Consejo: No compartas tu contraseña con nadie y cámbiala regularmente',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.blue.shade200 : Colors.blue.shade900,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool obscureText,
    required Color cardColor,
    required Color textColor,
    required Color primaryColor,
    required VoidCallback onToggleVisibility,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        validator: validator,
        style: TextStyle(color: textColor, fontSize: 16),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: primaryColor),
          suffixIcon: IconButton(
            icon: Icon(
              obscureText
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded,
              color: textColor.withValues(alpha: 0.6),
            ),
            onPressed: onToggleVisibility,
          ),
          labelStyle: TextStyle(
            color: textColor.withValues(alpha: 0.7),
          ),
          hintStyle: TextStyle(
            color: textColor.withValues(alpha: 0.4),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: textColor.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: primaryColor,
              width: 2,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: Colors.red,
              width: 2,
            ),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: Colors.red,
              width: 2,
            ),
          ),
          filled: true,
          fillColor: cardColor,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),
      ),
    );
  }
}

class _PasswordStrengthMeter extends StatefulWidget {
  final TextEditingController passwordController;
  final Color textColor;
  final Color cardColor;
  final bool isDark;

  const _PasswordStrengthMeter({
    required this.passwordController,
    required this.textColor,
    required this.cardColor,
    required this.isDark,
  });

  @override
  State<_PasswordStrengthMeter> createState() => _PasswordStrengthMeterState();
}

class _PasswordStrengthMeterState extends State<_PasswordStrengthMeter> {
  double _passwordStrength = 0.0;
  String _strengthText = '';
  Color _strengthColor = Colors.grey;

  @override
  void initState() {
    super.initState();
    widget.passwordController.addListener(_calculatePasswordStrength);
    _calculatePasswordStrength();
  }

  @override
  void dispose() {
    widget.passwordController.removeListener(_calculatePasswordStrength);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _PasswordStrengthMeter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.passwordController != oldWidget.passwordController) {
      oldWidget.passwordController.removeListener(_calculatePasswordStrength);
      widget.passwordController.addListener(_calculatePasswordStrength);
    }
  }

  void _calculatePasswordStrength() {
    if (!mounted) return;
    final password = widget.passwordController.text;

    if (password.isEmpty) {
      setState(() {
        _passwordStrength = 0.0;
        _strengthText = '';
        _strengthColor = Colors.grey;
      });
      return;
    }

    double strength = 0.0;
    if (password.length >= 8) strength += 0.15;
    if (password.length >= 12) strength += 0.10;
    if (password.length >= 16) strength += 0.05;
    if (password.contains(RegExp(r'[A-Z]'))) strength += 0.20;
    if (password.contains(RegExp(r'[a-z]'))) strength += 0.20;
    if (password.contains(RegExp(r'[0-9]'))) strength += 0.15;
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>\-_=+\[\]\\~`/]'))) {
      strength += 0.15;
    }

    setState(() {
      _passwordStrength = strength.clamp(0.0, 1.0);

      if (_passwordStrength < 0.3) {
        _strengthText = 'Muy débil';
        _strengthColor = Colors.red;
      } else if (_passwordStrength < 0.5) {
        _strengthText = 'Débil';
        _strengthColor = Colors.orange;
      } else if (_passwordStrength < 0.7) {
        _strengthText = 'Media';
        _strengthColor = Colors.yellow.shade700;
      } else if (_passwordStrength < 0.9) {
        _strengthText = 'Fuerte';
        _strengthColor = Colors.lightGreen;
      } else {
        _strengthText = 'Muy fuerte';
        _strengthColor = Colors.green;
      }
    });
  }

  String _getPasswordTip() {
    if (_passwordStrength < 0.3) {
      return 'Usa mayúsculas, minúsculas, números y símbolos para mayor seguridad';
    } else if (_passwordStrength < 0.5) {
      return 'Buen comienzo. Agrega más caracteres o símbolos especiales';
    } else if (_passwordStrength < 0.7) {
      return 'Contraseña decente. Considera hacerla más larga para mayor protección';
    } else if (_passwordStrength < 0.9) {
      return '¡Muy bien! Tu contraseña es bastante segura';
    } else {
      return '¡Excelente! Has creado una contraseña muy segura';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: widget.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _strengthColor.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.shield_rounded,
                color: _strengthColor,
                size: 22,
              ),
              const SizedBox(width: 10),
              Text(
                'Seguridad de la contraseña',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: widget.textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
              tween: Tween<double>(begin: 0, end: _passwordStrength),
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 12,
                backgroundColor: widget.isDark
                    ? Colors.grey.shade800
                    : Colors.grey.shade300,
                valueColor: AlwaysStoppedAnimation<Color>(_strengthColor),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _strengthText,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: _strengthColor,
                ),
              ),
              Text(
                '${(_passwordStrength * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: widget.textColor.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.blue.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.lightbulb_outline_rounded,
                  color: Colors.blue.shade400,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _getPasswordTip(),
                    style: TextStyle(
                      fontSize: 12,
                      color: widget.isDark ? Colors.blue.shade200 : Colors.blue.shade900,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
