/// Error informado por FastAPI con la forma definida en OpenAPI.
final class ApiException implements Exception {
  const ApiException({
    required this.statusCode,
    required this.codigo,
    required this.mensaje,
    this.detalles,
  });

  final int statusCode;
  final String codigo;
  final String mensaje;
  final Map<String, dynamic>? detalles;

  @override
  String toString() => 'ApiException($statusCode, $codigo): $mensaje';
}

/// La respuesta HTTP no respetó la representación JSON esperada.
final class ApiProtocolException implements Exception {
  const ApiProtocolException(this.statusCode, this.mensaje);

  final int statusCode;
  final String mensaje;

  @override
  String toString() => 'ApiProtocolException($statusCode): $mensaje';
}
