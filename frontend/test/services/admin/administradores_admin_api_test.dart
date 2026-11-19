import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api/api_error.dart';
import 'package:frontend/core/api/http_api_client.dart';
import 'package:frontend/models/admin/administrador.dart';
import 'package:frontend/services/admin/administradores_admin_api.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> administradorJson({
  int id = 7,
  String estado = 'activo',
  String? email = 'ada@vanfull.test',
}) => {
  'id_cuenta_acceso': id,
  'id_persona': 70 + id,
  'nombre': 'Ada',
  'apellido': 'Admin',
  'dni': '30111222',
  'email': ?email,
  'identificador_acceso': 'ada@vanfull.test',
  'estado': estado,
};

void main() {
  AdministradoresAdminApi api(
    Future<http.Response> Function(http.Request) responder,
  ) => AdministradoresAdminApi(
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

  test('listar: GET autenticado y lee items', () async {
    final lista = await api((r) async {
      expect(r.method, 'GET');
      expect(r.url.path, '/api/administradores');
      expect(r.headers['authorization'], 'Bearer token');
      return json({
        'items': [administradorJson(), administradorJson(id: 8, email: null)],
        'total': 2,
      });
    }).listar();
    expect(lista, hasLength(2));
    expect(lista.first.nombreCompleto, 'Admin, Ada');
    expect(lista.last.email, isNull);
    expect(lista.first.activo, isTrue);
  });

  test('listar: una respuesta que no respeta el contrato es de protocolo', () {
    expect(
      api((_) async => json([1, 2])).listar(),
      throwsA(isA<ApiProtocolException>()),
    );
  });

  test('crear: POST con la contraseña y sin opcionales vacíos', () async {
    final creado =
        await api((r) async {
          expect(r.method, 'POST');
          expect(r.url.path, '/api/administradores');
          final cuerpo = jsonDecode(r.body) as Map<String, dynamic>;
          expect(cuerpo['contrasena'], 'clave-segura-1');
          expect(cuerpo['identificador_acceso'], 'ada@vanfull.test');
          expect(cuerpo.containsKey('email'), isFalse);
          expect(cuerpo.containsKey('telefono'), isFalse);
          return json(administradorJson(email: null), 201);
        }).crear(
          const AdministradorCreate(
            nombre: 'Ada',
            apellido: 'Admin',
            dni: '30111222',
            identificadorAcceso: 'ada@vanfull.test',
            contrasena: 'clave-segura-1',
            email: '',
          ),
        );
    expect(creado.idCuentaAcceso, 7);
  });

  test('modificar: PATCH con solo los campos cambiados', () async {
    final cambiado = await api((r) async {
      expect(r.method, 'PATCH');
      expect(r.url.path, '/api/administradores/7');
      expect(jsonDecode(r.body), {'apellido': 'Nuevo'});
      return json(administradorJson());
    }).modificar(7, {'apellido': 'Nuevo'});
    expect(cambiado.idCuentaAcceso, 7);
  });

  test('deshabilitar: POST a /deshabilitacion', () async {
    final deshabilitado = await api((r) async {
      expect(r.method, 'POST');
      expect(r.url.path, '/api/administradores/7/deshabilitacion');
      return json(administradorJson(estado: 'deshabilitado'));
    }).deshabilitar(7);
    expect(deshabilitado.activo, isFalse);
  });

  test('un 409 del backend llega como ApiException con su código', () async {
    final error =
        api(
          (_) async => json({
            'error': {
              'codigo': 'DNI_DUPLICADO',
              'mensaje': 'Ya existe una persona con ese DNI.',
            },
          }, 409),
        ).crear(
          const AdministradorCreate(
            nombre: 'Ada',
            apellido: 'Admin',
            dni: '30111222',
            identificadorAcceso: 'ada@vanfull.test',
            contrasena: 'clave-segura-1',
          ),
        );
    await expectLater(
      error,
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 409)
            .having((e) => e.codigo, 'codigo', 'DNI_DUPLICADO'),
      ),
    );
  });
}
