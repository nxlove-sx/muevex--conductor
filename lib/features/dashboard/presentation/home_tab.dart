import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:muevex_conductor/core/router/app_router.dart';
import 'package:muevex_conductor/core/theme/muevex_theme.dart';
import 'package:muevex_conductor/core/utils/money.dart';
import 'package:muevex_conductor/core/widgets/animations.dart';
import 'package:muevex_conductor/core/widgets/muevex_snackbar.dart';
import 'package:muevex_conductor/core/widgets/state_views.dart';
import 'package:muevex_conductor/core/widgets/skeleton_shimmer.dart';
import 'package:muevex_conductor/data/models/driver_profile_model.dart';
import 'package:muevex_conductor/data/models/service_model.dart';
import 'package:muevex_conductor/features/active_service/providers/active_service_provider.dart';
import 'package:muevex_conductor/features/auth/providers/auth_provider.dart';
import 'package:muevex_conductor/features/dashboard/providers/driver_provider.dart';
import 'package:muevex_conductor/features/dashboard/providers/requests_provider.dart';
import 'package:muevex_conductor/features/dashboard/widgets/status_button.dart';
import 'package:muevex_conductor/features/misc/providers/earnings_history_providers.dart';
import 'package:muevex_conductor/features/dashboard/widgets/service_card.dart';

class HomeTab extends ConsumerWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(driverProfileProvider);
    final requestsAsync = ref.watch(requestsProvider);
    final activeAsync = ref.watch(activeServiceProvider);
    final online = ref.watch(availableProvider);
    final user = ref.watch(authProvider).valueOrNull;
    final earnings = ref.watch(earningsProvider).valueOrNull;

    final profile = profileAsync.valueOrNull;
    final active = activeAsync.valueOrNull;

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(requestsProvider.notifier).refresh();
        try {
          await ref.read(activeServiceProvider.notifier).refresh();
        } catch (_) {}
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (profile != null)
            _ProfileHeader(userName: user?.name ?? 'Conductor', profile: profile),
          const SizedBox(height: 14),
          const StatusButton(),
          if (earnings != null) ...[
            const SizedBox(height: 14),
            _EarningsStrip(summary: earnings),
          ],
          const SizedBox(height: 18),
          if (active != null) ...[
            _ActiveServiceCard(service: active, id: active.id),
            const SizedBox(height: 18),
          ],
          Row(
            children: [
              Text(
                online ? 'Servicios disponibles' : 'Búsqueda de servicios',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const Spacer(),
              if (online)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: MuevexTheme.successColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, size: 8, color: MuevexTheme.successColor),
                      const SizedBox(width: 4),
                      const Text('En vivo', style: TextStyle(fontSize: 12, color: MuevexTheme.successColor)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (!online)
            const _OfflineHint()
          else
            ..._buildRequests(context, ref, requestsAsync),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  List<Widget> _buildRequests(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<Service>> async,
  ) {
    if (async.isLoading) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: ServiceCardSkeleton(),
        ),
        ServiceCardSkeleton(),
        ServiceCardSkeleton(),
      ];
    }
    if (async.hasError) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: MuevexErrorView(
              message: 'No se pudieron cargar las solicitudes.',
              onRetry: () => ref.read(requestsProvider.notifier).refresh(),
            ),
          ),
        ),
      ];
    }
    final requests = async.value ?? const <Service>[];
    if (requests.isEmpty) {
      return [
        _EmptyRequests(
          onRefresh: () => ref.read(requestsProvider.notifier).refresh(),
        ),
      ];
    }
    return requests
        .map<Widget>((s) => ServiceCard(service: s))
        .toList();
  }
}

class _EarningsStrip extends StatelessWidget {
  final EarningsSummary summary;
  const _EarningsStrip({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF063A8F), Color(0xFF0F63FF)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: MuevexTheme.primaryColor.withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -40,
            top: -50,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    MuevexTheme.accentColor.withValues(alpha: 0.4),
                    MuevexTheme.accentColor.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: [
              _EarningsCell(
                label: 'Hoy',
                value: summary.today,
                icon: Icons.today_rounded,
              ),
              _EarningsDivider(),
              _EarningsCell(
                label: 'Semana',
                value: summary.week,
                icon: Icons.date_range_rounded,
              ),
              _EarningsDivider(),
              _EarningsCell(
                label: 'Mes',
                value: summary.month,
                icon: Icons.calendar_month_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EarningsCell extends StatelessWidget {
  final String label;
  final double value;
  final IconData icon;

  const _EarningsCell({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white70),
          const SizedBox(height: 4),
          AnimatedNumber(
            value: value,
            formatter: (v) => money(v),
            duration: const Duration(milliseconds: 600),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

class _EarningsDivider extends StatelessWidget {
  const _EarningsDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 34,
      color: Colors.white.withValues(alpha: 0.25),
    );
  }
}

class _ActiveServiceCard extends ConsumerStatefulWidget {
  final Service service;
  final String id;
  const _ActiveServiceCard({required this.service, required this.id});

  @override
  ConsumerState<_ActiveServiceCard> createState() => _ActiveServiceCardState();
}

class _ActiveServiceCardState extends ConsumerState<_ActiveServiceCard> {
  bool _cancelling = false;

  int get _phase {
    switch (widget.service.status) {
      case ServiceStatus.enRecogida:
      case ServiceStatus.enCurso:
        return 2;
      default:
        return 1;
    }
  }

  Future<void> _cancel() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('¿Cancelar servicio?'),
        content: const Text('El cliente será notificado y el servicio quedará cancelado.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sí, cancelar',
                style: TextStyle(color: MuevexTheme.errorColor)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _cancelling = true);
    final ok = await ref.read(activeServiceProvider.notifier).cancel();
    if (!mounted) return;
    setState(() => _cancelling = false);
    if (ok) {
      MuevexSnackBar.info(context, 'Servicio cancelado');
      goRouter.go('/home');
    } else {
      MuevexSnackBar.error(
        context,
        'No se pudo cancelar. Verifica tu conexión e inténtalo de nuevo.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = widget.service;
    final originName = service.originName?.isNotEmpty == true
        ? service.originName!
        : 'Origen';
    final destName = service.destinationName?.isNotEmpty == true
        ? service.destinationName!
        : 'Destino';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MuevexTheme.primaryColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: MuevexTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.route_rounded,
                  color: MuevexTheme.primaryColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Servicio en curso',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                money(service.estimatedPrice > 0
                    ? service.estimatedPrice
                    : service.priceBase),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: MuevexTheme.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _ActiveRouteLine(
            icon: Icons.my_location_rounded,
            color: MuevexTheme.primaryColor,
            text: originName,
          ),
          const SizedBox(height: 6),
          _ActiveRouteLine(
            icon: Icons.location_on_rounded,
            color: MuevexTheme.secondaryColor,
            text: destName,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => goRouter.go('/service/${widget.id}'),
                  icon: const Icon(Icons.tune_rounded, size: 18),
                  label: const Text('Estado'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: MuevexTheme.primaryColor,
                    side: BorderSide(
                      color: MuevexTheme.primaryColor.withValues(alpha: 0.4),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () =>
                      goRouter.go('/navigation/${widget.id}?phase=$_phase'),
                  icon: const Icon(Icons.navigation_rounded, size: 18),
                  label: const Text('Navegar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MuevexTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: _cancelling
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : OutlinedButton.icon(
                    onPressed: _cancel,
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('Cancelar servicio'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: MuevexTheme.errorColor,
                      side: BorderSide(
                        color: MuevexTheme.errorColor.withValues(alpha: 0.5),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ActiveRouteLine extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _ActiveRouteLine({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}

String _greeting() {
  final hour = DateTime.now().hour;
  if (hour < 6) return 'Buenas noches';
  if (hour < 12) return 'Buenos días';
  if (hour < 19) return 'Buenas tardes';
  return 'Buenas noches';
}

class _ProfileHeader extends StatelessWidget {
  final String userName;
  final DriverProfile profile;
  const _ProfileHeader({required this.userName, required this.profile});

  @override
  Widget build(BuildContext context) {
    final verified = profile.isVerified;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: MuevexTheme.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: MuevexTheme.primaryColor.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Burbujas de luz decorativas
          Positioned(
            right: -50,
            top: -40,
            child: Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.25),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: -60,
            bottom: -70,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    MuevexTheme.accentColor.withValues(alpha: 0.35),
                    MuevexTheme.accentColor.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    child: profile.photoUrl != null && profile.photoUrl!.isNotEmpty
                        ? ClipOval(
                            child: Image.network(
                              profile.photoUrl!,
                              width: 52,
                              height: 52,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 30,
                              ),
                            ),
                          )
                        : const Icon(Icons.person, color: Colors.white, size: 30),
                  ),
                  if (verified)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.verified,
                          size: 15,
                          color: MuevexTheme.primaryColor,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _greeting(),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      userName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _HeroStat(
                icon: Icons.star_rounded,
                label: 'Calificación',
                value: profile.rating.toStringAsFixed(1),
              ),
              const _HeroDivider(),
              _HeroStat(
                icon: Icons.task_alt_rounded,
                label: 'Servicios',
                value: '${profile.totalServices}',
              ),
              const _HeroDivider(),
              _HeroStat(
                icon: Icons.verified_user_rounded,
                label: 'Estado',
                value: verified ? 'Verificado' : 'Pendiente',
              ),
            ],
          ),
        ],
        ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _HeroStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroDivider extends StatelessWidget {
  const _HeroDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 34,
      color: Colors.white.withValues(alpha: 0.3),
    );
  }
}

class _OfflineHint extends StatelessWidget {
  const _OfflineHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off, color: Colors.grey),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Estás desconectado. Activa el modo disponible para recibir solicitudes de traslado.',
              style: TextStyle(color: Colors.grey, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyRequests extends StatelessWidget {
  final VoidCallback onRefresh;
  const _EmptyRequests({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return MuevexEmptyState(
      icon: Icons.search_off_rounded,
      title: 'Sin solicitudes por ahora',
      subtitle:
          'Cuando un cliente solicite un traslado compatible con tu vehículo, aparecerá aquí en tiempo real.',
      actionLabel: 'Actualizar',
      actionIcon: Icons.refresh_rounded,
      onAction: onRefresh,
    );
  }
}