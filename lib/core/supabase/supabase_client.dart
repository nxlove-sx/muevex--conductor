import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import 'package:muevex_conductor/core/supabase/supabase_config.dart';
import 'package:muevex_conductor/data/models/user_model.dart' as models;

late final SupabaseClient supabase;

class SecureLocalStorage extends LocalStorage {
  SecureLocalStorage({required this.persistSessionKey});

  final String persistSessionKey;
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() => _storage.containsKey(key: persistSessionKey);

  @override
  Future<String?> accessToken() => _storage.read(key: persistSessionKey);

  @override
  Future<void> removePersistedSession() =>
      _storage.delete(key: persistSessionKey);

  @override
  Future<void> persistSession(String persistSessionString) =>
      _storage.write(key: persistSessionKey, value: persistSessionString);
}

Future<void> initSupabase() async {
  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    publishableKey: SupabaseConfig.supabaseAnonKey,
    authOptions: FlutterAuthClientOptions(
      // Sesión en almacenamiento cifrado (flutter_secure_storage).
      localStorage: SecureLocalStorage(
        persistSessionKey:
            'sb-${Uri.parse(SupabaseConfig.supabaseUrl).host.split('.').first}-auth-token',
      ),
    ),
  );
  supabase = Supabase.instance.client;
}

String? currentUserId() => supabase.auth.currentUser?.id;

Future<models.User> getUserProfile(String userId) async {
  final res = await supabase.from('users').select().eq('id', userId).single();
  return models.User.fromMap(res);
}

Future<models.User?> supabaseAuthUser() async {
  final id = currentUserId();
  if (id == null) return null;
  try {
    return await getUserProfile(id);
  } catch (_) {
    return null;
  }
}