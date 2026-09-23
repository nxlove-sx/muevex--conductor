import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:muevex_conductor/core/constants/app_constants.dart';
import 'package:muevex_conductor/data/models/driver_profile_model.dart';
import 'package:muevex_conductor/data/models/vehicle_model.dart';
import 'package:muevex_conductor/data/repositories/driver_repository.dart';
import 'package:muevex_conductor/features/auth/providers/auth_provider.dart';

final driverRepositoryProvider = Provider<DriverRepository>((ref) {
  return DriverRepository();
});

class DriverProfileNotifier extends AsyncNotifier<DriverProfile?> {
  @override
  Future<DriverProfile?> build() async {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return null;
    final profile = await ref.read(driverRepositoryProvider).getProfile(userId);
    return profile;
  }

  Future<bool> toggleAvailability(bool online) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return false;
    try {
      final updated = await ref.read(driverRepositoryProvider).updateProfile(
            userId: userId,
            availability: online
                ? DriverAvailability.available
                : DriverAvailability.unavailable,
            setLastSeen: true,
          );
      state = AsyncValue.data(updated);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateBasicInfo({
    String? name,
    String? phone,
    String? photoUrl,
  }) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return false;
    try {
      final updated = await ref.read(driverRepositoryProvider).updateProfile(
            userId: userId,
            name: name,
            phone: phone,
            photoUrl: photoUrl,
          );
      state = AsyncValue.data(updated);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> setVerified() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return false;
    try {
      final updated = await ref.read(driverRepositoryProvider).updateProfile(
            userId: userId,
            isVerified: true,
          );
      state = AsyncValue.data(updated);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> setBusy() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return false;
    try {
      final updated = await ref.read(driverRepositoryProvider).updateProfile(
            userId: userId,
            availability: DriverAvailability.busy,
          );
      state = AsyncValue.data(updated);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> setAvailable() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return false;
    try {
      final updated = await ref.read(driverRepositoryProvider).updateProfile(
            userId: userId,
            availability: DriverAvailability.available,
          );
      state = AsyncValue.data(updated);
      return true;
    } catch (_) {
      return false;
    }
  }
}

final driverProfileProvider =
    AsyncNotifierProvider<DriverProfileNotifier, DriverProfile?>(
  DriverProfileNotifier.new,
);

class VehicleNotifier extends AsyncNotifier<Vehicle?> {
  @override
  Future<Vehicle?> build() async {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return null;
    return ref.read(driverRepositoryProvider).getVehicle(userId);
  }

  Future<bool> save({
    required String plate,
    required String type,
    required String brand,
    required String model,
    required int capacityKg,
    int year = 0,
    String? color,
    String? description,
    String? photoUrl,
  }) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return false;
    try {
      final vehicle = await ref.read(driverRepositoryProvider).saveVehicle(
            driverProfileId: userId,
            plate: plate,
            type: type,
            brand: brand,
            model: model,
            capacityKg: capacityKg,
            year: year,
            color: color,
            description: description,
            photoUrl: photoUrl,
          );
      state = AsyncValue.data(vehicle);
      return true;
    } catch (_) {
      return false;
    }
  }
}

final vehicleProvider =
    AsyncNotifierProvider<VehicleNotifier, Vehicle?>(VehicleNotifier.new);

final availableProvider = StateProvider<bool>((ref) {
  final profile = ref.watch(driverProfileProvider).valueOrNull;
  return profile?.availability == DriverAvailability.available;
});