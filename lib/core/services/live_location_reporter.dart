import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'package:muevex_conductor/core/constants/app_constants.dart';
import 'package:muevex_conductor/core/services/location_service.dart';
import 'package:muevex_conductor/data/repositories/location_repository.dart';

class LiveLocationReporter {
  final LocationRepository _repo = LocationRepository();
  StreamSubscription<Position>? _sub;
  String? _driverId;
  String? _serviceId;
  bool _enabled = false;
  DateTime _lastReport = DateTime.fromMillisecondsSinceEpoch(0);

  /// Único reporter compartido por toda la app: evita que el reporter del
  /// Home (botón "Disponible") y el de la navegación del servicio activo
  /// pisen el mismo `driver_locations` (último en escribir gana).
  void updateService(String? serviceId) {
    _serviceId = serviceId;
  }

  void attach(String driverId, String? serviceId) {
    _driverId = driverId.trim().isEmpty ? null : driverId;
    _serviceId = serviceId;
  }

  Future<bool> setEnabled(bool enabled) async {
    _enabled = enabled;
    if (!enabled) {
      await stop();
      return true;
    }
    final granted = await LocationService.requestPermission();
    if (!granted) {
      debugPrint('MUEVEX-C: permiso de ubicación denegado');
      return false;
    }
    _sub ??= LocationService.getPositionStream().listen((position) {
      if (!_enabled) return;
      _report(position);
    });
    return true;
  }

  Future<void> _report(Position position) async {
    final now = DateTime.now();
    if (now.difference(_lastReport) < kLocationReportInterval) return;
    _lastReport = now;
    final driverId = _driverId;
    if (driverId == null) return;
    try {
      await _repo.upsertLiveLocation(
        driverId: driverId,
        serviceId: _serviceId,
        latitude: position.latitude,
        longitude: position.longitude,
        heading: position.heading,
        speed: position.speed,
      );
    } catch (e) {
      debugPrint('MUEVEX-C: error al reportar ubicación: $e');
    }
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }

  /// Apaga por completo el reporte y elimina la fila de ubicación del
  /// conductor. Se usa al pasar a "No disponible" y al cerrar sesión para
  /// no dejar fantasmas en el mapa ni seguir gastando batería/GPS.
  Future<void> shutdown() async {
    await setEnabled(false);
    final driverId = _driverId;
    _driverId = null;
    _serviceId = null;
    if (driverId != null) {
      try {
        await _repo.clearLocation(driverId);
      } catch (_) {}
    }
  }

  Future<void> dispose() => stop();
}

/// Instancia global compartida por el Home y la pantalla de navegación.
final LiveLocationReporter sharedLocationReporter = LiveLocationReporter();