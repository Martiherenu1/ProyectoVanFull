import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api/api_error.dart';
import 'package:frontend/core/api/http_api_client.dart';
import 'package:frontend/models/admin/recorrido_gestion.dart';
import 'package:frontend/services/admin/recorridos_admin_api.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> recorridoJson({int id = 5}) => {
  'id_recorrido': id,
  'paradas': [
    {
      'orden': 1,
      'id_parada': 10,
      'nombre_descripcion': 'Plaza',
      'comprometida': false,
    },
    {'orden': 2, 'id_parada': 11, 'comprometida': true},
  ],
};

void main() {
  RecorridosAdminApi api(
    Future<http.Response> Function(http.Request) responder,
  ) => RecorridosAdminApi(
    HttpApiClient(
      baseUri: Uri.parse('https://vanfull.test/api/'),
      accessTokenProvider: () => 'token',
      transport: MockClient(responder),
    ),
  );

  http.Response json(Object cuerpo, [int estado = 200]) => http.Response(
    jsonEncode(cuerpo),
    estado,
    headers: {'content-type': 'application/json'},
  );

  test('listarRecorridos lee paradas, orden y comprometida', () async {
    final lista = await api((r) async {
      expect(r.method, 'GET');
      expect(r.url.path, '/api/administracion/recorridos');
      expect(r.headers['authorization'], 'Bearer token');
      return json({
        'items': [recorridoJson()],
        'total': 1,
      });
    }).listarRecorridos();
    expect(lista.single.paradas, hasLength(2));
    expect(lista.single.paradas.first.etiqueta, 'Plaza');
    expect(lista.single.paradas.last.etiqueta, 'Parada 11');
    expect(lista.single.paradas.last.comprometida, isTrue);
  });

  test('listarParadas lee el catálogo con coordenadas opcionales', () async {
    final lista = await api((r) async {
      expect(r.url.path, '/api/administracion/paradas');
      return json({
        'items': [
          {
            'id_parada': 1,
            'nombre_descripcion': 'A',
            'latitud': -34.6,
            'longitud': -58.4,
          },
          {'id_parada': 2},
        ],
        'total': 2,
      });
    }).listarParadas();
    expect(lista.first.latitud, -34.6);
    expect(lista.last.nombre, isNull);
  });

  test('listar con una respuesta fuera de contrato es de protocolo', () {
    expect(
      api((_) async => json([1])).listarRecorridos(),
      throwsA(isA<ApiProtocolException>()),
    );
  });

  test('crearParada envía coordenadas solo si van juntas', () async {
    await api((r) async {
      expect(r.method, 'POST');
      expect(r.url.path, '/api/administracion/paradas');
      expect(jsonDecode(r.body), {'nombre_descripcion': 'Sola'});
      return json({'id_parada': 9, 'nombre_descripcion': 'Sola'}, 201);
    }).crearParada(
      const ParadaCatalogoCreate(nombre: 'Sola', direccion: '', latitud: -34.6),
    );
  });

  test('crearRecorrido manda las paradas en orden', () async {
    final creado = await api((r) async {
      expect(r.method, 'POST');
      expect(r.url.path, '/api/administracion/recorridos');
      expect(jsonDecode(r.body), {
        'id_paradas': [3, 1, 2],
      });
      return json(recorridoJson(id: 8), 201);
    }).crearRecorrido([3, 1, 2]);
    expect(creado.idRecorrido, 8);
  });

  test('reemplazarParadas usa PATCH sobre el recorrido', () async {
    await api((r) async {
      expect(r.method, 'PATCH');
      expect(r.url.path, '/api/administracion/recorridos/5');
      expect(jsonDecode(r.body), {
        'id_paradas': [10, 11],
      });
      return json(recorridoJson());
    }).reemplazarParadas(5, [10, 11]);
  });

  test('un 409 PARADA_COMPROMETIDA llega con su código', () async {
    final error = api(
      (_) async => json({
        'error': {
          'codigo': 'PARADA_COMPROMETIDA',
          'mensaje': 'RN-021',
          'detalles': {
            'ordenes': [2],
          },
        },
      }, 409),
    ).reemplazarParadas(5, [10]);
    await expectLater(
      error,
      throwsA(
        isA<ApiException>()
            .having((e) => e.codigo, 'codigo', 'PARADA_COMPROMETIDA')
            .having((e) => e.statusCode, 'statusCode', 409),
      ),
    );
  });
}
