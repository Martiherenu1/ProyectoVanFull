import '../../models/chofer/viaje_resumen.dart' show SentidoViaje;
import '../../models/pasajero/deuda.dart';
import '../../models/pasajero/disponibilidad_viaje.dart';
import '../../models/pasajero/parada.dart';
import '../../models/pasajero/reserva.dart';
import '../../models/pasajero/respuesta_chat.dart';
import 'api_client.dart';
import 'api_error.dart';

/// Adaptador de las operaciones del pasajero sobre el cliente común. Sus
/// métodos tienen la forma de los `typedef` de las pantallas.
class PasajeroApi {
  const PasajeroApi(this._cliente);

  final ApiClient _cliente;

  List<Map<String, dynamic>> _lista(Object? cuerpo) =>
      (cuerpo! as List).cast<Map<String, dynamic>>();

  /// 400 y 409 con el cuerpo de error del contrato son rechazos de la
  /// operación; el resto (red, 5xx, 401) sube sin tocar.
  Never _rechazo(ApiException e) {
    if (e.statusCode == 400 || e.statusCode == 409) {
      throw ReservaRechazada(
        codigo: e.codigo,
        mensaje: e.mensaje,
        listaEspera: e.detalles?['lista_espera'] == true,
      );
    }
    throw e;
  }

  Future<List<DisponibilidadViaje>> cargarDisponibilidad(
    DateTime fecha,
    SentidoViaje sentido,
  ) async {
    final dia =
        '${fecha.year.toString().padLeft(4, '0')}-'
        '${fecha.month.toString().padLeft(2, '0')}-'
        '${fecha.day.toString().padLeft(2, '0')}';
    final cuerpo = await _cliente.get(
      'servicios/disponibilidad',
      queryParameters: {'fecha': dia, 'sentido': sentido.valorApi},
    );
    return _lista(cuerpo).map(DisponibilidadViaje.fromJson).toList();
  }

  Future<List<Parada>> cargarParadas(int idRecorrido) async {
    final cuerpo = await _cliente.get('recorridos/$idRecorrido/paradas');
    return _lista(cuerpo).map(Parada.fromJson).toList();
  }

  Future<Reserva> crearReserva(int idViaje, int ordenParada) async {
    try {
      final cuerpo = await _cliente.post(
        'reservas',
        body: {'id_viaje': idViaje, 'orden_parada': ordenParada},
      );
      return Reserva.fromJson(cuerpo! as Map<String, dynamic>);
    } on ApiException catch (e) {
      _rechazo(e);
    }
  }

  Future<List<Reserva>> cargarReservas() async {
    final cuerpo = await _cliente.get('pasajeros/me/reservas');
    return _lista(cuerpo).map(Reserva.fromJson).toList();
  }

  /// Quien nunca reservó no tiene cliente individual y el backend responde 404
  /// `CLIENTE_NO_ENCONTRADO`: sin cuenta corriente no hay nada que deber.
  Future<Deuda> cargarDeuda() async {
    try {
      final cuerpo = await _cliente.get('pasajeros/me/deuda');
      return Deuda.fromJson(cuerpo! as Map<String, dynamic>);
    } on ApiException catch (e) {
      if (e.statusCode == 404 && e.codigo == 'CLIENTE_NO_ENCONTRADO') {
        return const Deuda(saldo: 0, estado: EstadoDeuda.alDia);
      }
      rethrow;
    }
  }

  Future<ResultadoCancelacion> cancelarReserva(int idReserva) async {
    try {
      final cuerpo = await _cliente.post('reservas/$idReserva/cancelacion');
      return ResultadoCancelacion.fromJson(cuerpo! as Map<String, dynamic>);
    } on ApiException catch (e) {
      _rechazo(e);
    }
  }

  Future<RespuestaChat> enviarMensaje(
    String mensaje,
    String? conversacionId,
  ) async {
    final cuerpo = await _cliente.post(
      'chat',
      body: {'mensaje': mensaje, 'conversacion_id': ?conversacionId},
    );
    return RespuestaChat.fromJson(cuerpo! as Map<String, dynamic>);
  }
}
