import 'package:equatable/equatable.dart';

class Vehicle extends Equatable {
  final String id;
  final String driverId;
  final String plate;
  final String type;
  final String brand;
  final String model;
  final int capacityKg;
  final List<String> photos;
  final int year;
  final String? color;
  final String? description;
  final String status;
  final bool verified;
  final String? photoUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Vehicle({
    required this.id,
    required this.driverId,
    required this.plate,
    required this.type,
    required this.brand,
    required this.model,
    required this.capacityKg,
    this.photos = const [],
    this.year = 0,
    this.color,
    this.description,
    this.status = 'pendiente',
    this.verified = false,
    this.photoUrl,
    this.createdAt,
    this.updatedAt,
  });

  factory Vehicle.fromMap(Map<String, dynamic> map) {
    return Vehicle(
      id: map['id'] as String,
      driverId: map['driver_id'] as String,
      plate: map['plate'] as String? ?? '',
      type: map['type'] as String? ?? '',
      brand: map['brand'] as String? ?? '',
      model: map['model'] as String? ?? '',
      capacityKg: (map['capacity_kg'] as num?)?.toInt() ?? 500,
      photos: map['photos'] != null ? List<String>.from(map['photos']) : [],
      year: (map['year'] as num?)?.toInt() ?? 0,
      color: map['color'] as String?,
      description: map['description'] as String?,
      status: map['status'] as String? ?? 'pendiente',
      verified: map['verified'] as bool? ?? false,
      photoUrl: map['photo_url'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'] as String)
          : null,
    );
  }

  bool get isComplete => plate.isNotEmpty && type.isNotEmpty;

  String get displayName {
    final parts = [brand, model, plate].where((e) => e.isNotEmpty);
    return parts.isEmpty ? 'Sin vehículo' : parts.join(' ');
  }

  @override
  List<Object?> get props => [
    id,
    driverId,
    plate,
    type,
    brand,
    model,
    capacityKg,
    photos,
    year,
    color,
    description,
    status,
    verified,
    photoUrl,
  ];
}