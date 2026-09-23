import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:muevex_conductor/core/supabase/supabase_client.dart' as db;
import 'package:muevex_conductor/data/models/user_model.dart' as models;

enum AuthResult {
  success,
  needsEmailConfirm,
  invalidCredentials,
  failure,
}

class AuthRepository {
  final _client = db.supabase;

  dynamic get currentAuthUser => _client.auth.currentUser;

  /// Cambia la contraseña verificando la actual del usuario logueado.
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final email = _client.auth.currentUser?.email;
    if (email == null) return false;
    try {
      final res = await _client.auth.signInWithPassword(
        email: email,
        password: currentPassword,
      );
      if (res.user == null) return false;
      await _client.auth.updateUser(UserAttributes(password: newPassword));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<(AuthResult, models.User?)> login(String email, String password) async {
    try {
      final res = await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      if (res.user == null) return (AuthResult.failure, null);
      final profile = await getUserProfile(res.user!.id);
      return (AuthResult.success, profile);
    } on AuthException {
      return (AuthResult.invalidCredentials, null);
    } catch (_) {
      return (AuthResult.failure, null);
    }
  }

  Future<AuthResult> register({
    required String email,
    required String password,
    required String name,
    String? phone,
  }) async {
    try {
      final res = await _client.auth.signUp(
        email: email.trim(),
        password: password,
      );
      if (res.user == null) {
        return AuthResult.failure;
      }
      final confirmed = res.user!.emailConfirmedAt != null ||
          (res.user!.identities?.isNotEmpty ?? false);
      if (!confirmed) {
        // Si el proyecto de Supabase exige confirmación por correo, no
        // creamos perfiles ni damos por registrada una cuenta sin verificar.
        return AuthResult.needsEmailConfirm;
      }

      await _client.from('users').insert({
        'id': res.user!.id,
        'email': email.trim(),
        'role': 'driver',
        'name': name.trim(),
        'phone': phone,
      });

      await _client.from('driver_profiles').insert({
        'id': res.user!.id,
        'user_id': res.user!.id,
        'is_verified': false,
        'rating': 0,
        'total_services': 0,
        'availability': 'unavailable',
      });
      return AuthResult.success;
    } on AuthException catch (e) {
      final m = e.message.toLowerCase();
      if (m.contains('confirm')) return AuthResult.needsEmailConfirm;
      return AuthResult.failure;
    } catch (_) {
      return AuthResult.failure;
    }
  }

  Future<models.User> getUserProfile(String userId) => db.getUserProfile(userId);

  Future<void> logout() async {
    await _client.auth.signOut();
  }

  Stream<AuthState> onAuthState() {
    return _client.auth.onAuthStateChange;
  }
}