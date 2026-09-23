import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:muevex_conductor/core/constants/app_constants.dart';
import 'package:muevex_conductor/core/services/live_location_reporter.dart';
import 'package:muevex_conductor/core/services/location_service.dart';
import 'package:muevex_conductor/core/theme/muevex_theme.dart';
import 'package:muevex_conductor/data/models/user_model.dart';
import 'package:muevex_conductor/features/auth/providers/auth_provider.dart';
import 'package:muevex_conductor/features/dashboard/providers/driver_provider.dart';
import 'package:muevex_conductor/features/misc/presentation/earning_tab.dart';
import 'package:muevex_conductor/features/misc/presentation/history_tab.dart';
import 'package:muevex_conductor/features/misc/presentation/profile_tab.dart';
import 'package:muevex_conductor/features/dashboard/presentation/home_tab.dart';
import 'package:muevex_conductor/features/misc/providers/earnings_history_providers.dart';

class DashboardShell extends ConsumerStatefulWidget {
  const DashboardShell({super.key});

  @override
  ConsumerState<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends ConsumerState<DashboardShell> {
  int _index = 0;

  static const _titles = ['Mis servicios', 'Ganancias', 'Historial', 'Perfil'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _guardChecks();
      _primeLocation();
    });
  }

  // Pide el permiso de ubicación al abrir la app (sin necesidad de alternar
  // Disponible/No disponible). Si ya está disponible, además inicia el reporte
  // en vivo para que las solicitudes aparezcan desde el primer momento.
  Future<void> _primeLocation() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    final profile = ref.read(driverProfileProvider).valueOrNull;
    if (profile == null) return;
    final granted = await LocationService.requestPermission();
    if (!granted) return;
    if (profile.availability == DriverAvailability.available) {
      sharedLocationReporter.attach(userId, null);
      await sharedLocationReporter.setEnabled(true);
    }
  }

  void _guardChecks() {
    final auth = ref.read(authProvider);
    // Durante loading/error la sesión aún no está resuelta: no redirigir
    // (evita el rebote /home <-> /login en arranques lentos o sin red).
    if (!auth.hasValue) return;
    final user = auth.value;
    if (user == null) {
      context.go('/login');
      return;
    }
    if (user.role != UserRole.driver) {
      context.go('/only-drivers');
      return;
    }
    final profile = ref.read(driverProfileProvider).valueOrNull;
    if (profile == null) {
      context.go('/onboarding');
      return;
    }
    if (!profile.isVerified && !kDemoAutoVerified) {
      context.go('/review');
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const HomeTab(),
      const EarningsTab(),
      const HistoryTab(),
      const ProfileTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        automaticallyImplyLeading: false,
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: MuevexTheme.primaryGradient,
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Builder(
            builder: (context) {
              final unread = ref.watch(unreadNotificationsCountProvider);
              return IconButton(
                tooltip: 'Notificaciones',
                onPressed: () => context.push('/notifications'),
                icon: Badge.count(
                  count: unread,
                  isLabelVisible: unread > 0,
                  backgroundColor: Colors.white,
                  textColor: MuevexTheme.primaryColor,
                  child: const Icon(Icons.notifications_outlined),
                ),
              );
            },
          ),
        ],
      ),
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        indicatorColor: MuevexTheme.primaryColor.withValues(alpha: 0.15),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: MuevexTheme.primaryColor),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.payments_outlined),
            selectedIcon: Icon(Icons.payments, color: MuevexTheme.primaryColor),
            label: 'Ganancias',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history, color: MuevexTheme.primaryColor),
            label: 'Historial',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: MuevexTheme.primaryColor),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}