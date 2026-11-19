# Cobertura de los 37 casos de uso — corte del 19/11/2026

> **Borrador para la entrega final del 20/11.** Es la tabla que va en el documento de diseño, la
> presentación y el instructivo. **La clasificación es propuesta mía: Martiniano la confirma antes de
> que salga en un entregable** (afirmar «hecho» de más es el riesgo, no al revés).

## Cómo se contó (reproducible)

- **Operaciones:** salen de `backend/openapi/openapi.yaml`, que declara `x-cu` (a qué CU pertenece) y
  `x-cobertura: parcial` (cuando una operación cubre solo una parte del CU) en cada operación. 91 operaciones
  en el contrato (eran 83 antes de #277 y #279); 90 tienen ruta en `backend/app/routers/` (la que falta es
  `POST /abordajes`, CU-007).
  El script que las cuenta no se versiona; se corre con el Python 3.13 sobre el YAML.
- **Qué falta:** sale de los «Decisiones» y «Pendientes» de `Documentos/Sesiones/PC2/CONTEXTO-*.md`. No se
  agregó nada que esos documentos no digan.
- **Pantalla Flutter:** se comprobó que exista el archivo en `frontend/lib/screens/`. Que exista no prueba
  que se haya probado en un celular.

## Criterio

| Estado | Significa |
|---|---|
| **Hecho** | El flujo principal aprobado en la v1.3 está implementado y probado, sin un pendiente documentado que lo cambie. Pueden quedar pendientes técnicos del propio CU. |
| **Parcial** | Está implementado **recortado** a lo que la v1.3 aprueba, o tiene un pendiente documentado que afecta el flujo. Lo recortado figura en «Qué falta». |
| **Pendiente documentado** | Sin operación en `main`. El motivo y el responsable están escritos; **no se implementó ni se inventó nada**. |

## Resumen

| Estado | Cantidad | CU |
|---|---|---|
| Hecho | 7 | 006, 008, 010, 012, 016, 026, 029 |
| Parcial | 23 | 001, 002, 003, 004, 005, 009, 011, 013, 014, 015, 018, 019, 021, 022, 023, 027, 028, 030, 031, 032, 033, 035, 036 |
| Pendiente documentado | 7 | 007, 017, 020, 024, 025, 034, 037 |

## Tabla por caso de uso

Actor entre paréntesis. «Ops» = operaciones del contrato con ruta. **(c)** = clasificación a confirmar.

| CU | Nombre | Estado | Ops | Flutter | Qué falta (pendiente documentado) |
|---|---|---|---|---|---|
| 001 | Perfil del pasajero | Parcial | 2 | `perfil_screen` | Foto obligatoria, verificación de correo y teléfono con código y perfil «completo» (#25); hoy edita correo, teléfono y dirección sin verificar |
| 002 | Consultar servicios y disponibilidad | Parcial | 3 | `buscar_servicio_screen` | Filtro de destino en texto (400 `FILTRO_NO_DISPONIBLE`) y parada de descenso por reserva (#8); reservar en viaje en curso y recuperar el lugar tras una ausencia (#28) |
| 003 | Crear reserva | Parcial | 1 | `confirmar_reserva_screen` | No calcula tarifa ni genera deuda (RF-028, #9); ida y vuelta del mismo día en una contratación (#7); lista de espera FIFO sin operación (#34); abono, especial y corporativo |
| 004 | Cancelar reserva | Parcial | 1 | `mis_reservas_screen` | Crédito de RN-017, devolución (RN-018) y reintegro (RN-019) sin tabla (#75); cancelación del ocasional fuera de término no definida |
| 005 | Cambiar parada | Parcial | 1 | `cambiar_parada_screen` | Habilitación de la parada **por viaje** (RN-020 aclarada el 15/11, coordinar con #283); la pantalla no se probó contra Render ni en celular |
| 006 | Consultar deuda | **Hecho** | 1 | `pago_screen`, `mis_reservas_screen` | — (la deuda queda en 0 mientras CU-003 no genere el movimiento, #9) |
| 007 | Abordaje por QR | Pendiente | 0 (contrato sí) | — | `POST /abordajes` está en el contrato desde el PC1, **sin ruta**. Offline y sin duplicados (RNF-011/012), preguntas funcionales abiertas. Análisis en `PC2/ANALISIS-CU007.md`. Martín (19/11) propone dejarlo **pendiente documentado para esta entrega**, conservando el diseño y los requisitos offline; una implementación posterior solo online sería explícitamente parcial y no permitiría afirmar que se validó el descenso sin su dato. Falta confirmarlo entre los tres. Estimación de la primera entrega online: 20–35 h |
| 008 | Informar ausencia | **Hecho** | 1 | `ausencias_api.dart` (pantalla a confirmar) | Recuperar el lugar tras una ausencia (AC28-08) pertenece a la disponibilidad (#28), no a este CU |
| 009 | Ubicación del vehículo y ETA | Parcial | 1 | `ubicacion_screen` | ETA de ascenso y destino (propuesta de Martín sin aprobar); el seed no trae coordenadas de paradas; RNF-008 parcial (#39, #273) |
| 010 | Consultar reservas | **Hecho** | 2 | `mis_reservas_screen` | Qué ve el pasajero si su viaje se cancela (sin definir) |
| 011 | Asistente conversacional AG-01 | Parcial | 1 | `asistente_screen` | Conversaciones en memoria (#42); a qué persona se deriva (RF-032); PoC formal TC-01..10 con los modelos actuales (#156); identificación para datos sensibles |
| 012 | Sesión (login y logout) | **Hecho** | 2 | `login_screen` | Pendientes técnicos del propio CU: intentos máximos, bloqueo, expiración y lista negra del token |
| 013 | Gestionar pasajeros | Parcial | 5 | **sin pantalla** | Suspensión y habilitación excepcional (RN-004/005/006, #212), motivo de baja, catálogo de categoría, reservas futuras de un dado de baja |
| 014 | Registrar pago | Parcial | 1 | `pago_screen`, `checkout_pago_screen`, `registrar_pago_admin_screen` | Tipo y evidencia, efectivo con 15 % (RN-011) y señas (#84) |
| 015 | Gestionar deuda | Parcial | 1 | `consultar_deuda_admin_screen` | RN-004/005/006 sin implementar |
| 016 | Confirmar o rechazar pago | **Hecho (c)** | 2 | `pagos_pendientes_screen` | Bloqueo provisional del efectivo hasta definir el 15 % (#84): confirmar si entró |
| 017 | Créditos, devoluciones y reintegros | Pendiente | 0 | — | Depende de RN-017 sin definir (#75). Propuesto a Facundo |
| 018 | Viajes y asignaciones | Parcial | 4 | `viajes_dia_admin_screen`, `crear_viaje_admin_screen` | Conflictos de asignación de chofer y vehículo (pendiente del CU); sobrecapacidad al asignar (PV28-02) |
| 019 | Recorridos y paradas | Parcial | 8 | `recorridos_admin_screen` | Cómo una parada pasa a «comprometida»; sin baja; Martín (18 y 19/11) pide conservar la secuencia relativa con inserciones y no tratar una corrección de nombre como cambio físico; **el código exige hoy el mismo orden y bloquea cualquier cambio de una parada comprometida**. Para esta entrega se conserva la implementación actual y se declaran sus restricciones; no es una regla de negocio aprobada. Cambios de modelo o lógica, solo con acuerdo de los tres (#314) |
| 020 | Optimizar recorrido | Pendiente | 0 | — | Martín (18/11): ya hay una clave de Routes probada y seis coordenadas candidatas cargadas a mano, pero **la prueba de Routes no acredita el CU**. Faltan validación operativa y vial, configuración para esta integración, objetivo de optimización, restricciones de paradas comprometidas y aplicación/persistencia. Pendiente documentado para esta entrega |
| 021 | Gestionar choferes | Parcial | 4 | `choferes_admin_screen` | En `main` por el [PR #279](https://github.com/Martiherenu1/ProyectoVanFull/pull/279) (Facundo, 19/11), declarado PARCIAL en el propio PR: registra, lista, consulta y modifica reutilizando persona y chofer. Sin cuentas ni roles, bajas, estados, alertas ni documentación habilitante. Sin revisión mía previa al merge (revisión solicitada, no hecha) |
| 022 | Gestionar vehículos | Parcial | 4 | `vehiculos_admin_screen` | En `main` por el [PR #277](https://github.com/Martiherenu1/ProyectoVanFull/pull/277) (Facundo, 19/11), «primera entrega» declarada PARCIAL: alta, lista, consulta y modificación con los campos del modelo. Documentación operativa sin persistencia definida; sin reglas de disponibilidad. Sin revisión mía previa al merge |
| 023 | Clientes corporativos | Parcial | 8 | **sin pantalla** | Condiciones comerciales y modalidades de pago (RN-014 sin catálogo), catálogos de estado, corporativo que sea cliente individual |
| 024 | Facturación | Pendiente | 0 | — | Fiscal/ARCA fuera del alcance. Propuesto a Facundo |
| 025 | Reportes y exportación | Pendiente | 0 | — | Reservado al dueño (RN-027); export Excel/PDF y clasificación de reportes sin definir. Propuesto a Facundo |
| 026 | Historial de viajes | **Hecho (c)** | 2 | `historial_viajes_screen` | Historial = finalizados y cancelados con su estado; programados y en curso quedan fuera aunque su fecha haya pasado (respuesta funcional de Martín, 19/11; ajuste en el PR de esta rama, sin aprobación del diff). **Brecha:** un programado o en curso vencido solo se encuentra en `GET /viajes` eligiendo su fecha exacta, no hay vista de vencidos ([#324](https://github.com/Martiherenu1/ProyectoVanFull/issues/324)); retención y eliminación de datos pendiente legal; este CU no borra nada |
| 027 | Consultar reservas (administración) | Parcial | 1 | `consultar_reservas_admin_screen` | Marcado `parcial` en el contrato |
| 028 | Abonos mensuales | Parcial | 5 | `abonos_admin_screen` | Catálogo de estados, advertencia/suspensión/pérdida de cupo (RN-004), habilitación de 5 días, reserva anual (A6); el alta crea el cliente individual si falta: **Martín confirmó la validación funcional del alta el 19/11 (#319)**, sin aprobar el diff ni dar el CU por completo; que el pasajero pida su abono desde la app es otro circuito, no implementado |
| 029 | Consultar operación asignada | **Hecho (c)** | 2 | `viajes_chofer_screen`, `detalle_viaje_chofer_screen` | El contexto aclara que «cierra la consulta, no declara el CU completo»: confirmar el alcance |
| 030 | Ejecutar viaje (GPS, demoras) | Parcial | 7 | `chofer_shell`, `reporte_aviso` | Aviso registrado sin notificar (CU-037); automatismo y horarios por parada sin definir; RNF-008 parcial |
| 031 | Tarifas y descuentos (dueño) | Parcial | 4 | `tarifas_admin_screen` | Descuentos especiales (sin tabla), parámetros, vigencias e historial, efecto sobre saldos (A2/RN-012); sin baja |
| 032 | Administradores (dueño) | Parcial | 5 | `administradores_admin_screen` | Una operación `parcial` en el contrato; política de sesiones; **la cuenta `dueno1` no existe en Neon** |
| 033 | Pasajeros de la organización | Parcial | 4 | **sin pantalla** | Baja (A2, la spec la deja sin precisar), datos permitidos (decisión mía), pasajero en dos empresas, cuenta del pasajero corporativo |
| 034 | Consultar servicio empresarial | Pendiente | 0 | — | Pendiente documentado para el 20/11, acordado con Martín y Facundo ([#308](https://github.com/Martiherenu1/ProyectoVanFull/issues/308)) |
| 035 | Consultar comprobantes | Parcial | 2 | `mis_comprobantes_screen`, `comprobante_detalle_screen` | Descarga y representante corporativo (ACT-03); no hay facturas |
| 036 | Mercado Pago (pruebas) | Parcial | 1 | `checkout_pago_screen` | Producción fuera de alcance; reintentos de webhook sin verificar |
| 037 | Notificaciones | Pendiente | 0 | — | Proveedor de WhatsApp o push sin definir; simulación de Martín 12/12 fuera del repo; pendiente documentado ([#308](https://github.com/Martiherenu1/ProyectoVanFull/issues/308)) |

Operaciones con ruta que el contrato no atribuye a un CU: `GET /tarifas` (pendiente de rehacer, #9),
`POST /pagos/mercadopago/checkout`, `GET /pagos/mercadopago/retorno` y `GET /pagos/{id_pago}`.

## Para decidir antes de entregar

1. **CU-021 y CU-022 ya están en `main`** (Facundo mergeó #277 y #279 el 19/11) y figuran como Parciales,
   como los declara cada PR. Los mergeó sin la revisión que me había pedido; la revisión posterior sigue
   disponible si la querés dejar registrada.
2. **CU-007:** el contrato lo trae, el código no. En la tabla va como pendiente (no hay ruta); en el texto hay
   que decir «contrato declarado, implementación pendiente». Martín propone dejarlo pendiente documentado
   para esta entrega; falta que lo confirmemos los tres.
3. **Los tres «Hecho (c)»** (016, 026, 029) y la clasificación de los 21 parciales.
4. **Pantallas que faltan:** CU-013, 023 y 033 tienen backend y contrato pero ninguna pantalla en Flutter.

Fuentes: `backend/openapi/openapi.yaml`, `Documentos/Sesiones/CONTEXTO.md`,
`Documentos/Sesiones/PC2/CONTEXTO-pasajero-y-base-comun.md`, `…-chofer-y-viaje.md`, `…-administracion-y-flutter.md`.
