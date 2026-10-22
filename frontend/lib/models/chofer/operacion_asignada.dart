import 'viaje_resumen.dart';

/// Lectura de GET /choferes/me/viajes/{id_viaje} (CU-029).
/// Conserva listas y cantidades del servidor; no calcula cupos ni ocupación.
class OperacionAsignada {
  OperacionAsignada({
    required this.viaje,
    required this.capacidadPlanificada,
    required List<ParadaOperacion> paradas,
    required List<PasajeroOperacion> pasajerosConReserva,
    required List<IntegranteNominaOperacion> integrantesNomina,
    required this.cantidades,
  }) : paradas = List.unmodifiable(paradas),
       pasajerosConReserva = List.unmodifiable(pasajerosConReserva),
       integrantesNomina = List.unmodifiable(integrantesNomina);

  factory OperacionAsignada.fromJson(Map<String, dynamic> json) =>
      OperacionAsignada(
        viaje: ViajeResumen.fromJson(json['viaje'] as Map<String, dynamic>),
        capacidadPlanificada: _nullableRequerido<int>(
          json,
          'capacidad_planificada',
        ),
        paradas: (json['paradas'] as List<dynamic>)
            .map((p) => ParadaOperacion.fromJson(p as Map<String, dynamic>))
            .toList(),
        pasajerosConReserva: (json['pasajeros_con_reserva'] as List<dynamic>)
            .map((p) => PasajeroOperacion.fromJson(p as Map<String, dynamic>))
            .toList(),
        integrantesNomina: (json['integrantes_nomina'] as List<dynamic>)
            .map(
              (p) =>
                  IntegranteNominaOperacion.fromJson(p as Map<String, dynamic>),
            )
            .toList(),
        cantidades: CantidadesOperacion.fromJson(
          json['cantidades'] as Map<String, dynamic>,
        ),
      );

  final ViajeResumen viaje;
  final int? capacidadPlanificada;
  final List<ParadaOperacion> paradas;
  final List<PasajeroOperacion> pasajerosConReserva;
  final List<IntegranteNominaOperacion> integrantesNomina;
  final CantidadesOperacion cantidades;
}

class ParadaOperacion {
  const ParadaOperacion({
    required this.idParada,
    required this.orden,
    required this.comprometida,
    this.nombreDescripcion,
    this.direccion,
    this.latitud,
    this.longitud,
  });

  factory ParadaOperacion.fromJson(Map<String, dynamic> json) =>
      ParadaOperacion(
        idParada: json['id_parada'] as int,
        orden: json['orden'] as int,
        comprometida: json['comprometida'] as bool,
        nombreDescripcion: json['nombre_descripcion'] as String?,
        direccion: json['direccion'] as String?,
        latitud: (json['latitud'] as num?)?.toDouble(),
        longitud: (json['longitud'] as num?)?.toDouble(),
      );

  final int idParada;
  final int orden;
  final bool comprometida;
  final String? nombreDescripcion;
  // Dirección de la parada pública, nunca un domicilio personal.
  final String? direccion;
  final double? latitud;
  final double? longitud;
}

enum EstadoReservaOperacion {
  provisional('provisional', 'Provisional'),
  consolidada('consolidada', 'Consolidada');

  const EstadoReservaOperacion(this.valorApi, this.etiqueta);
  final String valorApi;
  final String etiqueta;
}

/// Lista explícita de datos permitidos por RN-029. No conserva el JSON original.
class PasajeroOperacion {
  const PasajeroOperacion({
    required this.idReserva,
    required this.idPasajero,
    required this.idViaje,
    required this.ordenParada,
    required this.estado,
    required this.nombre,
    required this.apellido,
    required this.dni,
    required this.fotografia,
    required this.abordajeRegistrado,
  });

  factory PasajeroOperacion.fromJson(Map<String, dynamic> json) =>
      PasajeroOperacion(
        idReserva: json['id_reserva'] as int,
        idPasajero: json['id_pasajero'] as int,
        idViaje: json['id_viaje'] as int,
        ordenParada: json['orden_parada'] as int,
        estado: EstadoReservaOperacion.values.firstWhere(
          (e) => e.valorApi == json['estado'],
          orElse: () =>
              throw const FormatException('Estado de reserva inválido'),
        ),
        nombre: json['nombre'] as String,
        apellido: json['apellido'] as String,
        dni: json['dni'] as String,
        fotografia: _nullableRequerido<String>(json, 'fotografia'),
        abordajeRegistrado: json['abordaje_registrado'] as bool,
      );

  final int idReserva;
  final int idPasajero;
  final int idViaje;
  final int ordenParada;
  final EstadoReservaOperacion estado;
  final String nombre;
  final String apellido;
  final String dni;

  /// Referencia existente, no necesariamente una URL descargable.
  final String? fotografia;
  final bool abordajeRegistrado;
}

/// La nómina no tiene fotografía, reserva ni registro de abordaje en el contrato.
class IntegranteNominaOperacion {
  const IntegranteNominaOperacion({
    required this.idIntegranteNomina,
    required this.nombre,
    required this.apellido,
    required this.dni,
  });

  factory IntegranteNominaOperacion.fromJson(Map<String, dynamic> json) =>
      IntegranteNominaOperacion(
        idIntegranteNomina: json['id_integrante_nomina'] as int,
        nombre: json['nombre'] as String,
        apellido: json['apellido'] as String,
        dni: json['dni'] as String,
      );

  final int idIntegranteNomina;
  final String nombre;
  final String apellido;
  final String dni;
}

class CantidadesOperacion {
  const CantidadesOperacion({
    required this.consolidadas,
    required this.provisionales,
    required this.totalReservas,
    required this.totalNomina,
    required this.abordajesRegistrados,
  });

  factory CantidadesOperacion.fromJson(Map<String, dynamic> json) =>
      CantidadesOperacion(
        consolidadas: json['consolidadas'] as int,
        provisionales: json['provisionales'] as int,
        totalReservas: json['total_reservas'] as int,
        totalNomina: json['total_nomina'] as int,
        abordajesRegistrados: json['abordajes_registrados'] as int,
      );

  final int consolidadas;
  final int provisionales;
  final int totalReservas;
  final int totalNomina;
  final int abordajesRegistrados;
}

T? _nullableRequerido<T>(Map<String, dynamic> json, String campo) {
  if (!json.containsKey(campo)) throw FormatException('Falta $campo');
  return json[campo] as T?;
}
