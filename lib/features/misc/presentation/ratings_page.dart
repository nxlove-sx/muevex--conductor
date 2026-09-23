import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:muevex_conductor/core/theme/muevex_theme.dart';
import 'package:muevex_conductor/core/widgets/state_views.dart';
import 'package:muevex_conductor/data/models/rating_model.dart';
import 'package:muevex_conductor/features/dashboard/providers/driver_provider.dart';
import 'package:muevex_conductor/features/misc/providers/earnings_history_providers.dart';

class RatingsPage extends ConsumerWidget {
  const RatingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(ratingsProvider);
    final profile = ref.watch(driverProfileProvider).valueOrNull;

    return Scaffold(
      appBar: brandMuevexAppBar(title: 'Mi reputación'),
      body: async.when(
        loading: () => const MuevexLoading(message: 'Cargando tus reseñas...'),
        error: (e, st) => MuevexErrorView(
          message: 'No se pudieron cargar tus reseñas.',
          onRetry: () => ref.invalidate(ratingsProvider),
        ),
        data: (ratings) {
          final avg = ratings.isEmpty
              ? (profile?.rating ?? 0.0)
              : ratings.map((r) => r.score).reduce((a, b) => a + b) / ratings.length;

          if (ratings.isEmpty) {
            return MuevexEmptyState(
              icon: Icons.star_border_rounded,
              title: 'Aún no tienes reseñas',
              subtitle:
                  'Cuando tus clientes te califiquen, verás tu reputación y sus comentarios aquí.',
              actionLabel: 'Aceptar servicios',
              actionIcon: Icons.local_shipping_outlined,
              onAction: () => context.go('/home'),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _AverageCard(average: avg, count: ratings.length),
              const SizedBox(height: 20),
              const Text('Reseñas recibidas',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              ...ratings.map((r) => _RatingTile(rating: r)),
            ],
          );
        },
      ),
    );
  }
}

class _AverageCard extends StatelessWidget {
  final double average;
  final int count;
  const _AverageCard({required this.average, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MuevexTheme.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Text(
            average.toStringAsFixed(1),
            style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: List.generate(5, (i) {
                  final filled = i < average.round();
                  return Icon(
                    filled ? Icons.star : Icons.star_border,
                    color: MuevexTheme.warningColor,
                    size: 22,
                  );
                }),
              ),
              const SizedBox(height: 4),
              Text('$count reseñas', style: TextStyle(color: Colors.grey.shade600)),
            ],
          ),
        ],
      ),
    );
  }
}

class _RatingTile extends StatelessWidget {
  final Rating rating;
  const _RatingTile({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: MuevexTheme.primaryColor.withValues(alpha: 0.1),
            child: const Icon(Icons.person, color: MuevexTheme.primaryColor),
          ),
          title: Row(
            children: List.generate(5, (i) {
              final filled = i < rating.score.round();
              return Icon(
                filled ? Icons.star : Icons.star_border,
                color: MuevexTheme.warningColor,
                size: 16,
              );
            }),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              rating.comment?.isNotEmpty == true
                  ? rating.comment!
                  : 'El cliente no dejó comentario escrito.',
              style: TextStyle(
                color: rating.comment?.isNotEmpty == true
                    ? Colors.black87
                    : Colors.grey.shade500,
                fontStyle: rating.comment?.isNotEmpty == true
                    ? FontStyle.normal
                    : FontStyle.italic,
              ),
            ),
          ),
          isThreeLine: rating.comment != null,
        ),
      ),
    );
  }
}