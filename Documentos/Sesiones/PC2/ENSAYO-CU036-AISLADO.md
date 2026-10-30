# CU-036 — implementación candidata y ensayo local (seguimiento #215)

## Estado y autorización

Trabajo local sobre `feat/admin-preparar-mercadopago-cu036-238`, base de rama
`440c578` (main remoto incorporado por fast-forward, sin crear commits). #240 ya fue
mergeado con la propuesta anterior y #238 cerrado; esta implementación se prepara
para otro PR vinculado a #215, todavía no creado. El usuario autoriza implementar en rama aislada; **no es aprobación de
D1–D6**. Modelo, migración, DDL, contrato y configuración son candidatos revisables,
no integrados a main. Se requiere decisión escrita de **Martiniano, Martín y Facundo**
antes de integrar cambios compartidos. Sin commit/push, merge ni despliegue en esta tarea.

CU-036 sigue **PARCIAL**: circuito local con Payments simulado, no webhook real
certificado. No se consultan credenciales compartidas ni servicios MP/Neon/Render.
Los cortes históricos de documentación describen el código integrado, no esta rama.

## Qué implementa el candidato

1. `pago_mercadopago`: PK de operación y FK UNIQUE a Pago (1:1), receptor, moneda,
   fecha; CHECK y ON DELETE RESTRICT. No cambia Pago ni crea reglas económicas.
   El servicio no expone edición/borrado/reasignación. La inmutabilidad se aplica en
   el servicio, no mediante trigger ni permisos especiales de DB. Migración optativa
   `mp_0001` y DDL equivalentes bajo `backend/sandbox/mercadopago/`, solo probados en
   bases temporales. El esquema base permanece en 35 tablas/54 FK y no se modifica.
2. Comando local de alta explícita: consulta GET Payments, exige `live_mode=false`,
   receptor/moneda configurados, importe/medio local coincidentes y Pago PENDIENTE.
   Lock Pago + restricciones únicas evitan carreras; repetir el mismo vínculo no
   duplica registros. No infiere external_reference ni crea pagos/preferencias remotos.
3. `POST /api/webhooks/mercadopago`: HMAC antes de consultar DB/proveedor, data.id
   consistente, consulta oficial Payments, vínculo persistente, validación y lock
   del Pago. Reutiliza CU-016 sin modificar su servicio: RECIBO, ACREEDOR y evento
   atómicos, una sola vez; no cambia estados locales para recursos no aprobados.
4. ACK 200 vacío tras commit, incluido duplicado. Firma inválida 401; cuerpo inválido
   400; vínculo/recurso incompatible 409; proveedor/DB/timeout 503; fallo inesperado
   500 sanitizado. Rollback permite reentrega segura. No hay reintento oculto, cola
   durable ni reproceso autónomo: el proveedor debe entregar una nueva notificación
   válida. Un replay fuera de ventana sigue rechazado, sin ampliar tolerancia.
5. Feature flag `MERCADOPAGO_SANDBOX_ENABLED=false`: no registrar ruta por defecto.
   Al habilitar exige ENV development/test, host DB local y nombre
   `vf_sandbox_*`/`vf_test_*`, token, secret, receptor y moneda explícitos. Configurar
   host local es una barrera operativa, no un aislamiento de red contra un operador
   malicioso. Entorno productivo o base compartida `vanfull` no admitidos.
6. `data.id` solo acepta texto numérico de 1–64 dígitos o entero estricto no negativo:
   rechaza booleanos, floats y conversiones implícitas; pruebas HTTP negativas.

## Migraciones: exclusión del arranque automático

`backend/arrancar.sh` y `render.yaml` NO cambian. Su `alembic upgrade head` solo
descubre `migrations/versions/0001`: no hay revisión CU-036 en esa cadena. El entorno
normal de Alembic excluye tabla/versión optativa de autogeneración/comparación, sin
ignorar las tablas base. El test habitual de migraciones sigue contando 35/54.

El circuito optativo tiene configuración, directorio y tabla de versión propios:
`sandbox/mercadopago/alembic.ini` / `alembic_version_mercadopago`. Exige destino local
`vf_sandbox_*`/`vf_test_*`, ENV development/test y `-x autorizar_cu036=SI` antes de
abrir conexión. No basta activar el webhook. Una llamada sin permiso o hacia entorno
productivo/host remoto/base compartida falla antes de conectar.

Así, publicar o incluso desplegar el código con el arranque habitual NO agrega la
tabla CU-036; este trabajo tampoco autoriza desplegarlo. No copiar la revisión optativa
a la cadena normal ni ejecutar comandos optativos desde un script de arranque.
El futuro paso a main sigue requiriendo aprobación escrita triple de D1–D6.

## Límite live_mode y operación conocida

La evidencia aportada por el usuario identifica Payment `186757433348` aprobado,
ARS 10000, comprador `3800207835`, receptor `3800084159`, orden `45687633638` y
preferencia `3800084159-1f311de9-a99d-46ec-8951-5f8bd5ccaa4f`; Payments devuelve
**live_mode=true**. No es prueba de dinero real por sí solo. El análisis documental
local no versionado explica el caso Preferences/usuarios ficticios.

**El candidato mantiene el rechazo** tanto en alta del vínculo como en webhook y
consulta Payments. No hay flag, allowlist, excepción por ese ID ni adaptador alternativo
que acepte true. La alternativa de usuarios ficticios continúa BLOQUEADA: falta definir
y aprobar una fuente de evidencia confiable de ambas cuentas/aplicación/credencial;
una variable declarativa o prefijo de token no bastan. No se propone habilitar un
perfil más permisivo en esta implementación. El pago conocido no se usa para producir
asientos locales ni para fingir una prueba punta a punta aprobada.

## Ensayo automatizado completo sin servicios externos

Docker y el PostgreSQL local existente deben estar disponibles. La URL administrativa
de pruebas apunta explícitamente a postgres local, no a la DB compartida vanfull.
`tests/_bd.py` crea `vf_test_<uuid>`, aplica esquema base allí y elimina esa base al
terminar; `tests/_bd_mercadopago.py` aplica la extensión optativa, únicamente con el
prefijo temporal verificado. Los fixtures nuevos comprueban el prefijo antes de escribir.
Los tests reemplazan HTTP por MockTransport; no necesitan credenciales verdaderas.

```powershell
docker compose run --rm --no-deps `
  -e DATABASE_URL=postgresql+asyncpg://vanfull:vanfull@db:5432/postgres `
  -e ENV=development -e CI=true -e MERCADOPAGO_SANDBOX_ENABLED=false `
  backend pytest -q tests/test_mercadopago_http.py tests/test_migracion_mercadopago.py
```

El caso `test_circuito_http_completo_y_duplicado_tras_respuesta_perdida` registra el
Pago mediante POST /pagos (CU-014), vincula mediante el servicio real con SQL, entrega
HMAC calculado con secreto sintético al router real, consulta Payments simulado y
confirma usando CU-016. Comprueba estado, recibo/movimiento/evento únicos y deuda
calculada. Prueba adicional hace competir dos webhooks con decisión administrativa
CU-016 observando espera real en PostgreSQL. Otra enfrenta dos altas para una operación.

No simular firma MP auténtica: en automatización la firma es válida criptográficamente
pero de secreto sintético; eso no demuestra entrega desde el proveedor. Se conserva
la diferencia entre transporte HTTP ASGI local, firma de prueba y notificación real.

## Ensayo futuro con notificación auténtica (NO EJECUTADO)

Solo después de aprobación escrita del perfil, contrato y modelo:

1. Crear base **local vacía dedicada** `vf_sandbox_*`, con autorización de preparar
   esquema; nunca apuntar comandos de migración al arranque de Render ni a Neon.
   En esa base local, aplicar primero el esquema base y después, explícitamente:
   `alembic -c sandbox/mercadopago/alembic.ini -x autorizar_cu036=SI upgrade head`.
   Aplicar antes de habilitar router; no hacen falta secretos del proveedor para
   migrar. No hay comando optativo ejecutado automáticamente en ningún entorno.
   Este ensayo no crea automáticamente infraestructura ni aplica migraciones locales
   compartidas. Identificar separadamente DB/cuenta/cliente de pruebas.
2. Proporcionar token y secret webhook por variables del proceso, fuera del repo;
   verificar origen de prueba sin inferir prefijo. Configurar receptor/moneda y flag
   solo en backend local. No habilitarlo en servicios existentes/desplegados.
3. Registrar Pago PENDIENTE de prueba mediante CU-014 existente y alta explícita:
   `python -m app.integrations.vincular_mercadopago --id-pago N --id-operacion ID`.
   No usar la operación conocida live_mode=true: seguirá fallando hasta nueva decisión.
4. Si existe operación compatible, aprobar HTTPS temporal hacia el backend local y
   registro de URL de prueba en panel MP; no crear nuevas compras o devoluciones.
   Reentrega del proveedor de una operación existente, con firma auténtica vigente.
5. Verificar ACK y contabilidad antes/después, repetir entrega autorizada y comprobar
   ausencia de duplicados. Evidencia sanitizada, cerrar URL temporal y deshabilitar flag.
   Ante fallo/timeout no crear un nuevo pago ni confirmar manualmente para ocultarlo.

El recurso compatible y la notificación real/secret/HTTPS siguen pendientes; no se
ejecuta este ensayo ni se habilita red pública por la autorización de implementar.

## Matriz de pendientes y diferencias respecto de la propuesta inicial

| Decisión | Preparación en rama | Falta para integrar/activar |
|---|---|---|
| D1 persistencia | Tabla/modelo/mp_0001/DDL optativos, PK/FK/UNIQUE/CHECK, pruebas SQL | Aprobación triple; actualizar DER si se acepta; no aplicar en DB compartida |
| D2 asociación | Servicio + CLI local, locks/unicidad y conflicto | Aprobación de procedimiento de alta y responsable de evidencia |
| D3 HTTP | Router/schema/OpenAPI YAML+JSON, HMAC, ACK tras commit | Aprobar contrato/códigos/ventana y prueba con firma auténtica |
| D4 reintentos | Rollback, 503 y nueva entrega, duplicados sin efectos, logs por categoría | Acordar límites; sin inbox durable ni comando de reproceso sin webhook; no se promete recuperación autónoma |
| D5 sandbox | MockTransport + PostgreSQL temporal; true sigue rechazado | Decisión explícita del equipo sobre perfil live_mode; evidencia de usuarios/credenciales; recurso compatible |
| D6 configuración | Desactivada por defecto, guardas locales y migración fuera del arranque habitual | Aprobar separación de esquema/variables; token/secret externos, HTTPS y activación local autorizados separadamente |

Contrato candidato: una respuesta Payments inválida/incompatible se traduce a 409
VINCULO_PAGO_INVALIDO; transporte/HTTP no 200 a 503. Esto concreta la distinción no
resuelta en D3 inicial, no modifica una decisión aprobada. Headers/body ausentes o
excesivos pueden producir 400 VALIDACION; firma o request-id vacío/inválido, 401.

No se implementa el comando `reprocesar` de la alternativa D4 para evitar introducir
un camino que eluda HMAC; se conserva entrega auténtica nueva. Si el equipo exige
ese comando o recuperación durable, aprobarlo como siguiente paso y probarlo aparte.

## Validaciones

Validación ejecutada:

Corrección precommit posterior: validación estricta, main actualizado preservando
CU-005/OpenAPI/contextos, migración optativa aislada y nuevas pruebas de carreras
inversas, timeout global, resultado ambiguo antes/después de commit y pérdida de ACK
en transporte ASGI. Las fallas de commit son inyección controlada en fronteras de
una transacción PostgreSQL real, no una certificación de cortes físicos de red.
Resultado final: **177 casos distintos aprobados** en tres ejecuciones focalizadas:
29 adaptador/HMAC/reintentos; 144 HTTP/contabilidad/migraciones/contratos/regresión
CU-005; 4 regresiones adicionales del schema (true/false/float con query y firma
coincidentes, entero válido admitido). El archivo HTTP ahora contiene 48 casos y
el nuevo archivo de migraciones optativas, 9. Ninguna prueba omitida o fallida.

Ruff y formato: 15 archivos Python del diff correctos. OpenAPI YAML/JSON válidos y
equivalentes, preservando CU-005 de main. Upgrade/downgrade/check optativos y normales,
DDL/modelo, exclusión del head de arranque y guardas de destino/autorización aprobados
en PostgreSQL temporal. Sin ejecución de suites generales ni proveedor real.

El único conflicto al avanzar main fue la cabecera del contexto general; se conservaron
íntegros ambos aportes. Copia de los 21 archivos previos verificada por SHA256 antes
de actualizar, fuera del repositorio. No se usó stash ni se crearon commits.

Publicación preparada para PR NUEVO vinculado a #215, todavía no abierto. #240 y #238
son antecedentes cerrados. La aprobación del diff/publicación no sustituye las tres
aprobaciones de modelo/contrato/perfil. No se marca CU-036 completo ni se cierra #215.

Antecedentes de la primera preparación (anteriores a separar la migración):

- Primera pasada: 70 pruebas CU-036 aprobadas.
- Pasada ampliada: 131 aprobadas y un fallo del observador de concurrencia del test:
  pg_stat_activity conservaba instantánea de sesiones. Se corrigió el observador
  con pg_stat_clear_snapshot(), sin modificar el servicio ni suavizar los locks.
- Revalidación dirigida: concurrencia corregida aprobada; segunda revalidación de
  concurrencia + seis restricciones SQL: **7/7 aprobadas**. Resultado combinado:
  **132 casos distintos verificados**, incluidos 33 casos del nuevo archivo HTTP.
- Ruff y formato: correctos en los 11 archivos Python nuevos/modificados elegibles.
- OpenAPI YAML/JSON válidos y equivalentes; rutas presentes en contrato.
- Migración/DDL/modelo equivalentes (columnas, constraints, índices, roles),
  Alembic check y upgrade/downgrade correctos en bases temporales vf_test_*.
- diff check correcto. No se ejecutó suite general, Flutter ni workflow Web.

Warnings observados: deprecación de TestClient/httpx y longitud de clave JWT de
desarrollo ya existente; no se cambiaron dependencias ni credenciales compartidas.
La primera ejecución propuesta sobre URL vanfull fue rechazada por revisión automática
antes de ejecutarse. Se demostró el aislamiento de los fixtures y se usó postgres
local como conexión administrativa para CREATE/DROP de bases vf_test_* exclusivamente.
Ninguna migración o escritura se aplicó a vanfull, Neon o Render.
No se acredita integración desplegada ni webhook auténtico del proveedor.
