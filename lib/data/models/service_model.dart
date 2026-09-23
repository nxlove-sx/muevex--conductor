import 'package:equatable/equatable.dart';

/// Estados canónicos de la plataforma MUEVEX (spec 50).
/// Ambas apps comparten EXACTAMENTE estos estados.
enum ServiceStatus {
  solicitado,
  aceptado,
  enRecogida,
  enCurso,
  completado,
  canceladoCliente,
  canceladoConductor,
}

extension ServiceStatusMapping on ServiceStatus {
  /// Nombre tal como se almacena en la base de datos (único y canónico).
  String get dbName {
    switch (this) {
      case ServiceStatus.solicitado:
        return 'solicitado';
      case ServiceStatus.aceptado:
        return 'aceptado';
      case ServiceStatus.enRecogida:
        return 'en_recogida';
      case ServiceStatus.enCurso:
        return 'en_curso';
      case ServiceStatus.completado:
        return 'completado';
      case ServiceStatus.canceladoCliente:
        return 'cancelado_cliente';
      case ServiceStatus.canceladoConductor:
        return 'cancelado_conductor';
    }
  }

  /// Convierte un nombre de la base de datos al enum Dart.
  /// Resiste valores legacy de versiones anteriores.
  static ServiceStatus fromDbName(String dbName) {
    switch (dbName.toLowerCase()) {
      case 'solicitado':
        return ServiceStatus.solicitado;
      case 'aceptado':
      case 'driver_accepted':
      case 'driver_on_way':
        return ServiceStatus.aceptado;
      case 'en_recogida':
      case 'driver_arrived':
      case 'loading':
        return ServiceStatus.enRecogida;
      case 'en_curso':
      case 'in_transit':
      case 'arrived_destination':
        return ServiceStatus.enCurso;
      case 'completado':
      case 'completed':
      case 'delivered':
        return ServiceStatus.completado;
      case 'cancelado_cliente':
        return ServiceStatus.canceladoCliente;
      case 'cancelado_conductor':
      case 'cancelled':
        return ServiceStatus.canceladoConductor;
      default:
        return ServiceStatus.solicitado;
    }
  }
}

extension ServiceStatusExtension on ServiceStatus {
  String get arabicName {
    switch (this) {
      case ServiceStatus.solicitado:
        return 'Solicitado';
      case ServiceStatus.aceptado:
        return 'Conductor aceptado';
      case ServiceStatus.enRecogida:
        return 'En recogida';
      case ServiceStatus.enCurso:
        return 'En curso';
      case ServiceStatus.completado:
        return 'Completado';
      case ServiceStatus.canceladoCliente:
        return 'Cancelado por cliente';
      case ServiceStatus.canceladoConductor:
        return 'Cancelado por conductor';
    }
  }

  /// Estados considerados "activos" para el conductor.
  bool get isActive =>
      this == ServiceStatus.aceptado ||
      this == ServiceStatus.enRecogida ||
      this == ServiceStatus.enCurso;
}

class Service extends Equatable {
  final String id;
  final String customerId;
  final String? driverId;
  final ServiceStatus status;

  final double priceBase;
  final double priceTotal;
  final double? priceOffer;

  final double originLat;
  final double originLng;
  final double destinationLat;
  final double destinationLng;

  final String origin;
  final String destination;
  final String? originName;
  final String? destinationName;

  final String description;

  final double distanceKm;
  final int durationMinutes;

  final String loadType;
  final String? loadDescription;
  final double loadWeightKg;
  final int floors;
  final bool loadingHelp;
  final List<String> photos;

  final double estimatedPrice;
  final double? finalPrice;
  final double platformFee;
  final double driverEarnings;

  final DateTime createdAt;
  final DateTime? acceptedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;

  // Campos heredados de versiones anteriores (solo lectura/backwards-compat)
  final double loadWeight;
  final double estimatedTimeMin;
  final bool needsHelp;
  final List<String> loadPhotos;
  final Map<String, dynamic> loadDetails;
  final double recommendedPrice;

  const Service({
    required this.id,
    required this.customerId,
    this.driverId,
    required this.status,
    this.priceBase = 0,
    this.priceTotal = 0,
    this.priceOffer,
    required this.originLat,
    required this.originLng,
    required this.destinationLat,
    required this.destinationLng,
    this.origin = '',
    this.destination = '',
    this.originName,
    this.destinationName,
    this.description = '',
    this.distanceKm = 0,
    this.durationMinutes = 0,
    this.loadType = 'muebles',
    this.loadDescription,
    this.loadWeightKg = 0,
    this.floors = 0,
    this.loadingHelp = false,
    this.photos = const [],
    this.estimatedPrice = 0,
    this.finalPrice,
    this.platformFee = 0,
    this.driverEarnings = 0,
    required this.createdAt,
    this.acceptedAt,
    this.startedAt,
    this.completedAt,
    this.loadWeight = 0,
    this.estimatedTimeMin = 0,
    this.needsHelp = false,
    this.loadPhotos = const [],
    this.loadDetails = const {},
    this.recommendedPrice = 0,
  });

  factory Service.fromMap(Map<String, dynamic> map) {
    final estimated = (map['estimated_price'] as num?)?.toDouble() ??
        (map['price_base'] as num?)?.toDouble() ??
        0.0;
    return Service(
      id: map['id'] as String,
      customerId: map['customer_id'] as String,
      driverId: map['driver_id'] as String?,
      status: ServiceStatusMapping.fromDbName(map['status'] as String),
      priceBase: (map['price_base'] as num?)?.toDouble() ?? 0.0,
      priceTotal: (map['price_total'] as num?)?.toDouble() ??
          (map['price_base'] as num?)?.toDouble() ??
          0.0,
      priceOffer: map['price_offer'] != null ? (map['price_offer'] as num).toDouble() : null,
      originLat: (map['origin_lat'] as num?)?.toDouble() ?? 0.0,
      originLng: (map['origin_lng'] as num?)?.toDouble() ?? 0.0,
      destinationLat: (map['destination_lat'] as num?)?.toDouble() ?? 0.0,
      destinationLng: (map['destination_lng'] as num?)?.toDouble() ?? 0.0,
      origin: map['origin'] as String? ?? '',
      destination: map['destination'] as String? ?? '',
      originName: map['origin_name'] as String?,
      destinationName: map['destination_name'] as String?,
      description: map['description'] as String? ?? '',
      distanceKm: (map['distance_km'] as num?)?.toDouble() ?? 0.0,
      durationMinutes:
          (map['duration_minutes'] as num?)?.toInt() ?? (map['estimated_time_min'] as num?)?.toInt() ?? 0,
      loadType: map['load_type'] as String? ?? 'muebles',
      loadDescription: map['load_description'] as String?,
      loadWeightKg: (map['load_weight_kg'] as num?)?.toDouble() ?? 0.0,
      floors: (map['floors'] as num?)?.toInt() ?? 0,
      loadingHelp: (map['loading_help'] as bool?) ??
          (map['needs_help'] as bool?) ??
          false,
      photos: map['photos'] != null
          ? List<String>.from(map['photos'])
          : (map['load_photos'] != null ? List<String>.from(map['load_photos']) : const <String>[]),
      estimatedPrice: estimated,
      finalPrice: map['final_price'] != null ? (map['final_price'] as num).toDouble() : null,
      platformFee: (map['platform_fee'] as num?)?.toDouble() ?? 0.0,
      driverEarnings: (map['driver_earnings'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.parse(map['created_at'] as String),
      acceptedAt: map['accepted_at'] != null
          ? DateTime.tryParse(map['accepted_at'] as String)
          : null,
      startedAt: map['started_at'] != null
          ? DateTime.tryParse(map['started_at'] as String)
          : null,
      completedAt: map['completed_at'] != null
          ? DateTime.tryParse(map['completed_at'] as String)
          : null,
      loadWeight: (map['load_weight'] as num?)?.toDouble() ?? 0.0,
      estimatedTimeMin: (map['estimated_time_min'] as num?)?.toDouble() ?? 0.0,
      needsHelp: map['needs_help'] as bool? ?? false,
      loadPhotos: map['load_photos'] != null
          ? List<String>.from(map['load_photos'])
          : const <String>[],
      loadDetails: map['load_details'] != null
          ? Map<String, dynamic>.from(map['load_details'])
          : const <String, dynamic>{},
      recommendedPrice: (map['recommended_price'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Service copyWith({
    ServiceStatus? status,
    String? driverId,
    DateTime? acceptedAt,
    DateTime? startedAt,
    DateTime? completedAt,
    double? finalPrice,
    double? driverEarnings,
  }) {
    return Service(
      id: id,
      customerId: customerId,
      driverId: driverId ?? this.driverId,
      status: status ?? this.status,
      priceBase: priceBase,
      priceTotal: priceTotal,
      priceOffer: priceOffer,
      originLat: originLat,
      originLng: originLng,
      destinationLat: destinationLat,
      destinationLng: destinationLng,
      origin: origin,
      destination: destination,
      originName: originName,
      destinationName: destinationName,
      description: description,
      distanceKm: distanceKm,
      durationMinutes: durationMinutes,
      loadType: loadType,
      loadDescription: loadDescription,
      loadWeightKg: loadWeightKg,
      floors: floors,
      loadingHelp: loadingHelp,
      photos: photos,
      estimatedPrice: estimatedPrice,
      finalPrice: finalPrice ?? this.finalPrice,
      platformFee: platformFee,
      driverEarnings: driverEarnings ?? this.driverEarnings,
      createdAt: createdAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      loadWeight: loadWeight,
      estimatedTimeMin: estimatedTimeMin,
      needsHelp: needsHelp,
      loadPhotos: loadPhotos,
      loadDetails: loadDetails,
      recommendedPrice: recommendedPrice,
    );
  }

  @override
  List<Object?> get props => [
    id, customerId, driverId, status, priceBase, priceTotal, priceOffer,
    originLat, originLng, destinationLat, destinationLng, originName,
    destinationName, distanceKm, estimatedPrice, finalPrice, createdAt,
    acceptedAt, startedAt, completedAt,
  ];
}