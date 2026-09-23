import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:muevex_conductor/core/theme/muevex_theme.dart';
import 'package:muevex_conductor/core/widgets/custom_button.dart';
import 'package:muevex_conductor/core/widgets/custom_text_field.dart';
import 'package:muevex_conductor/core/widgets/muevex_logo.dart';
import 'package:muevex_conductor/core/widgets/muevex_snackbar.dart';
import 'package:muevex_conductor/data/repositories/auth_repository.dart';
import 'package:muevex_conductor/features/auth/providers/auth_provider.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  bool get _canSubmit =>
      _name.text.trim().isNotEmpty &&
      _email.text.contains('@') &&
      _phone.text.trim().length >= 7 &&
      _password.text.length >= 8 &&
      _confirm.text == _password.text;

  @override
  void initState() {
    super.initState();
    for (final c in [_name, _email, _phone, _password, _confirm]) {
      c.addListener(_onChanged);
    }
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _password, _confirm]) {
      c.removeListener(_onChanged);
    }
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final result = await ref.read(authProvider.notifier).register(
          email: _email.text,
          password: _password.text,
          name: _name.text,
          phone: _phone.text,
        );
    if (!mounted) return;
    setState(() => _loading = false);
    switch (result) {
      case AuthResult.success:
        context.go('/onboarding');
      case AuthResult.needsEmailConfirm:
        MuevexSnackBar.info(
          context,
          'Revisa tu correo para confirmar la cuenta antes de iniciar sesión.',
        );
      case AuthResult.invalidCredentials:
      case AuthResult.failure:
        MuevexSnackBar.error(
          context,
          'No se pudo crear la cuenta. Inténtalo de nuevo.',
        );
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
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const MuevexLogo(size: 80),
                    const SizedBox(height: 12),
                    const Text(
                      'Regístrate como conductor',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 26),
                    CustomTextField(
                      label: 'Nombre completo',
                      controller: _name,
                      prefixIcon: Icons.person_outline,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Ingresa tu nombre' : null,
                    ),
                    const SizedBox(height: 14),
                    CustomTextField(
                      label: 'Correo electrónico',
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: Icons.mail_outline,
                      validator: (v) =>
                          (v == null || !v.contains('@')) ? 'Correo inválido' : null,
                    ),
                    const SizedBox(height: 14),
                    CustomTextField(
                      label: 'Teléfono',
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      prefixIcon: Icons.phone_outlined,
                      validator: (v) => (v == null || v.trim().length < 7)
                          ? 'Ingresa un teléfono válido'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    CustomTextField(
                      label: 'Contraseña',
                      controller: _password,
                      obscureText: _obscure,
                      prefixIcon: Icons.lock_outline,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscure ? Icons.visibility_off : Icons.visibility,
                          color: Colors.grey,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                      validator: (v) => (v == null || v.length < 6)
                          ? 'Mínimo 6 caracteres'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    CustomTextField(
                      label: 'Confirmar contraseña',
                      controller: _confirm,
                      obscureText: _obscure,
                      prefixIcon: Icons.lock_outline,
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Confirma tu contraseña';
                        }
                        return (v != _password.text)
                            ? 'Las contraseñas no coinciden'
                            : null;
                      },
                    ),
                    const SizedBox(height: 26),
                    CustomButton(
                      text: 'Crear cuenta',
                      gradient: true,
                      loading: _loading,
                      enabled: _canSubmit,
                      onPressed: _submit,
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => context.go('/login'),
                      child: const Text(
                        'Ya tengo cuenta',
                        style: TextStyle(color: Colors.white70),
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