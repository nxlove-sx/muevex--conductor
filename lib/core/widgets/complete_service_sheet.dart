import 'package:flutter/material.dart';

import 'package:muevex_conductor/core/models/invoice_model.dart';
import 'package:muevex_conductor/core/supabase/supabase_client.dart' as api;
import 'package:muevex_conductor/core/theme/muevex_theme.dart';
import 'package:muevex_conductor/core/widgets/custom_button.dart';
import 'package:muevex_conductor/core/widgets/invoice_sheet.dart';
import 'package:muevex_conductor/core/widgets/muevex_snackbar.dart';

/// Hoja de resumen que se muestra al conductor justo después de completar un
/// servicio. Desde aquí puede generar la minifactura del viaje, verla si ya
/// estaba, o volver al inicio. Se usa en los tres puntos de entrada del flujo
/// de finalización: el botón FINALIZAR de la navegación, la tarjeta de servicio
/// completado y la fila del historial.
Future<void> showServiceCompletedSheet(
  BuildContext context, {
  required String serviceId,
  String? serviceDescription,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ServiceCompletedSheet(
      serviceId: serviceId,
      serviceDescription: serviceDescription,
    ),
  );
}

class _ServiceCompletedSheet extends StatefulWidget {
  final String serviceId;
  final String? serviceDescription;

  const _ServiceCompletedSheet({
    required this.serviceId,
    this.serviceDescription,
  });

  @override
  State<_ServiceCompletedSheet> createState() => _ServiceCompletedSheetState();
}

class _ServiceCompletedSheetState extends State<_ServiceCompletedSheet> {
  static const _spinner = SizedBox(
    height: 68,
    child: Center(
      child: SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    ),
  );

  bool _checking = true;
  bool _generating = false;
  bool _hasInvoice = false;
  String? _invoiceNumber;

  /// Id de la factura emitida de este servicio, para poder abrirla.
  String? _invoiceId;

  @override
  void initState() {
    super.initState();
    _checkInvoice();
  }

  /// Consulta si este servicio ya fue facturado para no generar un duplicado
  /// si el conductor vuelve a abrir la hoja.
  Future<void> _checkInvoice() async {
    final invoices = await api.getDriverInvoices(status: InvoiceStatus.emitida);
    final match = invoices.where((i) => i.serviceId == widget.serviceId);
    if (!mounted) return;
    setState(() {
      _hasInvoice = match.isNotEmpty;
      _invoiceNumber = match.isEmpty ? null : match.first.numeroFactura;
      _invoiceId = match.isEmpty ? null : match.first.id;
      _checking = false;
    });
  }

  Future<void> _generateInvoice() async {
    if (_generating || _hasInvoice) return;
    setState(() => _generating = true);
    try {
      final invoice = await api.createInvoiceFromService(widget.serviceId);
      final publicada = await api.publicarMinifactura(invoice.id);
      if (!mounted) return;
      setState(() {
        _hasInvoice = true;
        _invoiceNumber = publicada?.numeroFactura ?? invoice.numeroFactura;
        _invoiceId = publicada?.id ?? invoice.id;
      });
      // Se abre el visor en el acto, igual que en la app del cliente: lo que se
      // acaba de generar es justo lo que se viene a mirar. Al cerrarlo se sigue
      // en esta hoja, con el aviso y el botón ya cambiados a "Ver".
      await showInvoiceSheet(context, invoiceId: _invoiceId!);
    } catch (e) {
      if (!mounted) return;
      MuevexSnackBar.error(context, 'No se pudo generar la minifactura: $e');
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final description = (widget.serviceDescription ?? '').trim();
    final subtitle = description.isEmpty
        ? null
        : Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
          );
    final actions =
        _checking ? const <Widget>[_spinner] : _buildActions(context);
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Row(
              children: [
                Icon(Icons.check_circle,
                    color: MuevexTheme.successColor, size: 28),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Servicio completado',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            if (subtitle != null) subtitle,
            const SizedBox(height: 18),
            ...actions,
          ],
        ),
      ),
    );
  }

  List<Widget> _buildActions(BuildContext context) {
    final buttons = <Widget>[];
    if (_hasInvoice) {
      buttons.add(
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: MuevexTheme.successColor.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: MuevexTheme.successColor.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Icon(Icons.receipt_long_outlined,
                  size: 20, color: MuevexTheme.successColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Minifactura ${_invoiceNumber ?? '—'} lista',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: MuevexTheme.successColor,
                  ),
                ),
              ),
              // Tocar el aviso abre la minifactura, en vez de dejarlo como texto
              // muerto. El icono de flecha deja claro que hay algo detrás.
              if (_invoiceId != null)
                TextButton.icon(
                  onPressed: () => showInvoiceSheet(context, invoiceId: _invoiceId!),
                  icon: const Icon(Icons.open_in_new, size: 15),
                  label: const Text('Ver'),
                  style: TextButton.styleFrom(
                    foregroundColor: MuevexTheme.successColor,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
        ),
      );
    } else {
      buttons.add(
        CustomButton(
          text: 'Generar minifactura',
          icon: Icons.receipt_long_outlined,
          gradient: true,
          loading: _generating,
          onPressed: _generating ? () {} : _generateInvoice,
        ),
      );
    }
    buttons.add(
      CustomButton(
        text: _hasInvoice ? 'Volver al inicio' : 'Ahora no, volver al inicio',
        backgroundColor: Colors.white,
        textColor: MuevexTheme.primaryColor,
        borderColor: MuevexTheme.primaryColor,
        onPressed: () => Navigator.of(context).pop(),
      ),
    );
    return buttons;
  }
}
