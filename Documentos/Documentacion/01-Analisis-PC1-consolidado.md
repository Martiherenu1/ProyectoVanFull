# Análisis PC1 — Digest consolidado (Vanfull)

> Versión legible/estructurada del documento fuente **`Documentacion Grupo 5 (1).docx`** (v1.0, 27/08/2026).
> El `.docx` original permanece como fuente de verdad en `Documentos/`. Este digest sirve para
> consulta rápida y para no releer el Word completo.

## Jerarquía de fuentes (clasificación usada en todo el proyecto)
1. **REQUERIDO POR LOS PROFESORES** — obligaciones académicas y entregables.
2. **CONFIRMADO POR VANFULL** — dicho por la empresa en el relevamiento (fuente primaria = entrevista al dueño).
3. **DEFINIDO POR EL EQUIPO** — decisiones aprobadas por los 3 integrantes (arquitectura/tecnología).
4. **PROPUESTA DE IA** — recomendación técnica no aprobada aún.
5. **PENDIENTE DE VALIDACIÓN** — requiere confirmación adicional.

## Problemática del negocio (CONFIRMADO POR VANFULL)
- Operatoria actual: WhatsApp + Excel + teléfono. Cupos por planilla; pagos verificados manualmente uno por uno.
- Riesgos: sumatorias manuales de disponibilidad con errores; **no detectar un pago**; tránsito en recorridos.
- Deseo: automatizar confirmaciones, recordatorios, proximidad del vehículo, demoras y cambios operativos.

## Objetivo general
Plataforma Web + Mobile que centraliza la gestión operativa/administrativa, habilita autoservicio de
pasajeros y clientes autorizados, integra pagos y seguimiento de viajes, e incorpora un agente de IA
para consultas y acciones controladas sobre el backend.

## Alcance (resumen — detalle completo en CONTEXTO.md §4)
- **Dentro:** pasajeros, clientes corporativos, reservas/cupos + lista de espera, tipos de servicio,
  tarifas/abonos, pagos y deuda, viajes, choferes/vehículos, abordaje QR, GPS, optimización de rutas,
  WhatsApp+chatbot, notificaciones, reportes (export Excel/PDF).
- **Fuera:** Uber, cambio libre de DNI por pasajero, chofer viendo contactos privados, abordaje manual
  por chofer, tracking de flota completa por pasajeros, cambio autónomo de rutas por IA, validación 100%
  autónoma de pagos por LLM, integración fiscal (ARCA), Mercado Pago productivo.
- **Extensión futura:** AG-02 (asistencia operativa admins), QR chofer, combustible, mantenimiento flota.

## Arquitectura (§ Componentes)
Cliente-servidor por capas. Frontend sin reglas críticas. Agentes de IA sin acceso directo a la BD.
FastAPI centraliza auth, permisos, validaciones, servicios de dominio e integraciones.

| Componente | Decisión | Clasificación |
|---|---|---|
| Frontend | Flutter Web+Mobile | DEFINIDO POR EL EQUIPO |
| Backend | Python + FastAPI (OpenAPI/JSON) | DEFINIDO POR EL EQUIPO |
| BD | PostgreSQL | DEFINIDO POR EL EQUIPO |
| Mapas/rutas | Google Maps Platform (Routes API) | DEFINIDO POR EL EQUIPO |
| Gateway LLM | OpenRouter | DEFINIDO POR EL EQUIPO |
| Pago | Mercado Pago (test) | REQUERIDO POR LOS PROFESORES |
| Mensajería | WhatsApp | CONFIRMADO VANFULL / REQUERIDO PROFESORES |
| GPS | Ubicación del dispositivo del chofer | CONFIRMADO VANFULL / REQUERIDO PROFESORES |

> Mecanismo de tiempo real GPS (WebSocket/SSE/polling): **PENDIENTE DE VALIDACIÓN TÉCNICA**.

## AG-01 — Agente conversacional
- Modelo principal: `minimax/minimax-m3:free`; fallback: `nvidia/nemotron-3-super-120b-a12b:free`; gateway OpenRouter.
- Acceso a datos indirecto vía tools de FastAPI. Acciones críticas validadas por backend.
- **11 tools:** consultar_disponibilidad, consultar_horarios, consultar_recorridos/paradas, consultar_tarifa,
  consultar_estado_pago/deuda, consultar_reserva, crear_reserva, cancelar_reserva, consultar_estado_viaje,
  consultar_ubicacion_vehiculo, derivar_humano.
- **Prompt base** (PoC): atender sólo temas Vanfull; nunca inventar cupos/horarios/tarifas/pagos/deudas;
  usar tools para datos; no revelar datos de terceros; no modificar pagos; no exceder cupo; pedir datos
  faltantes; derivar_humano() ante pedido; rechazar lo ajeno a Vanfull.
- **Hallazgo:** fechas relativas resueltas por backend, no por el modelo.

## Selección de modelos (PoC)
Matriz ponderada (Tool 25%, Args 20%, Seguridad 15%, No-alucinación 15%, Español 10%, Estructura 5%,
Latencia 5%, Disponibilidad 5%). 10 casos TC-01..TC-10. MiniMax 95,5 / Nemotron 94,5. GLM 5.2 evaluado
pero no validado (HTTP 429). Nota metodológica: en TC-04 (reserva multi-paso) ambos priorizaron
`consultar_disponibilidad` antes de `crear_reserva` — comportamiento razonable; se conservó el 90% original.

## Integraciones determinísticas (NO son agentes de IA)
- **Mercado Pago:** sandbox; FastAPI recibe webhooks y actualiza estado; el agente consulta pero no aprueba pagos.
- **GPS:** posición del dispositivo del chofer → FastAPI autoriza y expone sólo a usuarios del servicio; contemplar pérdida de conectividad.
- **Google Maps:** Routes API con tránsito y waypoints; respeta paradas obligatorias; admin puede intervenir; cuidar cuotas/costos.
- **WhatsApp:** mismo AG-01 en app y WhatsApp; API de mensajería + webhooks; derivación a humano.

## Gobernanza y modelo de desarrollo
- Todo output de IA es revisable/justificable. Flujo **Issue → Branch → Desarrollo → Commit → PR → Revisión → Merge**.
  Tablero To do / In progress / Review / Done. Revisión humana antes del merge.

## Seguridad / privacidad (restricciones de IA)
- No enviar al LLM fotos de DNI, documentos completos, contactos de terceros ni datos de pago sensibles.
- Usar identificadores internos y mínimo contexto para tool calling. Autorización en FastAPI antes de
  devolver reservas/ubicación/deuda/pagos. Backend provee fecha/hora. Datos de prueba ficticios/anonimizados.

## Pendientes que NO bloquean esta etapa
RNF (rendimiento/concurrencia/disponibilidad/recuperación); frecuencia/precisión GPS; sync offline del QR;
config WhatsApp; auth/sesiones/cifrado/auditoría; legales (DNI, geolocalización); fiscales; mecanismo realtime GPS.

## Anexo — Fuentes del proyecto (documentos del equipo)
- `Presentacion.pdf` (consigna docente), `01_Entrevista_VanFull_2026-08-25.docx`, `VanFull — AS-IS consolidado.md`,
  `02_Alcance_y_Limites_VanFull_v1.0_Aprobado_Equipo.docx`, `VanFull_Trabajo_de_Campo_7_diapos.pptx`,
  evidencia PoC (`preflight_10.csv`, `results_10.csv`, `summary_10.csv`, `raw_responses_10.json`).
