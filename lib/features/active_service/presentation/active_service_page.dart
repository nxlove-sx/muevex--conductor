import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:muevex_conductor/core/constants/app_constants.dart';
import 'package:muevex_conductor/core/theme/muevex_theme.dart';
import 'package:muevex_conductor/core/utils/money.dart';
import 'package:muevex_conductor/core/widgets/custom_button.dart';
import 'package:muevex_conductor/core/widgets/muevex_snackbar.dart';
import 'package:muevex_conductor/core/widgets/state_views.dart';
import 'package:muevex_conductor/data/models/service_model.dart';
import 'package:muevex_conductor/features/active_service/providers/active_service_provider.dart';

class ActiveServicePage extends ConsumerWidget {
  final String id;
  const ActiveServicePage({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(activeServiceProvider);

    return Scaffold(
      appBar: brandMuevexAppBar(title: 'Servicio activo'),
      body: async.when(
        loading: () => const MuevexLoading(message: 'Cargando tu servicio...'),
        error: (e, _) => MuevexErrorView(
          message: 'No se pudo cargar el servicio activo.',
          onRetry: () => ref.invalidate(activeServiceProvider),
        ),
        data: (service) {
          if (service == null) {
            return const _NoActiveService();
          }
          return _ServiceBody(service: service);
        },
      ),
    );
  }
}

class _NoActiveService extends StatelessWidget {
  const _NoActiveService();

  @override
  Widget build(BuildContext context) {
    return MuevexEmptyState(
      icon: Icons.done_all_rounded,
      iconColor: MuevexTheme.accentColor,
      title: 'No tienes un servicio activo',
      subtitle: 'Cuando aceptes una solicitud podrás seguirla desde aquí.',
      actionLabel: 'Volver al inicio',
      onAction: () => context.go('/home'),
    );
  }
}

class _ServiceBody extends ConsumerWidget {
  final Service service;
  const _ServiceBody({required this.service});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final amount = (service.estimatedPrice > 0 ? service.estimatedPrice : service.priceBase) > 0
        ? service.estimatedPrice > 0 ? service.estimatedPrice : service.priceBase
        : service.priceTotal;
    final originName = service.originName?.isNotEmpty == true
        ? service.originName!
        : '${service.originLat.toStringAsFixed(4)}, ${service.originLng.toStringAsFixed(4)}';
    final destName = service.destinationName?.isNotEmpty == true
        ? service.destinationName!
        : '${service.destinationLat.toStringAsFixed(4)}, ${service.destinationLng.toStringAsFixed(4)}';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _PriceCard(service: service, amount: amount),
        const SizedBox(height: 16),
        _RouteCard(service: service, originName: originName, destName: destName),
        const SizedBox(height: 16),
        _CargoCard(service: service),
        const SizedBox(height: 16),
        _HorizontalStepper(service: service),
        const SizedBox(height: 20),
        _ActionArea(service: service),
        const SizedBox(height: 12),
        if (service.status.isActive)
          TextButton(
            onPressed: () => _confirmCancel(context, ref),
            style: TextButton.styleFrom(foregroundColor: MuevexTheme.errorColor),
            child: const Text('Cancelar servicio'),
          ),
      ],
    );
  }

  Future<void> _confirmCancel(BuildContext context, WidgetRef ref) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cancelar servicio?'),
        content: const Text('El cliente será notificado de inmediato.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Volver'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancelar servicio',
                style: TextStyle(color: MuevexTheme.errorColor)),
          ),
        ],
      ),
    );
    if (res == true) {
      final ok = await ref.read(activeServiceProvider.notifier).cancel();
      if (!context.mounted) return;
      if (ok) {
        context.go('/home');
      } else {
        MuevexSnackBar.error(
          context,
          'No se pudo cancelar. Revisa tu conexión e inténtalo de nuevo.',
        );
      }
    }
  }
}

class _ActionArea extends ConsumerWidget {
  final Service service;
  const _ActionArea({required this.service});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(activeServiceProvider.notifier);

    return switch (service.status) {
      ServiceStatus.aceptado => Column(
          children: [
            _PhaseBanner(phase: 1, text: 'FASE 1 — Dirígete al origen'),
            const SizedBox(height: 12),
            CustomButton(
              text: 'Navegar al origen',
              backgroundColor: Colors.white,
              textColor: MuevexTheme.primaryColor,
              borderColor: MuevexTheme.primaryColor,
              onPressed: () => context.push('/navigation/${service.id}?phase=1'),
            ),
            const SizedBox(height: 12),
            CustomButton(
              text: 'LLEGUÉ',
              gradient: true,
              onPressed: () async {
                final ok =
                    await notifier.advance(ServiceStatus.enRecogida);
                if (!context.mounted) return;
                if (ok) {
                  context.pushReplacement('/service/${service.id}');
                } else {
                  MuevexSnackBar.error(
                    context,
                    'No se pudo actualizar. Revisa tu conexión e inténtalo de nuevo.',
                  );
                }
              },
            ),
          ],
        ),
      ServiceStatus.enRecogida => Column(
          children: [
            _PhaseBanner(phase: 1, text: 'Recogida en curso'),
            const SizedBox(height: 12),
            CustomButton(
              text: 'Iniciar servicio',
              gradient: true,
              onPressed: () async {
                final ok = await notifier.advance(ServiceStatus.enCurso);
                if (!context.mounted) return;
                if (ok) {
                  context.pushReplacement('/navigation/${service.id}?phase=2');
                } else {
                  MuevexSnackBar.error(
                    context,
                    'No se pudo actualizar. Revisa tu conexión e inténtalo de nuevo.',
                  );
                }
              },
            ),
          ],
        ),
      ServiceStatus.enCurso => Column(
          children: [
            _PhaseBanner(phase: 2, text: 'FASE 2 — En camino al destino'),
            const SizedBox(height: 12),
            CustomButton(
              text: 'Navegar al destino',
              backgroundColor: Colors.white,
              textColor: MuevexTheme.primaryColor,
              borderColor: MuevexTheme.primaryColor,
              onPressed: () => context.push('/navigation/${service.id}?phase=2'),
            ),
            const SizedBox(height: 12),
            CustomButton(
              text: 'FINALIZAR',
              gradient: true,
              onPressed: () async {
                final ok =
                    await notifier.advance(ServiceStatus.completado);
                if (!context.mounted) return;
                if (ok) {
                  MuevexSnackBar.success(context, 'Servicio completado');
                  context.go('/home');
                } else {
                  MuevexSnackBar.error(
                    context,
                    'No se pudo completar. Revisa tu conexión e inténtalo de nuevo.',
                  );
                }
              },
            ),
          ],
        ),
      ServiceStatus.completado => Column(
          children: [
            const Icon(Icons.celebration, size: 48, color: MuevexTheme.accentColor),
            const SizedBox(height: 8),
            const Text('Servicio completado',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            CustomButton(
              text: 'Completar y cobrar',
              gradient: true,
              onPressed: () => context.go('/home'),
            ),
          ],
        ),
      _ => const SizedBox(),
    };
  }
}

class _PhaseBanner extends StatelessWidget {
  final int phase;
  final String text;
  const _PhaseBanner({required this.phase, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MuevexTheme.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MuevexTheme.primaryColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.flag, color: MuevexTheme.primaryColor, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _PriceCard extends StatelessWidget {
  final Service service;
  final double amount;
  const _PriceCard({required this.service, required this.amount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: MuevexTheme.primaryGradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  money(amount),
                  style: const TextStyle(
                      color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${service.distanceKm.toStringAsFixed(1)} km · ${service.durationMinutes} min',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          const Icon(Icons.local_shipping, color: Colors.white, size: 40),
        ],
      ),
    );
  }
}

class _RouteCard extends StatelessWidget {
  final Service service;
  final String originName;
  final String destName;
  const _RouteCard({
    required this.service,
    required this.originName,
    required this.destName,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _RouteRow(
                icon: Icons.my_location,
                color: MuevexTheme.primaryColor,
                text: 'Origen: $originName'),
            const SizedBox(height: 8),
            _RouteRow(
                icon: Icons.location_on,
                color: MuevexTheme.secondaryColor,
                text: 'Destino: $destName'),
          ],
        ),
      ),
    );
  }
}

class _CargoCard extends StatelessWidget {
  final Service service;
  const _CargoCard({required this.service});

  @override
  Widget build(BuildContext context) {
    final items = <(IconData, String)>[
      (Icons.category, 'Tipo: ${kLoadTypeNames[service.loadType] ?? service.loadType}'),
      if ((service.loadDescription?.isNotEmpty ?? false))
        (Icons.description_outlined, service.loadDescription!),
      if (service.loadWeightKg > 0)
        (Icons.scale, 'Peso: ${service.loadWeightKg.toStringAsFixed(0)} kg'),
      if (service.floors > 0)
        (Icons.stairs, 'Pisos: ${service.floors}'),
      if (service.loadingHelp)
        (Icons.help_outline, 'Requiere ayuda de carga'),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Carga', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...items.map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Icon(e.$1, size: 18, color: MuevexTheme.primaryColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(e.$2,
                            style: const TextStyle(fontSize: 13)),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

class _RouteRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _RouteRow({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }
}

class _HorizontalStepper extends StatelessWidget {
  final Service service;
  const _HorizontalStepper({required this.service});

  @override
  Widget build(BuildContext context) {
    final stages = ServiceStages.conductorStages;
    final currentIndex = stages.indexOf(service.status.dbName);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Progreso del servicio',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 18),
          Row(
            children: List.generate(stages.length, (i) {
              final stage = stages[i];
              final done = i <= currentIndex;
              return Expanded(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (i > 0)
                          Expanded(
                            child: Container(
                              height: 3,
                              color: (i <= currentIndex)
                                  ? MuevexTheme.accentColor
                                  : Colors.grey.shade300,
                            ),
                          ),
                        _StepDot(
                          index: i,
                          done: done,
                          isCurrent: i == currentIndex,
                        ),
                        if (i < stages.length - 1)
                          Expanded(
                            child: Container(
                              height: 3,
                              color: (i < currentIndex)
                                  ? MuevexTheme.accentColor
                                  : Colors.grey.shade300,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      ServiceStages.labels[stage] ?? stage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: (i == currentIndex)
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: (i <= currentIndex)
                            ? Colors.black87
                            : Colors.grey,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  final int index;
  final bool done;
  final bool isCurrent;
  const _StepDot({
    required this.index,
    required this.done,
    required this.isCurrent,
  });

  @override
  Widget build(BuildContext context) {
    final color = done
        ? MuevexTheme.accentColor
        : (isCurrent ? MuevexTheme.primaryColor : Colors.grey.shade300);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: color,
          width: isCurrent ? 2.5 : 2,
        ),
      ),
      child: CircleAvatar(
        radius: 11,
        backgroundColor: color,
        child: done
            ? const Icon(Icons.check, size: 14, color: Colors.white)
            : Text(
                '${index + 1}',
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
      ),
    );
  }
}