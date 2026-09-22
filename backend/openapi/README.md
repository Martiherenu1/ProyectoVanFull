# Contrato de API (OpenAPI) — Vanfull

`openapi.yaml` es el **contrato REST** entre el frontend Flutter / el agente AG-01 y el backend FastAPI.
Cubre el requisito del PC1 **"Comunicación Vista-Controlador: OpenAPI (JSON)"**. Es el contrato de **diseño**
(escrito a mano, previo a la implementación); cuando el backend esté programado, FastAPI expondrá además
su propio `/openapi.json` generado, que deberá coincidir con este contrato.

## Cómo verlo

- Pegarlo en https://editor.swagger.io (render Swagger UI online), o
- `redocly preview-docs backend/openapi/openapi.yaml`, o
- al implementar el backend: `http://localhost:8000/docs` (Swagger UI de FastAPI).

Validado con `openapi-spec-validator`: **OpenAPI 3.0.3 · 21 paths · 22 operaciones · 22 schemas**.

## Convenciones

- **Auth:** JWT (`bearerAuth`). `/auth/login`, `/servicios*` y `/webhooks/*` son públicos; el resto requiere token.
- **Autorización por rol** (`rol_acceso`): el backend valida permisos por endpoint (RN-026..030).
- **Errores** uniformes con `{ error: { codigo, mensaje, detalles } }`. Códigos HTTP: 400 validación, 401 sin auth,
  403 sin permiso, 404 no existe, 409 conflicto de negocio (cupo, reserva duplicada RN-031, etc.).
- **El agente AG-01 consume estos mismos endpoints** vía tools; nunca accede a la BD ni confirma pagos.

## Trazabilidad CU → endpoint (cobertura de esta versión)

| CU | Endpoint(s) | RF/RN |
|---|---|---|
| CU-001 Perfil pasajero | `GET/PATCH /pasajeros/me` | RF-001/003, RN-026 |
| CU-002 Servicios y disponibilidad | `GET /servicios/disponibilidad`, `GET /servicios`, `GET /recorridos/{id}/paradas` | RF-004, RN-001 |
| RF-028 Tarifa aplicable | `GET /tarifas` | RN-010..014 |
| CU-003 Crear reserva | `POST /reservas` | RF-005, RN-001/002/031 |
| CU-004 Cancelar reserva | `POST /reservas/{id}/cancelacion` | RF-006, RN-017/018/019 |
| CU-005 Cambio de parada | `POST /reservas/{id}/cambio-parada` | RF-008, RN-020 |
| CU-006 Consultar deuda | `GET /pasajeros/me/deuda` | RF-010 |
| CU-007 Abordaje QR | `POST /abordajes` | RF-014/015, RN-023, RNF-011/012 |
| CU-008 Informar ausencia | `POST /ausencias` | RF-016, RN-024/025 |
| CU-009 Ubicación y ETA | `GET /viajes/{id}/ubicacion` | RF-022, RN-030, RNF-007/008 |
| CU-010 Reservas propias | `GET /pasajeros/me/reservas`, `GET /reservas/{id}` | RF-043 |
| CU-011 Chatbot | `POST /chat` | RF-029/032 |
| CU-012 Sesión | `POST /auth/login`, `POST /auth/logout` | RF-045 |
| CU-014 Registrar pago | `POST /pagos` | RF-009, RN-016 |
| CU-016 Confirmar/rechazar pago | `POST /pagos/{id}/confirmacion` | RF-011, RN-015 |
| CU-018 Gestionar viajes | `POST /viajes` | RF-017/018, RN-001 |
| CU-036 Webhook Mercado Pago | `POST /webhooks/mercadopago` | RF-012, RN-015 |

## CU pendientes de contrato (próxima iteración)

Siguen el mismo patrón (recurso + roles + errores); se agregarán en una segunda versión del contrato:
administración de pasajeros (CU-013), deuda admin (CU-015), créditos/devoluciones (CU-017), recorridos (CU-019),
optimización de recorrido (CU-020), choferes (CU-021), vehículos (CU-022), corporativos (CU-023/033/034/035),
facturación (CU-024), reportes (CU-025), historial (CU-026), reservas admin (CU-027), abonos (CU-028),
operación del chofer (CU-029/030), tarifas y administradores del dueño (CU-031/032), notificaciones (CU-037).
