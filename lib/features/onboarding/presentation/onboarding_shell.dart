import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:muevex_conductor/core/constants/app_constants.dart';
import 'package:muevex_conductor/core/theme/muevex_theme.dart';
import 'package:muevex_conductor/core/widgets/custom_button.dart';
import 'package:muevex_conductor/core/widgets/custom_text_field.dart';
import 'package:muevex_conductor/core/widgets/muevex_logo.dart';
import 'package:muevex_conductor/core/widgets/muevex_snackbar.dart';
import 'package:muevex_conductor/data/datasources/photo_storage.dart';
import 'package:muevex_conductor/features/auth/providers/auth_provider.dart';
import 'package:muevex_conductor/features/dashboard/providers/driver_provider.dart';

class OnboardingShell extends ConsumerStatefulWidget {
  const OnboardingShell({super.key});

  @override
  ConsumerState<OnboardingShell> createState() => _OnboardingShellState();
}

class _OnboardingShellState extends ConsumerState<OnboardingShell> {
  final _pageController = PageController();
  final _personalKey = GlobalKey<FormState>();
  final _vehicleKey = GlobalKey<FormState>();

  // Step 1
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  XFile? _photo;

  // Step 2
  final _plateCtrl = TextEditingController();
  String _vehicleType = 'motocarro';
  final _brandCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _capacityCtrl = TextEditingController(text: '500');
  XFile? _vehiclePhoto;

  bool _saving = false;
  int _step = 0;

  bool get _canContinue {
    switch (_step) {
      case 0:
        return _nameCtrl.text.trim().isNotEmpty &&
            _phoneCtrl.text.trim().isNotEmpty;
      case 1:
        final cap = int.tryParse(_capacityCtrl.text) ?? 0;
        return _plateCtrl.text.trim().length >= 5 &&
            _brandCtrl.text.trim().isNotEmpty &&
            _modelCtrl.text.trim().isNotEmpty &&
            cap >= 50;
      default:
        return true;
    }
  }

  void _onChanged() => setState(() {});

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).valueOrNull;
    if (user != null) {
      _nameCtrl.text = user.name;
      _phoneCtrl.text = user.phone ?? '';
    }
    for (final c in [
      _nameCtrl,
      _phoneCtrl,
      _plateCtrl,
      _brandCtrl,
      _modelCtrl,
      _capacityCtrl,
    ]) {
      c.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl,
      _phoneCtrl,
      _plateCtrl,
      _brandCtrl,
      _modelCtrl,
      _capacityCtrl,
    ]) {
      c.removeListener(_onChanged);
    }
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _plateCtrl.dispose();
    _brandCtrl.dispose();
    _modelCtrl.dispose();
    _capacityCtrl.dispose();
    _pageController.dispose();
    super.dispose();
  }

  bool _next() {
    switch (_step) {
      case 0:
        if (!_personalKey.currentState!.validate()) return false;
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.ease,
        );
        return true;
      case 1:
        if (!_vehicleKey.currentState!.validate()) return false;
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.ease,
        );
        return true;
      default:
        return false;
    }
  }

  void _back() {
    if (_step > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.ease,
      );
    }
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    try {
      final userId = ref.read(currentUserIdProvider);
      if (userId == null) return;

      String? photoUrl;
      if (_photo != null) {
        photoUrl = await PhotoStorage.upload(
          PhotoBucket.driver,
          userId,
          _photo!,
        );
      }

      String? vehiclePhotoUrl;
      if (_vehiclePhoto != null) {
        vehiclePhotoUrl = await PhotoStorage.upload(
          PhotoBucket.vehicle,
          userId,
          _vehiclePhoto!,
        );
      }

      await ref.read(driverProfileProvider.notifier).updateBasicInfo(
            name: _nameCtrl.text.trim(),
            phone: _phoneCtrl.text.trim(),
            photoUrl: photoUrl,
          );

      await ref.read(vehicleProvider.notifier).save(
            plate: _plateCtrl.text.trim(),
            type: _vehicleType,
            brand: _brandCtrl.text.trim(),
            model: _modelCtrl.text.trim(),
            capacityKg: int.tryParse(_capacityCtrl.text) ?? 500,
            photoUrl: vehiclePhotoUrl,
          );

      if (kDemoAutoVerified) {
        await ref.read(driverProfileProvider.notifier).setVerified();
      }

      if (!mounted) return;
      context.go('/home');
    } catch (_) {
      if (!mounted) return;
      MuevexSnackBar.error(context, 'Error al guardar los datos.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickImage(bool driver) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 85,
    );
    if (file == null) return;
    setState(() {
      if (driver) {
        _photo = file;
      } else {
        _vehiclePhoto = file;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final avatarBg = theme.brightness == Brightness.dark
        ? const Color(0xFF1F2337)
        : const Color(0xFFE9EAF5);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: MuevexTheme.primaryGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 12),
              const MuevexLogo(size: 60),
              const SizedBox(height: 4),
              const Text(
                'Completa tu perfil',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              // Step indicators
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _dot(0),
                  _line(),
                  _dot(1),
                  _line(),
                  _dot(2),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (i) => setState(() => _step = i),
                  children: [
                    // STEP 1: Personal
                    _buildPersonal(avatarBg),
                    // STEP 2: Vehicle
                    _buildVehicle(),
                    // STEP 3: Finish
                    _buildFinish(),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Row(
                  children: [
                    if (_step > 0)
                      Expanded(
                        child: CustomButton(
                          text: 'Atrás',
                          backgroundColor: Colors.white10,
                          textColor: Colors.white,
                          onPressed: _back,
                        ),
                      ),
                    if (_step > 0) const SizedBox(width: 12),
                    Expanded(
                      child: CustomButton(
                        text: _step == 2 ? 'Completar' : 'Continuar',
                        gradient: true,
                        loading: _saving,
                        enabled: _canContinue,
                        onPressed: _step == 2 ? _finish : () => _next(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dot(int i) {
    final active = i <= _step;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: active ? 32 : 8,
      height: 8,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        color: active ? MuevexTheme.accentColor : Colors.white24,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  Widget _line() => Container(
        width: 18,
        height: 2,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        color: Colors.white24,
      );

  Widget _buildPersonal(Color avatarBg) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Form(
          key: _personalKey,
          child: Column(
            children: [
              const SizedBox(height: 16),
              const Text(
                'Paso 1 de 3 — Información personal',
                style: TextStyle(
                  color: MuevexTheme.accentColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () => _pickImage(true),
                child: CircleAvatar(
                  radius: 56,
                  backgroundColor: avatarBg,
                  child: _photo != null
                      ? ClipOval(
                          child: Image.file(
                            File(_photo!.path),
                            fit: BoxFit.cover,
                            width: 112,
                            height: 112,
                          ),
                        )
                      : const Icon(Icons.camera_alt_outlined, size: 40),
                ),
              ),
              const SizedBox(height: 6),
              const Text('Toca para agregar foto', style: TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 24),
              CustomTextField(
                label: 'Nombre completo',
                controller: _nameCtrl,
                prefixIcon: Icons.person_outline,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa tu nombre' : null,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                label: 'Teléfono',
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                prefixIcon: Icons.phone_outlined,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa tu teléfono' : null,
              ),
            ],
          ),
        ),
      );

  Widget _buildVehicle() => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Form(
          key: _vehicleKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              const Text(
                'Paso 2 de 3 — Tu vehículo',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: MuevexTheme.accentColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => _pickImage(false),
                child: Container(
                  height: 110,
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: _vehiclePhoto != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.file(
                            File(_vehiclePhoto!.path),
                            fit: BoxFit.cover,
                          ),
                        )
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.directions_car_outlined, size: 36, color: Colors.white38),
                            SizedBox(height: 8),
                            Text('Toca para foto del vehículo', style: TextStyle(color: Colors.white38, fontSize: 12)),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 16),
              CustomTextField(
                label: 'Placa (formato ABC123)',
                controller: _plateCtrl,
                prefixIcon: Icons.badge_outlined,
                validator: (v) => (v == null || v.trim().length < 5) ? 'Placa inválida' : null,
                onChanged: (v) {
                  final upper = v?.toUpperCase() ?? '';
                  if (v != upper) _plateCtrl.value = _plateCtrl.value.copyWith(text: upper);
                },
              ),
              const SizedBox(height: 14),
              const Text('Tipo de vehículo', style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: kVehicleTypeNames.entries.map((e) {
                  final selected = _vehicleType == e.key;
                  return ChoiceChip(
                    label: Text(e.value),
                    selected: selected,
                    selectedColor: MuevexTheme.primaryColor,
                    backgroundColor: Colors.white10,
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : Colors.white70,
                    ),
                    onSelected: (_) => setState(() => _vehicleType = e.key),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              CustomTextField(
                label: 'Marca',
                controller: _brandCtrl,
                prefixIcon: Icons.label_outline,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa la marca' : null,
              ),
              const SizedBox(height: 14),
              CustomTextField(
                label: 'Modelo',
                controller: _modelCtrl,
                prefixIcon: Icons.car_rental_outlined,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa el modelo' : null,
              ),
              const SizedBox(height: 14),
              CustomTextField(
                label: 'Capacidad (kg)',
                controller: _capacityCtrl,
                keyboardType: TextInputType.number,
                prefixIcon: Icons.scale_outlined,
                validator: (v) {
                  final val = int.tryParse(v ?? '');
                  if (val == null || val < 50) return 'Capacidad mínima 50 kg';
                  return null;
                },
              ),
            ],
          ),
        ),
      );

  Widget _buildFinish() => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle_outline, size: 80, color: MuevexTheme.accentColor),
              const SizedBox(height: 20),
              Text(
                kDemoAutoVerified
                    ? '¡Listo! Tu perfil está completo.'
                    : '¡Casi listo!\nTu perfil será revisado por un administrador antes de activarse.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600, height: 1.4),
              ),
              if (!kDemoAutoVerified) ...[
                const SizedBox(height: 16),
                Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: MuevexTheme.warningColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: MuevexTheme.warningColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: MuevexTheme.warningColor,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Te notificaremos cuando tu cuenta sea aprobada y puedas aceptar servicios.',
                            style: TextStyle(
                              color: MuevexTheme.warningColor,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      );
}