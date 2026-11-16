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
