import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import 'package:muevex_conductor/data/models/user_model.dart';
import 'package:muevex_conductor/data/repositories/auth_repository.dart';

class AuthRefresh extends ChangeNotifier {
  AuthRefresh._();
  static final AuthRefresh instance = AuthRefresh._();
  void ping() => notifyListeners();
}

bool supabaseAuthState = false;

/// Listener global de sesión: se suscribe al arrancar (antes de que ningún
/// widget construya el provider) para restaurar "conductor sigue logueado"
/// sin depender del orden de build de Riverpod. Emite a [AuthRefresh]
/// para que el router re-evalúe el redirect tras cada evento de auth.
void initAuthListener() {
  final repo = AuthRepository();
  repo.onAuthState().listen((event) {
    final user = event.session?.user;
    supabaseAuthState = user != null;
    AuthRefresh.instance.ping();
  });
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

class AuthNotifier extends Notifier<AsyncValue<User?>> {
  StreamSubscription<AuthState>? _sub;

  @override
  AsyncValue<User?> build() {
    final repo = ref.watch(authRepositoryProvider);
    final current = repo.currentAuthUser;
    if (current != null) {
      supabaseAuthState = true;
      _loadProfile(current.id);
    } else {
      supabaseAuthState = false;
      state = const AsyncValue.data(null);
    }

    _sub = repo.onAuthState().listen((event) {
      final user = event.session?.user;
      if (user == null) {
        supabaseAuthState = false;
        state = const AsyncValue.data(null);
      } else {
        supabaseAuthState = true;
        _loadProfile(user.id);
      }
      AuthRefresh.instance.ping();
    });
    ref.onDispose(() => _sub?.cancel());
    return state;
  }

  Future<void> _loadProfile(String userId) async {
    state = const AsyncValue.loading();
    final repo = ref.read(authRepositoryProvider);
    state = await AsyncValue.guard(() => repo.getUserProfile(userId));
  }

  Future<bool> login(String email, String password) async {
    final repo = ref.read(authRepositoryProvider);
    final (result, profile) = await repo.login(email, password);
    if (result == AuthResult.success && profile != null) {
      supabaseAuthState = true;
      state = AsyncValue.data(profile);
      AuthRefresh.instance.ping();
      return true;
    }
    if (result != AuthResult.failure) {
      state = AsyncValue.data(null);
    }
    return false;
  }

  Future<AuthResult> register({
    required String email,
    required String password,
    required String name,
    String? phone,
  }) async {
    final repo = ref.read(authRepositoryProvider);
    final result = await repo.register(
      email: email,
      password: password,
      name: name,
      phone: phone,
    );
    if (result == AuthResult.success) {
      await login(email, password);
    }
    return result;
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) {
    return ref.read(authRepositoryProvider).changePassword(
          currentPassword: currentPassword,
          newPassword: newPassword,
        );
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    supabaseAuthState = false;
    state = const AsyncValue.data(null);
    AuthRefresh.instance.ping();
  }
}

final authProvider =
    NotifierProvider<AuthNotifier, AsyncValue<User?>>(AuthNotifier.new);

final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(authProvider).valueOrNull?.id;
});