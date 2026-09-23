import 'package:flutter/material.dart';

const String kAppName = 'Muevex Conductor';
const String kAppVersion = '1.0.0';

const Color kPrimary = Color(0xFF0F63FF);
const Color kSecondary = Color(0xFFFF6B35);
const Color kMint = Color(0xFF00C2A8);
const Color kDarkBg = Color(0xFF0D1321);

const Duration kLocationReportInterval = Duration(seconds: 8);
const double kRequestRadiusKm = 10;

/// En modo demo el conductor se considera verificado de inmediato
/// (el flujo real exige aprobación desde el admin).
const bool kDemoAutoVerified = true;

enum DriverAvailability { available, unavailable, busy }

extension DriverAvailabilityMapping on DriverAvailability {
  String get dbName {
    switch (this) {
      case DriverAvailability.available:
        return 'available';
      case DriverAvailability.unavailable:
        return 'unavailable';
      case DriverAvailability.busy:
        return 'busy';
    }
  }

  static DriverAvailability fromDbName(String? name) {
    switch (name) {
      case 'available':
        return DriverAvailability.available;
      case 'busy':
        return DriverAvailability.busy;
      default:
        return DriverAvailability.unavailable;
    }
  }
}

const Map<String, String> kLoadTypeNames = {
  'muebles': 'Muebles',
  'electrodomesticos': 'Electrodomésticos',
  'cajas': 'Cajas',
  'carga': 'Carga',
  'otro': 'Otro',
};

class ServiceStages {
  // Estados canónicos visibles en el flujo del conductor (spec 50)
  static const List<String> conductorStages = [
    'aceptado',
    'en_recogida',
    'en_curso',
    'completado',
  ];

  static const Map<String, String> labels = {
    'aceptado': 'Conductor aceptado',
    'en_recogida': 'Recogida',
    'en_curso': 'En curso',
    'completado': 'Completado',
  };
}

const Map<String, String> kVehicleTypeNames = {
  'motocarro': 'Motocarro',
  'camioneta': 'Camioneta',
  'furgoneta': 'Furgoneta',
  'pickup': 'Pickup / Camioneta',
  'camion': 'Camión',
  'otro': 'Otro',
};