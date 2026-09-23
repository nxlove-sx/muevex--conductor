import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:muevex_conductor/core/constants/app_constants.dart';
import 'package:muevex_conductor/core/services/live_location_reporter.dart';
import 'package:muevex_conductor/core/theme/muevex_theme.dart';
import 'package:muevex_conductor/core/widgets/muevex_snackbar.dart';
import 'package:muevex_conductor/features/auth/providers/auth_provider.dart';
import 'package:muevex_conductor/features/dashboard/providers/driver_provider.dart';
import 'package:muevex_conductor/features/dashboard/providers/requests_provider.dart';

class StatusButton extends ConsumerStatefulWidget {
  const StatusButton({super.key});

  @override
  ConsumerState<StatusButton> createState() => _StatusButtonState();
}

class _StatusButtonState extends ConsumerState<StatusButton> {
  bool _toggling = false;

  Future<void> _toggle(bool online) async {
    setState(() => _toggling = true);
    final ok = await ref
        .read(driverProfileProvider.notifier)
        .toggleAvailability(online);
    if (ok) {
      final userId = ref.read(currentUserIdProvider);
      if (online && userId != null) {
        sharedLocationReporter.attach(userId, null);
        final reporting = await sharedLocationReporter.setEnabled(true);
        if (!reporting && mounted) {
          MuevexSnackBar.info(
            context,
            'Activa la ubicación o permite el permiso en los ajustes para reportar en vivo.',
          );
        }
      } else if (!online) {
        // Al pasar a "No disponible" se detiene el reporte y se elimina la
        // fila de ubicación para no dejar un punto fantasma en el mapa.
        await sharedLocationReporter.shutdown();
      }
      ref.invalidate(requestsProvider);
    }
    if (mounted) setState(() => _toggling = false);
  }

  @override
  Widget build(BuildContext context) {
    final profileAvail = ref.watch(driverProfileProvider).valueOrNull?.availability;
    final online = profileAvail == DriverAvailability.available;

    return InkWell(
      onTap: () => _toggle(!online),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: online
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF00C2A8), Color(0xFF00A08C)],
                )
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF8A93A6), Color(0xFF6B7280)],
                ),
          boxShadow: [
            BoxShadow(
              color: (online ? MuevexTheme.accentColor : Colors.grey.shade500)
                  .withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              online ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: Colors.white,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    online ? 'Disponible' : 'No disponible',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    online
                        ? 'Recibiendo solicitudes en tiempo real'
                        : 'Toca para comenzar a recibir servicios',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (_toggling)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
          ],
        ),
      ),
    );
  }
}