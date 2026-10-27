/// Acciones locales explícitas, separadas de comprobar condiciones e iniciar.
/// Ninguna obtiene posiciones ni envía operaciones al backend.
enum ResultadoPermisoUbicacion { concedido, denegado, denegadoPermanentemente }

class AsistenciaUbicacionInicio {
  const AsistenciaUbicacionInicio({
    required this.solicitarPermiso,
    required this.abrirAjustesApp,
    required this.abrirAjustesUbicacion,
  });

  final Future<ResultadoPermisoUbicacion> Function() solicitarPermiso;
  final Future<bool> Function() abrirAjustesApp;
  final Future<bool> Function() abrirAjustesUbicacion;
}
