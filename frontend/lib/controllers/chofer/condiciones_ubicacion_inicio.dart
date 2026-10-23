/// Control local del telefono. No representa permisos de negocio ni un POST.
/// No contiene posicion, precision, señal ni condiciones temporales.
class CondicionesUbicacionInicio {
  const CondicionesUbicacionInicio({
    required this.servicioActivado,
    required this.permisoConcedido,
  });

  final bool servicioActivado;

  /// Incluye permiso aproximado: no se exige ubicacion precisa.
  final bool permisoConcedido;
}

typedef ComprobarUbicacionInicio =
    Future<CondicionesUbicacionInicio> Function();

enum BloqueoUbicacionInicio {
  servicioDesactivado,
  permisoNoConcedido,
  sinComprobador,
  consultaFallida,
}
