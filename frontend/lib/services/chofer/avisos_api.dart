import '../../core/api/api_client.dart';
import '../../core/api/api_error.dart';

class AvisoRechazado implements Exception {}

/// Sin sesión propia ni reenvío automático. El contenedor revalida su generación.
class AvisosApi {
  const AvisosApi(this.client);
  final ApiClient client;

  Future<int> registrar(
    int viaje,
    String clave,
    String clase,
    String detalle,
  ) async {
    try {
      return _id(
        await client.post(
          '/viajes/$viaje/avisos',
          body: {
            'clave_solicitud': clave,
            'clase': clase,
            'descripcion_interna': detalle,
          },
        ),
        viaje,
        clave,
      );
    } on ApiException catch (e) {
      // El contenedor debe recibir 403 para aplicar la protección común.
      if ([400, 401, 404, 409].contains(e.statusCode)) {
        throw AvisoRechazado();
      }
      rethrow;
    }
  }

  Future<int> recuperar(int viaje, String clave) async {
    final normalizada = clave.trim().toLowerCase();
    return _id(
      await client.get(
        '/viajes/$viaje/avisos/resultado',
        queryParameters: {'clave_solicitud': normalizada},
      ),
      viaje,
      normalizada,
    );
  }

  int _id(Object? data, int viaje, String clave) {
    if (data is! Map<String, dynamic> ||
        data['id_viaje'] != viaje ||
        data['clave_solicitud'] != clave.toLowerCase() ||
        data['registro'] != 'confirmado' ||
        data['id_evento_operativo'] is! int) {
      throw const FormatException('Resultado no confirmado');
    }
    return data['id_evento_operativo'] as int;
  }
}
