import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:muevex_conductor/core/theme/muevex_theme.dart';
import 'package:muevex_conductor/core/widgets/muevex_logo.dart';
import 'package:muevex_conductor/features/auth/providers/auth_provider.dart';

class OnlyDriversPage extends ConsumerWidget {
  const OnlyDriversPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: MuevexTheme.primaryGradient,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const MuevexLogo(size: 100),
                const SizedBox(height: 24),
                const Icon(
                  Icons.block_outlined,
                  size: 56,
                  color: MuevexTheme.errorColor,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Solo conductores',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Esta aplicación es exclusiva para conductores de MUEVEX. '
                  'Para solicitar traslados descarga la app principal.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 15),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () async {
                    await ref.read(authProvider.notifier).logout();
                    if (!context.mounted) return;
                    context.go('/login');
                  },
                  icon: const Icon(Icons.login),
                  label: const Text('Iniciar sesión como conductor'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MuevexTheme.primaryColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
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