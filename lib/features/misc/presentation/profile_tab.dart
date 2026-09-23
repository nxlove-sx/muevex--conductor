import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:muevex_conductor/core/constants/app_constants.dart';
import 'package:muevex_conductor/core/services/live_location_reporter.dart';
import 'package:muevex_conductor/core/theme/muevex_theme.dart';
import 'package:muevex_conductor/core/widgets/muevex_snackbar.dart';
import 'package:muevex_conductor/data/datasources/photo_storage.dart';
import 'package:muevex_conductor/features/active_service/providers/active_service_provider.dart';
import 'package:muevex_conductor/features/auth/providers/auth_provider.dart';
import 'package:muevex_conductor/features/dashboard/providers/driver_provider.dart';
import 'package:muevex_conductor/features/dashboard/providers/requests_provider.dart';
import 'package:muevex_conductor/features/misc/providers/earnings_history_providers.dart';

class ProfileTab extends ConsumerStatefulWidget {
  const ProfileTab({super.key});

  @override
  ConsumerState<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends ConsumerState<ProfileTab> {
  bool _uploadingPhoto = false;

  Future<void> _changePhoto() async {
    final file = await PhotoStorage.pickImage();
    if (file == null || !mounted) return;
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    setState(() => _uploadingPhoto = true);
    try {
      final url =
          await PhotoStorage.upload(PhotoBucket.driver, userId, file);
      final ok = await ref
          .read(driverProfileProvider.notifier)
          .updateBasicInfo(photoUrl: url);
      if (!mounted) return;
      if (ok) {
        MuevexSnackBar.success(context, 'Foto de perfil actualizada');
      } else {
        MuevexSnackBar.error(context, 'No se pudo guardar la foto');
      }
    } catch (_) {
      if (mounted) {
        MuevexSnackBar.error(context, 'No se pudo subir la foto');
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _showChangePassword() async {
    if (!mounted) return;
    final current = TextEditingController();
    final next = TextEditingController();
    final confirm = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cambiar contraseña'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: current,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Contraseña actual'),
                validator: (v) => (v != null && v.isNotEmpty)
                    ? null
                    : 'Ingresa tu contraseña actual',
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: next,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Nueva contraseña'),
                validator: (v) =>
                    v == null || v.length < 8 ? 'Mínimo 8 caracteres' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: confirm,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Confirmar contraseña'),
                validator: (v) =>
                    v != next.text ? 'Las contraseñas no coinciden' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final ok = await ref.read(authProvider.notifier).changePassword(
                    currentPassword: current.text,
                    newPassword: next.text,
                  );
              if (ctx.mounted) Navigator.pop(ctx, ok);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (saved ?? false) {
      MuevexSnackBar.success(context, 'Contraseña actualizada.');
    } else if (saved == false) {
      MuevexSnackBar.error(context, 'La contraseña actual no es correcta.');
    }
  }


  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).valueOrNull;
    final profile = ref.watch(driverProfileProvider).valueOrNull;
    final vehicle = ref.watch(vehicleProvider).valueOrNull;
    final photoUrl = profile?.photoUrl;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionCard(
          title: 'Foto de perfil',
          icon: Icons.photo_camera_outlined,
          trailingButton: TextButton(
            onPressed: _uploadingPhoto ? null : _changePhoto,
            child: Text(_uploadingPhoto ? 'Subiendo…' : 'Cambiar'),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: MuevexTheme.primaryColor,
                    child: photoUrl != null && photoUrl.isNotEmpty
                        ? ClipOval(
                            child: Image.network(
                              photoUrl,
                              width: 68,
                              height: 68,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                  Icons.person,
                                  size: 36,
                                  color: Colors.white),
                            ),
                          )
                        : const Icon(Icons.person,
                            size: 36, color: Colors.white),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      _uploadingPhoto
                          ? 'Subiendo tu foto…'
                          : 'Esta foto aparece en la tarjeta que ven '
                              'los clientes cuando reciben tu pedido.',
                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _VerificationBanner(
          verified: kDemoAutoVerified || (profile?.isVerified ?? false),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Cuenta',
          icon: Icons.person_outline,
          children: [
            ListTile(
              leading: const Icon(Icons.person),
              title: Text(user?.name ?? 'Conductor'),
              subtitle: Text(user?.email ?? ''),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.phone),
              title: Text(user?.phone?.isNotEmpty == true ? user!.phone! : 'Sin teléfono'),
            ),
            ListTile(
              leading: const Icon(Icons.star),
              title: Text('${profile?.rating ?? 0.0} reputación'),
              trailing: TextButton(
                onPressed: () => context.push('/ratings'),
                child: const Text('Ver reseñas'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Vehículo',
          icon: Icons.directions_car_outlined,
          trailingButton: TextButton(
            onPressed: () => context.push('/vehicle'),
            child: const Text('Editar'),
          ),
          children: [
            ListTile(
              leading: const Icon(Icons.directions_car),
              title: Text(vehicle?.displayName ?? 'Sin vehículo configurado'),
              subtitle: Text(
                vehicle != null
                    ? 'Placa ${vehicle.plate} · ${vehicle.capacityKg} kg'
                    : 'Agrega un vehículo',
              ),
              onTap: () => context.push('/vehicle'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Seguridad',
          icon: Icons.verified_user_outlined,
          children: [
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text('Cambiar contraseña'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _showChangePassword,
            ),
          ],
        ),
        _SectionCard(
          title: 'Ayuda',
          icon: Icons.support_agent_outlined,
          children: [
            const ListTile(
              leading: Icon(Icons.help_outline),
              title: Text('Centro de ayuda'),
              trailing: Icon(Icons.chevron_right),
            ),
            ListTile(
              leading: Icon(Icons.logout, color: MuevexTheme.errorColor),
              title: Text('Cerrar sesión', style: TextStyle(color: MuevexTheme.errorColor)),
              onTap: () async {
                // Teardown completo: se detiene el reporte/ubicación y se
                // invalidan los providers con canales realtime para que no
                // sigan consumiendo red ni recursos tras el logout.
                await sharedLocationReporter.shutdown();
                ref.invalidate(activeServiceProvider);
                ref.invalidate(requestsProvider);
                ref.invalidate(earningsProvider);
                ref.invalidate(historyProvider);
                ref.invalidate(notificationsProvider);
                await ref.read(authProvider.notifier).logout();
                if (context.mounted) context.go('/login');
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _VerificationBanner extends StatelessWidget {
  final bool verified;
  const _VerificationBanner({required this.verified});

  @override
  Widget build(BuildContext context) {
    final color = verified ? MuevexTheme.accentColor : MuevexTheme.warningColor;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(verified ? Icons.verified : Icons.hourglass_top, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              verified ? 'Cuenta verificada' : 'Tu cuenta está pendiente de aprobación',
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  final Widget? trailingButton;
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
    this.trailingButton,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Icon(icon, size: 20, color: MuevexTheme.primaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                if (trailingButton != null) trailingButton!,
              ],
            ),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}