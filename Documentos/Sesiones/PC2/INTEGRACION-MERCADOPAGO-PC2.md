# CU-036 — preparación interna integrada, webhook pendiente (#215/#216)

## Estado y fuentes

Corte 2026-10-29: #216 MERGED, código presente en main bceb929. Estado PARCIAL: preparación
interna; circuito HTTP PENDIENTE. El merge no activa el webhook ni certifica integración real.

CU-036 v1.3, RF-012 y RN-015 aprobados: integración académica en pruebas, validación de
operación conocida y acreditación automática válida, sin segunda aprobación humana.
La especificación deja API, credenciales, autenticidad, reintentos y escenario exacto como
definición técnica residual. **No es una integración real certificada ni un webhook activo.**

- [CU-036 aprobado](https://drive.google.com/file/d/1Kc4m4e2LH5xRc1J9HY-2hTQaiLNeRA7y/view).
- [RF-012](https://docs.google.com/document/d/1sA_3o6trf_B2B7H5JyI1yQQhFIzO-8rh/edit).
- [RN-015](https://docs.google.com/document/d/1aG6RTv1lTyY36PkyYyYl46NW4PKYvYMb/edit).
- Documentación primaria consultada: [webhooks oficiales](https://raw.githubusercontent.com/mercadopago/sdk-nodejs/master/docs/webhooks.md)
  y [consulta Payments del SDK Python oficial](https://raw.githubusercontent.com/mercadopago/sdk-python/master/mercadopago/resources/payment.py).

## Implementado de forma independiente

`app/integrations/mercadopago.py`: candidato técnico HMAC-SHA256 con comparación constante,
manifest firmado data.id/request-id/ts, rechazo de firma inválida o fuera de ventana.
La tolerancia debe suministrarla el integrador; 60 segundos es solo dato de tests.
Consulta exclusivamente GET /v1/payments/{id} con HTTP inyectado, timeout y sin redirects;
no crea ni captura cobros. Rechaza live_mode distinto de false e ID distinto, respuesta
malformada o error de proveedor. No devuelve payload completo ni expone credenciales en errores.

`app/services/mercadopago.py`: procesa una notificación recibida como objeto interno; valida
firma y consistencia de IDs/modo/type, exige un resolvedor confiable de vínculo, consulta
recurso actual y compara moneda/receptor. Para approved exige pago local MERCADO_PAGO y monto
idéntico. Bloquea la fila y reutiliza decidir_pago_pendiente: RECIBO, ACREEDOR y evento atómicos.
Si ya está CONFIRMADO no repite efectos; si RECHAZADO no lo revierte. Estados del proveedor
no acreditados no se traducen a nuevos estados locales ni deshacen confirmaciones anteriores.
Registra categorías técnicas sanitizadas en logs, sin payloads, firmas, tokens ni datos personales.

**Idempotencia acreditada únicamente por pago local y vínculo simulado fijo.** Garantizar que
una operación externa no pueda vincularse a dos pagos exige el vínculo único persistente
pendiente. No existe resolvedor real ni se infiere external_reference=id_pago.

## Qué falta para integrar

1. Acordar con el equipo escenario académico y selección técnica Payments/HMAC propuesta;
   no se declara como decisión funcional aprobada ni integración productiva.
2. Aprobar almacenamiento/asociación única e inmutable operación MP ↔ pago local. Definir
   moneda/cuenta receptora y asociación con CU-014; el modelo Pago actual no contiene esos datos.
3. Configurar fuera del repositorio token de pruebas, secreto de webhook y cuentas de prueba.
   No se consultaron credenciales reales ni se leyeron secretos locales para esta preparación.
4. Completar por coordinación el contrato compartido: headers/query necesarios, respuestas
   de autenticidad, configuración e indisponibilidad; ACK/reintentos y tolerancia anti-replay.
   Hoy OpenAPI solo declara objeto libre y 200. No se inventan códigos HTTP ni se instala
   un router que confirme con datos no vinculados o acuse éxito ante fallos transitorios.
5. Conectar handler/DI y resolvedor aprobado; decidir persistencia del resultado técnico y
   recuperación/reintentos. Logs actuales no equivalen a historial durable de conciliación.
6. Ejecutar demostración sandbox autorizada con operación conocida y pruebas de integración
   reales. Checkout/creación de operaciones concretas continúa pendiente del escenario.

## Evidencia local

82 pruebas focalizadas aprobadas: HMAC, HTTP simulado, modo live rechazado, errores/timeout,
vínculo/monto/moneda/receptor, no acreditados, no reversión, rollback, duplicados y concurrencia
con espera efectiva del lock; más regresión de pagos y rutas. PostgreSQL temporal real en
el entorno testing existente; HTTP/proveedor/vínculo completamente falsos. Ruff y formato
correctos. Sin nuevas dependencias, router/configuración activos, OpenAPI ni cambios de modelo.

Base a8696de y stashes citados en la preparación son históricos. Hoy main bceb929 integra
#210/#214/#216/#217/#218. PR #216 informa 599 pruebas backend aprobadas al publicar;
separadas de las 82 focalizadas anteriores. Sin nuevas suites, cobros ni producción en #225.
