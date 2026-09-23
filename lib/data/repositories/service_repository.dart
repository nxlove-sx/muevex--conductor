import 'dart:async';
import 'dart:math' as math;

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:muevex_conductor/core/supabase/supabase_client.dart' as db;
import 'package:muevex_conductor/data/models/service_model.dart';

class ServiceRepository {
  final _client = db.supabase;

  static const _activeStatuses = ['aceptado', 'en_recogida', 'en_curso'];
  static const _historyStatuses = [
    'completado',
    'cancelado_cliente',
    'cancelado_conductor',
  ];

  /// Solicitudes disponibles: status = 'solicitado' y sin conductor.
  /// Filtros opcionales según el vehículo/ubicación del conductor (spec 53).
  Future<List<Service>> getAvailableRequests({
    double? maxDistanceKm,
    double? requiredCapacityKg,
    double? driverLat,
    double? driverLng,
  }) async {
    var query = _client
        .from('services')
        .select()
        .eq('status', 'solicitado')
        .isFilter('driver_id', null)
        .order('created_at', ascending: false)
        .limit(30);

    var services = (await query).map(Service.fromMap).toList();

    if (requiredCapacityKg != null && requiredCapacityKg > 0) {
      services = services
          .where((s) =>
              s.loadWeightKg <= 0 ||
              s.loadWeightKg <= requiredCapacityKg)
          .toList();
    }

    if (driverLat != null && driverLng != null && maxDistanceKm != null) {
      services = services.where((s) {
        final d = _haversineKm(driverLat, driverLng, s.originLat, s.originLng);
        return d <= maxDistanceKm;
      }).toList();
    }

    return services;
  }

  double _haversineKm(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    final dLat = _rad(lat2 - lat1);
    final dLng = _rad(lng2 - lng1);
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(_rad(lat1)) * math.cos(_rad(lat2)) * math.pow(math.sin(dLng / 2), 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _rad(double deg) => deg * math.pi / 180.0;

  Future<Service> accept(String serviceId) async {
    final res = await _client.rpc(
      'accept_service',
      params: {'p_service_id': serviceId},
    );
    final rows = (res as List?) ?? [];
    if (rows.isEmpty) {
      throw StateError('Este servicio ya fue asignado a otro conductor.');
    }
    return Service.fromMap(rows.first as Map<String, dynamic>);
  }

  Future<Service?> getActiveService(String driverId) async {
    final res = await _client
        .from('services')
        .select()
        .eq('driver_id', driverId)
        .inFilter('status', _activeStatuses)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (res == null) return null;
    return Service.fromMap(res);
  }

  /// Transiciones controladas vía RPC (spec 50/60).
  Future<Service> updateStatus(String serviceId, ServiceStatus status) async {
    final res = await _client.rpc(
      'update_service_status',
      params: {'p_service_id': serviceId, 'p_status': status.dbName},
    );
    final rows = (res as List?) ?? [];
    if (rows.isEmpty) {
      throw StateError('No se pudo actualizar el estado del servicio.');
    }
    return Service.fromMap(rows.first as Map<String, dynamic>);
  }

  Future<Service> cancel(String serviceId) async {
    final res = await _client.rpc(
      'cancel_service',
      params: {'p_service_id': serviceId, 'p_cancelled_by': 'conductor'},
    );
    final rows = (res as List?) ?? [];
    if (rows.isEmpty) {
      throw StateError('No se pudo cancelar el servicio.');
    }
    return Service.fromMap(rows.first as Map<String, dynamic>);
  }

  Future<List<Service>> getHistory(String driverId) async {
    final res = await _client
        .from('services')
        .select()
        .eq('driver_id', driverId)
        .inFilter('status', _historyStatuses)
        .order('created_at', ascending: false)
        .limit(100);
    return res.map(Service.fromMap).toList();
  }

  Future<List<Service>> getCompletedServices(String driverId) async {
    final res = await _client
        .from('services')
        .select()
        .eq('driver_id', driverId)
        .eq('status', 'completado')
        .order('created_at', ascending: false)
        .limit(200);
    return res.map(Service.fromMap).toList();
  }

  Stream<Service?> watchActiveService(String driverId) {
    final controller = StreamController<Service?>();

    _client
        .channel('services:active:$driverId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'services',
          callback: (payload) async {
            try {
              final active = await getActiveService(driverId);
              controller.add(active);
            } catch (_) {
              controller.add(null);
            }
          },
        )
        .subscribe();

    return controller.stream;
  }
}