import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:frontend/core/api/http_api_client.dart';
import 'package:frontend/services/pasajero/ausencias_api.dart';
import 'package:frontend/screens/pasajero/accion_informar_ausencia.dart';

void main() {
  for (final status in [200, 201]) {
    testWidgets('interfaz confirma HTTP $status sin afirmar nueva creación', (
      t,
    ) async {
      final transport = MockClient(
        (_) async => http.Response(
          '{"id_ausencia":1,"id_pasajero":7,"id_viaje":12}',
          status,
        ),
      );
      addTearDown(transport.close);
      final api = AusenciasApi(
        HttpApiClient(
          baseUri: Uri.parse('https://example.test/api/'),
          transport: transport,
        ),
      );
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AccionInformarAusencia(
              idViaje: 12,
              alcance: Object(),
              contextoVigente: () => true,
              informar: (id) => api.informar(id, accessToken: 'A'),
            ),
          ),
        ),
      );
      await t.tap(find.byKey(const ValueKey('informar-ausencia')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('confirmar-ausencia')));
      await t.pumpAndSettle();
      expect(
        find.text('Tu aviso de ausencia está registrado.'),
        findsOneWidget,
      );
    });
  }
  for (final caso in [
    (500, '{"error":{"codigo":"INTERNO","mensaje":"Error interno"}}'),
    (200, '{}'),
    (201, 'no es JSON'),
  ]) {
    testWidgets(
      'HTTP ${caso.$1} cuerpo ${caso.$2}: incierto y reintento explícito',
      (t) async {
        var envios = 0;
        final transport = MockClient((_) async {
          envios++;
          return envios == 1
              ? http.Response(caso.$2, caso.$1)
              : http.Response(
                  '{"id_ausencia":1,"id_pasajero":7,"id_viaje":12}',
                  200,
                );
        });
        addTearDown(transport.close);
        final api = AusenciasApi(
          HttpApiClient(
            baseUri: Uri.parse('https://example.test/api/'),
            transport: transport,
          ),
        );
        await t.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AccionInformarAusencia(
                idViaje: 12,
                alcance: Object(),
                contextoVigente: () => true,
                informar: (id) => api.informar(id, accessToken: 'A'),
              ),
            ),
          ),
        );
        Future<void> abrir() async {
          await t.tap(find.byKey(const ValueKey('informar-ausencia')));
          await t.pumpAndSettle();
        }

        await abrir();
        await t.tap(find.byKey(const ValueKey('confirmar-ausencia')));
        await t.pumpAndSettle();
        expect(
          find.textContaining(
            'No pudimos confirmar si el aviso quedó registrado',
          ),
          findsOneWidget,
        );
        expect(
          find.text('Tu aviso de ausencia está registrado.'),
          findsNothing,
        );
        await t.pump(const Duration(minutes: 1));
        expect(envios, 1);
        await abrir();
        expect(envios, 1);
        await t.tap(find.byKey(const ValueKey('no-informar-ausencia')));
        await t.pumpAndSettle();
        expect(envios, 1);
        await abrir();
        expect(envios, 1);
        await t.tap(find.byKey(const ValueKey('confirmar-ausencia')));
        await t.pumpAndSettle();
        expect(envios, 2);
        expect(
          find.text('Tu aviso de ausencia está registrado.'),
          findsOneWidget,
        );
      },
    );
  }
}
