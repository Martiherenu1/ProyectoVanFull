import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:frontend/core/api/http_api_client.dart';
import 'package:frontend/core/api/api_error.dart';
import 'package:frontend/models/gps/ubicacion_viaje.dart';
import 'package:frontend/services/gps/ubicacion_api.dart';

Map<String, Object?> cuerpo() => {
  'id_viaje': 1,
  'latitud': 1,
  'longitud': 2,
  'fecha_hora_posicion': '2026-11-16T12:00:00Z',
  'fecha_hora_evaluacion': '2026-11-16T12:00:29Z',
  'desactualizada': false,
  'eta_minutos': null,
};
void main() {
  for (final caso in [
    ({'cache-control': 'no-store'}, true),
    ({'cache-control': 'private, no-store'}, true),
    ({'cache-control': 'no-cache'}, false),
    (<String, String>{}, false),
    ({'cache-control': 'no-store', 'age': '1'}, false),
    ({'cache-control': 'no-store', 'age': 'invalido'}, false),
  ]) {
    test(
      'ancla requiere transporte no-store y Age no reutilizado ${caso.$1}',
      () async {
        var llamadas = 0;
        final transport = MockClient((request) async {
          llamadas++;
          expect(request.headers['Authorization'], 'Bearer actual');
          expect(request.headers['Cache-Control'], 'no-cache');
          return http.Response(jsonEncode(cuerpo()), 200, headers: caso.$1);
        });
        final api = UbicacionApi(
          HttpApiClient(
            baseUri: Uri.parse('https://api.test/api'),
            transport: transport,
            accessTokenProvider: () => 'actual',
          ),
        );
        final p = await api.consultar(1);
        expect(p.fechaEvaluacion, DateTime.utc(2026, 11, 16, 12, 0, 29));
        expect(p.sinCache, caso.$2);
        expect(llamadas, 1);
        transport.close();
      },
    );
  }
  for (final valor in [null, 123, 'invalido', '2026-11-16T12:00:29']) {
    test(
      'metadato inválido/ausente no elimina posición ni inventa referencia: $valor',
      () {
        final json = cuerpo()..['fecha_hora_evaluacion'] = valor;
        final p = UbicacionViaje.fromJson(json, 1, sinCache: true);
        expect(p.fechaEvaluacion, isNull);
        expect(p.latitud, 1);
        json.remove('fecha_hora_evaluacion');
        expect(UbicacionViaje.fromJson(json, 1).fechaEvaluacion, isNull);
      },
    );
  }
  test(
    'GET con metadatos conserva 401 de la sesión saliente y no reintenta',
    () async {
      final inicio = Completer<void>();
      final liberar = Completer<void>();
      String token = 'anterior';
      final avisos = <String>[];
      var llamadas = 0;
      final transport = MockClient((request) async {
        llamadas++;
        inicio.complete();
        expect(request.headers['Authorization'], 'Bearer anterior');
        await liberar.future;
        return http.Response(
          '{"error":{"codigo":"NO_AUTENTICADO","mensaje":"Sin acceso"}}',
          401,
        );
      });
      final cliente = HttpApiClient(
        baseUri: Uri.parse('https://api.test/api'),
        transport: transport,
        accessTokenProvider: () => token,
        onNoAutorizado: avisos.add,
      );
      final pendiente = expectLater(
        cliente.getConMetadatos('viajes/1/ubicacion'),
        throwsA(isA<ApiException>()),
      );
      await inicio.future;
      token = 'nueva';
      liberar.complete();
      await pendiente;
      expect(avisos, ['anterior']);
      expect(llamadas, 1);
      transport.close();
    },
  );
}
