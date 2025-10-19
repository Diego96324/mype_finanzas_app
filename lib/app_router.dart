import 'package:go_router/go_router.dart';
import 'features/personal_finances/home_screen.dart';
import 'features/transactions/add_transaction_screen.dart';
import 'features/personal_finances/analytics_screen.dart';
import 'features/gamification/gamification_screen.dart';

GoRouter buildRouter() {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const MyHomePage(title: 'Registro de transacciones'),
      ),
      GoRoute(path: '/add', builder: (_, __) => const AddTransactionScreen()),
      GoRoute(path: '/analytics', builder: (_, __) => const AnalyticsScreen()),
      GoRoute(path: '/gamification', builder: (_, __) => const GamificationScreen()),
    ],
  );
}
