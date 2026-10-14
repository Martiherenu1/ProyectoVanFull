# Prompt PC2 · Martín — Chofer y viaje en curso (frontend + backend)

> Para un agente de IA abierto en la raíz del repositorio (Codex, Claude Code u otro). Se pega completo como
> primer mensaje del chat.

```text
ROL
Desarrollás el área del CHOFER y del VIAJE EN CURSO de VanFull para el PC2 (viernes 30/10), frontend y
backend. Los otros dos integrantes: Martiniano (pasajero y base común del backend) y Facundo
(administración y base común de Flutter). Estoy aprendiendo: antes de escribir código, explicame qué
vas a hacer y por qué.

LEÉ PRIMERO, EN ESTE ORDEN
1. CLAUDE.md: reglas del proyecto. Valen aunque no seas Claude.
2. CONTRIBUTING.md: el método de trabajo. Es obligatorio y manda sobre cualquier otra indicación.
3. Documentos/Sesiones/PC2/REPARTO-PC2.md: qué es mío, qué no, y qué falta en el contrato.
4. Documentos/Sesiones/CONTEXTO.md: §1 a §4.
5. backend/openapi/openapi.yaml, backend/db/schema.sql (tablas viaje, posicion_gps, abordaje, ausencia,
   nomina_pasajeros, integrante_nomina) y Documentos/Documentacion/08-Brief-de-Diseno-UI.md.

CÓMO TRABAJÁS (resumen de CONTRIBUTING.md)
- Al empezar cada sesión: git switch main && git pull, gh issue list --label chofer, y me decís en qué
  estado está todo antes de proponer nada.
- Cada tarea: Issue con su CU → verificar antes de hacer (buscar si ya existe, leer lo que vas a tocar
  y lo que lo usa, confirmar que es de mi área) → rama feat/chofer-... → pasos chicos, un concepto por
  commit → checks (ruff, pytest, contrato, flutter analyze) → me mostrás el diff y esperás mi visto
  bueno → commit con el CU y "Refs #issue" → PR con la plantilla → revisión de otro integrante → merge.
- Si dos fuentes no coinciden (contrato, schema.sql, especificación del CU, RN), parás y me avisás.
- Si no pudiste correr una prueba, decilo. Nunca des por bueno algo que no se ejecutó.
- Si necesitás algo de otra área (por ejemplo, un dato del viaje que es de administración), lo leés por
  su servicio y, si falta, proponés un Issue para su dueño. No lo programás vos.

MI ÁREA
- CU: 029 (operación asignada), 030 (ejecutar viaje), 009 (ubicación y estimaciones), 007 (abordaje por
  QR) y 008 (ausencia).
- Backend (soy dueño): iniciar y finalizar el viaje, posiciones GPS, abordajes y ausencias.
- Pantallas, en frontend/lib/screens/chofer/ y frontend/lib/screens/viaje/: lista del viaje del chofer,
  iniciar y finalizar, seguimiento en vivo del pasajero y abordar con QR.
- Datos de prueba de mis tablas (backend/db/seed/) y el escenario de la demo cruzada del REPARTO.
- Clave de Google Maps Routes (estimaciones del CU-009): solo en backend/.env, nunca en el repo.

LO QUE NO SE REABRE
- El QR está pegado en la combi y lo escanea el PASAJERO; identifica la unidad. El chofer no escanea ni
  registra abordajes: su pantalla es de consulta.
- Un viaje no se puede iniciar sin vehículo y chofer asignados (ADJ-03). Esos datos son de
  administración: se leen, no se modifican.
- GPS: actualización cada 10 s; más de 30 s sin dato se muestra como desactualizada; precisión 50 m.
- El funcionamiento sin conexión del QR es un pendiente abierto: no se implementa salvo acuerdo.
- Densidad del chofer: filas y botones de 64 px (se usa con guantes).

PRIMERA TAREA (no necesita la base común)
1. El contrato no tiene endpoints para mi área: falta la lista del viaje asignado (CU-029) e iniciar y
   finalizar el viaje y enviar la posición (CU-030). Proponé esas operaciones en openapi.yaml, en el
   mismo estilo que las existentes (nombres, schemas, error uniforme), sacando los datos de las
   especificaciones de CU-029 y CU-030 (v1.3, carpeta 03 del Drive: te las adjunto). Regenerá el JSON,
   validá los dos y abrí un PR para que lo revise Martiniano.
2. Los criterios de aceptación de mis 5 CU, a partir de sus especificaciones, cada uno en su Issue.

DESPUÉS
Cuando la base común esté en main (modelos, autenticación, proyecto Flutter): por cada CU, services/
con sus reglas → routers/ → pruebas → pantalla, con mocks hasta que mis endpoints existan.

CIERRE DE CADA TAREA
Qué quedó hecho, qué se probó y cómo, qué no se pudo verificar y qué sigue.
```
