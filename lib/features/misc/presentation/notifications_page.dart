import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:muevex_conductor/core/theme/muevex_theme.dart';
import 'package:muevex_conductor/core/widgets/animations.dart';
import 'package:muevex_conductor/core/widgets/state_views.dart';
import 'package:muevex_conductor/data/models/app_notification_model.dart';
import 'package:muevex_conductor/features/misc/providers/earnings_history_providers.dart';

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationsProvider.notifier).markAllRead();
    });
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(notificationsProvider);
    final unread = async.valueOrNull?.where((n) => !n.read).length ?? 0;

    return Scaffold(
      appBar: brandMuevexAppBar(
        title: 'Notificaciones',
        actions: [
          if (unread > 0)
            IconButton(
              tooltip: 'Marcar todo leído',
              onPressed: () =>
                  ref.read(notificationsProvider.notifier).markAllRead(),
              icon: const Icon(Icons.done_all),
            ),
        ],
      ),
      body: async.when(
        loading: () =>
            const MuevexLoading(message: 'Cargando notificaciones...'),
        error: (e, st) => MuevexErrorView(
          message: 'No se pudieron cargar tus notificaciones.',
          onRetry: () => ref.read(notificationsProvider.notifier).refresh(),
        ),
        data: (items) {
          if (items.isEmpty) {
            return RefreshIndicator(
              onRefresh: () =>
                  ref.read(notificationsProvider.notifier).refresh(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 60),
                  MuevexEmptyState(
                    icon: Icons.notifications_off_outlined,
                    title: 'No tienes notificaciones',
                    subtitle:
                        'Te avisaremos aquí sobre nuevos servicios, pagos y novedades.',
                  ),
                ],
              ),
            );
          }
          // NOTA: no se dispara ninguna notificación local desde aquí. El
          // sonido lo emite `NotificationsNotifier` en el callback Realtime
          // (INSERT), de modo que solo suena cuando llega algo de verdad y no
          // cada vez que se abre esta pantalla.
          return RefreshIndicator(
            onRefresh: () => ref.read(notificationsProvider.notifier).refresh(),
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              itemBuilder: (_, i) => StaggeredEntrance(
                // Escalonado por posición: los primeros avisos se ven enseguida
                // y el resto va entrando detrás, en vez de aparecer la lista
                // entera de golpe.
                index: i,
                child: _NotificationTile(n: items[i]),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification n;
  const _NotificationTile({required this.n});

  (IconData, Color) _style() {
    switch (n.type) {
      case 'service_accepted':
        return (Icons.check_circle_outline, MuevexTheme.primaryColor);
      case 'service_arrival':
        return (Icons.location_on_outlined, MuevexTheme.accentColor);
      case 'service_started':
        return (Icons.local_shipping_outlined, MuevexTheme.primaryColor);
      case 'service_completed':
        return (Icons.verified_outlined, MuevexTheme.successColor);
      case 'service_cancelled':
      case 'service_cancelled_by_driver':
        return (Icons.cancel_outlined, MuevexTheme.errorColor);
      case 'new_rating':
        return (Icons.star_outline, MuevexTheme.warningColor);
      default:
        return (Icons.notifications_outlined, MuevexTheme.primaryColor);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _style();
    final time = n.createdAt.toLocal();
    final dateLabel =
        '${time.day}/${time.month} ${time.hour}:${time.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: n.read ? Colors.white : color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: n.read ? Colors.grey.shade200 : color.withValues(alpha: 0.35),
        ),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(icon, color: color),
        ),
        title: Text(
          n.title,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: n.read ? Colors.grey.shade800 : Colors.black87,
          ),
        ),
        subtitle: Text(n.message),
        isThreeLine: true,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              dateLabel,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
            ),
            if (!n.read) ...[
              const SizedBox(height: 4),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
