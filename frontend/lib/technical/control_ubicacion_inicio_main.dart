import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';

import '../adapters/chofer/comprobador_ubicacion_android.dart';
import '../controllers/chofer/ejecucion_viaje_controller.dart';
import '../models/chofer/operacion_asignada.dart';
import '../models/chofer/viaje_resumen.dart';
import '../screens/chofer/detalle_viaje_chofer_screen.dart';

void main() => runApp(crearAppControlUbicacionInicio());

Widget crearAppControlUbicacionInicio() {
  // Aislar tambien las fuentes remotas del tema compartido: sin HTTP en el ensayo.
  // Si no hay fuentes locales se usan las alternativas del sistema.
  GoogleFonts.config.allowRuntimeFetching = false;
  return const MaterialApp(home: ControlUbicacionInicioTecnico());
}

/// Ubicacion del telefono real; viaje, detalle y operaciones solo en memoria.
class ControlUbicacionInicioTecnico extends StatefulWidget {
  const ControlUbicacionInicioTecnico({this.comprobador, super.key});

  final ComprobadorUbicacionAndroid? comprobador;

  @override
  State<ControlUbicacionInicioTecnico> createState() =>
      _ControlUbicacionInicioTecnicoState();
}

class _ControlUbicacionInicioTecnicoState
    extends State<ControlUbicacionInicioTecnico> {
  late final _comprobador = widget.comprobador ?? ComprobadorUbicacionAndroid();
  late final _acciones = AccionesEjecucionViaje(
    iniciar: _iniciarSimulado,
    finalizar: _finalizarSimulado,
  );
  int _idSimulado = 1;
  int _iniciosInvocados = 0;
  EstadoViaje _estado = EstadoViaje.programado;

  ViajeResumen _viaje() => ViajeResumen(
    idViaje: _idSimulado,
    idServicio: 1,
    idRecorrido: 1,
    idVehiculo: 1,
    idChofer: 1,
    fecha: DateTime.utc(2026, 10, 30),
    sentido: SentidoViaje.ida,
    estado: _estado,
  );

  Future<OperacionAsignada?> _cargarSimulado(int id) async {
    if (id != _idSimulado) return null;
    return OperacionAsignada(
      viaje: _viaje(),
      capacidadPlanificada: 1,
      paradas: const [],
      pasajerosConReserva: const [],
      integrantesNomina: const [],
      cantidades: const CantidadesOperacion(
        consolidadas: 0,
        provisionales: 0,
        totalReservas: 0,
        totalNomina: 0,
        abordajesRegistrados: 0,
      ),
    );
  }

  Future<ViajeResumen> _iniciarSimulado(int id) async {
    if (id != _idSimulado) throw StateError('Escenario simulado sustituido');
    setState(() {
      _iniciosInvocados++;
      _estado = EstadoViaje.enCurso;
    });
    return _viaje();
  }

  Future<ViajeResumen> _finalizarSimulado(int id) async {
    if (id != _idSimulado) throw StateError('Escenario simulado sustituido');
    setState(() => _estado = EstadoViaje.finalizado);
    return _viaje();
  }

  Future<void> _abrirAjustes({required bool ubicacion}) async {
    try {
      final abierto = ubicacion
          ? await Geolocator.openLocationSettings()
          : await Geolocator.openAppSettings();
      if (!abierto) throw StateError('Ajustes no disponibles');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo abrir Ajustes. Abrilos manualmente.'),
          ),
        );
      }
    }
    // Volver de Ajustes no comprueba ni inicia: requiere pulsar Iniciar viaje.
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Operaciones simuladas: sin backend',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Text('Invocaciones simuladas de inicio: $_iniciosInvocados'),
          const Text(
            'Solo consulta permiso y servicio. Sin captura GPS ni datos reales.',
          ),
          Wrap(
            alignment: WrapAlignment.center,
            children: [
              TextButton(
                onPressed: () => _abrirAjustes(ubicacion: false),
                child: const Text('Ajustes de la app: permiso de ubicación'),
              ),
              TextButton(
                onPressed: () => _abrirAjustes(ubicacion: true),
                child: const Text('Ajustes de ubicación'),
              ),
              TextButton(
                onPressed: () => setState(() {
                  _idSimulado++;
                  _estado = EstadoViaje.programado;
                }),
                child: const Text('Nuevo viaje simulado'),
              ),
            ],
          ),
          const Text(
            'Contador acumulado en memoria. Los IDs y fechas son ficticios.',
          ),
          Expanded(
            child: DetalleViajeChoferScreen(
              idViaje: _idSimulado,
              cargarDetalle: _cargarSimulado,
              acciones: _acciones,
              comprobarUbicacionInicio: _comprobador.comprobar,
            ),
          ),
        ],
      ),
    ),
  );
}
