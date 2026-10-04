import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart' hide ServiceStatus;
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import 'package:muevex_conductor/core/services/live_location_reporter.dart';
import 'package:muevex_conductor/core/services/location_service.dart';
import 'package:muevex_conductor/core/theme/muevex_theme.dart';
import 'package:muevex_conductor/core/utils/money.dart';
import 'package:muevex_conductor/core/widgets/complete_service_sheet.dart';
import 'package:muevex_conductor/core/widgets/custom_button.dart';
import 'package:muevex_conductor/core/widgets/muevex_snackbar.dart';
import 'package:muevex_conductor/core/widgets/state_views.dart';
import 'package:muevex_conductor/data/models/service_model.dart';
import 'package:muevex_conductor/features/active_service/providers/active_service_provider.dart';
import 'package:muevex_conductor/features/auth/providers/auth_provider.dart';
import 'package:muevex_conductor/shared/maps/map_pins.dart';
import 'package:muevex_conductor/shared/maps/map_route_style.dart';
import 'package:muevex_conductor/shared/maps/map_widget.dart';
import 'package:muevex_conductor/shared/maps/route_service.dart';

class NavigationPage extends ConsumerStatefulWidget {
  final String id;
  final int phase;
  const NavigationPage({super.key, required this.id, this.phase = 1});

  @override
  ConsumerState<NavigationPage> createState() => _NavigationPageState();
}

class _NavigationPageState extends ConsumerState<NavigationPage> {
  final _mapController = MapController();
  final _routeService = RouteService();

  StreamSubscription<Position>? _positionSub;
  Position? _position;
  Service? _loaded;
  List<LatLng>? _route;
  double _routeDistanceM = 0;
  double _routeDurationS = 0;
  bool _loading = false;
  bool _updating = false;
  bool _following = true;

  LatLng? _lastRouteOrigin;
  DateTime _lastRouteAt = DateTime.fromMillisecondsSinceEpoch(0);

  // Recalcula la ruta cuando el conductor se mueve más de 50 m o cada 15 s,
  // de forma que el trazo siempre parte de la posición en vivo.
  static const double _routeRecalcMeters = 50;
  static const Duration _routeRecalcInterval = Duration(seconds: 15);

  int get _phase => widget.phase;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    // Esperamos a que el provider se refresque: en la primera build suele
    // devolver null y la pantalla retornaría sin ruta, sin tracking ni
    // reporter de ubicación.
    final notifier = ref.read(activeServiceProvider.notifier);
    try {
      await notifier.refresh();
    } catch (_) {}
    if (!mounted) return;
    final service = ref.read(activeServiceProvider).valueOrNull;
    if (service == null) return;
    _loaded = service;
    sharedLocationReporter.attach(userId, service.id);
    await sharedLocationReporter.setEnabled(true);

    // Cada `await` puede dejar el widget destruido (el conductor cierra la
    // pantalla mientras se resuelve la ruta, que es lo normal con datos
    // móviles). Sin esta comprobación, `_loadInitialRoute` haría setState
    // sobre un State liberado y, peor, `_listenPosition` abriría un stream de
    // GPS que `dispose` ya no puede cerrar: el GPS se quedaba encendido
    // reportando posición indefinidamente, vaciando la batería.
    if (!mounted) return;

    await _loadInitialRoute(service);
    if (!mounted) return;

    _listenPosition();
  }

  // El destino depende de la fase en la que está el servicio (1 = ir al
  // origen, 2 = ir al destino). Usamos la copia _loaded guardada al iniciar
  // para no depender de redes/hidrataciones a mitad de la navegación.
  LatLng? get _target {
    final s = _loaded;
    if (s == null) return null;
    final lat = _phase == 1 ? s.originLat : s.destinationLat;
    final lng = _phase == 1 ? s.originLng : s.destinationLng;
    if (lat == 0 && lng == 0) return null;
    return LatLng(lat, lng);
  }

  Future<void> _loadInitialRoute(Service service) async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final pos = await LocationService.getCurrentPosition();
      final target = _target;
      if (pos == null || target == null) return;
      if (!mounted) return;
      await _fetchRoute(LatLng(pos.latitude, pos.longitude), target);
    } catch (e) {
      if (!mounted) return;
      _onRouteError(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fetchRoute(LatLng from, LatLng to) async {
    final result = await _routeService.getRoute(origin: from, destination: to);
    if (!mounted) return;
    setState(() {
      _route = result.points;
      _routeDistanceM = result.distanceMeters;
      _routeDurationS = result.durationSeconds;
    });
    _lastRouteOrigin = from;
    _lastRouteAt = DateTime.now();
  }

  void _onRouteError(Object error) {
    if (!mounted) return;
    final msg = error is RouteException ? error.message : 'Sin ruta disponible';
    MuevexSnackBar.error(context, msg);
  }

  void _listenPosition() {
    _positionSub ??= LocationService.getPositionStream().listen(_onPosition);
  }

  Future<void> _onPosition(Position pos) async {
    if (!mounted) return;
    setState(() => _position = pos);

    if (_following) {
      _mapController.move(
        LatLng(pos.latitude, pos.longitude),
        _mapController.camera.zoom,
      );
    }

    final current = LatLng(pos.latitude, pos.longitude);
    final shouldRefresh = _lastRouteOrigin == null ||
        const Distance().distance(_lastRouteOrigin!, current) >=
            _routeRecalcMeters ||
        DateTime.now().difference(_lastRouteAt) >= _routeRecalcInterval;
    if (shouldRefresh && !_loading) {
      setState(() => _loading = true);
      final target = _target;
      try {
        if (target != null) {
          await _fetchRoute(current, target);
        }
      } catch (e) {
        _onRouteError(e);
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    }
  }

  void _onMapMoved(MapPosition position, bool hasGesture) {
    if (hasGesture && _following && mounted) {
      setState(() => _following = false);
    }
  }

  void _recenter() {
    final pos = _position;
    if (pos == null) return;
    setState(() => _following = true);
    _mapController.move(
      LatLng(pos.latitude, pos.longitude),
      _mapController.camera.zoom,
    );
  }

  Future<void> _finalize() async {
    if (_updating) return;
    _updating = true;
    final ok = await ref
        .read(activeServiceProvider.notifier)
        .advance(ServiceStatus.completado);
    _updating = false;
    if (!context.mounted) return;
    if (!ok) {
      MuevexSnackBar.error(
        context,
        'No se pudo completar. Revisa tu conexión e inténtalo de nuevo.',
      );
      return;
    }
    final service = ref.read(activeServiceProvider).valueOrNull;
    await showServiceCompletedSheet(
      context,
      serviceId: widget.id,
      serviceDescription: service?.description,
    );
    if (context.mounted) context.go('/home');
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _positionSub = null;
    sharedLocationReporter.shutdown();
    _routeService.dispose();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(activeServiceProvider).valueOrNull;
    final isPhase2 = _phase == 2;

    return Scaffold(
      appBar: brandMuevexAppBar(
        title: isPhase2 ? 'En camino al destino' : 'Camino al origen',
      ),
      body: service == null
          ? MuevexEmptyState(
              icon: Icons.route_outlined,
              title: 'Sin servicio activo',
              subtitle:
                  'El servicio ya no está disponible en esta ruta de navegación.',
              actionLabel: 'Volver al inicio',
              actionIcon: Icons.home_outlined,
              onAction: () => context.go('/home'),
            )
          : _buildMap(service, isPhase2),
    );
  }

  Widget _buildMap(Service service, bool isPhase2) {
    final origin = LatLng(service.originLat, service.originLng);
    final destination = LatLng(service.destinationLat, service.destinationLng);
    final target = isPhase2 ? destination : origin;

    final polylines =
        _route != null ? [...buildRoutePolylines(_route!)] : const <Polyline>[];

    final targetLabel = isPhase2
        ? (service.destinationName?.isNotEmpty == true
            ? service.destinationName!
            : 'Destino')
        : (service.originName?.isNotEmpty == true
            ? service.originName!
            : 'Origen');

    final remainingKm = _routeDistanceM / 1000.0;
    final remainingMin = (_routeDurationS / 60).round();

    return Stack(
      children: [
        TransportMap(
          controller: _mapController,
          initialCenter: target,
          initialZoom: 14,
          polylines: polylines,
          onMapMoved: _onMapMoved,
          markers: [
            if (!isPhase2)
              Marker(
                point: destination,
                width: 76,
                height: 92,
                alignment: Alignment.bottomCenter,
                child: const WaypointPin(
                  icon: Icons.place_rounded,
                  label: 'Destino',
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFF8A3D), Color(0xFFEC5A2A)],
                  ),
                ),
              ),
            Marker(
              point: target,
              width: 76,
              height: 92,
              alignment: Alignment.bottomCenter,
              child: WaypointPin(
                icon: Icons.flag_rounded,
                label: targetLabel,
                gradient: MuevexTheme.primaryGradient,
              ),
            ),
            if (_position != null)
              Marker(
                point: LatLng(_position!.latitude, _position!.longitude),
                width: 40,
                height: 40,
                child: Transform.rotate(
                  angle: (_position!.heading <= 0
                          ? _position!.speed > 0
                              ? 90 * pi / 180
                              : 0
                          : _position!.heading) *
                      pi /
                      180,
                  child: Container(
                    decoration: BoxDecoration(
                      color: MuevexTheme.accentColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color:
                              MuevexTheme.accentColor.withValues(alpha: 0.45),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.navigation,
                        color: Colors.white, size: 24),
                  ),
                ),
              ),
            ...?(_route != null ? routeFlowMarkers(_route!) : null),
          ],
        ),
        Positioned(
          top: 16,
          left: 0,
          right: 0,
          child: Center(
            child: Material(
              borderRadius: BorderRadius.circular(20),
              color: Colors.black.withValues(alpha: 0.55),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: _loading
                    ? const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text('Calculando ruta…',
                              style:
                                  TextStyle(fontSize: 12, color: Colors.white)),
                        ],
                      )
                    : Text(
                        _route != null
                            ? '${remainingKm.toStringAsFixed(1)} km · ~$remainingMin min'
                            : 'Sin ruta a la vista',
                        style:
                            const TextStyle(fontSize: 12, color: Colors.white),
                      ),
              ),
            ),
          ),
        ),
        Positioned(
          right: 16,
          bottom: 180,
          child: FloatingActionButton.small(
            heroTag: 'recenter-btn',
            backgroundColor: MuevexTheme.primaryColor,
            foregroundColor: Colors.white,
            tooltip:
                _following ? 'Siguiendo tu posición' : 'Centrar en mi posición',
            onPressed: _recenter,
            child: Icon(_following ? Icons.my_location : Icons.navigation),
          ),
        ),
        SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Card(
                    child: ListTile(
                      leading: Icon(
                        isPhase2 ? Icons.location_on : Icons.my_location,
                        color: MuevexTheme.primaryColor,
                      ),
                      title: Text(targetLabel,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        _route != null
                            ? '${remainingKm.toStringAsFixed(1)} km · ~$remainingMin min restantes'
                            : '${service.distanceKm.toStringAsFixed(1)} km aprox.',
                      ),
                      trailing: Text(moneyConIva(service.estimatedPrice),
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (isPhase2)
                    CustomButton(
                      text: 'FINALIZAR',
                      gradient: true,
                      onPressed: _finalize,
                    )
                  else
                    CustomButton(
                      text: 'LLEGUÉ',
                      gradient: true,
                      onPressed: () => _startLoading(service),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _startLoading(Service service) async {
    if (_updating) return;
    _updating = true;
    final ok = await ref
        .read(activeServiceProvider.notifier)
        .advance(ServiceStatus.enRecogida);
    _updating = false;
    if (!context.mounted) return;
    if (ok) {
      context.go('/service/${widget.id}');
    } else {
      MuevexSnackBar.error(
        context,
        'No se pudo actualizar. Revisa tu conexión e inténtalo de nuevo.',
      );
    }
  }
}
