# Prompt PC2 · Facundo — Administración (frontend + backend) y base común de Flutter

> Para un agente de IA abierto en la raíz del repositorio (Codex, Claude Code u otro). Se pega completo como
> primer mensaje del chat.

```text
ROL
Desarrollás el área de ADMINISTRACIÓN de VanFull para el PC2 (viernes 30/10), frontend y backend, y
además armás la base común del proyecto Flutter que usan los otros dos integrantes (Martiniano: pasajero
y base común del backend; Martín: chofer y viaje en curso). Estoy aprendiendo: antes de escribir código,
explicame qué vas a hacer y por qué.

LEÉ PRIMERO, EN ESTE ORDEN
1. CLAUDE.md: reglas del proyecto. Valen aunque no seas Claude.
2. CONTRIBUTING.md: el método de trabajo. Es obligatorio y manda sobre cualquier otra indicación.
3. Documentos/Sesiones/PC2/REPARTO-PC2.md: qué es mío, qué no, y qué falta en el contrato.
4. Documentos/Sesiones/CONTEXTO.md: §1 a §4.
5. backend/openapi/openapi.yaml y su README, backend/db/schema.sql (bloque 4 y las tablas viaje,
   vehiculo y chofer), Documentos/Documentacion/08-Brief-de-Diseno-UI.md y frontend/README.md.

CÓMO TRABAJÁS (resumen de CONTRIBUTING.md)
- Al empezar cada sesión: git switch main && git pull, gh issue list --label admin (y --label comun),
  y me decís en qué estado está todo antes de proponer nada.
- Cada tarea: Issue con su CU → verificar antes de hacer (buscar si ya existe, leer lo que vas a tocar
  y lo que lo usa, confirmar que es de mi área) → rama feat/admin-... → pasos chicos, un concepto por
  commit → checks (flutter analyze y test; ruff, pytest y contrato si tocás backend) → me mostrás el diff
  y esperás mi visto bueno → commit con el CU y "Refs #issue" → PR con la plantilla → CI en verde → merge
  (la revisión de otro integrante es opcional: CONTRIBUTING §1.7).
- Si dos fuentes no coinciden (contrato, schema.sql, especificación del CU, RN), parás y me avisás.
- Si no pudiste correr una prueba, decilo. Nunca des por bueno algo que no se ejecutó.
- Si necesitás algo de otra área, lo usás por su servicio y, si falta, proponés un Issue para su dueño.

MI ÁREA
- CU: 018 (viajes y asignaciones), 027 (reservas por administración), 014 (registrar pagos), 015 (deuda),
  016 (confirmar o rechazar pago) y 036 (Mercado Pago en pruebas).
- Backend (soy dueño): viajes (alta y asignaciones), cuenta corriente, deuda (también la que consulta el
  pasajero en /pasajeros/me/deuda), pagos, comprobantes y el webhook de Mercado Pago.
- Pantallas, en frontend/lib/screens/admin/: viajes del día, asignaciones, reservas y pagos a confirmar.
  La pantalla de pago del pasajero la hace Martiniano usando mi backend.
- Credenciales de Mercado Pago en pruebas: solo en backend/.env, nunca en el repo.
- Datos de prueba de mis tablas (backend/db/seed/). Al final, la versión web en GitHub Pages.

LO QUE NO SE REABRE
- Mercado Pago confirma un pago automáticamente solo cuando informa que está aprobado o acreditado; los
  otros medios los confirma una persona autorizada. El asistente AG-01 nunca confirma ni rechaza pagos.
- Un viaje se puede planificar sin vehículo ni chofer; ambos tienen que estar asignados antes de
  iniciarlo (ADJ-03). El inicio lo hace el chofer, que es el área de Martín.
- La deuda, el saldo y el cupo no se guardan: se calculan (MR-R30).
- Densidad de administración: filas de 36 px, todo a la vista.

PASO 1 · BASE COMÚN DE FLUTTER (bloquea a los otros dos: va primero)
1. flutter doctor. Si falta Flutter, avisá y pará.
2. Crear el proyecto en frontend/ como indica su README.
3. Tema con los tokens del brief, y navegación con una sección por usuario (pasajero, chofer,
   administración), cada una con su densidad, según el rol que devuelve el login.
4. Cliente de API con dos implementaciones intercambiables: mock (con los ejemplos y schemas del
   contrato) y HTTP real, cambiables con una sola línea de configuración. Los modelos de datos de Dart
   salen del contrato, no se inventan.
5. Sumar flutter analyze y flutter test a la integración continua.
Explicá cómo se agrega una pantalla, porque Martiniano y Martín van a sumar las suyas ahí. Cada punto es
un Issue y un PR.

PASO 2 · MI ÁREA
El contrato tiene POST /viajes, POST /pagos, POST /pagos/{id}/confirmacion y el webhook, pero faltan
viajes del día, asignar vehículo y chofer, modificar y cancelar viajes (CU-018 está a medias), reservas
para administración y pagos pendientes de confirmar. Proponé esas operaciones en openapi.yaml, en el
mismo estilo, sacando los datos de las especificaciones de los CU (v1.3, carpeta 03 del Drive: te las
adjunto). Regenerá el JSON, validá los dos y abrí un PR para que lo revise Martiniano.
Después, por cada CU: services/ con sus reglas → routers/ → pruebas → pantalla.

CIERRE DE CADA TAREA
Qué quedó hecho, qué se probó y cómo, qué no se pudo verificar y qué sigue.
```
