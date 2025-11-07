import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/providers.dart';
import '../../presentation/features/auth/views/login_view.dart';
import '../../presentation/features/auth/views/register_view.dart';
import '../../presentation/features/auth/views/forgot_password_view.dart';
import '../../presentation/features/auth/views/reset_password_view.dart';
import '../../presentation/features/home/views/home_screen.dart';
import '../../presentation/features/transactions/views/add_transaction_view.dart';
import '../../presentation/features/analytics/views/analytics_view.dart';
import '../../presentation/features/gamification/views/gamification_screen.dart';
import '../../presentation/features/categories/views/categories_management_view.dart';

/// Provider del GoRouter que integra el estado de autenticación
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/login',
    debugLogDiagnostics: true,
    redirect: (BuildContext context, GoRouterState state) {
      final isAuthStateLoading = authState.isLoading;
      final isAuthenticated = authState.value != null;

      final isGoingToLogin = state.matchedLocation == '/login';
      final isGoingToRegister = state.matchedLocation == '/register';
      final isGoingToForgotPassword = state.matchedLocation == '/forgot-password';
      final isGoingToResetPassword = state.matchedLocation == '/reset-password';

      // Si está cargando, mantener en la ruta actual
      if (isAuthStateLoading) {
        return null;
      }

      // Si no está autenticado y no va a rutas públicas, redirigir a login
      if (!isAuthenticated && !isGoingToLogin && !isGoingToRegister &&
          !isGoingToForgotPassword && !isGoingToResetPassword) {
        return '/login';
      }

      // Si está autenticado y va a rutas públicas, redirigir a home
      if (isAuthenticated && (isGoingToLogin || isGoingToRegister ||
          isGoingToForgotPassword || isGoingToResetPassword)) {
        return '/';
      }

      // No redirigir
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        name: 'forgot-password',
        builder: (context, state) => const ForgotPasswordView(),
      ),
      GoRoute(
        path: '/reset-password',
        name: 'reset-password',
        builder: (context, state) {
          final email = state.uri.queryParameters['email'] ?? '';
          return ResetPasswordView(email: email);
        },
      ),
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const MyHomePage(title: 'Registro de transacciones'),
      ),
      GoRoute(
        path: '/add',
        name: 'add-transaction',
        builder: (context, state) => const AddTransactionScreen(),
      ),
      GoRoute(
        path: '/analytics',
        name: 'analytics',
        builder: (context, state) => const AnalyticsScreen(),
      ),
      GoRoute(
        path: '/gamification',
        name: 'gamification',
        builder: (context, state) => const GamificationScreen(),
      ),
      GoRoute(
        path: '/categories',
        name: 'categories',
        builder: (context, state) => const CategoriesManagementView(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Página no encontrada',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(state.uri.toString()),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/'),
              child: const Text('Ir al inicio'),
            ),
          ],
        ),
      ),
    ),
  );
});

/// Función legacy para compatibilidad
GoRouter buildRouter() {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const MyHomePage(title: 'Registro de transacciones'),
      ),
      GoRoute(path: '/add', builder: (context, state) => const AddTransactionScreen()),
      GoRoute(path: '/analytics', builder: (context, state) => const AnalyticsScreen()),
      GoRoute(path: '/gamification', builder: (context, state) => const GamificationScreen()),
    ],
  );
}
