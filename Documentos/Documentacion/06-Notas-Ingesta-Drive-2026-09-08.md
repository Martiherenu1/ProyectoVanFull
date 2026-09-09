# Notas de ingesta — archivos nuevos del Drive (2026-09-08)

> Solo lectura y anotación (sin implementar ni modificar nada). Resume qué entendí de los archivos que
> subió Int2/el equipo entre el 01 y el 04/09. Fuente: Drive de martindefez@gmail.com.

---

## 0. Reparto de roles — RESUELTO por Martiniano (2026-09-08)

> **Decisión de Martiniano:** no darle peso a la distribución formal de estos archivos. **Int1 e Int3 se juntan
> y hacen las cosas juntos** (backend + API + integraciones + frontend Flutter + IA/agentes, como veníamos).
> **GitHub/tablero se hace igual** aunque no aparezca asignado en los prompts. Lo de abajo queda solo como
> referencia de lo que dicen los documentos, no como algo a debatir.

### (Referencia) Lo que dicen los documentos nuevos

Los documentos nuevos **redefinen la distribución** respecto del PDF de comparación que habíamos usado.
Según `README_VanFull.md`, `Guia_Integrante_*` y sobre todo los `PROMPT_Integrante_*` (los más recientes, 03/09):

| Integrante | Rol VIGENTE (según docs nuevos) | IA de trabajo asignada |
|---|---|---|
| **Integrante 1** | **Arquitectura técnica, Backend, FastAPI, API/OpenAPI, integraciones, pruebas técnicas** | **Claude / Claude Code** |
| **Integrante 2** | Análisis funcional, Etapa 04 (Modelo/UML) y **DER + Modelo Relacional** | — |
| **Integrante 3** | **Frontend Flutter + IA/agentes** (pantallas, chatbot UI, AG-01, tools) | ChatGPT / Codex |

**Diferencias vs. lo que teníamos anotado:**
1. El **DER/Modelo Relacional es de Int2** (ya lo sabíamos por lo que dijiste; ahora está oficializado en los prompts).
2. El **Frontend Flutter** pasó a **Int3** (antes lo teníamos como "fase posterior"). Ahora es parte explícita del scope.
3. La IA/agentes está en **Int3**, no en Int1.
4. El "Modelo de Desarrollo" (Git/GitHub/tablero/cronograma) que el PDF de comparación ponía en Int3 **ya no aparece
   asignado explícitamente** en los prompts nuevos. → **PENDIENTE DE VALIDACIÓN: ¿quién lo lleva?**
5. El `PROMPT_Integrante_1` está escrito para **Claude/Claude Code** = es, de hecho, el rol que trabajás conmigo.

> Como vos y tu compañero toman **1 y 3 juntos**, la **unión de tareas no cambia demasiado**: backend + API +
> integraciones + frontend Flutter + IA/agentes. Pero conviene **confirmar con el equipo** el reparto vigente y
> quién se ocupa de Git/tablero, y si nuestro `05-Roadmap` debe sumar tareas de **Frontend Flutter** (antes lo
> habíamos dejado para más adelante). No lo resuelvo solo — lo dejo marcado.

---

## 1. DER / Modelo Relacional OFICIAL (carpeta 05)

`VanFull_MR_Entidades_y_Relaciones_Revision_Equipo.md` — **DEFINIDO POR EL EQUIPO. 35 tablas** en 5 bloques.
Es la línea base que **reemplaza a nuestro `03-Modelo-de-Datos-DER-v0.1.md`** (nuestro borrador queda obsoleto).

**Bloques (35 tablas):**
- **Personas, clientes y acceso (12):** PERSONA, PASAJERO, CHOFER, CLIENTE, CLIENTE_INDIVIDUAL,
  CLIENTE_PERSONA_JURIDICA, CLIENTE_CORPORATIVO, CONTACTO_CORPORATIVO, PASAJERO_CORPORATIVO, CUENTA_ACCESO,
  ROL_ACCESO, CUENTA_ROL.
- **Servicios y contratación (6):** SERVICIO, TARIFA, CONTRATACION, ABONO_MENSUAL, PERIODO_ABONO, PERIODO_ABONO_VIAJE.
- **Viajes, recorridos y operación (12):** RECORRIDO, PARADA, PARADA_RECORRIDO, VEHICULO, VIAJE, POSICION_GPS,
  RESERVA, REGISTRO_LISTA_ESPERA, NOMINA_PASAJEROS, INTEGRANTE_NOMINA, ABORDAJE, AUSENCIA.
- **Cuenta corriente, pagos y comprobantes (4):** CUENTA_CORRIENTE, PAGO, MOVIMIENTO_CUENTA, COMPROBANTE.
- **Trazabilidad operativa (1):** EVENTO_OPERATIVO.

**Decisiones de modelado clave (y cómo se comparan con nuestras 5 dudas del v0.1):**
1. **Recurrencia charter → RESUELTA a favor de "materializar RESERVA por VIAJE"** (PERIODO_ABONO_VIAJE define los
   viajes del período; se crea/reactiva una RESERVA por cada VIAJE — MR-R15/R16). **Coincide con mi recomendación.**
2. **Deuda / cupo / saldo → DERIVADOS, no se persisten** (MR-R30). **Coincide con mi recomendación.**
3. **GPS → solo última posición, sin historial** (POSICION_GPS, MR-R31). Coherente con el polling que definimos.
4. **NOTIFICACION → no es entidad persistente** (MR-R32).
5. **PK → identificadores sintéticos numéricos**; tipo físico PostgreSQL diferido (mi duda uuid-vs-bigint queda
   para el modelo físico — la resolvemos nosotros en Etapa 05).
6. **RESERVA** tiene exactamente un respaldo: **PeriodoAbono XOR ContratacionDirecta**; única por (Pasajero+Viaje);
   referencia la parada concreta vía PARADA_RECORRIDO (FKs compuestas de consistencia).
7. **Personas vs Clientes vs Roles:** PERSONA (supertipo) → PASAJERO/CHOFER (subtipos); CLIENTE = INDIVIDUAL **XOR**
   PERSONA_JURIDICA, y CLIENTE_CORPORATIVO como especialización que **coexiste**; Admin/Dueño/Representante son
   **roles de acceso** (CUENTA_ACCESO + ROL_ACCESO + CUENTA_ROL), no subtipos.
8. **Conceptos nuevos que nuestro v0.1 no tenía:** SERVICIO con 4 tipos (UNIVERSITARIO/LABORAL/CORPORATIVO/ESPECIAL);
   CONTRATACION como operación comercial; NOMINA_PASAJEROS/INTEGRANTE_NOMINA para servicios ESPECIALES;
   MOVIMIENTO_CUENTA + COMPROBANTE (Recibo/Factura/NC/ND) con reglas por estado; EVENTO_OPERATIVO.
9. **Decisiones físicas explícitamente diferidas** (nuestras, Etapa 05): tipos SQL, ENUM vs catálogo, índices,
   cascadas, soft-delete, auditoría, timestamps, ORM, almacenamiento de fotos, auth/hash/JWT, DDL.

Otros artefactos del DER: `DER_VanFull_General.drawio` (+ "Sin Paquetes"), `MR_VanFull_General.png`,
`DER General.puml`, `DER Diagrama General.png`.

---

## 2. Casos de Uso OFICIALES (carpeta 03) — Etapa 03 CERRADA

`03_Especificaciones_Casos_de_Uso...md/.docx` (82 KB). **9 actores + 37 casos de uso**, línea base congelada.

**Actores (ACT-01..09):** Pasajero, Pasajero empresarial, Representante corporativo, Chofer, Administrador,
Dueño/Superadministrador, Mercado Pago, WhatsApp, Servicio de mapas/geo/tránsito. (MP/WhatsApp/Maps = sistemas externos.)

**CU-001..037**, agrupados: Pasajero+acceso (CU-001..012, CU-035), Administración (CU-013..028),
Chofer (CU-029, 030), Dueño (CU-031, 032), Corporativo (CU-033..035), Integraciones/Soporte (CU-036, 037).

**Decisiones UML:** ACT-06 (Dueño) **especializa** ACT-05 (Admin); ACT-02 NO especializa ACT-01; sin `<<include>>`;
`CU-036 <<extend>> CU-014`; CU-037 = soporte independiente.

Diagramas: general + 6 vistas parciales (Pasajero, Corporativo, Chofer, Admin operativa, Dueño avanzada, Integraciones), `.puml` + `.png`.
`03_Cierre_Etapa_03.md` cierra la etapa y lista **pendientes trasladados** (campos editables del perfil, gastos
de RN-018, validación offline del QR, auth/seguridad técnica, fallback de mapas/notificaciones, fiscal, auditoría=PROPUESTA).

---

## 3. Etapa 04 — Modelo y UML (carpeta 04)

- `VanFull_Etapa04_Diagramas_PUML.puml` (modelo conceptual + UML aprobados de Etapa 04).
- `Cardinalidades.xlsx`.
- **Subcarpeta "Modelo Conceptual":** PNGs por dominio (Pasajeros/Reservas/Abonos; Clientes/Contratación/Economía;
  Servicios/Viajes/Operación; con y sin notas) + `Notas Modelo Conceptual.txt`.
- **Subcarpeta "Diagramas de Actividad":** DA por CU (CU003 Crear reserva, CU004 Cancelar, CU007 Abordaje QR,
  CU017 Créditos/reintegros, CU018 Viajes/asignaciones, CU020 Optimizar recorrido, CU028 Abonos, CU030 Ejecutar viaje).

*(Los .puml/.drawio/.xlsx y PNGs no los abrí en detalle; anoté su existencia y propósito.)*

---

## 4. Guías y prompts por integrante (raíz)

- `README_VanFull.md` — **índice maestro**: estado por etapa (01, 02, 03 CERRADAS), jerarquía de fuentes,
  qué archivos son fuente vigente y cuáles NO usar (v0.x, "Revision_Equipo" si hay v1.0, históricos), decisiones
  tecnológicas (Flutter/FastAPI/PostgreSQL/Google Maps/MP/OpenRouter/MiniMax+Nemotron), organización del trabajo,
  reglas para IA, estructura de carpetas (incluye `99_Archivo_Historico`), control de cambios, trazabilidad objetivo.
- `Guia_Integrante_1_Backend_API_Datos.docx` — guía operativa de backend: reglas de fuentes, orden de trabajo
  (línea base → modelo de datos → **contrato API antes de implementar** → FastAPI → integraciones → entrega),
  matriz de trazabilidad `CU→RF/RN→endpoint→servicio→datos→prueba`, entregables y checklist de "terminado".
- `Guia_Integrante_3_Frontend_IA.docx` — guía de Flutter + IA: orden Flutter (actores/CU → wireframes → arquitectura
  → mocks → integrar OpenAPI → mapas → QR → notificaciones), orden IA (AG-01, System Prompt, tools por CU, seguridad,
  fallback, WhatsApp, PoC), interfaz Int3↔Int1.
- `PROMPT_Integrante_1_Claude...md` y `PROMPT_Integrante_3_ChatGPT...md` — **prompts maestros** para pegar en el
  entorno de IA de cada rol; fijan rol, jerarquía de fuentes, lista de fuentes a cargar y el trabajo a elaborar.
  El de Int1 dice explícitamente: **"NO vuelvas a diseñar el DER ni el MR; tomalos como entrada"**.

**Nota de proceso relevante para nosotros:** ambos prompts y guías insisten en **definir el contrato OpenAPI ANTES
de implementar**, coordinado entre Int1 (define) e Int3 (consume), usando mocks mientras no exista. Alineado con nuestro roadmap.

---

## 5. Qué implica para nuestro trabajo (solo anotado, sin ejecutar)

- Nuestro **DER v0.1 queda obsoleto** → la referencia es el MR oficial de 35 tablas. (Coinciden nuestras 2 decisiones
  principales: reservas materializadas por viaje y deuda/cupo derivados.)
- Los **CU oficiales (CU-001..037)** son ahora la fuente para derivar endpoints/OpenAPI (EPIC F del roadmap) y tools de AG-01.
- Reparto de roles: **resuelto** (§0) — Int1+Int3 juntos; **Frontend Flutter entra al scope** de nosotros; **GitHub/tablero se hace igual**.
- Nada de esto se implementa aún: pendiente tu OK para pasar a la conciliación/Etapa 05.

---

## 6. Lectura profunda (2026-09-08) — 37 CU + MR + cardinalidades leídos completos

**Qué leí al 100%:** especificaciones de los 37 CU (objetivo, precondiciones, flujos principal/alternativos,
postcondiciones, pendientes), el MR de 35 tablas + 32 restricciones (MR-R01..R32), las 51 cardinalidades y las
notas del modelo conceptual. **No decodifiqué** los `.puml`/`.drawio`/`.png` (son la versión visual del mismo
contenido; si hace falta detalle de atributos por entidad, se decodifica el PUML del DER puntualmente).

### 6.1 Casos de uso — mapa por actor
- **Pasajero (ACT-01):** CU-001 perfil, CU-002 consultar servicios/disponibilidad, CU-003 crear reserva,
  CU-004 cancelar, CU-005 cambio de parada, CU-006 consultar deuda, CU-007 abordaje QR, CU-008 informar ausencia,
  CU-009 ubicación/ETA, CU-010 consultar reservas, CU-011 chatbot, CU-012 sesión (login/logout).
- **Administración (ACT-05, y ACT-06 por especialización):** CU-013 pasajeros, CU-014 registrar pagos,
  CU-015 gestionar deuda, CU-016 confirmar/rechazar pago, CU-017 créditos/devoluciones/reintegros,
  CU-018 viajes+asignaciones, CU-019 recorridos/paradas, CU-020 optimizar recorrido, CU-021 choferes,
  CU-022 vehículos, CU-023 clientes corporativos, CU-024 facturación, CU-025 reportes+export, CU-026 historial,
  CU-027 consultar reservas.
- **Chofer (ACT-04):** CU-029 consultar operación asignada, CU-030 ejecutar viaje (GPS, demoras).
- **Dueño (ACT-06):** CU-031 tarifas/descuentos, CU-032 administradores. (exclusivos del dueño, RN-027)
- **Corporativo:** CU-033 pasajeros de la organización (ACT-03), CU-034 consultar servicio empresarial (ACT-02),
  CU-035 consultar/descargar comprobantes propios (ACT-01/ACT-03).
- **Integración/soporte:** CU-036 Mercado Pago pruebas (`<<extend>> CU-014`), CU-037 notificaciones (disparado por eventos).

### 6.2 Decisiones/hechos clave para la implementación
- **Pagos:** CU-014 registra → **CU-016 confirma/rechaza (humano, RN-015)**. **CU-036 (MP) `<<extend>>` CU-014** y
  NO reemplaza la confirmación humana. El LLM nunca confirma pagos.
- **Chatbot (CU-011):** solo **consultas** (disponibilidad, horarios, recorridos, paradas, tarifas, estado de pago, deuda)
  + derivar_humano (RF-032). **Reservar = CU-003 / Cancelar = CU-004** (tienen flujo alterno "por chatbot", mismas validaciones).
  → Mapa tools AG-01: consultar_* → CU-002/006/011; crear_reserva → CU-003; cancelar_reserva → CU-004; ubicacion → CU-009.
- **Reserva (CU-003):** valida RN-031 (no doble ida/doble vuelta mismo día) → RN-001 (cupo) → RF-028 (tarifa) → estado
  provisional vs consolidado (RN-002). Sin cupo → lista de espera (FIFO). Respaldo **PeriodoAbono XOR Contratacion**.
- **Abordaje QR (CU-007):** offline → registro pendiente, sync ≤60s (RNF-011) sin duplicados (RNF-012). El chofer NO confirma abordaje.
- **GPS (CU-009/CU-030/CU-034):** solo **última posición**; update objetivo cada 10s, precisión ≤50m (RNF-007..010);
  >30s = "desactualizada"; autorización RN-030 (solo vinculados al servicio, durante la prestación).
- **Optimizar recorrido (CU-020):** propone (ACT-09 Maps) respetando paradas comprometidas; admin decide; ≤5s propio (RNF-003).
- **Abonos (CU-028):** solo UNIVERSITARIO/LABORAL; pago días 1-10, adv/susp 11-13, pérdida >13, habilitación excepcional 5 días,
  deuda ≤ 1 mes (RN-006, sin excepción), reserva anual estudiante = pago julio solo ida.
- **Reportes (CU-025):** reservados solo ACT-06 (RN-027); export Excel/PDF.
- **RNF detectados vía CU:** RNF-003 (≤5s optimización), RNF-007..010 (GPS), RNF-011/012 (QR offline). *(El doc de 14 RNF
  no lo leí entero; conviene leer `02_Requisitos_No_Funcionales` y `02_Metricas_RNF` antes de fijar métricas.)*

### 6.3 Pendientes que el equipo dejó abiertos (no inventar)
Campos editables del perfil (CU-001); prioridad lista de espera (CU-003); cancelación ocasional fuera de RN-017 (CU-004);
validación QR offline (CU-007); liberación de cupo por ausencia (CU-008); auth del chatbot para datos sensibles (CU-011);
política de sesiones/seguridad (CU-012/032); conflictos de asignación chofer/vehículo (CU-018); fallback de optimización (CU-020);
clasificación de reportes reservados (CU-025); retención de historial (CU-026); baja corporativa (CU-033); fiscal/ARCA (CU-024/035);
MP técnico —SDK/webhooks— (CU-036); notificaciones —reintentos/fallback— (CU-037). Auditoría = PROPUESTA, no línea base.

### 6.4 Requisitos No Funcionales — 14 RNF leídos completos (todos DEFINIDO POR EL EQUIPO)

`02_Requisitos_No_Funcionales` + `02_Metricas_RNF` (ambos consistentes). Métricas verificables:

| RNF | Métrica aprobada |
|---|---|
| **RNF-001** Disponibilidad | **99 % mensual** (períodos operativos, excluye mantenimiento programado) |
| **RNF-002** Ops habituales | **95 % ≤ 2 s** (condiciones normales, dentro de la concurrencia establecida) |
| **RNF-003** Ops pesadas/integraciones | **≤ 5 s** tiempo propio del sistema (excluye demora del proveedor externo) |
| **RNF-004** Concurrencia mínima | **100 usuarios concurrentes** sin degradar tiempos |
| **RNF-005** Pico de carga | prueba con **hasta 150 usuarios** concurrentes |
| **RNF-006** Escalabilidad | soportar **≥ 2× carga** de referencia sin rediseño estructural |
| **RNF-007** Frecuencia GPS | update objetivo **cada 10 s** (con conectividad/datos) |
| **RNF-008** Vigencia GPS | **> 30 s ⇒ "desactualizada"**, no se muestra como actual |
| **RNF-009** Precisión GPS | objetivo **≤ 50 m** (no garantía absoluta) |
| **RNF-010** Recuperación GPS | conservar última posición + **reanudar automáticamente** al volver la señal |
| **RNF-011** Sync QR offline | intentar sincronizar **≤ 60 s** tras recuperar conexión |
| **RNF-012** Integridad QR offline | **sin duplicados** ante reintentos |
| **RNF-013** RTO | recuperación del servicio **≤ 1 hora** ante fallo grave |
| **RNF-014** RPO | pérdida máxima de datos transaccionales **≤ 15 min** |

**Pendientes fuera de la línea base RNF (no inventar valores):** seguridad/autenticación detallada (sesiones,
recuperación de cuenta, cifrado) → PENDIENTE TÉCNICA/EQUIPO (lo funcional lo cubre RF-045); privacidad/protección
de datos (DNI, fotos, CUIL, contactos, ubicación) → PENDIENTE LEGAL/TÉCNICA; retención de datos → sin plazo fijado;
auditoría de cambios sensibles → **PROPUESTA, no aprobada** como RNF.

→ **Impacto para nosotros:** estas métricas guían tests de carga/rendimiento, el diseño de GPS (polling ~10s calza
con RNF-007), la sync offline del QR, y la estrategia de backups (RPO 15 min / RTO 1 h) en el deploy.
