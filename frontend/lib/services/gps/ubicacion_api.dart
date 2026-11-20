import '../../core/api/api_client.dart';
import '../../models/gps/ubicacion_viaje.dart';
import '../../models/gps/eta_reserva.dart';

class UbicacionApi {
  const UbicacionApi(this._cliente);
  final ApiClient _cliente;

  Future<void> enviar(
    int id,
    double lat,
    double lon,
    DateTime fecha,
    String token,
  ) async {
    final value = await _cliente.post(
      'viajes/$id/ubicacion',
      accessToken: token,
      body: {
        'latitud': lat,
        'longitud': lon,
        'fecha_hora_posicion': fecha.toUtc().toIso8601String(),
      },
    );
    if (value is! Map ||
        value['actualizada'] is! bool ||
        DateTime.tryParse(value['fecha_hora_posicion'] as String? ?? '') ==
            null) {
      throw const FormatException('Respuesta GPS inválida');
    }
  }

  Future<void> configurarDescensos(int idViaje, Set<int> ordenes) async {
    await _cliente.patch('viajes/$idViaje/descensos', body: {'ordenes': ordenes.toList()});
  }

  Future<EtaReserva> consultarEta(int idReserva) async => EtaReserva.fromJson(
    await _cliente.get('reservas/$idReserva/eta'),
  );

  Future<int> registrarPaso(int idViaje, int orden, String token) async {
    final respuesta = await _cliente.post(
      'viajes/$idViaje/paso-parada',
      accessToken: token,
      body: {'orden_parada': orden},
    );
    return (respuesta as Map)['orden_parada'] as int;
  }

  Future<UbicacionViaje> consultar(int id) async {
    final cliente = _cliente;
    if (cliente is ApiClientConMetadatos) {
      final respuesta = await cliente.getConMetadatos('viajes/$id/ubicacion');
      final directivas = (respuesta.headers['cache-control'] ?? '')
          .toLowerCase()
          .split(',')
          .map((d) => d.trim());
      final age = respuesta.headers['age'];
      final sinCache =
          directivas.contains('no-store') &&
          (age == null || int.tryParse(age.trim()) == 0);
      return UbicacionViaje.fromJson(respuesta.cuerpo, id, sinCache: sinCache);
    }
    return UbicacionViaje.fromJson(
      await cliente.get('viajes/$id/ubicacion'),
      id,
    );
  }
}
