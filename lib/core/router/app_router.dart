import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:muevex_conductor/core/supabase/supabase_client.dart';
import 'package:muevex_conductor/data/models/user_model.dart';
import 'package:muevex_conductor/features/auth/presentation/login_page.dart';
import 'package:muevex_conductor/features/auth/presentation/only_drivers_page.dart';
import 'package:muevex_conductor/features/auth/presentation/register_page.dart';
import 'package:muevex_conductor/features/active_service/presentation/active_service_page.dart';
import 'package:muevex_conductor/features/active_service/presentation/navigation_page.dart';
import 'package:muevex_conductor/features/auth/providers/auth_provider.dart';
import 'package:muevex_conductor/features/dashboard/presentation/dashboard_shell.dart';
import 'package:muevex_conductor/features/misc/presentation/earning_tab.dart';
import 'package:muevex_conductor/features/misc/presentation/history_tab.dart';
import 'package:muevex_conductor/features/misc/presentation/notifications_page.dart';
import 'package:muevex_conductor/features/misc/presentation/profile_tab.dart';
import 'package:muevex_conductor/features/misc/presentation/ratings_page.dart';
import 'package:muevex_conductor/features/onboarding/presentation/onboarding_shell.dart';
import 'package:muevex_conductor/features/review/presentation/review_page.dart';
import 'package:muevex_conductor/features/vehicle/presentation/vehicle_page.dart';

final goRouter = GoRouter(
  initialLocation: '/',
  refreshListenable: AuthRefresh.instance,
  redirect: (context, state) {
    final logged = supabaseAuthed() ?? false;
    final loc = state.matchedLocation;
    final publicRoutes = {'/', '/login', '/register'};
    if (!logged && !publicRoutes.contains(loc)) return '/login';
    if (logged && (loc == '/login' || loc == '/register')) return '/home';
    return null;
  },
  routes: [
    GoRoute(path: '/', builder: (_, __) => const RedirectPage()),
    GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
    GoRoute(path: '/register', builder: (_, __) => const RegisterPage()),
    GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingShell()),
    GoRoute(path: '/only-drivers', builder: (_, __) => const OnlyDriversPage()),
    GoRoute(path: '/review', builder: (_, __) => const ReviewPage()),
    GoRoute(path: '/home', builder: (_, __) => const DashboardShell()),
    GoRoute(
      path: '/service/:id',
      builder: (_, state) => ActiveServicePage(id: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/navigation/:id',
      builder: (_, state) {
        final phase =
            int.tryParse(state.queryParameters['phase'] ?? '') ?? 1;
        return NavigationPage(id: state.pathParameters['id']!, phase: phase.clamp(1, 2));
      },
    ),
    GoRoute(path: '/earnings', builder: (_, __) => const EarningsTab()),
    GoRoute(path: '/history', builder: (_, __) => const HistoryTab()),
    GoRoute(path: '/notifications', builder: (_, __) => const NotificationsPage()),
    GoRoute(path: '/ratings', builder: (_, __) => const RatingsPage()),
    GoRoute(path: '/profile', builder: (_, __) => const ProfileTab()),
    GoRoute(path: '/vehicle', builder: (_, __) => const VehiclePage()),
  ],
);

bool? supabaseAuthed() {
  // La sesión restaurada por supabase_flutter ya vale sola: evita que un
  // arranque en frío caiga a /login aunque el provider aún no se haya construido.
  if (supabase.auth.currentUser != null) return true;
  return supabaseAuthState;
}

class RedirectPage extends StatelessWidget {
  const RedirectPage({super.key});

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final user = await supabaseAuthUser();
      final home = user != null && user.role == UserRole.driver;
      context.go(home ? '/home' : '/login');
    });
    return const Scaffold(body: SizedBox());
  }
}