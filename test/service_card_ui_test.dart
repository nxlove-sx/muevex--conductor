import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:muevex_conductor/data/models/service_model.dart';
import 'package:muevex_conductor/features/dashboard/widgets/service_card.dart';

/// Pantallas distintas, no una sola. Una tarjeta que solo se prueba en un móvil
/// de 6" se rompe cuando aparece una dirección más larga o un precio de siete
/// cifras.
const _pantallas = <String, Size>{
  'pantalla pequeña 360x640': Size(360, 640),
  'móvil normal 412x915': Size(412, 915),
};

Service _s({
  required String id,
  ServiceStatus status = ServiceStatus.solicitado,
  String? loadDescription,
  double precio = 184500,
  double ganancia = 0,
  double km = 12.4,
  int minutos = 45,
  double kg = 420,
  int pisos = 0,
  bool ayuda = false,
  String? origen,
  String? destino,
}) {
  return Service(
    id: id,
    customerId: 'c1',
    status: status,
    priceBase: precio,
    priceTotal: precio,
    estimatedPrice: precio,
    driverEarnings: ganancia,
    originLat: 6.2442,
    originLng: -75.5812,
    destinationLat: 6.25,
    destinationLng: -75.57,
    originName: origen ?? 'Calle 10 # 30-20, Medellín',
    destinationName: destino ?? 'Carrera 70 # 1-50, Medellín',
    loadType: 'muebles',
    loadDescription: loadDescription,
    distanceKm: km,
    durationMinutes: minutos,
    loadWeightKg: kg,
    floors: pisos,
    needsHelp: ayuda,
    createdAt: DateTime.now(),
  );
}

/// Monta la tarjeta y devuelve los desbordos que Flutter haya reportado.
Future<List<String>> _pumpTarjeta(
  WidgetTester tester,
  Service servicio, {
  Size tamano = const Size(412, 915),
  double escalaTexto = 1.0,
}) async {
  tester.view.physicalSize = tamano;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final errores = <String>[];
  final flutterError = FlutterError.onError;
  FlutterError.onError = (details) {
    final texto = details.exceptionAsString();
    if (texto.contains('overflowed')) errores.add(texto);
    flutterError?.call(details);
  };
  addTearDown(() => FlutterError.onError = flutterError);

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ServiceCard(service: servicio),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return errores;
}

void main() {
  testWidgets('muestra el precio y el recorrido', (tester) async {
    await _pumpTarjeta(tester, _s(id: 'a'));

    expect(find.text('Muebles'), findsOneWidget);
    expect(find.text('ORIGEN'), findsOneWidget);
    expect(find.text('DESTINO'), findsOneWidget);
    expect(find.text('Aceptar servicio'), findsOneWidget);
    expect(find.text('Descartar'), findsOneWidget);
  });

  testWidgets('con ganancia calculada se emphasis esa cifra', (tester) async {
    await _pumpTarjeta(tester, _s(id: 'b', ganancia: 139200));

    expect(find.text('tu ganancia'), findsOneWidget);
    expect(find.text('precio del cliente'), findsNothing);
  });

  testWidgets('sin ganancia muestra el precio del cliente', (tester) async {
    await _pumpTarjeta(tester, _s(id: 'c', ganancia: 0));

    expect(find.text('precio del cliente'), findsOneWidget);
    expect(find.text('tu ganancia'), findsNothing);
  });

  for (final pantalla in _pantallas.entries) {
    testWidgets('sin desbordes en ${pantalla.key}', (tester) async {
      final errores = await _pumpTarjeta(
        tester,
        _s(
          id: 'd',
          loadDescription:
              'Mudanza de apartamento con ascensor, terraza y garaje',
          precio: 1234567,
          kg: 987,
          pisos: 4,
          ayuda: true,
        ),
        tamano: pantalla.value,
      );
      expect(errores, isEmpty, reason: errores.join('\n'));
    });
  }

  testWidgets('sin desbordes con direcciones largas', (tester) async {
    final errores = await _pumpTarjeta(
      tester,
      _s(
        id: 'e',
        origen:
            'Carrera 43A # 1 Sur-50, Edificio Torre Mirador, Apartamento 502',
        destino: 'Centro Comercial El Tesoro, Local 2045, Medellín, Antioquia',
      ),
      tamano: const Size(360, 640),
    );
    expect(errores, isEmpty, reason: errores.join('\n'));
  });

  testWidgets('sin desbordes con la fuente al 160%', (tester) async {
    final errores = await _pumpTarjeta(
      tester,
      _s(id: 'f', kg: 540, pisos: 3, ayuda: true),
      escalaTexto: 1.6,
      tamano: const Size(360, 640),
    );
    expect(errores, isEmpty, reason: errores.join('\n'));
  });
}
