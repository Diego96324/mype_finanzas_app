import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers/providers.dart';
import '../../../../core/widgets/animated_form_field.dart';
import '../../../../core/utils/form_validators.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _rememberMe = false;

  late final AnimationController _animationController;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    debugPrint('🧪 [LoginScreen] initState called');
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // Cargar preferencia de "Mantener sesión iniciada"
    Future.microtask(() async {
      final remember = await ref.read(secureStorageServiceProvider).getRememberMe();
      if (mounted) setState(() => _rememberMe = remember);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final authState = ref.read(authStateProvider);
      final isAuthenticated = authState.value != null;
      final userId = authState.value?.id;
      final location = GoRouter.of(context).routeInformationProvider.value.uri.toString();
      debugPrint('🧪 [LoginScreen] postFrame auth check -> isAuthenticated=$isAuthenticated userId=$userId location=$location');
    });
  }

  Future<void> _login() async {
    debugPrint('👆 Botón login presionado');
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Revisa los campos: email y contraseña válidos son requeridos')),);
      return;
    }

    setState(() => _loading = true);
    final ctx = context;
    final messenger = ScaffoldMessenger.of(ctx);

    final user = _userCtrl.text.trim();
    final pass = _passCtrl.text.trim();
    debugPrint('📧 Intentando login con email=$user rememberMe=$_rememberMe');

    final authNotifier = ref.read(authStateProvider.notifier);
    final result = await authNotifier.login(email: user, password: pass, rememberMe: _rememberMe);

    if (!ctx.mounted) return;

    if (result['success'] == true) {
      debugPrint('➡️ Navegando a home');
      ctx.go('/');
    } else {
      debugPrint('❌ Login fallido: ${result['message']}');
      setState(() => _loading = false);
      messenger.showSnackBar(
        SnackBar(content: Text('❌ ${result['message']}')),
      );
    }
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final isAuthenticated = authState.value != null;
    final userId = authState.value?.id;
    final router = GoRouter.of(context);
    final location = router.routeInformationProvider.value.uri.toString();
    final routeSyncBlocked = ref.watch(routeSyncBlockProvider);
    debugPrint('🧪 [LoginScreen] build() -> isAuthenticated=$isAuthenticated userId=$userId location=$location blocked=$routeSyncBlocked');

    if (isAuthenticated) {
      // Si hay sesión activa pero el router todavía intenta mostrar /login,
      // forzamos regresar al perfil y evitamos mostrar el formulario.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final currentLoc = GoRouter.of(context).routeInformationProvider.value.uri.toString();
        if (currentLoc != '/profile') {
          debugPrint('🧪 [LoginScreen] authenticated user detected while en $currentLoc -> forcing /profile');
          context.go('/profile');
        }
      });
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final isDark = ref.watch(themeStateProvider); // ahora bool directo

    final bgColor = isDark ? Colors.black : Colors.green.shade50;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final primaryColor = isDark ? Colors.greenAccent : Colors.green.shade700;

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // Botón de cambio de tema
          Positioned(
            top: 50,
            right: 20,
            child: Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
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
                    // Usar el provider para cambiar el tema
                    ref.read(themeStateProvider.notifier).toggle();
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
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
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Contenido principal
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo animado
                    ScaleTransition(
                      scale: _animation,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: SvgPicture.asset(
                          'assets/icons/logo_numeria2.svg',
                          height: 120,
                          colorFilter: ColorFilter.mode(
                            primaryColor,
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    Text(
                      'Bienvenido a Numeria',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Inicia sesión para continuar',
                      style: TextStyle(
                        fontSize: 16,
                        color: textColor.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Campo de usuario
                    AnimatedFormField(
                      controller: _userCtrl,
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

                    // Campo de contraseña (AHORA CON ESTADO AISLADO)
                    _PasswordFormField(
                      controller: _passCtrl,
                      cardColor: cardColor,
                      textColor: textColor,
                      primaryColor: primaryColor,
                    ),
                    const SizedBox(height: 12),

                    // Checkbox
                    CheckboxListTile(
                      value: _rememberMe,
                      onChanged: (v) => setState(() => _rememberMe = v ?? false),
                      title: Text(
                        'Mantener sesión iniciada',
                        style: TextStyle(color: textColor),
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      activeColor: primaryColor,
                    ),

                    // Enlace de olvidé mi contraseña
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => context.push('/forgot-password'),
                        style: TextButton.styleFrom(
                          foregroundColor: primaryColor,
                        ),
                        child: Text(
                          '¿Olvidaste tu contraseña?',
                          style: TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Botón de login
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
                          shadowColor: primaryColor.withOpacity(0.5),
                        ),
                        onPressed: _loading ? null : _login,
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
                                    Icons.login_rounded,
                                    color: isDark ? Colors.black : Colors.white,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Iniciar sesión',
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
                    const SizedBox(height: 24),

                    // Divisor
                    Row(
                      children: [
                        Expanded(
                          child: Divider(
                            color: textColor.withOpacity(0.3),
                            thickness: 1,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'o',
                            style: TextStyle(
                              color: textColor.withOpacity(0.6),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(
                            color: textColor.withOpacity(0.3),
                            thickness: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Botón de registro
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: primaryColor, width: 2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () {
                          context.push('/register');
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.person_add_rounded, color: primaryColor),
                            const SizedBox(width: 8),
                            Text(
                              'Crear cuenta nueva',
                              style: TextStyle(
                                fontSize: 18,
                                color: primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// WIDGET CON ESTADO AISLADO PARA EL CAMPO DE CONTRASEÑA
class _PasswordFormField extends StatefulWidget {
  final TextEditingController controller;
  final Color cardColor;
  final Color textColor;
  final Color primaryColor;

  const _PasswordFormField({
    required this.controller,
    required this.cardColor,
    required this.textColor,
    required this.primaryColor,
  });

  @override
  State<_PasswordFormField> createState() => _PasswordFormFieldState();
}

class _PasswordFormFieldState extends State<_PasswordFormField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return AnimatedFormField(
      controller: widget.controller,
      label: 'Contraseña',
      hint: '••••••',
      icon: Icons.lock_rounded,
      obscureText: _obscure,
      cardColor: widget.cardColor,
      textColor: widget.textColor,
      primaryColor: widget.primaryColor,
      validator: FormValidators.validatePassword,
      autoValidate: false,
      showSuccessIcon: false,
      suffixIcon: IconButton(
        icon: Icon(
          _obscure ? Icons.visibility_off : Icons.visibility,
          color: widget.textColor.withOpacity(0.6),
        ),
        onPressed: () => setState(() => _obscure = !_obscure),
      ),
    );
  }
}
