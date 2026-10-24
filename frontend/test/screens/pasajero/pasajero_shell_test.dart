import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/core/api/pasajero_api.dart';
import 'package:frontend/screens/pasajero/pasajero_shell.dart';
import 'package:frontend/screens/pasajero/perfil_screen.dart';

/// Servidor falso con un viaje y una parada; guarda las reservas que se crean.
class ServidorFalso implements ApiClient {
  final reservas = <Map<String, dynamic>>[];
  int pedidosDeReservas = 0;
  final perfil = <String, dynamic>{
    'id_persona': 7,
    'nombre': 'Ana',
    'apellido': 'Gómez',
    'dni': '30111222',
    'email': 'ana@vanfull.test',
    'telefono': '1155550000',
    'estado_habilitacion': 'habilitado',
  };

  @override
  Future<Object?> get(
    String path, {
    Map<String, String>? queryParameters,
  }) async {
    switch (path) {
      case 'servicios/disponibilidad':
        return [
          {
            'id_viaje': 12,
            'id_servicio': 2,
            'id_recorrido': 3,
            'fecha': queryParameters!['fecha'],
            'horario': '06:15',
            'sentido': queryParameters['sentido'],
            'cupo_disponible': 14,
          },
        ];
      case 'recorridos/3/paradas':
        return [
          {
            'id_parada': 10,
            'orden': 1,
            'nombre_descripcion': 'Plaza Belgrano',
            'comprometida': true,
          },
        ];
      case 'pasajeros/me/reservas':
        pedidosDeReservas++;
        return reservas;
      case 'pasajeros/me/deuda':
        return {'saldo': 0, 'estado': 'al_dia'};
      case 'pasajeros/me':
        return perfil;
    }
    throw StateError('GET inesperado: $path');
  }

  @override
  Future<Object?> post(String path, {Object? body}) async {
    if (path == 'reservas') {
      final reserva = {
        'id_reserva': 41,
        'id_pasajero': 7,
        'id_viaje': 12,
        'id_recorrido': 3,
        'orden_parada': 1,
        'fecha': '2026-10-30',
        'horario': '06:15',
        'sentido': 'IDA',
        'estado': 'consolidada',
      };
      reservas.add(reserva);
      return reserva;
    }
    throw StateError('POST inesperado: $path');
  }

  @override
  Future<Object?> patch(String path, {Object? body}) async {
    if (path == 'pasajeros/me') {
      perfil.addAll(body! as Map<String, dynamic>);
      return perfil;
    }
    throw StateError('PATCH inesperado: $path');
  }
}

void main() {
  testWidgets('buscar, reservar y ver la reserva en Mis reservas', (
    tester,
  ) async {
    final servidor = ServidorFalso();
    var salio = false;
    await tester.pumpWidget(
      MaterialApp(
        home: PasajeroShell(
          api: PasajeroApi(servidor),
          onSalir: () => salio = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Buscar servicio lista el viaje y abre la reserva.
    expect(find.text('Buscar servicio'), findsWidgets);
    await tester.tap(find.textContaining('06:15').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('reservar-viaje')));
    await tester.pumpAndSettle();

    // Confirmar reserva: se elige la parada y se confirma.
    await tester.tap(find.text('Plaza Belgrano'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('confirmar-reserva')));
    await tester.pumpAndSettle();
    expect(servidor.reservas, hasLength(1));

    // Al terminar, el pasajero queda en Mis reservas con la reserva creada.
    await tester.tap(find.byKey(const ValueKey('terminar-reserva')));
    await tester.pumpAndSettle();
    expect(find.text('Mis reservas'), findsWidgets);
    expect(servidor.pedidosDeReservas, greaterThan(0));

    // Cuenta: cerrar sesión.
    await tester.tap(find.text('Cuenta'));
    await tester.pumpAndSettle();
    expect(find.text('Ana Gómez'), findsOneWidget);
    // El botón queda bajo el pliegue de la lista: se desplaza hasta verlo.
    await tester.drag(
      find.descendant(
        of: find.byType(PerfilScreen),
        matching: find.byType(ListView),
      ),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('cerrar-sesion')));
    expect(salio, isTrue);
  });

  testWidgets('volver a Mis reservas la recarga', (tester) async {
    final servidor = ServidorFalso();
    await tester.pumpWidget(
      MaterialApp(
        home: PasajeroShell(api: PasajeroApi(servidor), onSalir: () {}),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mis reservas'));
    await tester.pumpAndSettle();
    final primeras = servidor.pedidosDeReservas;

    await tester.tap(find.text('Asistente'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mis reservas'));
    await tester.pumpAndSettle();

    expect(servidor.pedidosDeReservas, greaterThan(primeras));
  });
}
