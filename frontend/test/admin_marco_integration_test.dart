import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';
import 'package:frontend/screens/admin/abonos_admin_screen.dart';
import 'package:frontend/screens/admin/administradores_admin_screen.dart';
import 'package:frontend/screens/admin/choferes_admin_screen.dart';
import 'package:frontend/screens/admin/consultar_deuda_admin_screen.dart';
import 'package:frontend/screens/admin/consultar_reservas_admin_screen.dart';
import 'package:frontend/screens/admin/historial_viajes_screen.dart';
import 'package:frontend/screens/admin/pagos_pendientes_screen.dart';
import 'package:frontend/screens/admin/recorridos_admin_screen.dart';
import 'package:frontend/screens/admin/registrar_pago_admin_screen.dart';
import 'package:frontend/screens/admin/tarifas_admin_screen.dart';
import 'package:frontend/screens/admin/vehiculos_admin_screen.dart';
import 'package:frontend/screens/admin/viajes_dia_admin_screen.dart';
import 'package:frontend/screens/gps/ubicacion_screen.dart';
import 'package:frontend/widgets/admin/marco_admin.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'admin_menu_helpers.dart';
import 'services/admin/viajes_dia_admin_api_test.dart' as datos;

void main() {
  testWidgets('cerrar el detalle descarta una carga tardía de descensos', (
    t,
  ) async {
    await t.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => t.binding.setSurfaceSize(null));
    final descensos = Completer<http.Response>();
    var consultasDescensos = 0;
    final transporte = MockClient((r) async {
      final ruta = r.url.path;
      if (ruta.endsWith('/auth/login')) {
        return http.Response(
          '{"access_token":"token","token_type":"bearer","roles":["administrador"]}',
          200,
        );
      }
      if (ruta.endsWith('/viajes')) {
        return http.Response(jsonEncode([datos.viaje(41)]), 200);
      }
      if (ruta.endsWith('/recorridos/3/paradas')) {
        return http.Response('[]', 200);
      }
      if (ruta.endsWith('/viajes/41/descensos')) {
        consultasDescensos++;
        return descensos.future;
      }
      return http.Response('[]', 200);
    });
    await t.pumpWidget(
      VanFullBootstrap(
        apiBaseUrl: 'https://vanfull.test/api/',
        crearTransporte: () => transporte,
      ),
    );
    await t.enterText(find.byType(TextField).at(0), 'admin@vanfull.test');
    await t.enterText(find.byType(TextField).at(1), 'sintetica');
    await t.tap(find.text('Ingresar'));
    await t.pumpAndSettle();
    await t.tap(find.text('41'));
    await t.pumpAndSettle();
    await t.tap(find.text('Configurar descensos'));
    await t.pump();
    expect(consultasDescensos, 1);
    await t.tap(find.text('Cerrar'));
    await t.pumpAndSettle();
    await tocarMenuAdmin(t, DestinoAdmin.reservas.clave);
    await t.pumpAndSettle();
    expect(find.byType(ConsultarReservasAdminScreen), findsOneWidget);

    descensos.complete(http.Response('{"ordenes":[]}', 200));
    await t.pumpAndSettle();

    expect(find.text('Descensos habilitados'), findsNothing);
    expect(find.byType(ConsultarReservasAdminScreen), findsOneWidget);
    await tocarMenuAdmin(t, DestinoAdmin.viajes.clave);
    await t.pumpAndSettle();
    await t.tap(find.text('41'));
    await t.pumpAndSettle();
    await t.tap(find.text('Configurar descensos'));
    await t.pumpAndSettle();
    expect(consultasDescensos, 2);
    expect(find.text('Descensos habilitados'), findsOneWidget);
  });

  const pantallas = {
    DestinoAdmin.viajes: ViajesDiaAdminScreen,
    DestinoAdmin.historial: HistorialViajesScreen,
    DestinoAdmin.reservas: ConsultarReservasAdminScreen,
    DestinoAdmin.recorridos: RecorridosAdminScreen,
    DestinoAdmin.vehiculos: VehiculosAdminScreen,
    DestinoAdmin.choferes: ChoferesAdminScreen,
    DestinoAdmin.abonos: AbonosAdminScreen,
    DestinoAdmin.tarifas: TarifasAdminScreen,
    DestinoAdmin.registrarPago: RegistrarPagoAdminScreen,
    DestinoAdmin.pagosPendientes: PagosPendientesScreen,
    DestinoAdmin.deuda: ConsultarDeudaAdminScreen,
    DestinoAdmin.administradores: AdministradoresAdminScreen,
  };
  for (final ancho in [390.0, 1440.0]) {
    for (final rol in ['administrador', 'dueno']) {
      testWidgets('$rol: módulos, detalle y retorno a $ancho px', (t) async {
        await t.binding.setSurfaceSize(Size(ancho, 900));
        addTearDown(() => t.binding.setSurfaceSize(null));
        final peticiones = <String>[];
        final transporte = MockClient((r) async {
          if (r.url.path.endsWith('/auth/login')) {
            return http.Response(
              jsonEncode({
                'access_token': 'token-$rol',
                'token_type': 'bearer',
                'roles': [rol],
              }),
              200,
            );
          }
          expect(r.headers['authorization'], 'Bearer token-$rol');
          peticiones.add('${r.method} ${r.url.path}');
          if (r.url.path.endsWith('/auth/logout')) {
            return http.Response('', 204);
          }
          if (r.url.path.endsWith('/viajes')) {
            return http.Response(jsonEncode([datos.viaje(41)]), 200);
          }
          if (r.url.path.endsWith('/historial-viajes')) {
            return http.Response('{"items":[]}', 200);
          }
          return http.Response('[]', 200);
        });
        await t.pumpWidget(
          VanFullBootstrap(
            apiBaseUrl: 'https://vanfull.test/api/',
            crearTransporte: () => transporte,
          ),
        );
        await t.enterText(find.byType(TextField).at(0), 'p1@vanfull.test');
        await t.enterText(find.byType(TextField).at(1), 'sintetica');
        await t.tap(find.text('Ingresar'));
        await t.pumpAndSettle();

        Future<void> ir(DestinoAdmin destino) async {
          await tocarMenuAdmin(t, destino.clave);
          await t.pumpAndSettle();
          expect(t.widget<MarcoAdmin>(find.byType(MarcoAdmin)).activo, destino);
          expect(find.byType(pantallas[destino]!), findsOneWidget);
          expect(t.takeException(), isNull);
        }

        await abrirMenuAdmin(t);
        for (final exclusivo in [
          DestinoAdmin.tarifas,
          DestinoAdmin.administradores,
        ]) {
          expect(
            find.byKey(exclusivo.clave),
            rol == 'dueno' ? findsOneWidget : findsNothing,
          );
        }
        if (ancho < 1024) {
          expect(await t.binding.handlePopRoute(), isTrue);
          await t.pumpAndSettle();
          expect(find.byKey(DestinoAdmin.viajes.clave), findsNothing);
        }
        final viaje = ancho < 1024
            ? find.byKey(const ValueKey('viaje-41'))
            : find.text('41');
        await t.tap(viaje);
        await t.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        await t.tap(find.text('Cerrar'));
        await t.pumpAndSettle();
        // La selección también abre la consulta de ubicación bajo el diálogo.
        expect(find.byType(UbicacionScreen), findsOneWidget);
        expect(viaje, findsNothing);
        await t.pageBack();
        await t.pumpAndSettle();
        expect(viaje, findsOneWidget);
        for (final destino in DestinoAdmin.values.where(
          (d) =>
              d != DestinoAdmin.viajes &&
              (rol == 'dueno' ||
                  ![
                    DestinoAdmin.tarifas,
                    DestinoAdmin.administradores,
                  ].contains(d)),
        )) {
          await ir(destino);
        }
        await ir(DestinoAdmin.viajes);
        await t.tap(find.byKey(const Key('admin-crear-viaje')));
        await t.pumpAndSettle();
        expect(find.byKey(const Key('id-servicio')), findsOneWidget);
        await t.pageBack();
        await t.pumpAndSettle();
        expect(viaje, findsOneWidget);
        await tocarMenuAdmin(t, const Key('admin-salir'));
        await t.pumpAndSettle();
        expect(find.text('Ingresar'), findsOneWidget);
        expect(
          peticiones.where(
            (p) => !p.startsWith('GET ') && !p.endsWith('/auth/logout'),
          ),
          isEmpty,
        );
        expect(t.takeException(), isNull);
      });
    }
  }
}
