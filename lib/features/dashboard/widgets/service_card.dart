import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:muevex_conductor/core/utils/money.dart';
import 'package:muevex_conductor/core/router/app_router.dart';
import 'package:muevex_conductor/core/theme/muevex_theme.dart';
import 'package:muevex_conductor/core/widgets/muevex_snackbar.dart';
import 'package:muevex_conductor/data/models/service_model.dart';
import 'package:muevex_conductor/features/dashboard/providers/requests_provider.dart';

/// Tarjeta de una solicitud en la cola del conductor.
///
/// El orden de lo que se pinte importa: un conductor elige con los ojos, así que
/// primero va lo que decide (cuánto cobra y cuánto tarda), después el recorrido
/// y al final los metadatos que solo sirven para decidir si el vehículo vale.
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
    final precio =
        service.estimatedPrice > 0 ? service.estimatedPrice : service.priceBase;
    final origen = service.originName?.isNotEmpty == true
        ? service.originName!
        : _fallbackCoords(service.originLat, service.originLng);
    final destino = service.destinationName?.isNotEmpty == true
        ? service.destinationName!
        : _fallbackCoords(service.destinationLat, service.destinationLng);
    // El ingreso del conductor solo existe cuando la tarifa ya lo calculó. Si no
    // está, se enseña el precio del cliente y no se inventa una cifra.
    final ganancia = service.driverEarnings > 0 ? service.driverEarnings : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context, precio, ganancia),
          _buildRoute(context, origen, destino),
          if (_hayMetadatos) _buildMeta(context),
          _buildActions(context),
        ],
      ),
    );
  }

  bool get _hayMetadatos =>
      service.loadWeightKg > 0 ||
      service.floors > 0 ||
      service.loadingHelp ||
      service.needsHelp;

  /// Tipo de carga, tipo de trabajo y lo que se cobra. La cifra va a la
  /// derecha y en grande porque es la respuesta a "¿me conviene?".
  Widget _buildHeader(BuildContext context, double precio, double ganancia) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: MuevexTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.local_shipping_rounded,
              color: MuevexTheme.primaryColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _loadTypeLabel(service.loadType),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: MuevexTheme.textPrimaryColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  service.loadDescription?.isNotEmpty == true
                      ? service.loadDescription!
                      : 'Solicitud de traslado',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                ganancia > 0 ? moneyConIva(ganancia) : moneyConIva(precio),
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  height: 1.1,
                  color: ganancia > 0
                      ? MuevexTheme.successColor
                      : MuevexTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                ganancia > 0 ? 'tu ganancia' : 'precio del cliente',
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Origen → destino con la línea que los une. Una columna de puntos sueltos se
  /// lee como dos direcciones sin relación; conectadas, se lee como un viaje.
  Widget _buildRoute(BuildContext context, String origen, String destino) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        color: MuevexTheme.primaryColor.withValues(alpha: 0.03),
        border: Border(
          top: BorderSide(color: Colors.grey.shade100),
          bottom: BorderSide(color: Colors.grey.shade100),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              _RouteNode(MuevexTheme.primaryColor, filled: true),
              Container(
                width: 2,
                height: 28,
                margin: const EdgeInsets.symmetric(vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
              _RouteNode(MuevexTheme.secondaryColor, filled: false),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _RouteLine('ORIGEN', origen),
                const SizedBox(height: 14),
                _RouteLine('DESTINO', destino),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeta(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Wrap(
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
          if (service.floors > 0)
            _MetaChip(
              icon: Icons.stairs,
              label: service.floors == 1 ? '1 piso' : '${service.floors} pisos',
            ),
          if (service.loadingHelp || service.needsHelp)
            const _MetaChip(
              icon: Icons.help_outline,
              label: 'Necesita ayuda',
              highlight: true,
            ),
        ],
      ),
    );
  }

  /// Aceptar es la acción principal y por eso va sólida; descartar es
  /// deliberadamente discreta, no un segundo botón en el mismo plano.
  Widget _buildActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _busy ? null : _reject,
              style: OutlinedButton.styleFrom(
                foregroundColor: MuevexTheme.errorColor,
                backgroundColor: MuevexTheme.errorColor.withValues(alpha: 0.05),
                side: BorderSide(
                  color: MuevexTheme.errorColor.withValues(alpha: 0.4),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                minimumSize: const Size.fromHeight(48),
                textStyle: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: const Text('Descartar'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
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
                    : const Icon(Icons.check_circle_outline, size: 20),
                label: const Text(
                  'Aceptar servicio',
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

class _RouteNode extends StatelessWidget {
  const _RouteNode(this.color, {required this.filled});
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? color : Colors.white,
        border: Border.all(color: color, width: 2.5),
      ),
    );
  }
}

class _RouteLine extends StatelessWidget {
  const _RouteLine(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 13.5,
            height: 1.3,
            color: MuevexTheme.textPrimaryColor,
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
