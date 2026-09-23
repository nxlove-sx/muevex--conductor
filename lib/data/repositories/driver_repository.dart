import 'package:muevex_conductor/core/constants/app_constants.dart';
import 'package:muevex_conductor/core/supabase/supabase_client.dart' as db;
import 'package:muevex_conductor/data/models/driver_profile_model.dart';
import 'package:muevex_conductor/data/models/rating_model.dart';
import 'package:muevex_conductor/data/models/vehicle_model.dart';

class DriverRepository {
  final _client = db.supabase;

  Future<DriverProfile?> getProfile(String userId) async {
    final res = await _client
        .from('driver_profiles')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    if (res == null) return null;
    return DriverProfile.fromMap(res);
  }

  Future<DriverProfile> updateProfile({
    required String userId,
    DriverAvailability? availability,
    String? photoUrl,
    bool? isVerified,
    bool setLastSeen = false,
    String? name,
    String? phone,
  }) async {
    final payload = <String, dynamic>{};
    if (availability != null) payload['availability'] = availability.dbName;
    if (photoUrl != null) payload['photo_url'] = photoUrl;
    if (isVerified != null) payload['is_verified'] = isVerified;
    if (setLastSeen) payload['last_seen'] = DateTime.now().toUtc().toIso8601String();

    await _client.from('driver_profiles').update(payload).eq('user_id', userId);

    if (name != null || phone != null) {
      final u = <String, dynamic>{};
      if (name != null) u['name'] = name;
      if (phone != null) u['phone'] = phone;
      await _client.from('users').update(u).eq('id', userId);
    }

    final updated = await getProfile(userId);
    if (updated == null) throw StateError('Perfil de conductor no encontrado');
    return updated;
  }

  Future<Vehicle?> getVehicle(String driverProfileId) async {
    final res = await _client
        .from('vehicles')
        .select()
        .eq('driver_id', driverProfileId)
        .order('created_at', ascending: false)
        .limit(1).maybeSingle();
    if (res == null) return null;
    return Vehicle.fromMap(res);
  }

  Future<Vehicle> saveVehicle({
    required String driverProfileId,
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
    final existing = await _client
        .from('vehicles')
        .select('id')
        .eq('driver_id', driverProfileId)
        .limit(1).maybeSingle();

    final payload = <String, dynamic>{
      'driver_id': driverProfileId,
      'plate': plate.trim().toUpperCase(),
      'type': type,
      'brand': brand.trim(),
      'model': model.trim(),
      'capacity_kg': capacityKg,
    };

    if (existing != null) {
      // Edición: conserva year/color/description/photo_url existentes.
      final res = await _client
          .from('vehicles')
          .update(payload)
          .eq('id', existing['id'])
          .select()
          .single();
      return Vehicle.fromMap(res);
    }
    payload['year'] = year;
    if (color != null) payload['color'] = color;
    if (description != null) payload['description'] = description;
    if (photoUrl != null) payload['photo_url'] = photoUrl;
    final res = await _client.from('vehicles').insert(payload).select().single();
    return Vehicle.fromMap(res);
  }

  Future<void> deleteVehicle(String vehicleId) async {
    await _client.from('vehicles').delete().eq('id', vehicleId);
  }

  Future<List<Rating>> getMyRatings(String userId) async {
    final res = await _client
        .from('ratings')
        .select()
        .eq('rated_id', userId)
        .order('created_at', ascending: false)
        .limit(100);
    return res.map(Rating.fromMap).toList();
  }
}