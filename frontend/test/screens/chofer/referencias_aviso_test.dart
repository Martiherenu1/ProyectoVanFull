import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:frontend/screens/chofer/detalle_viaje_chofer_screen.dart';
import 'package:frontend/screens/chofer/recuperar_aviso.dart';
import 'package:frontend/screens/chofer/reporte_aviso.dart';

import 'avisos_integracion_test.dart' as avisos;
import 'ejecucion_autenticada_chofer_test.dart' as base;

const clave = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const otra = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const referencias = [
  ReferenciaAviso(41, clave),
  ReferenciaAviso(41, otra),
  ReferenciaAviso(52, clave),
];

// Referencias de resultados inciertos inyectadas por la interfaz del detalle.
// No fabrica pérdidas de respuesta ni ejecuta escrituras sobre un servicio real.
Future<void> preparar(WidgetTester t) async {
  await base.detalle(t);
  await t.pumpAndSettle();
  final detalle = t.widget<DetalleViajeChoferScreen>(
    find.byType(DetalleViajeChoferScreen),
  );
  for (final referencia in referencias) {
    detalle.onAvisoIncierto!(referencia);
  }
  detalle.onAvisoIncierto!(ReferenciaAviso(41, '  ${clave.toUpperCase()}  '));
  await base.volver(t);
  await t.tap(find.text('Resultado propio'));
  await t.pumpAndSettle();
  expect(pendientes(t), ['41/$clave', '41/$otra', '52/$clave']);
}

Future<void> consultar(WidgetTester t) async {
  await t.enterText(find.byType(TextField).at(0), '41');
  await t.enterText(find.byType(TextField).at(1), '  ${clave.toUpperCase()}  ');
  await t.ensureVisible(find.text('Consultar resultado'));
  await t.tap(find.text('Consultar resultado'));
  await base.paso(t);
}

List<String> pendientes(WidgetTester t) => t
    .widget<RecuperarAvisoScreen>(find.byType(RecuperarAvisoScreen))
    .referencias
    .map((r) => '${r.viaje}/${r.clave}')
    .toList();

void main() {
  test('referencia expone una clave canónica sin alterar el viaje', () {
    expect(ReferenciaAviso(41, '  ${clave.toUpperCase()}  ').clave, clave);
    expect(ReferenciaAviso(52, clave).viaje, 52);
  });

  testWidgets('UUID mayúscula confirmada retira solo su referencia incierta', (
    t,
  ) async {
    final e = avisos.CircuitoAvisos()..estado = 'en_curso';
    e.guardado = {
      'id_viaje': 41,
      'id_evento_operativo': 51,
      'registro': 'confirmado',
      'clave_solicitud': clave,
    };
    // El servidor interpreta la UUID y devuelve su representación canónica.
    e.consultaPendiente = Completer()
      ..complete(base.Escenario.json(200, e.guardado!));
    await e.montar(t);
    await base.ingresar(t);
    await preparar(t);
    await consultar(t);
    expect(find.text('Aviso registrado (#51).'), findsOneWidget);
    expect(pendientes(t), ['41/$otra', '52/$clave']);
    expect(e.consultas.single.url.queryParameters['clave_solicitud'], clave);
    expect(e.reportes, isEmpty);
    await t.pumpWidget(const SizedBox.shrink());
  });

  for (final fallo in [
    '400',
    '404',
    '500',
    'timeout',
    'otra_clave',
    'otro_viaje',
    'incierto',
  ]) {
    testWidgets('recuperación $fallo conserva todas las referencias', (
      t,
    ) async {
      final e = avisos.CircuitoAvisos()..estado = 'en_curso';
      await e.montar(t);
      await base.ingresar(t);
      await preparar(t);
      if (fallo == 'timeout') {
        e.fallarConsultas = true;
      } else if (int.tryParse(fallo) != null) {
        e.statusConsulta = int.parse(fallo);
      } else {
        e.consultaPendiente = Completer()
          ..complete(
            base.Escenario.json(200, {
              'id_viaje': fallo == 'otro_viaje' ? 52 : 41,
              'id_evento_operativo': 51,
              'registro': fallo == 'incierto' ? 'incierto' : 'confirmado',
              'clave_solicitud': fallo == 'otra_clave' ? otra : clave,
            }),
          );
      }
      await consultar(t);
      expect(find.textContaining('Resultado no disponible.'), findsOneWidget);
      expect(pendientes(t), ['41/$clave', '41/$otra', '52/$clave']);
      expect(find.text('Aviso registrado (#51).'), findsNothing);
      expect(e.reportes, isEmpty);
      await t.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets(
    'UUID inválida rechazada no retira referencia ni se transforma en válida',
    (t) async {
      final e = avisos.CircuitoAvisos()..estado = 'en_curso';
      await e.montar(t);
      await base.ingresar(t);
      await preparar(t);
      e.statusConsulta = 400;
      await t.enterText(find.byType(TextField).at(0), '41');
      await t.enterText(find.byType(TextField).at(1), '  NO-ES-UUID  ');
      await t.ensureVisible(find.text('Consultar resultado'));
      await t.tap(find.text('Consultar resultado'));
      await base.paso(t);
      expect(
        e.consultas.single.url.queryParameters['clave_solicitud'],
        'no-es-uuid',
      );
      expect(pendientes(t), ['41/$clave', '41/$otra', '52/$clave']);
      expect(find.textContaining('Resultado no disponible.'), findsOneWidget);
      await t.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final falla in [false, true]) {
    testWidgets(
      'respuesta tardía falla=$falla no retira referencias de otra sesión',
      (t) async {
        final e = avisos.CircuitoAvisos()..estado = 'en_curso';
        await e.montar(t);
        await base.ingresar(t);
        await preparar(t);
        final respuesta = Completer<http.StreamedResponse>();
        e.consultaPendiente = respuesta;
        await consultar(t);
        await base.nuevaCuenta(t);
        await preparar(t);
        if (falla) {
          respuesta.completeError(TimeoutException('Controlado'));
        } else {
          respuesta.complete(
            base.Escenario.json(200, {
              'id_viaje': 41,
              'id_evento_operativo': 51,
              'registro': 'confirmado',
              'clave_solicitud': clave,
            }),
          );
        }
        await base.paso(t);
        expect(pendientes(t), ['41/$clave', '41/$otra', '52/$clave']);
        expect(find.text('Aviso registrado (#51).'), findsNothing);
        expect(find.textContaining('Resultado no disponible.'), findsNothing);
        expect(e.consultas.length, 1);
        expect(e.reportes, isEmpty);
        await t.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
