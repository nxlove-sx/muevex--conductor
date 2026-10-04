import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:muevex_conductor/core/constants/app_constants.dart';
import 'package:muevex_conductor/core/router/app_router.dart';
import 'package:muevex_conductor/core/services/notification_service.dart';
import 'package:muevex_conductor/core/supabase/supabase_client.dart';
import 'package:muevex_conductor/core/theme/muevex_theme.dart';
import 'package:muevex_conductor/features/auth/providers/auth_provider.dart';
import 'package:muevex_conductor/features/misc/providers/earnings_history_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _setupGlobalErrorHandling();

  try {
    await initSupabase();
  } catch (e) {
    debugPrint('MUEVEX-C: No se pudo inicializar Supabase: $e');
  }

  // Inicializar notificaciones locales con sonido
  await notificationService.initialize();

  // Restaura "seguir logueado" al reabrir la app (escucha eventos de auth).
  initAuthListener();

  runApp(
    const ProviderScope(
      child: MuevexConductorApp(),
    ),
  );
}

void _setupGlobalErrorHandling() {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    // En release el error ya fue presentado; se evita romper el frame.
    if (kDebugMode) {
      debugPrint('MUEVEX error: ${details.exceptionAsString()}');
    }
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    if (kDebugMode) {
      debugPrint('MUEVEX platform error: $error');
    }
    return true;
  };
}

class MuevexConductorApp extends ConsumerWidget {
  const MuevexConductorApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // La suscripción de Realtime se mira aquí, en la raíz, y no en el
    // DashboardShell: las pantallas de servicio activo se abren con `go()`,
    // que destruye el shell, y entonces se cerraba el canal y dejaban de
    // sonar las notificaciones. Ver `notificationsSubscriptionProvider`.
    ref.watch(notificationsSubscriptionProvider);

    return MaterialApp.router(
      title: kAppName,
      theme: MuevexTheme.light(),
      darkTheme: MuevexTheme.dark(),
      themeMode: ThemeMode.light,
      routerDelegate: goRouter.routerDelegate,
      routeInformationParser: goRouter.routeInformationParser,
      routeInformationProvider: goRouter.routeInformationProvider,
    );
  }
}
