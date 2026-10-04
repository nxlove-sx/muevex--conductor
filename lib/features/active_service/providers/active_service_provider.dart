import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:muevex_conductor/core/services/live_location_reporter.dart';
import 'package:muevex_conductor/core/supabase/supabase_client.dart' as db;
import 'package:muevex_conductor/data/models/service_model.dart';
import 'package:muevex_conductor/features/auth/providers/auth_provider.dart';
import 'package:muevex_conductor/features/dashboard/providers/driver_provider.dart';
import 'package:muevex_conductor/features/dashboard/providers/requests_provider.dart';
import 'package:muevex_conductor/features/misc/providers/earnings_history_providers.dart';
import 'package:muevex_conductor/core/services/notification_service.dart';

class ActiveServiceNotifier extends AsyncNotifier<Service?> {
  RealtimeChannel? _channel;

  Future<Service?> _fetch() async {
    final driverId = ref.read(currentUserIdProvider);
    if (driverId == null) return null;
    return ref.read(serviceRepositoryProvider).getActiveService(driverId);
  }

  @override
  Future<Service?> build() async {
    final driverId = ref.watch(currentUserIdProvider);
    if (driverId == null) return null;

    _channel ??= db.supabase
        .channel('services-active:$driverId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'services',
          callback: (_) => _silentRefresh(),
        )
        .subscribe();

    ref.onDispose(() {
      _channel?.unsubscribe();
      _channel = null;
    });
    return _fetch();
  }

  Future<void> _silentRefresh() async {
    try {
      state = AsyncValue.data(await _fetch());
    } catch (_) {}
  }

  Future<bool> advance(ServiceStatus next) async {
    final current = state.valueOrNull;
    if (current == null) return false;
    try {
      final updated = await ref
          .read(serviceRepositoryProvider)
          .updateStatus(current.id, next);
      state = AsyncValue.data(updated);
      if (next == ServiceStatus.completado) {
        await ref.read(driverProfileProvider.notifier).setAvailable();
        // Al completar el servicio, dejamos de reportar ubicación activa
        // y mostramos "Servicio completado" en lugar de la ubicación
        sharedLocationReporter.updateService(null);
        ref.invalidate(earningsProvider);
        ref.invalidate(historyProvider);
        ref.invalidate(ratingsProvider);
        // Notificación de servicio completado - Ya no se envía "mi ubicación"
        // Se envía notificación de finalización en su lugar
        notificationService.showOrderEventNotification(
          type: 'service_completed',
          userRole: 'driver',
          data: {'serviceId': current.id},
        );
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> cancel() async {
    final current = state.valueOrNull;
    if (current == null) return false;
    try {
      final updated =
          await ref.read(serviceRepositoryProvider).cancel(current.id);
      state = AsyncValue.data(updated);
      await ref.read(driverProfileProvider.notifier).setAvailable();
      sharedLocationReporter.updateService(null);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_fetch);
  }
}

final activeServiceProvider =
    AsyncNotifierProvider<ActiveServiceNotifier, Service?>(
  ActiveServiceNotifier.new,
);
