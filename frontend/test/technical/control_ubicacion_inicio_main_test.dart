import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:frontend/technical/control_ubicacion_inicio_main.dart'
    as ensayo;

import '../fixtures/chofer/plataforma_ubicacion_fake.dart';

void main() {
  late GeolocatorPlatform anterior;
  late bool descargaFuentesAnterior;
  late PlataformaUbicacionFake plataforma;
  setUp(() {
    anterior = GeolocatorPlatform.instance;
    descargaFuentesAnterior = GoogleFonts.config.allowRuntimeFetching;
    plataforma = PlataformaUbicacionFake();
    GeolocatorPlatform.instance = plataforma;
  });
  tearDown(() {
    GeolocatorPlatform.instance = anterior;
    GoogleFonts.config.allowRuntimeFetching = descargaFuentesAnterior;
  });

  Future<void> abrir(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ensayo.ControlUbicacionInicioTecnico()),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'operaciones simuladas: bloqueo no invoca inicio; habilitado si',
    (tester) async {
      plataforma.permiso = LocationPermission.denied;
      await abrir(tester);
      expect(find.text('Operaciones simuladas: sin backend'), findsOneWidget);
      expect(plataforma.llamadas, isEmpty);
      await tester.tap(find.text('Iniciar viaje'));
      await tester.pumpAndSettle();
      expect(find.text('Invocaciones simuladas de inicio: 0'), findsOneWidget);
      expect(
        find.text(
          'Permití que VanFull acceda a tu ubicación para iniciar el viaje.',
        ),
        findsOneWidget,
      );
      plataforma.permiso = LocationPermission.whileInUse;
      await tester.tap(find.text('Iniciar viaje'));
      await tester.pumpAndSettle();
      expect(find.text('Invocaciones simuladas de inicio: 1'), findsOneWidget);
      expect(find.text('Finalizar viaje'), findsOneWidget);
      expect(plataforma.llamadas, [
        'servicio',
        'permiso',
        'servicio',
        'permiso',
      ]);
    },
  );

  testWidgets('Ajustes solo explicitos; volver no consulta ni inicia', (
    tester,
  ) async {
    await abrir(tester);
    await tester.tap(find.text('Ajustes de la app: permiso de ubicación'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ajustes de ubicación'));
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(plataforma.llamadas, ['ajustesApp', 'ajustesUbicacion']);
    expect(find.text('Invocaciones simuladas de inicio: 0'), findsOneWidget);
    expect(find.text('Iniciar viaje'), findsOneWidget);
  });

  testWidgets('fallo al abrir Ajustes orienta sin iniciar', (tester) async {
    plataforma.ajustesAbiertos = false;
    await abrir(tester);
    await tester.tap(find.text('Ajustes de ubicación'));
    await tester.pump();
    expect(
      find.text('No se pudo abrir Ajustes. Abrilos manualmente.'),
      findsOneWidget,
    );
    expect(find.text('Invocaciones simuladas de inicio: 0'), findsOneWidget);
    expect(plataforma.llamadas, ['ajustesUbicacion']);
  });

  testWidgets(
    'finalizar simulado no consulta ubicacion y permite otro escenario',
    (tester) async {
      await abrir(tester);
      await tester.tap(find.text('Iniciar viaje'));
      await tester.pumpAndSettle();
      plataforma.servicio = false;
      plataforma.permiso = LocationPermission.denied;
      await tester.tap(find.text('Finalizar viaje'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(ElevatedButton, 'Finalizar viaje').last,
      );
      await tester.pumpAndSettle();
      expect(find.text('Invocaciones simuladas de inicio: 1'), findsOneWidget);
      expect(plataforma.llamadas, ['servicio', 'permiso']);
      await tester.tap(find.text('Nuevo viaje simulado'));
      await tester.pumpAndSettle();
      expect(find.text('Iniciar viaje'), findsOneWidget);
      expect(find.text('Invocaciones simuladas de inicio: 1'), findsOneWidget);
    },
  );

  testWidgets(
    'entrada tecnica deshabilita fuentes HTTP sin iniciar consultas',
    (tester) async {
      GoogleFonts.config.allowRuntimeFetching = true;
      await tester.pumpWidget(ensayo.crearAppControlUbicacionInicio());
      await tester.pumpAndSettle();
      expect(GoogleFonts.config.allowRuntimeFetching, isFalse);
      expect(find.text('Operaciones simuladas: sin backend'), findsOneWidget);
      expect(find.text('Invocaciones simuladas de inicio: 0'), findsOneWidget);
      expect(plataforma.llamadas, isEmpty);
    },
  );
}
