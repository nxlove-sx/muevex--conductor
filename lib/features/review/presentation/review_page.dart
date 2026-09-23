import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:muevex_conductor/core/theme/muevex_theme.dart';
import 'package:muevex_conductor/core/widgets/muevex_logo.dart';
import 'package:muevex_conductor/features/dashboard/providers/driver_provider.dart';

class ReviewPage extends ConsumerWidget {
  const ReviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(driverProfileProvider).valueOrNull;
    final isVerified = profile?.isVerified ?? false;

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: MuevexTheme.primaryGradient,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const MuevexLogo(size: 80),
                const SizedBox(height: 20),
                const Icon(
                  Icons.hourglass_top_rounded,
                  size: 64,
                  color: MuevexTheme.warningColor,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Tu cuenta está siendo revisada',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Un administrador verificará tus datos y documentos. '
                  'Recibirás una notificación cuando tu cuenta sea aprobada.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.4),
                ),
                const SizedBox(height: 32),
                if (isVerified)
                  ElevatedButton.icon(
                    onPressed: () => context.go('/home'),
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Ir al inicio'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MuevexTheme.accentColor,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.white54),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Puedes cerrar la app y volver más tarde para verificar el estado.',
                            style: TextStyle(color: Colors.white54, fontSize: 13),
                          ),
                        ),
                      ],
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