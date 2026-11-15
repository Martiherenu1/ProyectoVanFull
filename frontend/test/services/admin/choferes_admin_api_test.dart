import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api/api_error.dart';
import 'package:frontend/core/api/http_api_client.dart';
import 'package:frontend/models/admin/chofer_admin.dart';
import 'package:frontend/services/admin/choferes_admin_api.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> choferJson({int id = 7}) => {
  'id_persona': id,
  'nombre': 'Ana',
  'apellido': 'Pérez',
  'dni': '21000001',
  'direccion': 'Calle 1',
  'telefono': '1122334455',
  'email': 'ana@vanfull.test',
  'cuil': '27-21000001-1',
  'registro_conducir': 'REG-21',
  'fecha_vencimiento_registro': '2028-06-30',
};

void main() {
  late Future<http.Response> Function(http.Request) responder;
  late ChoferesAdminApi api;

  setUp(() {
    responder = (_) async => http.Response(jsonEncode([choferJson()]), 200);
    api = ChoferesAdminApi(
      HttpApiClient(
        baseUri: Uri.parse('https://vanfull.test/api/'),
        transport: MockClient((request) => responder(request)),
        accessTokenProvider: () => 'token-administrativo',
      ),
    );
  });

  test('lista choferes con el token de la sesión', () async {
    late http.Request enviada;
    responder = (request) async {
      enviada = request;
      return http.Response(jsonEncode([choferJson()]), 200);
    };

    final resultado = await api.listar();

    expect(enviada.method, 'GET');
    expect(enviada.url.toString(), 'https://vanfull.test/api/choferes');
    expect(enviada.headers['authorization'], 'Bearer token-administrativo');
    expect(resultado.single.idPersona, 7);
    expect(resultado.single.fechaVencimientoRegistro, DateTime(2028, 6, 30));
  });

  test('registra solo los campos vigentes de Persona y Chofer', () async {
    late http.Request enviada;
    responder = (request) async {
      enviada = request;
      return http.Response(jsonEncode(choferJson()), 201);
    };

    await api.crear(
      ChoferAdminCreate(
        nombre: 'Ana',
        apellido: 'Pérez',
        dni: '21000001',
        direccion: 'Calle 1',
        telefono: '1122334455',
        email: 'ana@vanfull.test',
        cuil: '27-21000001-1',
        registroConducir: 'REG-21',
        fechaVencimientoRegistro: DateTime(2028, 6, 30),
      ),
    );

    final cuerpo = jsonDecode(enviada.body) as Map<String, dynamic>;
    expect(enviada.method, 'POST');
    expect(cuerpo['fecha_vencimiento_registro'], '2028-06-30');
    expect(cuerpo, isNot(contains('cuenta')));
    expect(cuerpo, isNot(contains('roles')));
    expect(cuerpo, isNot(contains('estado')));
    expect(cuerpo, isNot(contains('documentacion')));
  });

  test('modifica campos y permite vaciar los opcionales', () async {
    late http.Request enviada;
    responder = (request) async {
      enviada = request;
      return http.Response(
        jsonEncode({
          ...choferJson(),
          'direccion': null,
          'telefono': null,
          'email': null,
          'cuil': null,
          'registro_conducir': null,
          'fecha_vencimiento_registro': null,
        }),
        200,
      );
    };

    final resultado = await api.actualizar(
      7,
      const ChoferAdminUpdate(
        nombre: 'Ana',
        apellido: 'Pérez',
        dni: '21000001',
        direccion: null,
        telefono: null,
        email: null,
        cuil: null,
        registroConducir: null,
        fechaVencimientoRegistro: null,
      ),
    );

    expect(enviada.method, 'PATCH');
    expect(enviada.url.path, '/api/choferes/7');
    expect(resultado.registroConducir, isNull);
  });

  test('rechaza listado y chofer con estructuras incompatibles', () async {
    responder = (_) async => http.Response('{}', 200);
    await expectLater(api.listar(), throwsA(isA<ApiProtocolException>()));
    responder = (_) async => http.Response(jsonEncode({'id_persona': '7'}), 201);
    await expectLater(
      api.crear(
        const ChoferAdminCreate(
          nombre: 'A',
          apellido: 'P',
          dni: '1',
          direccion: null,
          telefono: null,
          email: null,
          cuil: null,
          registroConducir: null,
          fechaVencimientoRegistro: null,
        ),
      ),
      throwsA(isA<ApiProtocolException>()),
    );
  });
}
