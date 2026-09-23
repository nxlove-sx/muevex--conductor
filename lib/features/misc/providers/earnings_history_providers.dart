import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:muevex_conductor/core/supabase/supabase_client.dart' as db;
import 'package:muevex_conductor/data/models/app_notification_model.dart';
import 'package:muevex_conductor/data/models/rating_model.dart';
import 'package:muevex_conductor/data/models/service_model.dart';
import 'package:muevex_conductor/data/repositories/notifications_repository.dart';
import 'package:muevex_conductor/features/auth/providers/auth_provider.dart';
import 'package:muevex_conductor/features/dashboard/providers/driver_provider.dart';
import 'package:muevex_conductor/features/dashboard/providers/requests_provider.dart';

class EarningsSummary {
  final double today;
  final double week;
  final double month;
  final double total;
  final int completedCount;

  const EarningsSummary({
    required this.today,
    required this.week,
    required this.month,
    required this.total,
    required this.completedCount,
  });
}

class EarningsNotifier extends AsyncNotifier<EarningsSummary> {
  @override
  Future<EarningsSummary> build() async {
    final driverId = ref.watch(currentUserIdProvider);
    if (driverId == null) {
      return const EarningsSummary(
        today: 0, week: 0, month: 0, total: 0, completedCount: 0,
      );
    }
    final services = await ref
        .read(serviceRepositoryProvider)
        .getCompletedServices(driverId);
    return _summarize(services);
  }

  /// Recarga manual (pull-to-refresh) sin invalidar desde fuera.
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    await _buildValue();
  }

  Future<void> _buildValue() async {
    final driverId = ref.read(currentUserIdProvider);
    if (driverId == null) {
      state = const AsyncValue.data(EarningsSummary(
        today: 0, week: 0, month: 0, total: 0, completedCount: 0,
      ));
      return;
    }
    state = await AsyncValue.guard(() async {
      final services = await ref
          .read(serviceRepositoryProvider)
          .getCompletedServices(driverId);
      return _summarize(services);
    });
  }

  EarningsSummary _summarize(List<Service> services) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekStart = todayStart.subtract(Duration(days: now.weekday - 1));
    final monthStart = DateTime(now.year, now.month, 1);

    double today = 0, week = 0, month = 0, total = 0;
    for (final s in services) {
      final amount = s.driverEarnings;
      total += amount;
      // Imputar el ingreso a la FECHA DE COBRO (completed_at), no de creación
      final earned = s.completedAt ?? s.createdAt;
      if (!earned.isBefore(todayStart)) today += amount;
      if (!earned.isBefore(weekStart)) week += amount;
      if (!earned.isBefore(monthStart)) month += amount;
    }
    return EarningsSummary(
      today: today,
      week: week,
      month: month,
      total: total,
      completedCount: services.length,
    );
  }
}

final earningsProvider =
    AsyncNotifierProvider<EarningsNotifier, EarningsSummary>(EarningsNotifier.new);

class HistoryNotifier extends AsyncNotifier<List<Service>> {
  @override
  Future<List<Service>> build() async {
    final driverId = ref.watch(currentUserIdProvider);
    if (driverId == null) return <Service>[];
    return ref.read(serviceRepositoryProvider).getHistory(driverId);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    final driverId = ref.read(currentUserIdProvider);
    if (driverId == null) {
      state = const AsyncValue.data([]);
      return;
    }
    state = await AsyncValue.guard(
      () => ref.read(serviceRepositoryProvider).getHistory(driverId),
    );
  }
}

final historyProvider =
    AsyncNotifierProvider<HistoryNotifier, List<Service>>(HistoryNotifier.new);

class RatingsNotifier extends AsyncNotifier<List<Rating>> {
  @override
  Future<List<Rating>> build() async {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return <Rating>[];
    return ref.read(driverRepositoryProvider).getMyRatings(userId);
  }
}

final ratingsProvider =
    AsyncNotifierProvider<RatingsNotifier, List<Rating>>(RatingsNotifier.new);

final notificationsRepositoryProvider = Provider<NotificationsRepository>((ref) {
  return NotificationsRepository();
});

class NotificationsNotifier extends AsyncNotifier<List<AppNotification>> {
  RealtimeChannel? _channel;

  @override
  Future<List<AppNotification>> build() async {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return <AppNotification>[];

    _channel ??= db.supabase
        .channel('notifications:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (_) => refresh(),
        )
        .subscribe();

    ref.onDispose(() {
      _channel?.unsubscribe();
      _channel = null;
    });
    return ref.read(notificationsRepositoryProvider).getMine(userId);
  }

  Future<void> refresh() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    state = await AsyncValue.guard(
      () => ref.read(notificationsRepositoryProvider).getMine(userId),
    );
  }

  Future<void> markAllRead() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    try {
      await ref.read(notificationsRepositoryProvider).markAllRead(userId);
    } catch (e) {
      debugPrint('MUEVEX-C: no se pudo marcar leídas: $e');
      return;
    }
    final current = state.valueOrNull;
    if (current != null && current.any((n) => !n.read)) {
      state = AsyncValue.data(
        current.map((n) => n.copyWith(read: true)).toList(),
      );
    }
  }
}

final notificationsProvider =
    AsyncNotifierProvider<NotificationsNotifier, List<AppNotification>>(
  NotificationsNotifier.new,
);

/// Conteo de notificaciones sin leer para el badge de la barra superior.
final unreadNotificationsCountProvider = Provider<int>((ref) {
  final list = ref.watch(notificationsProvider).valueOrNull;
  if (list == null) return 0;
  return list.where((n) => !n.read).length;
});