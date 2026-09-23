import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:muevex_conductor/core/constants/app_constants.dart';
import 'package:muevex_conductor/core/theme/muevex_theme.dart';
import 'package:muevex_conductor/core/widgets/custom_button.dart';
import 'package:muevex_conductor/core/widgets/custom_text_field.dart';
import 'package:muevex_conductor/core/widgets/muevex_snackbar.dart';
import 'package:muevex_conductor/core/widgets/state_views.dart';
import 'package:muevex_conductor/features/dashboard/providers/driver_provider.dart';

class VehiclePage extends ConsumerStatefulWidget {
  const VehiclePage({super.key});

  @override
  ConsumerState<VehiclePage> createState() => _VehiclePageState();
}

class _VehiclePageState extends ConsumerState<VehiclePage> {
  final _formKey = GlobalKey<FormState>();
  final _plate = TextEditingController();
  final _brand = TextEditingController();
  final _model = TextEditingController();
  final _capacity = TextEditingController();
  String _type = 'motocarro';
  bool _saving = false;

  bool get _canSave =>
      _plate.text.trim().length >= 5 &&
      _brand.text.trim().isNotEmpty &&
      _model.text.trim().isNotEmpty &&
      (int.tryParse(_capacity.text) ?? 0) >= 50;

  @override
  void initState() {
    super.initState();
    final v = ref.read(vehicleProvider).valueOrNull;
    if (v != null) {
      _plate.text = v.plate;
      _brand.text = v.brand;
      _model.text = v.model;
      _capacity.text = '${v.capacityKg}';
      _type = v.type;
    }
    for (final c in [_plate, _brand, _model, _capacity]) {
      c.addListener(_onChanged);
    }
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    for (final c in [_plate, _brand, _model, _capacity]) {
      c.removeListener(_onChanged);
    }
    _plate.dispose();
    _brand.dispose();
    _model.dispose();
    _capacity.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final ok = await ref.read(vehicleProvider.notifier).save(
          plate: _plate.text.trim(),
          type: _type,
          brand: _brand.text.trim(),
          model: _model.text.trim(),
          capacityKg: int.tryParse(_capacity.text) ?? 500,
        );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      MuevexSnackBar.success(context, 'Vehículo guardado');
    } else {
      MuevexSnackBar.error(context, 'No se pudo guardar el vehículo');
    }
    if (ok) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: brandMuevexAppBar(title: 'Mi vehículo'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CustomTextField(
                label: 'Placa',
                controller: _plate,
                prefixIcon: Icons.badge_outlined,
                validator: (v) => (v == null || v.trim().length < 5)
                    ? 'Placa inválida'
                    : null,
                onChanged: (v) {
                  final upper = v?.toUpperCase() ?? '';
                  if (v != upper) {
                    _plate.value = _plate.value.copyWith(text: upper);
                  }
                },
              ),
              const SizedBox(height: 14),
              const Text('Tipo de vehículo'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: kVehicleTypeNames.entries.map((e) {
                  final selected = _type == e.key;
                  return ChoiceChip(
                    label: Text(e.value),
                    selected: selected,
                    selectedColor: MuevexTheme.primaryColor,
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : Colors.black87,
                    ),
                    onSelected: (_) => setState(() => _type = e.key),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              CustomTextField(
                label: 'Marca',
                controller: _brand,
                prefixIcon: Icons.label_outline,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Marca requerida' : null,
              ),
              const SizedBox(height: 14),
              CustomTextField(
                label: 'Modelo',
                controller: _model,
                prefixIcon: Icons.car_rental_outlined,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Modelo requerido' : null,
              ),
              const SizedBox(height: 14),
              CustomTextField(
                label: 'Capacidad (kg)',
                controller: _capacity,
                keyboardType: TextInputType.number,
                prefixIcon: Icons.scale_outlined,
                validator: (v) => (int.tryParse(v ?? '') ?? 0) < 50
                    ? 'Capacidad mínima 50 kg'
                    : null,
              ),
              const SizedBox(height: 24),
              CustomButton(
                text: 'Guardar vehículo',
                gradient: true,
                loading: _saving,
                enabled: _canSave,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}