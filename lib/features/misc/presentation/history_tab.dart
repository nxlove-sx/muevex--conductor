import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:muevex_conductor/core/models/invoice_model.dart';
import 'package:muevex_conductor/core/utils/money.dart';
import 'package:muevex_conductor/core/theme/muevex_theme.dart';
import 'package:muevex_conductor/core/widgets/complete_service_sheet.dart';
import 'package:muevex_conductor/core/widgets/invoice_sheet.dart';
import 'package:muevex_conductor/core/widgets/state_views.dart';
import 'package:muevex_conductor/data/models/service_model.dart';
import 'package:muevex_conductor/features/misc/providers/earnings_history_providers.dart';

class HistoryTab extends ConsumerWidget {
  const HistoryTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(historyProvider);
    // Mapa de facturas traído una sola vez. Mientras no llega, `invoiceIdFor`
    // es null y las filas salen sin botón en vez de con uno que no abre nada.
    final invoicesAsync = ref.watch(driverInvoicesByServiceProvider);
    final invoices = invoicesAsync.value;
    final invoiceFor = invoices == null
        ? null
        : (String serviceId) => invoices[serviceId];

    // Si la consulta de facturas falla, el conductor vería filas sin botón sin
    // saber por qué. Mejor decirlo: el problema es de red o de permisos, no que
    // falte la minifactura.
    final invoicesError = invoicesAsync.hasError && invoices == null;

    return RefreshIndicator(
      onRefresh: () async {
        // También las facturas: si se acaba de generar una al completar un
        // servicio, al abrir el historial tiene que verse sin reiniciar la app.
        ref.invalidate(driverInvoicesByServiceProvider);
        await ref.read(historyProvider.notifier).refresh();
      },
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
            itemCount: services.length + (invoicesError ? 1 : 0),
            itemBuilder: (_, i) {
              // Aviso arriba del todo, no un error a pantalla completa: el
              // historial sí se pudo cargar, lo que falló fueron las facturas.
              if (invoicesError && i == 0) {
                return const _Aviso(
                  icon: Icons.cloud_off_rounded,
                  texto:
                      'No se pudieron leer tus minifacturas. Tira hacia abajo '
                      'para reintentar.',
                );
              }
              final service = services[i - (invoicesError ? 1 : 0)];
              return _HistoryTile(
                service: service,
                invoice: invoiceFor?.call(service.id),
                cargandoFacturas: invoices == null,
              );
            },
          );
        },
      ),
    );
  }
}

/// Fila del historial: los datos del servicio y, a la derecha, lo que se pueda
/// hacer con su minifactura.
class _HistoryTile extends ConsumerWidget {
  final Service service;
  final Invoice? invoice;

  /// Hay una ventana (breve) en la que el historial ya se pintó pero las facturas
  /// todavía no. En vez de un botón que luego_resulta que no abre nada, se deja
  /// el hueco vacío y se rellena solo cuando llegan.
  final bool cargandoFacturas;

  const _HistoryTile({
    required this.service,
    required this.cargandoFacturas,
    this.invoice,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final amount = service.driverEarnings;
    final date = (service.completedAt ?? service.createdAt).toLocal();
    final isCompleted = service.status == ServiceStatus.completado;
    final cancelado = !isCompleted;

    // Solo los servicios completados se pueden facturar. Un cancelado no lleva
    // minifactura ni botón que la genere: ofrecerla sería una promesa falsa.
    final puedeFacturar = isCompleted && !cargandoFacturas;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: (isCompleted
                  ? MuevexTheme.accentColor
                  : MuevexTheme.errorColor)
              .withValues(alpha: 0.15),
          child: Icon(
            isCompleted ? Icons.check : Icons.close,
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
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${date.day}/${date.month}/${date.year} · '
              '${service.distanceKm.toStringAsFixed(1)} km · ${money(amount)}',
            ),
            // El número va en la línea de abajo del subtítulo, no en el botón:
            // el botón se queda corto ("Ver") y la fila no se descuadra en
            // pantallas angostas.
            if (invoice != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  'Minifactura ${invoice!.numeroFactura}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: MuevexTheme.successColor,
                  ),
                ),
              )
            else if (cancelado)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  'Cancelado · sin minifactura',
                  style: TextStyle(fontSize: 12, color: Colors.black45),
                ),
              ),
          ],
        ),
        // El ListTile solo admite un `trailing`, así que el monto se fue a la
        // línea de abajo: si no, el botón tapaba lo que ganaste.
        trailing: cancelado
            ? null
            : puedeFacturar
                ? _BotonMinifactura(
                    tieneMinifactura: invoice != null,
                    numero: invoice?.numeroFactura,
                    onPressed: () => _abrirMinifactura(context, ref),
                  )
                : const SizedBox(
                    width: 20,
                    height: 20,
                    child: Center(
                      child: SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
      ),
    );
  }

  /// Una minifactura emitida se abre directamente en el visor. Si no hay, se
  /// pasa por la hoja de completado, que es quien sabe crearla y publicarla.
  ///
  /// Se reutiliza esa hoja a propósito: el conductor que completó un servicio y
  /// salió con "Ahora no, volver al inicio" ya no tenía manera de emitirla, y
  /// duplicar aquí la llamada a `crear_factura_desde_servicio` +
  /// `emitir_factura` dejaría dos sitios que se pueden desincronizar.
  Future<void> _abrirMinifactura(BuildContext context, WidgetRef ref) async {
    final emitida = invoice != null;
    if (emitida) {
      await showInvoiceSheet(context, invoiceId: invoice!.id);
      return;
    }
    await showServiceCompletedSheet(
      context,
      serviceId: service.id,
      serviceDescription: service.description,
    );
    // Al volver, la fila tiene que reflejar lo que pasó: si se acaba de emitir,
    // el botón y el número aparecen sin reiniciar la app.
    ref.invalidate(driverInvoicesByServiceProvider);
  }
}

class _BotonMinifactura extends StatelessWidget {
  final bool tieneMinifactura;
  final String? numero;
  final VoidCallback onPressed;

  const _BotonMinifactura({
    required this.tieneMinifactura,
    required this.onPressed,
    this.numero,
  });

  @override
  Widget build(BuildContext context) {
    final color = tieneMinifactura
        ? MuevexTheme.successColor
        : MuevexTheme.primaryColor;
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(
        tieneMinifactura ? Icons.receipt_long : Icons.receipt_long_outlined,
        size: 16,
      ),
      label: Text(tieneMinifactura ? 'Ver' : 'Generar'),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color),
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 10),
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  final IconData icon;
  final String texto;

  const _Aviso({required this.icon, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      color: MuevexTheme.errorColor.withValues(alpha: 0.08),
      child: ListTile(
        dense: true,
        leading: Icon(icon, color: MuevexTheme.errorColor),
        title: Text(texto, style: const TextStyle(fontSize: 12.5)),
      ),
    );
  }
}