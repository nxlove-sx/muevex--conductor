import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:muevex_conductor/core/utils/money.dart';
import 'package:muevex_conductor/core/theme/muevex_theme.dart';
import 'package:muevex_conductor/core/widgets/state_views.dart';
import 'package:muevex_conductor/data/models/service_model.dart';
import 'package:muevex_conductor/features/misc/providers/earnings_history_providers.dart';

class HistoryTab extends ConsumerWidget {
  const HistoryTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(historyProvider);

    return RefreshIndicator(
      onRefresh: () => ref.read(historyProvider.notifier).refresh(),
      child: async.when(
        loading: () => const Center(
          child: MuevexLoading(message: 'Cargando tu historial...'),
        ),
        error: (e, st) => Center(
          child: MuevexErrorView(
            message: 'No se pudo cargar tu historial.',
            onRetry: () => ref.read(historyProvider.notifier).refresh(),
          ),
        ),
        data: (services) {
          if (services.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 60),
                MuevexEmptyState(
                  icon: Icons.history_rounded,
                  title: 'Sin servicios realizados',
                  subtitle:
                      'Cuando completes tu primer traslado, aparecerá aquí en tu historial.',
                  actionLabel: 'Ir al inicio',
                  onAction: () => context.go('/home'),
                ),
              ],
            );
          }
          return ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(12),
            itemCount: services.length,
            itemBuilder: (_, i) => _HistoryTile(service: services[i]),
          );
        },
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final Service service;
  const _HistoryTile({required this.service});

  @override
  Widget build(BuildContext context) {
    final amount = service.driverEarnings;
    final date = (service.completedAt ?? service.createdAt).toLocal();
    final isCompleted = service.status == ServiceStatus.completado;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: (isCompleted
                  ? MuevexTheme.accentColor
                  : MuevexTheme.errorColor)
              .withValues(alpha: 0.15),
          child: Icon(
            isCompleted ? Icons.check : Icons.cancel,
            color: isCompleted ? MuevexTheme.accentColor : MuevexTheme.errorColor,
          ),
        ),
        title: Text(
          service.originName?.isNotEmpty == true
              ? service.originName!
              : 'Traslado',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${date.day}/${date.month}/${date.year} · ${service.distanceKm.toStringAsFixed(1)} km',
        ),
        trailing: Text(
          money(amount),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }
}