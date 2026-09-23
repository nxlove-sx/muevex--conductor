import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:muevex_conductor/core/theme/muevex_theme.dart';

import 'package:muevex_conductor/core/widgets/custom_button.dart';
import 'package:muevex_conductor/core/widgets/custom_text_field.dart';
import 'package:muevex_conductor/core/widgets/muevex_logo.dart';
import 'package:muevex_conductor/core/widgets/muevex_snackbar.dart';
import 'package:muevex_conductor/features/auth/providers/auth_provider.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  bool get _canSubmit =>
      _email.text.trim().isNotEmpty && _password.text.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _email.addListener(_onChanged);
    _password.addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _email.removeListener(_onChanged);
    _password.removeListener(_onChanged);
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final ok = await ref
        .read(authProvider.notifier)
        .login(_email.text, _password.text);
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) {
      context.go('/home');
    } else {
      MuevexSnackBar.error(context, 'Correo o contraseña incorrectos.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: MuevexTheme.primaryGradient,
        ),
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light,
          child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const MuevexLogo(size: 90),
                    const SizedBox(height: 16),
                    const Text(
                      'MUEVEX Conductor',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Traslados de muebles y cargas pequeñas',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 36),
                    CustomTextField(
                      label: 'Correo electrónico',
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: Icons.mail_outline,
                      hintText: 'tu@correo.com',
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Ingresa tu correo' : null,
                    ),
                    const SizedBox(height: 14),
                    CustomTextField(
                      label: 'Contraseña',
                      controller: _password,
                      obscureText: _obscure,
                      prefixIcon: Icons.lock_outline,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: Colors.grey,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'Ingresa tu contraseña'
                          : null,
                    ),
                    const SizedBox(height: 28),
                    CustomButton(
                      text: 'Iniciar sesión',
                      gradient: true,
                      loading: _loading,
                      enabled: _canSubmit,
                      onPressed: _submit,
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => context.push('/register'),
                      child: const Text(
                        '¿Aún no tienes cuenta? Regístrate',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'App exclusiva para conductores',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          ),
        ),
      ),
    );
  }
}