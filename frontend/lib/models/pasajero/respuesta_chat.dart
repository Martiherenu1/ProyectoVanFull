/// Lectura de ChatResponse en POST /chat (CU-011). Lo que el asistente dice y
/// si derivó a una persona lo decide el backend; acá solo se muestra.
class RespuestaChat {
  const RespuestaChat({
    required this.respuesta,
    required this.conversacionId,
    this.derivarHumano = false,
    this.toolUsada,
  });

  factory RespuestaChat.fromJson(Map<String, dynamic> json) => RespuestaChat(
    respuesta: json['respuesta'] as String,
    conversacionId: json['conversacion_id'] as String,
    derivarHumano: json['derivar_humano'] as bool? ?? false,
    toolUsada: json['tool_usada'] as String?,
  );

  final String respuesta;

  /// Se manda de vuelta en el mensaje siguiente para seguir la conversación.
  final String conversacionId;

  /// RF-032: el asistente escaló la conversación a una persona de VanFull.
  final bool derivarHumano;

  /// Última tool que usó el asistente en este mensaje; `null` si no usó ninguna.
  final String? toolUsada;
}
