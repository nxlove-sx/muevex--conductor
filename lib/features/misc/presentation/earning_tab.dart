import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:muevex_conductor/core/supabase/supabase_client.dart' as db;
import 'package:muevex_conductor/core/utils/money.dart';
import 'package:muevex_conductor/core/theme/muevex_theme.dart';
import 'package:muevex_conductor/core/widgets/muevex_snackbar.dart';
import 'package:muevex_conductor/core/widgets/state_views.dart';
import 'package:muevex_conductor/features/misc/providers/earnings_history_providers.dart';

class EarningsTab extends ConsumerWidget {
  const EarningsTab({super.key});

  Future<void> _resetEarnings(BuildContext context, WidgetRef ref) async {
    final driverId = db.currentUserId();
    if (driverId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('¿Reiniciar ganancias?'),
        content: const Text(
          'Se pondrán en 0 las ganancias de tus servicios completados. '
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: MuevexTheme.errorColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sí, reiniciar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await db.supabase
          .from('services')
          .update({'driver_earnings': 0})
          .eq('driver_id', driverId)
          .eq('status', 'completado');
    } catch (e) {
      debugPrint('MUEVEX-C: no se pudieron reiniciar ganancias: $e');
      if (context.mounted) {
        MuevexSnackBar.error(context, 'No se pudieron reiniciar las ganancias.');
      }
      return;
    }
    ref.invalidate(earningsProvider);
    if (context.mounted) {
      MuevexSnackBar.success(context, 'Ganancias reiniciadas');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(earningsProvider);

    return async.when(
      loading: () => const MuevexLoading(message: 'Calculando tus ganancias...'),
      error: (e, st) => MuevexErrorView(
        message: 'No se pudieron cargar tus ganancias.',
        onRetry: () => ref.invalidate(earningsProvider),
      ),
      data: (summary) => RefreshIndicator(
        onRefresh: () => ref.read(earningsProvider.notifier).refresh(),
        child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _TotalCard(
            total: summary.today,
            week: summary.week,
            month: summary.month,
            completed: summary.completedCount,
          ),
          const SizedBox(height: 12),
          if (summary.total <= 0) _NoEarningsBanner(),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _PeriodCard('Esta semana', summary.week, Icons.calendar_view_week, MuevexTheme.primaryColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PeriodCard('Este mes', summary.month, Icons.calendar_month, MuevexTheme.secondaryColor),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _PeriodCard('Total acumulado', summary.total, Icons.account_balance_wallet, MuevexTheme.accentColor),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: MuevexTheme.primaryColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: MuevexTheme.primaryColor.withValues(alpha: 0.2)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: MuevexTheme.primaryColor, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Los pagos se acreditan al completar cada servicio. '
                    'Aquí verás tus ganancias en tiempo real.',
                    style: TextStyle(fontSize: 13, height: 1.35),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _resetEarnings(context, ref),
            style: OutlinedButton.styleFrom(
              foregroundColor: MuevexTheme.errorColor,
              side: BorderSide(color: MuevexTheme.errorColor.withValues(alpha: 0.4)),
              minimumSize: const Size.fromHeight(44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.restart_alt_rounded, size: 20),
            label: const Text('Reiniciar ganancias'),
          ),
        ],
      ),
      ),
    );
  }
}

class _NoEarningsBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: MuevexTheme.accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.savings_outlined,
              color: MuevexTheme.accentColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Aún no generas ganancias',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                SizedBox(height: 3),
                Text(
                  'Cuando completes tu primer servicio, el pago se verá reflejado aquí.',
                  style: TextStyle(color: Colors.grey, fontSize: 12, height: 1.35),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => context.go('/home'),
            child: const Text('Buscar'),
          ),
        ],
      ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  final double total;
  final double week;
  final double month;
  final int completed;
  const _TotalCard({
    required this.total,
    required this.week,
    required this.month,
    required this.completed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: MuevexTheme.primaryGradient,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: MuevexTheme.primaryColor.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Ganado hoy',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.paid_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            money(total),
            style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.25),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(money(week),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    const Text('Esta semana', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
              Container(width: 1, height: 26, color: Colors.white.withValues(alpha: 0.25)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(money(month),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      const Text('Este mes', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
              ),
              Container(width: 1, height: 26, color: Colors.white.withValues(alpha: 0.25)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$completed',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      const Text('Servicios', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PeriodCard extends StatelessWidget {
  final String label;
  final double amount;
  final IconData icon;
  final Color color;
  const _PeriodCard(this.label, this.amount, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 8),
          Text(
            money(amount),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        ],
      ),
    );
  }
}