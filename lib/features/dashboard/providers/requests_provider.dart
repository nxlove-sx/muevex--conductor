import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:muevex_conductor/core/services/live_location_reporter.dart';
import 'package:muevex_conductor/core/supabase/supabase_client.dart' as db;
import 'package:muevex_conductor/data/models/service_model.dart';
import 'package:muevex_conductor/data/repositories/location_repository.dart';
import 'package:muevex_conductor/data/repositories/service_repository.dart';
import 'package:muevex_conductor/features/dashboard/providers/driver_provider.dart';

final serviceRepositoryProvider = Provider<ServiceRepository>((ref) {
  return ServiceRepository();
});

final locationRepositoryProvider = Provider<LocationRepository>((ref) {
  return LocationRepository();
});

class RequestsNotifier extends AsyncNotifier<List<Service>> {
  RealtimeChannel? _channel;
  Set<String> _rejectedIds = {};
  static const String _rejectedKey = 'rejected_service_ids_v1';
  static const double _maxDistanceKm = 40;

  Future<List<Service>> _fetch() async {
    final repo = ref.read(serviceRepositoryProvider);
    final vehicle = ref.read(vehicleProvider).valueOrNull;
    final lastPos =
        await ref.read(locationRepositoryProvider).getEffectiveLastLocation();

    final list = await repo.getAvailableRequests(
      maxDistanceKm: _maxDistanceKm,
      requiredCapacityKg: (vehicle?.capacityKg ?? 0).toDouble(),
      driverLat: lastPos?.latitude,
      driverLng: lastPos?.longitude,
    );
    return list.where((s) => !_rejectedIds.contains(s.id)).toList();
  }

  Future<void> _loadRejected() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _rejectedIds = (prefs.getStringList(_rejectedKey) ?? const <String>[]).toSet();
    } catch (_) {
      _rejectedIds = <String>{};
    }
  }

  Future<void> _persistRejected() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_rejectedKey, _rejectedIds.toList());
    } catch (_) {}
  }

  @override
  Future<List<Service>> build() async {
    ref.watch(availableProvider);
    await _loadRejected();

    _channel ??= db.supabase
        .channel('services-requests')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'services',
          callback: (payload) {
            final row = payload.newRecord;
            final status = row['status'] as String?;
            if (status == 'solicitado') {
              HapticFeedback.heavyImpact();
              SystemSound.play(SystemSoundType.alert);
              _silentRefresh();
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'services',
          callback: (payload) {
            _silentRefresh();
          },
        )
        .subscribe();

    ref.onDispose(_disposeChannel);
    return _fetch();
  }

  Future<void> _silentRefresh() async {
    try {
      final list = await _fetch();
      state = AsyncValue.data(list);
    } catch (_) {}
  }

  void _disposeChannel() {
    _channel?.unsubscribe();
    _channel = null;
  }

  Future<bool> accept(String serviceId) async {
    try {
      final accepted =
          await ref.read(serviceRepositoryProvider).accept(serviceId);
      if (accepted.id.isEmpty) return false;
      _rejectedIds.remove(serviceId);
      await _persistRejected();
      sharedLocationReporter.updateService(serviceId);
      await ref.read(driverProfileProvider.notifier).setBusy();
      await _silentRefresh();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> reject(String serviceId) async {
    _rejectedIds.add(serviceId);
    await _persistRejected();
    await _silentRefresh();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_fetch);
  }
}

final requestsProvider =
    AsyncNotifierProvider<RequestsNotifier, List<Service>>(RequestsNotifier.new);