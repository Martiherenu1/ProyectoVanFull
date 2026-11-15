import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'ejecucion_autenticada_chofer_test.dart' as base;

class CircuitoAvisos extends base.Escenario {
  Map<String, dynamic>? guardado;
  final reportes = <http.Request>[];
  @override
  Future<http.StreamedResponse> send(http.BaseRequest r) async {
    if (r.url.path.endsWith('/avisos') && r.method == 'POST') {
      final req = r as http.Request;
      reportes.add(req);
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      guardado = {
        'id_viaje': 41,
        'id_evento_operativo': 51,
        'registro': 'confirmado',
        'clave_solicitud': body['clave_solicitud'],
      };
      // Simula respuesta perdida después de persistir, no un servicio externo.
      throw TimeoutException('Respuesta perdida controlada');
    }
    if (r.url.path.endsWith('/avisos/resultado')) {
      expect(
        r.url.queryParameters['clave_solicitud'],
        guardado!['clave_solicitud'],
      );
      return base.Escenario.json(200, guardado!);
    }
    return super.send(r);
  }
}

void main() {
  testWidgets(
    'bootstrap sesión listado detalle reporte incierto y recuperación',
    (t) async {
      final e = CircuitoAvisos()..estado = 'en_curso';
      await e.montar(t);
      await base.ingresar(t);
      await base.detalle(t);
      await t.tap(find.text('Informar demora o problema'));
      await base.paso(t);
      await t.enterText(find.byType(TextField), 'Información interna');
      await t.tap(find.text('Registrar aviso'));
      await base.paso(t);
      expect(find.textContaining('No pudimos confirmar'), findsOneWidget);
      expect(e.reportes.length, 1);
      expect(e.reportes.single.headers['Authorization'], 'Bearer cuenta-1');
      await t.tap(find.text('Consultar resultado'));
      await base.paso(t);
      expect(find.textContaining('Aviso registrado (#51)'), findsOneWidget);
      expect(e.reportes.length, 1);
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump();
    },
  );
}
