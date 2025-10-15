import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../main.dart'; // para MyHomePage

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  bool _rememberMe = false; // ✅ mantener sesión

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    final ctx = context;
    final nav = Navigator.of(ctx);
    final messenger = ScaffoldMessenger.of(ctx);

    // Simulación de delay (si quieres mantenerla)
    await Future.delayed(const Duration(milliseconds: 400));

    if (!ctx.mounted) return; // ✅ chequea el MISMO contexto que usarás

    final user = _userCtrl.text.trim();
    final pass = _passCtrl.text.trim();

    if (user == 'admin' && pass == '1234') {
      // Guardar preferencia de sesión
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('stay_logged_in', _rememberMe);

      // Navegar reemplazando el login
      nav.pushReplacement(
        MaterialPageRoute(
          builder: (_) => const MyHomePage(title: 'Registro de transacciones'),
        ),
      );
    } else {
      setState(() => _loading = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('❌ Usuario o contraseña incorrectos')),
      );
    }
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 80, color: Colors.green),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _userCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Usuario',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'Ingrese su usuario' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passCtrl,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'Ingrese su contraseña' : null,
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  value: _rememberMe,
                  onChanged: (v) => setState(() => _rememberMe = v ?? false),
                  title: const Text('Mantener sesión iniciada'),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _login,
                    child: _loading
                        ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                        : const Text('Iniciar sesión'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
