/// Respuesta sintética con la estructura de schemas/chofer.py y OpenAPI.
/// La nómina es solo un mock; no acredita el caso manual C12.
Map<String, dynamic> detalleJson({int id = 41}) => {
  'viaje': <String, dynamic>{
    'id_viaje': id,
    'id_servicio': 2,
    'id_recorrido': 3,
    'id_vehiculo': 4,
    'id_chofer': 5,
    'fecha': '2026-10-30',
    'horario': '07:30',
    'sentido': 'IDA',
    'estado': 'en_curso',
  },
  'capacidad_planificada': 18,
  'paradas': [
    {
      'id_parada': 11,
      'orden': 1,
      'nombre_descripcion': 'Primera parada',
      'direccion': 'Dirección pública de parada',
      'latitud': -34,
      'longitud': -58.5,
      'comprometida': true,
    },
    {'id_parada': 12, 'orden': 2, 'comprometida': false},
  ],
  'pasajeros_con_reserva': [
    {
      'id_reserva': 61,
      'id_pasajero': 21,
      'id_viaje': id,
      'orden_parada': 1,
      'estado': 'consolidada',
      'nombre': 'Ana',
      'apellido': 'Prueba',
      'dni': '90000011',
      'fotografia': null,
      'abordaje_registrado': true,
    },
    {
      'id_reserva': 62,
      'id_pasajero': 22,
      'id_viaje': id,
      'orden_parada': 2,
      'estado': 'provisional',
      'nombre': 'Bruno',
      'apellido': 'Prueba',
      'dni': '90000012',
      'fotografia': 'foto-referenciada',
      'abordaje_registrado': false,
    },
  ],
  'integrantes_nomina': [
    {
      'id_integrante_nomina': 71,
      'nombre': 'Invitada',
      'apellido': 'Nómina',
      'dni': '90000014',
    },
  ],
  'cantidades': {
    'consolidadas': 1,
    'provisionales': 1,
    'total_reservas': 2,
    'total_nomina': 1,
    'abordajes_registrados': 1,
  },
};
