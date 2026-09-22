# IA y Agentes — Documentación consolidada (PC1)

> **Estado:** DEFINIDO POR EL EQUIPO (consolidación). Cubre los requisitos del PC1:
> *"Modelos de IA utilizados y justificación"*, *"Agentes IA implementados"* y *"Selección de modelos (chat)
> y agentes IA – Prompts"*. Destino: carpeta `06_IA_y_Agentes` del Drive.
> Consolida el documento del PC1, la PoC de modelos, el scaffold del backend (`backend/app/agent/`) y el
> contrato OpenAPI (`backend/openapi/openapi.yaml`).

---

## 1. Principio rector

La IA está **separada de las reglas de negocio**. El modelo interpreta la intención del usuario y **elige una
herramienta (tool)**; **FastAPI valida y ejecuta** (permisos, cupos, pagos, privacidad). El agente **NO** accede
directamente a PostgreSQL: sólo consume servicios/endpoints del backend. El backend es la autoridad.

## 2. Dos usos de IA (no confundir)

| | IA para **desarrollar** el proyecto | IA **dentro** de la solución (producto) |
|---|---|---|
| Qué es | Herramientas para analizar, diseñar, documentar y programar | El agente conversacional que usa el pasajero |
| Cuáles | ChatGPT / Claude (análisis, diseño), Codex / Claude Code (programación) | **AG-01** sobre OpenRouter (MiniMax M3 / Nemotron 3 Super) |
| Gobernanza | Revisión humana obligatoria; una salida de IA no es una decisión del proyecto ni se mergea sin revisar | El modelo no decide reglas; las valida el backend |

Este documento se enfoca en la **IA del producto** (requisito del PC1), y deja constancia de la IA de desarrollo por trazabilidad.

## 3. Modelos de la solución y justificación

- **Gateway:** **OpenRouter** (permite rutear y aplicar *fallback* entre modelos con una interfaz común).
- **Modelo principal:** **MiniMax M3 Free** — `minimax/minimax-m3:free`.
- **Modelo fallback:** **NVIDIA Nemotron 3 Super Free** — `nvidia/nemotron-3-super-120b-a12b:free`.
- **Por qué endpoints `:free`:** criterio de la etapa académica (costo cero); desacoplado por OpenRouter para
  reevaluar proveedor/modelo en una eventual producción sin cambiar la arquitectura.

### 3.1 Justificación por PoC (evidencia empírica)

Se evaluaron los candidatos con una **batería común de 10 casos** (TC-01..TC-10) y una **matriz de criterios ponderada**:

| Criterio | Peso |
|---|---|
| Selección correcta de tool | 25% |
| Exactitud de argumentos | 20% |
| Seguridad / respeto de permisos y reglas | 15% |
| No alucinación de datos operativos | 15% |
| Comprensión/respuesta en español | 10% |
| Respuesta estructurada/utilizable | 5% |
| Latencia | 5% |
| Disponibilidad / ausencia de errores | 5% |

**Resultado:** MiniMax **95,5/100** (principal) · Nemotron **94,5/100** (fallback). Ambos: 10/10 requests HTTP 200,
90% tool accuracy, 90% argumentos correctos, seguridad y no-alucinación correctas, latencias ~2,5 s / ~2,8 s.
Alternativas descartadas por indisponibilidad en la ventana de prueba: GLM 5.2 (HTTP 429), Gemma (429/404), GPT-OSS (404).
Evidencia: `preflight_10.csv`, `results_10.csv`, `summary_10.csv`, `raw_responses_10.json`.

**Hallazgo clave:** las fechas relativas ("mañana") **no** se delegan al modelo; el backend inyecta la fecha/hora
determinística antes de ejecutar cualquier tool.

## 4. Agente AG-01 — definición formal

| Atributo | Definición |
|---|---|
| **Identificador** | AG-01 — Agente Conversacional VanFull |
| **Objetivo** | Atender consultas en lenguaje natural y ejecutar acciones habilitadas mediante tools controladas del backend |
| **Usuarios** | Pasajeros / clientes autorizados, desde la app y (luego) WhatsApp — mismo agente en ambos canales |
| **Modelo principal / fallback** | MiniMax M3 Free / NVIDIA Nemotron 3 Super Free |
| **Gateway** | OpenRouter (fase académica) |
| **Acceso a datos** | Indirecto, sólo vía tools/servicios de FastAPI. Sin acceso directo a PostgreSQL |
| **Acciones críticas** | Las valida el backend: no ignora cupos, permisos, reglas de pago ni privacidad |
| **Ante error de proveedor** | Reintenta con el modelo fallback; si no hay respuesta válida, informa indisponibilidad y ofrece/ejecuta derivación a humano |
| **Canal de entrada** | `POST /chat` (backend orquesta el loop de tools) |

**AG-02** (asistencia operativa para administradores) queda como **extensión futura, fuera del MVP**.

## 5. System Prompt (base)

```
Sos el asistente conversacional de VanFull.
Fecha actual del sistema: <provista por backend>.
- Atendé únicamente consultas vinculadas con VanFull.
- Nunca inventes cupos, horarios, tarifas, pagos ni deudas.
- Para datos operativos usá las herramientas disponibles.
- No reveles datos personales de terceros.
- No modifiques estados de pago.
- No permitas reservas por encima del cupo.
- Las reglas de negocio las valida el backend.
- Si faltan datos esenciales, pedilos antes de ejecutar una acción.
- Si el usuario pide atención humana, usá derivar_humano().
- Rechazá solicitudes ajenas a VanFull de manera breve.
```

## 6. Tools / Function Calling — trazabilidad `tool → CU → endpoint`

Las 11 tools (formato function-calling en `backend/app/agent/tools.py`). Cada una se mapea a un caso de uso y a un
endpoint del contrato OpenAPI. Estado del endpoint: ✅ ya definido en `openapi.yaml` v0.1 · ⏳ en la próxima iteración del contrato.

| Tool | CU | Endpoint | Estado |
|---|---|---|---|
| `consultar_disponibilidad()` | CU-002 | `GET /servicios/disponibilidad` | ✅ |
| `consultar_horarios()` | CU-002 | `GET /servicios` (+ disponibilidad) | ✅ |
| `consultar_recorridos()` | CU-002 | `GET /recorridos` | ⏳ |
| `consultar_paradas()` | CU-002 | `GET /recorridos/{id}/paradas` | ✅ |
| `consultar_tarifa()` | RF-028 | `GET /tarifas` | ✅ |
| `consultar_estado_pago()` | CU-006 | `GET /pasajeros/me/pagos` | ⏳ |
| `consultar_deuda()` | CU-006 | `GET /pasajeros/me/deuda` | ✅ |
| `consultar_reserva()` | CU-010 | `GET /reservas/{id}` · `GET /pasajeros/me/reservas` | ✅ |
| `crear_reserva()` | CU-003 | `POST /reservas` | ✅ |
| `cancelar_reserva()` | CU-004 | `POST /reservas/{id}/cancelacion` | ✅ |
| `consultar_estado_viaje()` | CU-009 | `GET /viajes/{id}` | ⏳ |
| `consultar_ubicacion_vehiculo()` | CU-009 | `GET /viajes/{id}/ubicacion` | ✅ |
| `derivar_humano()` | RF-032 | (interno de `/chat`, sin endpoint propio) | ✅ |

> El agente solo **consulta** por chat; **reservar/cancelar** por chat reusan CU-003/CU-004 con las mismas
> validaciones que cualquier canal. Operaciones sensibles requieren identificación/autenticación del usuario
> (mecanismo exacto para el canal WhatsApp: pendiente de definición técnica).

## 7. Arquitectura de la integración (flujo)

```
Usuario → POST /chat → Backend (inyecta fecha/hora + contexto del usuario)
      → LLM (OpenRouter: MiniMax → fallback Nemotron) elige tool + argumentos
      → Backend ejecuta la tool = servicio/endpoint FastAPI (valida RN, permisos, cupo)
      → resultado vuelve al modelo → respuesta en lenguaje natural
      → si no puede resolver de forma segura o el usuario lo pide → derivar_humano()
```

Implementación de referencia en el scaffold: `backend/app/agent/openrouter_client.py` (cliente con fallback),
`backend/app/agent/tools.py` (definición de tools + system prompt).

## 8. Seguridad de la IA

- No enviar al LLM DNI/fotos/documentos completos ni datos de contacto de terceros; usar identificadores internos y mínimo contexto.
- El backend autoriza antes de devolver reservas, ubicación, deuda o estado de pagos (RN-026..030).
- El agente **no** modifica reglas de negocio, cupos, permisos ni estados de pago; la confirmación de pagos es **humana** (RN-015).
- Casos de prueba de seguridad cubiertos en la PoC: rechazo de alterar pagos (TC-07), privacidad / prompt injection (TC-08),
  fuera de alcance (TC-09), derivación (TC-10).
- Ante fallo de proveedor/tool: registrar el error, aplicar fallback o derivar; nunca inventar respuestas.

## 9. Pendientes (no bloquean el PC1)

- Identificación/autenticación del usuario para consultas sensibles vía chatbot (especialmente WhatsApp).
- Configuración concreta de WhatsApp (cuenta, plantillas, costos).
- Endpoints marcados ⏳ en §6, a incorporar en la próxima iteración del contrato OpenAPI.
- Re-ejecutar la PoC si cambian el prompt, las tools o el modelo.
