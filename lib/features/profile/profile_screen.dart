import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/login_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            final ctx = context;
            final prefs = await SharedPreferences.getInstance();
            if (!ctx.mounted) return;
            await prefs.remove('stay_logged_in');
            if (!ctx.mounted) return;
            Navigator.pushAndRemoveUntil(
              ctx,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
            );
          },
          child: const Text('Cerrar sesión'),
        ),
      ),
    );
  }
}
