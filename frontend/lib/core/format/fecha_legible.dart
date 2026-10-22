/// dd/mm/aaaa, el formato con que se muestran las fechas al pasajero.
String fechaLegible(DateTime fecha) =>
    '${fecha.day.toString().padLeft(2, '0')}/'
    '${fecha.month.toString().padLeft(2, '0')}/'
    '${fecha.year.toString().padLeft(4, '0')}';
