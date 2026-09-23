import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:muevex_conductor/core/utils/money.dart';
import 'package:muevex_conductor/core/router/app_router.dart';
import 'package:muevex_conductor/core/theme/muevex_theme.dart';
import 'package:muevex_conductor/core/widgets/muevex_snackbar.dart';
import 'package:muevex_conductor/data/models/service_model.dart';
import 'package:muevex_conductor/features/dashboard/providers/requests_provider.dart';

class ServiceCard extends ConsumerStatefulWidget {
  final Service service;
  const ServiceCard({super.key, required this.service});

  @override
  ConsumerState<ServiceCard> createState() => _ServiceCardState();
}

class _ServiceCardState extends ConsumerState<ServiceCard> {
  // Guard anti doble-tap: evita aceptar/rechazar el mismo servicio dos veces
  // (dos Aceptar muy seguidos pueden disparar aceptaciones duplicadas).
  bool _busy = false;

  Service get service => widget.service;

  Future<void> _reject() async {
    if (_busy) return;
    setState(() => _busy = true);
    await ref.read(requestsProvider.notifier).reject(service.id);
    if (!mounted) return;
    setState(() => _busy = false);
    MuevexSnackBar.info(context, 'Solicitud descartada');
  }

  Future<void> _accept() async {
    if (_busy) return;
    setState(() => _busy = true);
    final ok = await ref.read(requestsProvider.notifier).accept(service.id);
    if (!mounted) return;
    setState(() => _busy = false);
    // El router global evita el bug de "se acepta y no pasa nada": al
    // refrescar la cola la tarjeta se desmonta y su contexto deja de valer.
    if (ok) {
      goRouter.push('/navigation/${service.id}?phase=1');
    } else {
      MuevexSnackBar.error(
        context,
        'Este servicio ya fue asignado a otro conductor.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final price = service.estimatedPrice > 0
        ? service.estimatedPrice
        : service.priceBase;
    final originName = service.originName?.isNotEmpty == true
        ? service.originName!
        : _fallbackCoords(service.originLat, service.originLng);
    final destName = service.destinationName?.isNotEmpty == true
        ? service.destinationName!
        : _fallbackCoords(service.destinationLat, service.destinationLng);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: MuevexTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.local_shipping_rounded,
                    color: MuevexTheme.primaryColor,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _loadTypeLabel(service.loadType),
                        style: const TextStyle(
                          color: Color(0xFF111827),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Solicitud de traslado',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  money(price),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: MuevexTheme.primaryColor,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _RoutePill(
                  icon: Icons.my_location_rounded,
                  color: MuevexTheme.primaryColor,
                  text: originName,
                ),
                const SizedBox(height: 8),
                _RoutePill(
                  icon: Icons.location_on_rounded,
                  color: MuevexTheme.secondaryColor,
                  text: destName,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MetaChip(
                      icon: Icons.straighten,
                      label: '${service.distanceKm.toStringAsFixed(1)} km',
                    ),
                    _MetaChip(
                      icon: Icons.schedule,
                      label: '${_durationMinutes(service)} min',
                    ),
                    if (service.loadWeightKg > 0)
                      _MetaChip(
                        icon: Icons.scale,
                        label: '${service.loadWeightKg.toStringAsFixed(0)} kg',
                      ),
                    if (service.loadingHelp || service.needsHelp)
                      const _MetaChip(
                        icon: Icons.help_outline,
                        label: 'Necesita ayuda',
                        highlight: true,
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _busy ? null : _reject,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: MuevexTheme.errorColor,
                          side: BorderSide(
                            color: MuevexTheme.errorColor.withValues(alpha: 0.5),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          minimumSize: const Size.fromHeight(48),
                        ),
                        child: const Text('Rechazar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: MuevexTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ElevatedButton.icon(
                          onPressed: _busy ? null : _accept,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            minimumSize: const Size.fromHeight(48),
                          ),
                          icon: _busy
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check_circle_outline,
                                  size: 20),
                          label: const Text(
                            'Aceptar',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _loadTypeLabel(String type) {
    const names = {
      'muebles': 'Muebles',
      'electrodomesticos': 'Electrodomésticos',
      'cajas': 'Cajas',
      'carga': 'Carga',
      'otro': 'Otro',
    };
    return names[type] ?? 'Carga';
  }

  int _durationMinutes(Service s) {
    if (s.durationMinutes > 0) return s.durationMinutes;
    return s.estimatedTimeMin.round();
  }

  String _fallbackCoords(double lat, double lng) =>
      '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
}

class _RoutePill extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _RoutePill({
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool highlight;
  const _MetaChip({
    required this.icon,
    required this.label,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = highlight ? MuevexTheme.secondaryColor : Colors.grey.shade700;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }
}