/// dd/mm/aaaa, el formato con que se muestran las fechas al pasajero.
String fechaLegible(DateTime fecha) =>
    '${fecha.day.toString().padLeft(2, '0')}/'
    '${fecha.month.toString().padLeft(2, '0')}/'
    '${fecha.year.toString().padLeft(4, '0')}';

/// dd/mm/aaaa HH:MM en la hora del dispositivo, para instantes que el backend
/// informa con zona (`date-time`).
String fechaHoraLegible(DateTime instante) {
  final local = instante.toLocal();
  return '${fechaLegible(local)} '
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}
