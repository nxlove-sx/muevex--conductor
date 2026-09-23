import 'package:muevex_conductor/core/services/location_service.dart';
import 'package:muevex_conductor/core/supabase/supabase_client.dart' as db;
import 'package:muevex_conductor/data/models/driver_location_model.dart';

class LocationRepository {
  final _client = db.supabase;

  Future<void> upsertLiveLocation({
    required String driverId,
    required double latitude,
    required double longitude,
    String? serviceId,
    double heading = 0,
    double speed = 0,
  }) async {
    final payload = {
      'driver_id': driverId,
      'service_id': serviceId,
      'latitude': latitude,
      'longitude': longitude,
      'heading': heading,
      'speed': speed,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    try {
      await _client.from('driver_locations').upsert(payload, onConflict: 'driver_id');
    } catch (_) {
      // Esquema sin índice único en driver_id: inserta una fila nueva.
      await _client.from('driver_locations').insert(payload);
    }
  }

  /// Borra la fila de ubicación del conductor (al pasar a "No disponible"
  /// o cerrar sesión), para que no quede un punto fantasma en el mapa.
  Future<void> clearLocation(String driverId) async {
    try {
      await _client
          .from('driver_locations')
          .delete()
          .eq('driver_id', driverId);
    } catch (_) {}
  }

  /// Última ubicación registrada del conductor actual.
  Future<DriverLocation?> getLastLocation() async {
    final driverId = db.currentUserId();
    if (driverId == null) return null;
    final res = await _client
        .from('driver_locations')
        .select()
        .eq('driver_id', driverId)
        .order('updated_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (res == null) return null;
    return DriverLocation.fromMap(res);
  }

  // Caché corta de la posición en vivo: evita disparar un fix de GPS (de
  // hasta 15 s en algunos dispositivos) en CADA refresco de la cola cuando
  // los eventos realtime son frecuentes.
  static DriverLocation? _cachedLive;
  static DateTime _cachedAt = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _cacheTtl = Duration(seconds: 30);

  /// Ubicación ESTIMADA para filtrar solicitudes cercanas:
  /// usa la posición en vivo del dispositivo si está disponible (más fiable),
  /// y como respaldo la última fila guardada en la BD.
  Future<DriverLocation?> getEffectiveLastLocation() async {
    if (_cachedLive != null &&
        DateTime.now().difference(_cachedAt) < _cacheTtl) {
      return _cachedLive;
    }
    final position = await LocationService.getCurrentPosition();
    if (position != null) {
      final loc = DriverLocation(
        id: '',
        latitude: position.latitude,
        longitude: position.longitude,
        heading: position.heading,
        speed: position.speed,
        updatedAt: DateTime.now(),
      );
      _cachedLive = loc;
      _cachedAt = DateTime.now();
      return loc;
    }
    return getLastLocation();
  }
}