"""Definición de las herramientas (tools) de AG-01, en formato function-calling (OpenAI/OpenRouter).

Estas son las 11 tools acordadas. Cada una se MAPEA a un servicio de FastAPI que aplica las reglas de
negocio: el LLM sólo elige la tool y arma argumentos; NUNCA accede a la base de datos ni decide reglas.
Referencia: Documentos/Recursos/Stack-y-Referencias.md y RF-029..032.
"""

# Nota de la PoC: las fechas relativas ("mañana") NO las resuelve el modelo. El backend inyecta la
# fecha/hora actual en el contexto y/o resuelve la fecha antes de ejecutar la tool.

TOOLS: list[dict] = [
    {
        "type": "function",
        "function": {
            "name": "consultar_disponibilidad",
            "description": "Consultar cupos disponibles para una fecha, destino y sentido (ida/vuelta).",
            "parameters": {
                "type": "object",
                "properties": {
                    "fecha": {"type": "string", "description": "Fecha del viaje (YYYY-MM-DD). Resuelta por el backend."},
                    "destino": {"type": "string"},
                    "sentido": {"type": "string", "enum": ["ida", "vuelta"]},
                },
                "required": ["fecha", "sentido"],
            },
        },
    },
    {"type": "function", "function": {"name": "consultar_horarios", "description": "Consultar horarios vigentes de un servicio/recorrido.", "parameters": {"type": "object", "properties": {"recorrido": {"type": "string"}}}}},
    {"type": "function", "function": {"name": "consultar_recorridos", "description": "Informar recorridos disponibles.", "parameters": {"type": "object", "properties": {"tipo_servicio": {"type": "string"}}}}},
    {"type": "function", "function": {"name": "consultar_paradas", "description": "Informar paradas de un recorrido.", "parameters": {"type": "object", "properties": {"recorrido": {"type": "string"}}, "required": ["recorrido"]}}},
    {"type": "function", "function": {"name": "consultar_tarifa", "description": "Consultar tarifa según tipo de cliente y modalidad.", "parameters": {"type": "object", "properties": {"tipo_cliente": {"type": "string"}, "modalidad": {"type": "string", "enum": ["ida", "vuelta", "ida_vuelta"]}, "dias": {"type": "integer"}}, "required": ["tipo_cliente", "modalidad"]}}},
    {"type": "function", "function": {"name": "consultar_estado_pago", "description": "Informar estado de pago del usuario autenticado. No modifica pagos.", "parameters": {"type": "object", "properties": {}}}},
    {"type": "function", "function": {"name": "consultar_deuda", "description": "Informar la deuda del usuario autenticado.", "parameters": {"type": "object", "properties": {}}}},
    {"type": "function", "function": {"name": "consultar_reserva", "description": "Consultar una reserva propia/autorizada.", "parameters": {"type": "object", "properties": {"reserva_id": {"type": "string"}}, "required": ["reserva_id"]}}},
    {"type": "function", "function": {"name": "crear_reserva", "description": "Solicitar la creación de una reserva. FastAPI valida cupo, reglas, estado y datos.", "parameters": {"type": "object", "properties": {"fecha": {"type": "string"}, "recorrido": {"type": "string"}, "parada": {"type": "string"}, "sentido": {"type": "string", "enum": ["ida", "vuelta"]}}, "required": ["fecha", "sentido"]}}},
    {"type": "function", "function": {"name": "cancelar_reserva", "description": "Solicitar la cancelación de una reserva. FastAPI valida titularidad y plazo.", "parameters": {"type": "object", "properties": {"reserva_id": {"type": "string"}}, "required": ["reserva_id"]}}},
    {"type": "function", "function": {"name": "consultar_estado_viaje", "description": "Informar el estado operativo de un viaje.", "parameters": {"type": "object", "properties": {"viaje_id": {"type": "string"}}, "required": ["viaje_id"]}}},
    {"type": "function", "function": {"name": "consultar_ubicacion_vehiculo", "description": "Obtener la ubicación del vehículo del servicio autorizado. Solo usuarios vinculados al viaje.", "parameters": {"type": "object", "properties": {"viaje_id": {"type": "string"}}, "required": ["viaje_id"]}}},
    {"type": "function", "function": {"name": "derivar_humano", "description": "Escalar la conversación a una persona. Se usa si el usuario lo pide o el agente no puede resolver de forma segura.", "parameters": {"type": "object", "properties": {"motivo": {"type": "string"}}}}},
]

# Prompt base de la PoC (BASE DE IMPLEMENTACIÓN — se refinará al desarrollar el agente completo).
SYSTEM_PROMPT = """Sos el asistente conversacional de VanFull.
Fecha actual del sistema: {fecha_actual}.
- Atendé únicamente consultas vinculadas con VanFull.
- Nunca inventes cupos, horarios, tarifas, pagos ni deudas.
- Para datos operativos usá las herramientas disponibles.
- No reveles datos personales de terceros.
- No modifiques estados de pago.
- No permitas reservas por encima del cupo.
- Las reglas de negocio las valida el backend.
- Si faltan datos esenciales, pedilos antes de ejecutar una acción.
- Si el usuario pide atención humana, usá derivar_humano().
- Rechazá solicitudes ajenas a VanFull de manera breve."""
