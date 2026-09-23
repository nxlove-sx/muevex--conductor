import 'package:equatable/equatable.dart';

class DriverLocation extends Equatable {
  final String id;
  final String? driverId;
  final String? serviceId;
  final double latitude;
  final double longitude;
  final double heading;
  final double speed;
  final DateTime? updatedAt;

  const DriverLocation({
    required this.id,
    this.driverId,
    this.serviceId,
    required this.latitude,
    required this.longitude,
    this.heading = 0,
    this.speed = 0,
    this.updatedAt,
  });

  factory DriverLocation.fromMap(Map<String, dynamic> map) {
    return DriverLocation(
      id: map['id'] as String,
      driverId: map['driver_id'] as String?,
      serviceId: map['service_id'] as String?,
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0,
      heading: (map['heading'] as num?)?.toDouble() ?? 0,
      speed: (map['speed'] as num?)?.toDouble() ?? 0,
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'] as String)
          : null,
    );
  }

  @override
  List<Object?> get props => [
    id,
    driverId,
    serviceId,
    latitude,
    longitude,
    heading,
    speed,
    updatedAt,
  ];
}