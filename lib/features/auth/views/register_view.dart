import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/providers.dart';
import '../../../core/widgets/animated_form_field.dart';
import '../../../core/utils/form_validators.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  final _nombreCtrl = TextEditingController();
  final _apellidoCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();

  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _loading = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    _nombreCtrl.dispose();
    _apellidoCtrl.dispose();
    _telefonoCtrl.dispose();
    _animationController.dispose();
    super.dispose();
  }


  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    final ctx = context;
    final messenger = ScaffoldMessenger.of(ctx);

    // Usar provider en lugar de singleton
    final authNotifier = ref.read(authStateProvider.notifier);
    final result = await authNotifier.register(
      email: _emailCtrl.text.trim().toLowerCase(),
      password: _passCtrl.text.trim(),
      nombre: _nombreCtrl.text.trim(),
      apellido: _apellidoCtrl.text.trim().isEmpty ? null : _apellidoCtrl.text.trim(),
      telefono: _telefonoCtrl.text.trim().isEmpty ? null : _telefonoCtrl.text.trim(),
    );

    if (!ctx.mounted) return;

    if (result['success'] == true) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('✅ Registro exitoso. ¡Bienvenido!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      await Future.delayed(const Duration(milliseconds: 500));

      if (!ctx.mounted) return;

      // GoRouter se encargará de la navegación automáticamente
      ctx.go('/');
    } else {
      setState(() => _loading = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text('❌ ${result['message']}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Usar provider en lugar de singleton
    final isDark = ref.watch(isDarkModeProvider);
    final bgColor = isDark ? Colors.black : Colors.green.shade50;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final primaryColor = isDark ? Colors.greenAccent : Colors.green.shade700;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: primaryColor),
          onPressed: () => context.pop(),
        ),
        actions: [
          // Botón de cambio de tema
          Container(
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  ref.read(themeStateProvider.notifier).toggle();
                },
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, animation) {
                      return RotationTransition(
                        turns: animation,
                        child: FadeTransition(opacity: animation, child: child),
                      );
                    },
                    child: Icon(
                      isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                      key: ValueKey(isDark),
                      color: primaryColor,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icono de usuario
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.person_add_rounded,
                        size: 50,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 24),

                    Text(
                      'Crear Cuenta',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Regístrate para comenzar',
                      style: TextStyle(
                        fontSize: 16,
                        color: textColor.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Campo Email
                    AnimatedFormField(
                      controller: _emailCtrl,
                      label: 'Email',
                      hint: 'tu@email.com',
                      icon: Icons.email_rounded,
                      cardColor: cardColor,
                      textColor: textColor,
                      primaryColor: primaryColor,
                      keyboardType: TextInputType.emailAddress,
                      validator: FormValidators.validateEmail,
                      autoValidate: true,
                      showSuccessIcon: true,
                    ),
                    const SizedBox(height: 16),

                    // Campo Nombre
                    AnimatedFormField(
                      controller: _nombreCtrl,
                      label: 'Nombre',
                      hint: 'Juan',
                      icon: Icons.person_rounded,
                      cardColor: cardColor,
                      textColor: textColor,
                      primaryColor: primaryColor,
                      textCapitalization: TextCapitalization.words,
                      validator: FormValidators.validateName,
                      autoValidate: true,
                      showSuccessIcon: true,
                    ),
                    const SizedBox(height: 16),

                    // Campo Apellido
                    AnimatedFormField(
                      controller: _apellidoCtrl,
                      label: 'Apellido (opcional)',
                      hint: 'Pérez',
                      icon: Icons.person_outline_rounded,
                      cardColor: cardColor,
                      textColor: textColor,
                      primaryColor: primaryColor,
                      textCapitalization: TextCapitalization.words,
                      autoValidate: false,
                      showSuccessIcon: false,
                    ),
                    const SizedBox(height: 16),

                    // Campo Teléfono
                    AnimatedFormField(
                      controller: _telefonoCtrl,
                      label: 'Teléfono (opcional)',
                      hint: '999 999 999',
                      icon: Icons.phone_rounded,
                      cardColor: cardColor,
                      textColor: textColor,
                      primaryColor: primaryColor,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(9),
                      ],
                      validator: FormValidators.validatePhoneOptional,
                      autoValidate: true,
                      showSuccessIcon: true,
                    ),
                    const SizedBox(height: 16),

                    // Campo Contraseña
                    AnimatedFormField(
                      controller: _passCtrl,
                      label: 'Contraseña',
                      hint: '••••••',
                      icon: Icons.lock_rounded,
                      cardColor: cardColor,
                      textColor: textColor,
                      primaryColor: primaryColor,
                      obscureText: _obscurePass,
                      validator: FormValidators.validatePassword,
                      autoValidate: true,
                      showSuccessIcon: true,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePass ? Icons.visibility_off : Icons.visibility,
                          color: textColor.withValues(alpha: 0.6),
                        ),
                        onPressed: () => setState(() => _obscurePass = !_obscurePass),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Campo Confirmar Contraseña
                    AnimatedFormField(
                      controller: _confirmPassCtrl,
                      label: 'Confirmar Contraseña',
                      hint: '••••••',
                      icon: Icons.lock_outline_rounded,
                      cardColor: cardColor,
                      textColor: textColor,
                      primaryColor: primaryColor,
                      obscureText: _obscureConfirm,
                      validator: (value) => FormValidators.validateConfirmPassword(
                        value,
                        _passCtrl.text,
                      ),
                      autoValidate: true,
                      showSuccessIcon: true,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                          color: textColor.withValues(alpha: 0.6),
                        ),
                        onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Botón de Registro
                    SizedBox(
                      width: double.infinity,
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
                        onPressed: _loading ? null : _register,
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
                                    Icons.person_add_rounded,
                                    size: 22,
                                    color: isDark ? Colors.black : Colors.white,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Registrarse',
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

                    // Link a Login
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '¿Ya tienes cuenta?',
                          style: TextStyle(
                            color: textColor.withValues(alpha: 0.7),
                            fontSize: 15,
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.pop(),
                          child: Text(
                            'Inicia Sesión',
                            style: TextStyle(
                              color: primaryColor,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
