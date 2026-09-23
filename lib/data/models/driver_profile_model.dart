import 'package:equatable/equatable.dart';

import 'package:muevex_conductor/core/constants/app_constants.dart';

class DriverProfile extends Equatable {
  final String id;
  final String userId;
  final bool isVerified;
  final double rating;
  final int totalServices;
  final DriverAvailability availability;
  final String? photoUrl;
  final DateTime? lastSeen;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const DriverProfile({
    required this.id,
    required this.userId,
    required this.isVerified,
    required this.rating,
    required this.totalServices,
    required this.availability,
    this.photoUrl,
    this.lastSeen,
    this.createdAt,
    this.updatedAt,
  });

  factory DriverProfile.fromMap(Map<String, dynamic> map) {
    return DriverProfile(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      isVerified: map['is_verified'] as bool? ?? false,
      rating: (map['rating'] as num?)?.toDouble() ?? 0,
      totalServices: (map['total_services'] as num?)?.toInt() ?? 0,
      availability: DriverAvailabilityMapping.fromDbName(
        map['availability'] as String?,
      ),
      photoUrl: map['photo_url'] as String?,
      lastSeen: map['last_seen'] != null
          ? DateTime.tryParse(map['last_seen'] as String)
          : null,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'is_verified': isVerified,
      'rating': rating,
      'total_services': totalServices,
      'availability': availability.dbName,
      'photo_url': photoUrl,
      'last_seen': lastSeen?.toIso8601String(),
    };
  }

  DriverProfile copyWith({
    String? id,
    String? userId,
    bool? isVerified,
    double? rating,
    int? totalServices,
    DriverAvailability? availability,
    String? photoUrl,
    DateTime? lastSeen,
  }) {
    return DriverProfile(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      isVerified: isVerified ?? this.isVerified,
      rating: rating ?? this.rating,
      totalServices: totalServices ?? this.totalServices,
      availability: availability ?? this.availability,
      photoUrl: photoUrl ?? this.photoUrl,
      lastSeen: lastSeen ?? this.lastSeen,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    userId,
    isVerified,
    rating,
    totalServices,
    availability,
    photoUrl,
    lastSeen,
  ];
}