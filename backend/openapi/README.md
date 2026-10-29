# Contrato de API (OpenAPI) — Vanfull

El **contrato REST** entre el frontend Flutter / el agente AG-01 y el backend FastAPI.
Cubre el requisito del PC1 **"Comunicación Vista-Controlador: OpenAPI (JSON)"**. Es el contrato de **diseño**
(escrito a mano, previo a la implementación); cuando el backend esté programado, FastAPI expondrá además
su propio `/openapi.json` generado, que deberá coincidir con este contrato.

## Los dos formatos

| Archivo | Para qué |
|---|---|
| **`openapi.yaml`** | **La fuente.** Es la que se edita: admite comentarios y se compara bien en un diff. |
| **`openapi.json`** | Generado a partir del YAML. La consigna del PC1 pide el contrato en **formato JSON**. |

Son **el mismo contrato**: el JSON se produce parseando el YAML y volviéndolo a serializar, no reescribiéndolo.
Si se toca el YAML hay que regenerar el JSON:

```bash
python -c "import yaml,json,io; io.open('backend/openapi/openapi.json','w',encoding='utf-8',newline='\n').write(json.dumps(yaml.safe_load(io.open('backend/openapi/openapi.yaml',encoding='utf-8')),ensure_ascii=False,indent=2)+'\n')"
```

## Cómo verlo

- Pegarlo en https://editor.swagger.io (render Swagger UI online), o
- `redocly preview-docs backend/openapi/openapi.yaml`, o
- al implementar el backend: `http://localhost:8000/docs` (Swagger UI de FastAPI).

Validado con `openapi-spec-validator`: **OpenAPI 3.0.3 · 26 rutas · 28 operaciones HTTP · 29 schemas**.

## Cobertura de esta versión (v0.1)

Actualización CU-015/#212: `GET /clientes/{id_cliente}/deuda` agrega consulta administrativa
de solo lectura (administrador/dueno), reutilizando Deuda. Sin cuenta informa 0.00/al_dia;
inexistente CLIENTE_NO_ENCONTRADO. CU-006 conserva su comportamiento. La gestión de
consecuencias RN-004/005/006 sigue pendiente; CU-015 conserva cobertura parcial.

> **v0.1 representa 18 de los 37 casos de uso, además de RF-028.** Los otros **19 CU** todavía no tienen
> operaciones y se listan al final. Estos indicadores describen la **cobertura contractual de diseño**;
> no indican funcionalidades implementadas en el backend ni en el frontend.

Se cuentan las rutas distintas de `paths`, los métodos HTTP de cada ruta, los schemas de
`components.schemas` y los identificadores distintos de `x-cu`. RF-028 es un requisito, no un CU adicional.

**Tres de los 18 CU representados tienen cobertura parcial documentada**:

| CU | Qué cubre v0.1 | Qué falta |
|---|---|---|
| **CU-003** Crear reserva | La creación y el rechazo por falta de cupo | La incorporación y gestión de la **lista de espera** que anuncia el `409` |
| **CU-018** Gestionar viajes | Creación y actualización segura; propuesta local #180 de cancelación limitada | Confirmación final de Martín para #180; RN-019 y CU-017/#75 (reintegros); cambiar servicio/recorrido; reglas de solapamiento |
| **CU-030** Ejecutar viaje | Inicio, finalización y recepción de posiciones GPS | Avisos de demora y problemas, pendientes para otra tarea |

La cobertura parcial queda marcada con `x-cobertura: parcial` o aclarada en la descripción del endpoint.

**CU-029 tiene documentadas sus operaciones de consulta**: viajes propios, el caso sin asignaciones y
el detalle operativo con recorrido, paradas, identificación permitida y cantidades. El detalle separa
pasajeros con reservas e integrantes de nómina y respeta RN-029. Su implementación funcional en backend
y frontend continúa pendiente; documentar el contrato no implementa los servicios ni las pantallas.

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
| RF-028 Tarifa aplicable *(requisito, no CU: se marca `x-rf`)* | `GET /tarifas` | RN-010..014 |
| CU-003 Crear reserva ⚠️ *parcial* | `POST /reservas` | RF-005, RN-001/002/031 |
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
| CU-016 Confirmar/rechazar pago | `POST /pagos/{id}/confirmacion` | RF-011, RN-015 — validación administrativa cuando el medio no acredita automáticamente |
| CU-018 Gestionar viajes ⚠️ *parcial* | `POST /viajes`, `PATCH /viajes/{id_viaje}` | RF-017/018, RN-001 |
| CU-029 Consultar operación asignada | `GET /choferes/me/viajes` | RF-024, RN-029 |
| CU-029 Consultar operación asignada | `GET /choferes/me/viajes/{id_viaje}` | RF-024, RN-029 |
| CU-030 Ejecutar viaje ⚠️ *parcial* | `POST /viajes/{id_viaje}/inicio` | RF-025, ADJ-03 |
| CU-030 Ejecutar viaje ⚠️ *parcial* | `POST /viajes/{id_viaje}/finalizacion` | RF-025 |
| CU-030 Ejecutar viaje ⚠️ *parcial* | `POST /viajes/{id_viaje}/ubicacion` | RF-021, RF-025, RNF-007 a RNF-010 |
| CU-036 Webhook Mercado Pago | `POST /webhooks/mercadopago` | RF-012, RN-015 — confirmación automática de operaciones aprobadas/acreditadas |

Las referencias de la tabla describen el contrato; no prueban que las reglas estén implementadas.
CU-030 relaciona en su especificación RN-022 (continuar el recorrido ante un pasajero ausente) y RN-023
(condiciones de abordaje y ausencia de confirmación manual por el chofer). Son referencias generales del CU,
no validaciones directas de los POST de inicio, finalización o envío GPS. RN-030 regula la **consulta** de
ubicación en CU-009/CU-034 y no es una regla directa del POST GPS.

## CU pendientes de contrato (próxima iteración)

Los siguientes CU todavía no tienen operaciones en el contrato:
administración de pasajeros (CU-013), créditos/devoluciones (CU-017), recorridos (CU-019),
optimización de recorrido (CU-020), choferes (CU-021), vehículos (CU-022), corporativos (CU-023, CU-033, CU-034, CU-035),
facturación (CU-024), reportes (CU-025), historial (CU-026), reservas admin (CU-027), abonos (CU-028),
tarifas y administradores del dueño (CU-031, CU-032), notificaciones (CU-037).
