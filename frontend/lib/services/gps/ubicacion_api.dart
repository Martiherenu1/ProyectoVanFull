import '../../core/api/api_client.dart';
import '../../models/gps/ubicacion_viaje.dart';

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

  Future<UbicacionViaje> consultar(int id) async =>
      UbicacionViaje.fromJson(await _cliente.get('viajes/$id/ubicacion'), id);
}
