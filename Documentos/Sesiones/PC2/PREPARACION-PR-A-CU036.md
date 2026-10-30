# PR A — CU-036, Issue #247

**PROPUESTA DE IA / PENDIENTE DE VALIDACIÓN.** Preparación autorizada por el usuario;
D1–D6 siguen pendientes de aprobación escrita de Martín, Martiniano y Facundo.
CU-036 continúa PARCIAL. Referencias: #215 y #240 (antecedente documental).
El futuro PR cerrará solamente #247, no #215.

## Corte y dependencia

Base actualizada por fast-forward el 30/10/2026: `fb6e422` (`origin/main` verificado).
El corte original se preparó sobre `440c578`; se conservaron todos los cambios locales.
Rama local: `feat/admin-integracion-cu036-247`, en un checkout separado.
Los 25 archivos del corte CU-036 anterior a Checkout fueron recuperados de su respaldo
y verificados por SHA256 antes de copiarlos. El checkout original conserva íntegros
los 45 archivos de la implementación combinada; no se hizo stash ni commit.

A contiene vínculo explícito operación↔Pago, CLI local, HTTP/HMAC, GET Payments,
reutilización de CU-016, `mp_0001`, configuración, contrato y pruebas.
No modifica `services/pagos.py`: la confirmación contable existente se reutiliza.
No agrega rutas Checkout, Preferences, intención UUID, Flutter, dependencias ni `mp_0002`.
B depende de A y conservará esos cambios; al prepararlo habrá que integrar el delta
por cambios, preservando correcciones que eventualmente reciba A.

## Decisiones aún pendientes

| Decisión | Aprobación solicitada |
|---|---|
| D1 | Vínculo 1:1, restricciones y actualización del DER si se acepta |
| D2 | Alta explícita, responsable y evidencia; inmutabilidad aplicada por servicio |
| D3 | Contrato HTTP, HMAC, ventana candidata 300 s, errores y ACK posterior al commit |
| D4 | Reentrega/rollback/idempotencia; aceptar límites sin inbox durable ni recuperación autónoma |
| D5 | Perfil de pruebas verificable; `live_mode=true` sigue rechazado sin excepción |
| D6 | Variables y migración optativa; activación local requiere autorización separada |

## Protección del PC2

Webhook desactivado por defecto. En A no existe funcionalidad Checkout.
El modo habilitado exige entorno development/test y DB local `vf_test_`/`vf_sandbox_`.
El cuerpo y el recurso Payments deben ser `live_mode=false`.

`mp_0001` vive fuera de `backend/migrations/versions`, usa tabla de versión propia y
exige permiso explícito antes de conectar. La cadena habitual conserva únicamente `0001`.
`backend/db/schema.sql`, `arrancar.sh` y `render.yaml` permanecen intactos.
Render **sí conserva** el `alembic upgrade head` habitual: lo excluido es la migración
candidata CU-036. Un futuro merge de backend puede disparar el despliegue automático
ya configurado; no se debe mergear sin autorización y coordinación del despliegue.

## Publicación controlada

1. El usuario autorizó el 30/10/2026 commit, push y apertura de A exclusivamente en Draft,
   condicionados a los controles completos. Esto NO aprueba D1–D6.
2. Mantener D1–D6 pendientes de aprobación escrita triple antes de integrar/activar.
3. Commits por concepto con `Refs #247` y coautoría IA; PR con plantilla y `Closes #247`.
4. CI verde y revisión de contrato/modelo por Martiniano, con Martín por DER.
5. Autorizar por separado merge y efecto de despliegue; usar merge commit según CONTRIBUTING.
6. Preparar B apilado sobre la rama A, sin esperar ni realizar su merge; comparar B contra A.
   Tras el futuro merge autorizado de A, actualizar la base de B a main. Ensayo auténtico,
   activación y cualquier cambio
   para migración remota quedan fuera de esta autorización.

## Validación completa del 30/10/2026

- `pytest -q`: **731 passed**, sin fallos ni omisiones, 192.11 s; una advertencia
  preexistente de deprecación TestClient/httpx. Incluye contrato y migraciones locales.
- `ruff check .` correcto y `ruff format --check .`: 113 archivos correctos.
- OpenAPI JSON regenerado desde YAML; ambos válidos y equivalentes.
- PostgreSQL 16 efímero en red dedicada y almacenamiento temporal, sin puertos publicados;
  solo DB `vf_test_*`, JWT sintético, sin `.env`, proveedor simulado y webhook apagado.
- 45 archivos originales preservados por SHA256. Diff A de 27 archivos, sin Flutter,
  Checkout ni mp_0002; escaneo de patrones de secretos y archivos indebidos sin hallazgos.
- Publicación autorizada únicamente como Draft; sin merge ni despliegue. D1–D6 pendientes.

## Resultados históricos de la preparación del 29/10

- `ruff check .`: correcto. `ruff format --check .`: 113 archivos correctos.
- `pytest -q`: 727 aprobadas y 4 fallos en las comprobaciones antiguas de modelos;
  ninguna omitida. Esa ejecución había cargado el archivo antes de su corrección.
- Se ajustó únicamente `test_modelos.py`: verifica 35 tablas/54 FK base más la tabla/1 FK
  del DDL optativo y compara exactamente tablas/columnas. Revalidación final: 4/4 aprobadas.
  Total: 731 casos verificados por lotes; no se afirma una segunda corrida completa en verde.
- La suite incluye HMAC/Payments simulados, rechazo de live_mode=true en cuerpo/recurso,
  duplicados, carreras CU-016, rollback/commit ambiguo, pérdida de ACK, migraciones y contrato.
- OpenAPI JSON regenerado: YAML y JSON válidos y equivalentes.
- Bases temporales PostgreSQL locales `vf_test_*`, `CI=true` (sin omisiones silenciosas),
  JWT sintético y sin cargar `.env`. Sin proveedor real ni ejecución de Flutter (sin cambios).
- Primer intento de suite: error de configuración del contenedor (JWT/entorno); corregido
  solo en las variables de ejecución. Advertencia restante: deprecación TestClient/httpx.

Diff completo, inventario/hash y resultados detallados se adjuntan en el informe local de revisión.
Los resultados históricos de ENSAYO-CU036-AISLADO corresponden a sus cortes indicados.
