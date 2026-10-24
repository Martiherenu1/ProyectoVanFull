import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/core/api/api_error.dart';
import 'package:frontend/core/api/auth_api.dart';
import 'package:frontend/core/api/pasajero_api.dart';
import 'package:frontend/core/session/sesion.dart';
import 'package:frontend/models/chofer/viaje_resumen.dart';
import 'package:frontend/models/pasajero/pago.dart';
import 'package:frontend/models/pasajero/reserva.dart';

/// Responde por "METODO ruta" y guarda lo último que recibió.
class ClienteFalso implements ApiClient {
  ClienteFalso(this.respuestas);

  final Map<String, Object? Function()> respuestas;
  String? ultimaClave;
  Map<String, String>? ultimaConsulta;
  Object? ultimoCuerpo;

  Object? _atender(String clave) {
    ultimaClave = clave;
    return respuestas[clave]!();
  }

  @override
  Future<Object?> get(
    String path, {
    Map<String, String>? queryParameters,
  }) async {
    ultimaConsulta = queryParameters;
    return _atender('GET $path');
  }

  @override
  Future<Object?> post(String path, {Object? body}) async {
    ultimoCuerpo = body;
    return _atender('POST $path');
  }
}

ApiException error(
  int estado,
  String codigo, {
  Map<String, dynamic>? detalles,
}) => ApiException(
  statusCode: estado,
  codigo: codigo,
  mensaje: 'Mensaje de $codigo',
  detalles: detalles,
);

Map<String, dynamic> reservaJson({String estado = 'consolidada'}) => {
  'id_reserva': 41,
  'id_pasajero': 7,
  'id_viaje': 12,
  'id_recorrido': 3,
  'orden_parada': 2,
  'fecha': '2026-10-30',
  'horario': '06:15',
  'sentido': 'IDA',
  'estado': estado,
};

void main() {
  group('AuthApi', () {
    test('login manda el contrato y devuelve la sesión', () async {
      final cliente = ClienteFalso({
        'POST auth/login': () => {
          'access_token': 'tok',
          'token_type': 'bearer',
          'roles': ['pasajero'],
        },
      });
      final sesion = await AuthApi(cliente).iniciarSesion('ana', 'clave');

      expect(cliente.ultimoCuerpo, {
        'identificador_acceso': 'ana',
        'password': 'clave',
      });
      expect(sesion.accessToken, 'tok');
      expect(sesion.roles, ['pasajero']);
    });

    test('el 401 es CredencialesInvalidas y otros errores suben', () async {
      final invalido = ClienteFalso({
        'POST auth/login': () => throw error(401, 'CREDENCIALES_INVALIDAS'),
      });
      expect(
        AuthApi(invalido).iniciarSesion('a', 'b'),
        throwsA(isA<CredencialesInvalidas>()),
      );

      final caido = ClienteFalso({
        'POST auth/login': () => throw error(500, 'ERROR_INTERNO'),
      });
      expect(
        AuthApi(caido).iniciarSesion('a', 'b'),
        throwsA(isA<ApiException>()),
      );
    });

    test('logout llama a POST auth/logout', () async {
      final cliente = ClienteFalso({'POST auth/logout': () => null});
      await AuthApi(cliente).cerrarSesion();
      expect(cliente.ultimaClave, 'POST auth/logout');
    });
  });

  group('PasajeroApi', () {
    test('disponibilidad manda fecha ISO y sentido sin destino', () async {
      final cliente = ClienteFalso({
        'GET servicios/disponibilidad': () => [
          {
            'id_viaje': 12,
            'id_servicio': 2,
            'id_recorrido': 3,
            'fecha': '2026-10-30',
            'sentido': 'IDA',
            'cupo_disponible': 14,
          },
        ],
      });
      final viajes = await PasajeroApi(cliente)
          .cargarDisponibilidad(DateTime(2026, 10, 5), SentidoViaje.vuelta);

      expect(cliente.ultimaConsulta, {
        'fecha': '2026-10-05',
        'sentido': 'VUELTA',
      });
      expect(viajes.single.idViaje, 12);
      expect(viajes.single.horario, isNull);
    });

    test('paradas del recorrido', () async {
      final cliente = ClienteFalso({
        'GET recorridos/3/paradas': () => [
          {'id_parada': 10, 'orden': 1, 'comprometida': true},
        ],
      });
      final paradas = await PasajeroApi(cliente).cargarParadas(3);
      expect(paradas.single.orden, 1);
    });

    test('crear reserva manda id_viaje y orden_parada', () async {
      final cliente = ClienteFalso({'POST reservas': reservaJson});
      final reserva = await PasajeroApi(cliente).crearReserva(12, 2);

      expect(cliente.ultimoCuerpo, {'id_viaje': 12, 'orden_parada': 2});
      expect(reserva.estado, EstadoReserva.consolidada);
    });

    test('el 409 de cupo es ReservaRechazada con lista de espera', () async {
      final cliente = ClienteFalso({
        'POST reservas': () => throw error(
          409,
          'CUPO_NO_DISPONIBLE',
          detalles: {'lista_espera': true},
        ),
      });
      await expectLater(
        PasajeroApi(cliente).crearReserva(12, 2),
        throwsA(
          isA<ReservaRechazada>()
              .having((e) => e.codigo, 'codigo', 'CUPO_NO_DISPONIBLE')
              .having((e) => e.listaEspera, 'listaEspera', isTrue),
        ),
      );
    });

    test('el 400 también es rechazo; el 500 y el 401 suben tal cual', () async {
      final rechazo400 = ClienteFalso({
        'POST reservas': () => throw error(400, 'PARADA_NO_VALIDA'),
      });
      await expectLater(
        PasajeroApi(rechazo400).crearReserva(1, 9),
        throwsA(isA<ReservaRechazada>()),
      );

      for (final estado in [401, 500]) {
        final cliente = ClienteFalso({
          'POST reservas': () => throw error(estado, 'X'),
        });
        await expectLater(
          PasajeroApi(cliente).crearReserva(1, 1),
          throwsA(isA<ApiException>()),
        );
      }
    });

    test('mis reservas y deuda', () async {
      final cliente = ClienteFalso({
        'GET pasajeros/me/reservas': () => [reservaJson()],
        'GET pasajeros/me/deuda': () => {'saldo': 11600, 'estado': 'con_deuda'},
      });
      final api = PasajeroApi(cliente);

      expect((await api.cargarReservas()).single.idReserva, 41);
      expect((await api.cargarDeuda()).saldo, 11600.0);
    });

    test('registrar pago manda importe y medio, sin id_cliente', () async {
      final cliente = ClienteFalso({
        'POST pagos': () => {
          'id_pago': 5,
          'id_cliente': 1,
          'importe': 5800,
          'medio_pago': 'TRANSFERENCIA',
          'estado': 'PENDIENTE',
          'fecha_hora': '2026-10-24T18:00:00Z',
        },
      });
      final pago = await PasajeroApi(cliente)
          .registrarPago(5800, MedioPago.transferencia);

      expect(cliente.ultimoCuerpo, {
        'importe': 5800,
        'medio_pago': 'TRANSFERENCIA',
      });
      expect(pago.estado, EstadoPago.pendiente);

      final sinCuenta = ClienteFalso({
        'POST pagos': () => throw error(404, 'CUENTA_CORRIENTE_NO_ENCONTRADA'),
      });
      await expectLater(
        PasajeroApi(sinCuenta).registrarPago(1, MedioPago.efectivo),
        throwsA(isA<ApiException>()),
      );
    });

    test('cancelar usa la ruta de la reserva y traduce el 409', () async {
      final cliente = ClienteFalso({
        'POST reservas/41/cancelacion': () => {
          'reserva': reservaJson(estado: 'cancelada'),
          'cupo_liberado': true,
          'penalidad_aplicada': false,
          'importe_penalidad': 0,
          'motivo': 'Motivo.',
        },
      });
      final resultado = await PasajeroApi(cliente).cancelarReserva(41);
      expect(resultado.cupoLiberado, isTrue);

      final rechazada = ClienteFalso({
        'POST reservas/41/cancelacion': () =>
            throw error(409, 'RESERVA_NO_CANCELABLE'),
      });
      await expectLater(
        PasajeroApi(rechazada).cancelarReserva(41),
        throwsA(isA<ReservaRechazada>()),
      );
    });

    test('chat reenvía el conversacion_id solo si existe', () async {
      final cliente = ClienteFalso({
        'POST chat': () => {
          'respuesta': 'Hola',
          'conversacion_id': 'c1',
          'derivar_humano': false,
        },
      });
      final api = PasajeroApi(cliente);

      await api.enviarMensaje('hola', null);
      expect(cliente.ultimoCuerpo, {'mensaje': 'hola'});

      final r = await api.enviarMensaje('y?', 'c1');
      expect(cliente.ultimoCuerpo, {'mensaje': 'y?', 'conversacion_id': 'c1'});
      expect(r.conversacionId, 'c1');
    });
  });
}
