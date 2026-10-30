# PR B — Checkout Pro, Issue #252

**PROPUESTA DE IA / PENDIENTE DE APROBACIÓN ESCRITA DEL EQUIPO.**
Preparación del 30/10/2026. El usuario autorizó posteriormente commit, push y publicación
exclusivamente en Draft, condicionados a verificar base, diff y controles. Sin merge ni activación.

## Base y preservación

Issue: #252. Depende del Draft A #251 / Issue #247, commit `10dd5bf`.
Rama: `feat/pasajero-checkout-pro-252`; base de comparación: `feat/admin-integracion-cu036-247`.
No comparar B contra main mientras A no esté integrado: eso incluiría también CU-036.
Después del futuro merge autorizado de A, actualizar la rama y la base del PR B a main.

Se recuperó únicamente el delta entre el corte CU-036 anterior y la implementación
combinada de 45 archivos. Los 45 originales se verificaron por SHA256 antes de recuperar;
permanecen intactos en el checkout original y respaldados fuera de este repositorio.
Se conservaron la documentación y las correcciones nuevas de A. La prueba de modelos
de A se amplió explícitamente de una a dos tablas optativas; siguen siendo 35 tablas
y 54 FK base, sin cambiar `backend/db/schema.sql`.

## Diff de B

- Intención técnica persistente, UUID opaco, inicio/consulta propios y retorno informativo.
- Preferences y reconciliación mediante GET cuando el POST tiene resultado incierto;
  nunca repetir POST ciegamente ni crear un nuevo Pago por un reintento.
- Asociación verificada Payment→orden→preferencia, reutilizando webhook/HMAC y CU-016.
- `mp_0002` después de `mp_0001`, ambas fuera del head de migración habitual.
- Flutter pasajero, composición mínima compartida, abridor externo y url_launcher/lock.
- Ampliación de contrato/documentación/pruebas; no repite la implementación base de A.

## Decisiones pendientes y límites

D1–D6 siguen sin aprobación triple. La ampliación requiere aceptar explícitamente
modelo/DER/contrato, saga DB→proveedor→DB, UUID/external_reference, estados inciertos,
conciliación de múltiples operaciones y cambios de Flutter compartido.
No hay recuperador autónomo ni recuperación persistente de clave después de destruir
el formulario. No se infieren reintegros ni reglas de deuda nuevas.

Webhook, Checkout backend y opción Flutter están desactivados por defecto.
`live_mode=true` continúa rechazado en notificación y recurso Payments, sin excepción.
Schema base, Render, Neon, sitio-web y arranque de despliegue no cambian.
Render conserva la migración habitual de base y autodespliegue de main; las migraciones
candidatas siguen fuera de ese circuito. No hay autorización para merge/despliegue.

Flutter 3.47.7 y Chrome disponibles; Android SDK ausente y no hay entorno Xcode en Windows.
Pruebas de lógica/reanudación/apertura con mocks no certifican navegador/dispositivo real.
No se ejecutan compras nuevas ni se abre un Checkout real durante esta preparación.

## Validación del 30/10/2026

- Backend completo: **763 passed**, sin omisiones ni fallos, 334.81 s; una advertencia
  preexistente TestClient/httpx. Incluye migraciones, contrato, CU-036 y Checkout.
- Ruff y formato correctos: 119 archivos Python. OpenAPI regenerado, válido y equivalente.
- Flutter 3.47.7: dependencias con lock exigido; analyze sin incidencias;
  **780 pruebas aprobadas** en suite completa, incluido retorno/reanudación móvil con mocks.
- Compilación Web debug local con `CHECKOUT_MP_ENABLED=true`: correcta (187.6 s).
  Es una configuración de compilación de prueba; los defaults del código siguen false.
- Android SDK ausente; iOS requiere entorno Apple. Sin compilación nativa ni dispositivo
  real certificado. El ensayo auténtico con firma/Payments del proveedor sigue pendiente.
- Auditoría: 45 originales intactos; código recuperado igual al original, salvo adaptación
  explícita de la prueba de modelos y documentación de preparación. Sin secretos detectados.
- A #251 quedó Draft abierto, sin merge, con CI backend y Flutter en verde.

Los resultados y el patch revisable se entregan en `local-cu036/pr-b-252`, fuera del repo.
## Publicación controlada y revisión solicitada

La autorización de publicación en Draft no aprueba D1–D6 ni la ampliación Checkout.
Martín debe aprobar explícitamente el impacto funcional/DER, Martiniano el contrato y
pasajero/Flutter, y Facundo la integración de pagos y composición compartida. Las decisiones
compartidas requieren aprobación escrita de los tres; la autoría o el push no la sustituyen.
Se solicitará revisión a Martiniano y Martín en GitHub. Facundo, autor, debe registrar su
aceptación explícita por separado; no se presume aprobación de nadie.

Controles prepublicación: Ruff y formato (119 archivos) correctos, Flutter analyze sin
incidencias y 24 pruebas Checkout aprobadas. Revalidación backend: 127 aprobadas en 67.01 s
(una advertencia preexistente TestClient/httpx), cubriendo Checkout/CU-036, HMAC,
contrato/rutas, modelos y migraciones locales sobre el mismo código de las suites completas
anteriores; sin repetir compras ni modificar el perfil live_mode.
