import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/providers.dart';
import '../../views/auth/login_view.dart';
import '../../views/auth/register_view.dart';
import '../../views/auth/forgot_password_view.dart';
import '../../views/auth/reset_password_view.dart';
import '../home/home_screen.dart';
import 'package:mype_finanzas/views/transactions/add_transaction_view.dart';
import '../../views/analytics/analytics_view.dart';
import '../../views/reports/reports_view.dart' as reports;
import '../../views/profile/profile_view.dart';
import '../../views/transactions/transactions_list_view.dart';
import '../../views/gamification/gamification_screen.dart';
import '../../views/categories/categories_management_view.dart';

/// Provider del GoRouter que integra el estado de autenticación
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/login',
    debugLogDiagnostics: true,
    redirect: (BuildContext context, GoRouterState state) async {
      // Depuración: print del estado de autenticación
      debugPrint('➡️ [router] authState: isLoading=${authState.isLoading}, isAuthenticated=${authState.value != null}, userId=${authState.value?.id}');

      final desired = ref.read(shellDesiredIndexProvider);
      final now = DateTime.now();
      final inGrace = ref.read(routeSyncUnblockAtProvider) != null && now.isBefore(ref.read(routeSyncUnblockAtProvider)!);
      final lastAuth = ref.read(routeSyncLastAuthProvider);
      final recentAuth = lastAuth != null && now.difference(lastAuth) < const Duration(seconds: 10);
      final blockedFlag = ref.read(routeSyncBlockProvider);
      final externalActive = ref.read(routeSyncExternalActiveProvider);
      final authOpActive = ref.read(routeSyncAuthOpProvider);
      if (blockedFlag || inGrace || desired != null || externalActive || authOpActive || recentAuth) {
        debugPrint('➡️ [router] Redirect skipped because blocked=$blockedFlag, inGrace=$inGrace, shellDesired=$desired, externalActive=$externalActive, authOp=$authOpActive, recentAuth=$recentAuth, unblockAt=${ref.read(routeSyncUnblockAtProvider)}');
        return null;
      }
      final isAuthStateLoading = authState.isLoading;
      final isAuthenticated = authState.value != null;

      final isGoingToLogin = state.matchedLocation == '/login';
      final isGoingToRegister = state.matchedLocation == '/register';
      final isGoingToForgotPassword = state.matchedLocation == '/forgot-password';
      final isGoingToResetPassword = state.matchedLocation == '/reset-password';

      // Si está cargando, mantener en la ruta current
      if (isAuthStateLoading) {
        debugPrint('➡️ [router] Redirect skipped because authState.isLoading=true');
        return null;
      }

      // Si no está autenticado y no va a rutas públicas, redirigir a login
      if (!isAuthenticated && !isGoingToLogin && !isGoingToRegister &&
          !isGoingToForgotPassword && !isGoingToResetPassword) {
        // Antes de redirigir, comprobamos si en el secure storage hay una sesión activa
        try {
          final secure = ref.read(secureStorageServiceProvider);
          final has = await secure.hasActiveSession();
          if (has) {
            debugPrint('➡️ [router] evitando redirect a /login porque secure.hasActiveSession() == true');
            return null;
          }
        } catch (e) {
          debugPrint('⚠️ [router] error comprobando secure.hasActiveSession: $e');
        }
        return '/login';
      }

      // Si está autenticado y se encuentra en la pantalla de login,
      // enviarlo a la pantalla principal.
      if (isAuthenticated && isGoingToLogin) {
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
      // ShellRoute para la navegación principal con pestañas
      ShellRoute(
        builder: (context, state, child) => MyHomePage(key: const ValueKey('main-shell'), title: 'Registro de transacciones', child: child),
        routes: [
          GoRoute(
            path: '/',
            name: 'home',
            builder: (context, state) => const TransactionsListView(),
          ),
          GoRoute(
            path: '/analytics',
            name: 'analytics',
            builder: (context, state) => const AnalyticsScreen(),
          ),
          GoRoute(
            path: '/reports',
            name: 'reports',
            builder: (context, state) => const reports.ReportsScreen(),
          ),
          GoRoute(
            path: '/profile',
            name: 'profile',
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/add',
        name: 'add-transaction',
        builder: (context, state) {
          final quick = state.uri.queryParameters['quick'] == '1';
          // AddTransactionScreen deberá leer este valor para usar modo rápido.
          return AddTransactionScreen(isQuickAdd: quick);
        },
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
