import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api/api_error.dart';
import '../../models/gps/ubicacion_viaje.dart';

class UbicacionScreen extends StatefulWidget {
  const UbicacionScreen({
    required this.idViaje,
    required this.consultar,
    super.key,
  });
  final int idViaje;
  final Future<UbicacionViaje> Function(int) consultar;
  @override
  State<UbicacionScreen> createState() => _UbicacionScreenState();
}

class _UbicacionScreenState extends State<UbicacionScreen> {
  Timer? _timer;
  UbicacionViaje? _posicion;
  bool _cargando = false, _bloqueada = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _consultar();
    // Polling contratado, sin solicitudes simultáneas.
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _consultar());
  }

  Future<void> _consultar() async {
    if (_cargando || _bloqueada || !mounted) return;
    _cargando = true;
    try {
      final p = await widget.consultar(widget.idViaje);
      if (mounted) {
        setState(() {
          _posicion = p;
          _error = null;
        });
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        if (e.statusCode == 404 && e.codigo == 'UBICACION_NO_DISPONIBLE') {
          _posicion = null;
          _error = 'Todavía no hay una posición disponible.';
        } else if ([401, 403, 404].contains(e.statusCode)) {
          _posicion = null;
          _bloqueada = true;
          _timer?.cancel();
          _error = 'Ubicación no disponible para esta sesión o viaje.';
        } else {
          _error = 'Consulta interrumpida. Última posición recibida; no es ubicación actual.';
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Sin actualización de ubicación. Revisá la conexión.';
        });
      }
    } finally {
      _cargando = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ubicación del viaje')),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_error != null) Text(_error!),
          if (_posicion case final p?) ...[
            Text('Última posición: ${p.latitud}, ${p.longitud}'),
            Text('Fecha informada: ${p.fecha.toLocal()}'),
            Text(
              p.desactualizada || _error != null
                  ? 'Información desactualizada / sin actualización confirmada.'
                  : 'No marcada desactualizada en la última consulta.',
            ),
            const Text('La antigüedad real de captura no está verificada.'),
            Text(
              p.etaMinutos == null
                  ? 'ETA no disponible.'
                  : 'ETA informado por el servidor: ${p.etaMinutos} min.',
            ),
            const Text('Mapa no disponible.'),
          ] else if (_error == null)
            const Text('Consultando ubicación…'),
          OutlinedButton(
            onPressed: _bloqueada ? null : _consultar,
            child: const Text('Actualizar ubicación'),
          ),
        ],
      ),
    ),
  );
}
