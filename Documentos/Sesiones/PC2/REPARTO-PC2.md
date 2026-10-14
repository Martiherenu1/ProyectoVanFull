# Reparto del desarrollo hacia el PC2 (viernes 30/10/2026)

> Acordado el 13/10/2026. Toma como base el plan de Martín (`08_Plan_PC2_VanFull_v1.0`): contrato OpenAPI como
> frontera, mocks, circuitos de punta a punta, freeze antes del PC2. Cambia el reparto: **por tipo de usuario**, y
> cada uno hace el frontend **y** el backend de su parte. El cronograma es orientativo.

## 1. Quién hace qué

| | Martiniano | Martín | Facundo |
|---|---|---|---|
| **Usuario** | Pasajero (antes del viaje) | Chofer y el viaje en curso | Administración |
| **CU para el PC2** | CU-012, 001, 002, 003, 004, 010, 006 (pantalla), 011 | CU-029, 030, 009, 007, 008 | CU-018, 027, 014, 015, 016, 036 |
| **Pantallas** | Del PC1: Login, Buscar servicio, Confirmar reserva, Mis reservas y deuda, Pago (la registra el pasajero; el backend es de Facundo), Asistente | Del PC1: Lista del viaje (chofer), Seguimiento en vivo, Abordar con QR. Nueva: iniciar y finalizar el viaje | Del PC1: Viajes del día. Nuevas: asignaciones, reservas, pagos a confirmar |
| **Backend (dueño)** | Autenticación y roles, perfil, servicios y disponibilidad, tarifas, reservas y lista de espera, agente AG-01 (`/chat`) | Ejecución del viaje (iniciar y finalizar), posiciones GPS, abordajes, ausencias | Viajes (alta y asignaciones), cuenta corriente, deuda, pagos, comprobantes, Mercado Pago |
| **Endpoints que ya existen** | `/auth/*`, `/pasajeros/me`, `/pasajeros/me/reservas`, `/servicios*`, `/recorridos/{id}/paradas`, `/tarifas`, `/reservas*`, `/chat` | `GET /viajes/{id}/ubicacion`, `POST /abordajes`, `POST /ausencias` | `POST /viajes`, `POST /pagos`, `POST /pagos/{id}/confirmacion`, `/webhooks/mercadopago`, `GET /pasajeros/me/deuda` (el backend) |
| **Endpoints que faltan** | — | Lista del viaje asignado al chofer (CU-029); iniciar y finalizar viaje y enviar posición (CU-030) | Viajes del día; asignar vehículo y chofer (CU-018); reservas para administración (CU-027); pagos pendientes de confirmar |

**Fuera del PC2:** dueño, clientes corporativos, reportes, facturación, abonos, recorridos y paradas,
optimización de recorridos, alta de choferes y vehículos (CU-005, 013, 017, 019 a 026, 028, 031 a 035, 037).
Los datos que esos CU administran se cargan con el seed.

**Una frontera que hay que respetar:** el viaje lo crea y lo asigna administración (Facundo); lo inicia, lo
ejecuta y lo termina el chofer (Martín). Iniciar el viaje exige que tenga vehículo y chofer asignados (ADJ-03):
esa validación la hace el servicio de Martín, leyendo los datos de Facundo, sin modificarlos.

### Las 35 tablas: quién escribe en cada una

Cualquiera puede **leer** cualquier tabla, a través del servicio de su dueño. **Escribir** en una tabla (crear,
modificar, cambiar su estado) es solo del dueño, en su servicio. Las tablas cuyos CU quedan fuera del PC2 se
llenan con el seed.

| Dueño | Tablas |
|---|---|
| **Martiniano** | `persona`, `pasajero`, `cliente`, `cliente_individual`, `cliente_persona_juridica`, `cliente_corporativo`, `contacto_corporativo`, `pasajero_corporativo`, `cuenta_acceso`, `rol_acceso`, `cuenta_rol`, `servicio`, `tarifa`, `contratacion`, `recorrido`, `parada`, `parada_recorrido`, `reserva`, `registro_lista_espera` |
| **Martín** | `posicion_gps`, `nomina_pasajeros`, `integrante_nomina`, `abordaje`, `ausencia`, y los cambios de estado de ejecución de `viaje` (iniciar y finalizar) |
| **Facundo** | `chofer`, `vehiculo`, `viaje` (alta, asignaciones, modificación y cancelación), `cuenta_corriente`, `pago`, `movimiento_cuenta`, `comprobante`, `abono_mensual`, `periodo_abono`, `periodo_abono_viaje` |
| **Común** | `evento_operativo`: lo escribe cualquiera, solo a través del helper de la base común |

`viaje` es la única tabla con dos dueños, y por eso la frontera está escrita más abajo.

**El contrato está incompleto, y completarlo es parte de cada área.** La v0.1 cubre 16 de los 37 CU
(`backend/openapi/README.md`). Además de los endpoints que faltan en la tabla, hay dos CU a medias: **CU-003**
no tiene la lista de espera (Martiniano) y **CU-018** solo tiene el alta del viaje, sin modificar, cancelar ni
reasignar (Facundo).

### Lo que no es de un usuario, pero hay que hacer

| Qué | Quién | Cuándo |
|---|---|---|
| Integración continua en GitHub Actions: `ruff`, `pytest` y validación del contrato; `flutter analyze` y `flutter test` cuando exista el proyecto | Martiniano (Flutter: lo suma Facundo) | Base común |
| Etiquetas de GitHub (`pasajero`, `chofer`, `admin`, `comun`) | Martiniano | Base común |
| Datos de prueba: carpeta `backend/db/seed/` y el script que los carga | Martiniano | Base común |
| Escenario de la demo cruzada (qué pasajeros, qué viaje, qué pagos) | Martín | Base común |
| Datos de prueba de cada tabla | El dueño del tema, por PR al seed | Con cada circuito |
| Login de chofer y administración | La autenticación de Martiniano sirve para todos los roles; la navegación por rol es de Facundo | Base común |
| Claves de servicios externos, siempre en `.env` y nunca en el repo: OpenRouter (agente), Mercado Pago en pruebas, Google Maps Routes (estimaciones del CU-009) | Martiniano, Facundo y Martín, respectivamente | Con cada circuito |
| Despliegue para la demo, a costo 0 (`CONTEXTO.md` §7 y §13): base en Neon y backend en Render | Martiniano | Semana de integración |
| Versión web de Flutter en GitHub Pages | Facundo | Semana de integración |
| Avance por CU en el tablero de Notion | Cada uno, sus CU | Al mergear cada PR |

## 2. Reglas para no pisarse

> **El método de trabajo** (Issue, verificar antes de hacer, rama, commits, PR, revisión, una sola fuente por
> dato) está en **`CONTRIBUTING.md`** y es obligatorio para los tres y para sus agentes de IA. Esta sección solo
> agrega lo que es propio del reparto.

1. **Un dueño por tema en el backend.** Si necesitás datos de otro tema (por ejemplo, la deuda en la pantalla del
   pasajero), usás su servicio o su endpoint. **Nunca escribís tu propia versión de una regla ajena:** las 31 RN
   viven una sola vez, en `services/`.
2. **Archivos por dueño.** `backend/app/services/<tema>.py` y `backend/app/routers/<tema>.py` son del dueño del
   tema. `frontend/lib/screens/<usuario>/` es de quien tiene ese usuario. Los archivos compartidos (`main.py`, los
   modelos, la navegación de Flutter, el tema, el cliente de API, `openapi.yaml`) se cambian en PR chicos.
3. **El contrato.** Agregar operaciones de tu tema está permitido, por PR, con aviso a Martiniano, que puede
   revisar la coherencia (nombres, schemas, errores) y que el JSON se regenere desde el YAML. **Cambiar una operación que
   ya existe** requiere el acuerdo de los tres.
4. **No inventar.** Ni reglas, ni campos, ni rutas. Lo que no está en `schema.sql`, en el contrato o en la RN
   vigente es un pendiente y se consulta. El texto de cada RN vigente está en el Drive (carpeta 02); las
   especificaciones de los CU, en la carpeta 03 (v1.3).
5. **Git:** Issue → rama → PR → CI en verde → merge; la revisión de otro integrante es opcional, como dice `CONTRIBUTING.md`. Ramas
   `<tipo>/<área>-<descripción>-<CU>`, con área `pasajero`, `chofer`, `admin` o `comun`. No se tocan los tags.
6. **Seguimiento:** las tareas, en Issues de GitHub (se cierran con el PR); el avance por CU, en el tablero de Notion.

## 3. La base común (primero, entre los tres)

Antes de repartir, hace falta lo que usan todos. Se arma en paralelo, en los primeros días:

| Qué | Quién |
|---|---|
| Entorno: Docker (PostgreSQL + backend) y Flutter instalados en las tres máquinas | Cada uno en la suya |
| Modelos de las 35 tablas, primera migración de Alembic, autenticación (login, JWT, roles), helper para registrar `evento_operativo` | Martiniano |
| Proyecto Flutter: tema con los tokens del brief, navegación con una sección por usuario, cliente de API intercambiable (mock o HTTP) | Facundo |
| Escenario de la demo cruzada y los CSV de sus tablas (el seed base y el cargador ya están: `backend/db/seed/README.md`) | Martín (vuelve el 16/10) |

**Estado:** la base del backend ya está en `main` (modelos, migración, login y roles, helper de eventos, seed y
CI). Cómo arrancar: `README.md`; cómo se escribe una operación: `backend/CONVENCIONES.md`. Lo que sigue
pendiente de esta base es el proyecto Flutter (Facundo) y el escenario de la demo (Martín).

## 4. La demo del PC2 cruza a los tres

El pasajero reserva → administración arma y asigna el viaje → el chofer ve su lista y lo inicia → el pasajero
sigue la combi y escanea el QR → el pasajero paga y administración confirma. Por eso: datos de prueba comunes, y
la última semana se usa para integrar, no para funcionalidades nuevas (freeze desde el 25/10, salvo acuerdo).

## 5. Lo que no se reabre

QR pegado en la combi y escaneado por el pasajero; el chofer solo consulta y no registra abordajes · Mercado Pago
confirma solo cuando informa aprobado o acreditado; los otros medios los confirma una persona autorizada; AG-01
nunca confirma ni rechaza pagos · AG-01 no accede a la base: usa los servicios del backend · lista de espera FIFO ·
ADJ-03 · densidades: 48 px pasajero, 64 px chofer, 36 px administración.
