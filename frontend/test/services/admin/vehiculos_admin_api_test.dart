import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api/api_error.dart';
import 'package:frontend/core/api/http_api_client.dart';
import 'package:frontend/models/admin/vehiculo_admin.dart';
import 'package:frontend/services/admin/vehiculos_admin_api.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> vehiculo({
  int id = 1,
  String patente = 'VF022AA',
  bool disponibilidad = true,
}) => {
  'id_vehiculo': id,
  'patente': patente,
  'marca': 'Mercedes-Benz',
  'modelo': 'Sprinter',
  'capacidad': 19,
  'disponibilidad': disponibilidad,
};

void main() {
  late Future<http.Response> Function(http.Request) responder;
  late VehiculosAdminApi api;

  setUp(() {
    final transporte = MockClient((request) => responder(request));
    api = VehiculosAdminApi(
      HttpApiClient(
        baseUri: Uri.parse('https://vanfull.test/api/'),
        transport: transporte,
        accessTokenProvider: () => 'token-admin',
      ),
    );
  });

  test('lista vehículos con el token de la sesión', () async {
    late http.Request enviada;
    responder = (request) async {
      enviada = request;
      return http.Response(jsonEncode([vehiculo()]), 200);
    };
    final resultado = await api.listar();
    expect(enviada.method, 'GET');
    expect(enviada.url.toString(), 'https://vanfull.test/api/vehiculos');
    expect(enviada.headers['authorization'], 'Bearer token-admin');
    expect(resultado.single.patente, 'VF022AA');
  });

  test('registra los campos contractuales sin documentación', () async {
    late Map<String, dynamic> cuerpo;
    responder = (request) async {
      cuerpo = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(jsonEncode(vehiculo()), 201);
    };
    await api.crear(
      const VehiculoCreate(
        patente: 'VF022AA',
        marca: 'Mercedes-Benz',
        modelo: 'Sprinter',
        capacidad: 19,
        disponibilidad: true,
      ),
    );
    expect(cuerpo, {
      'patente': 'VF022AA',
      'marca': 'Mercedes-Benz',
      'modelo': 'Sprinter',
      'capacidad': 19,
      'disponibilidad': true,
    });
    expect(cuerpo, isNot(contains('documentacion')));
  });

  test('modifica por PATCH y conserva disponibilidad explícita', () async {
    late http.Request enviada;
    responder = (request) async {
      enviada = request;
      return http.Response(jsonEncode(vehiculo(disponibilidad: false)), 200);
    };
    final resultado = await api.actualizar(
      1,
      const VehiculoUpdate(
        patente: 'VF022AA',
        marca: 'Mercedes-Benz',
        modelo: 'Sprinter',
        capacidad: 19,
        disponibilidad: false,
      ),
    );
    expect(enviada.method, 'PATCH');
    expect(enviada.url.toString(), 'https://vanfull.test/api/vehiculos/1');
    expect(resultado.disponibilidad, isFalse);
  });

  test('rechaza respuestas incompatibles sin inventar datos', () async {
    responder = (_) async => http.Response(
      jsonEncode([
        {'id_vehiculo': 1},
      ]),
      200,
    );
    await expectLater(api.listar(), throwsA(isA<ApiProtocolException>()));
  });
}
