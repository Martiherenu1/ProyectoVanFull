# Propuesta de modelo — descenso por reserva y paradas habilitadas por viaje (CU-007, punto 1)

**Estado:** PROPUESTA PARA REVISIÓN. No está aprobada por Martín, Facundo ni VanFull, y no implementa nada.
**Issue:** #282 · **Autor:** Martiniano (pasajero y base común) · **Fecha:** 15/11/2026
**Responde a:** punto 1 del mensaje de Martín del 15/11 («descenso previsto por reserva y paradas habilitadas para
ascenso/descenso, coordinando las tablas de Marti»). No toca los puntos 2 a 4 (QR, idempotencia, offline).

## 1. Qué se pide decidir

Dos cambios de modelo, que se pueden aprobar por separado:

- **A. Descenso previsto por reserva:** una columna nueva en `reserva`.
- **B. Paradas habilitadas por viaje:** una tabla nueva (`parada_viaje`), que **suma una tabla a las 35** de la línea
  base. Esto lo tiene que aceptar Martín como dueño del DER.

Recomiendo A y B1 (ver §4). Las decisiones abiertas están en §7, cada una con quién decide.

## 2. Fuentes y su peso

| Fuente | Qué aporta | Peso |
|---|---|---|
| `ACLARACION-FUNCIONAL-CU002-ISSUE8` (AC08-01 a 08) | Destino por pasajero, ascenso y descenso distintos, habilitaciones que varían por viaje, se definen antes de iniciar | Validada funcionalmente por Martín el 18/10. **No** aprueba cambios técnicos |
| `ANALISIS-CU007`, aclaraciones S10 (10/11) | Universitario y laboral eligen destino (UADE/UCA u otra parada habilitada); el descenso real no se controla; Administración o el dueño deciden las habilitaciones | Recuerdo de la entrevista comunicado por Martín. No es una entrevista nueva ni aprobación técnica |
| `ANALISIS-CU007`, Recomendaciones 1 y 2 | `orden_parada_descenso` en `reserva` y una configuración efectiva por viaje | Propuesta de IA, no aprobada. Esta propuesta la toma y la ajusta donde se indica |
| Criterios ratificados por Martín (30/10) | El ascenso real puede ser anterior o posterior al reservado, debe preceder al descenso, y no sobrescribe la reserva | Funcionalmente ratificados |

## 3. Qué hay hoy (verificado el 15/11 sobre `main` `7107233`, lectura estática)

| Elemento | Hoy | Consecuencia |
|---|---|---|
| `reserva` | `orden_parada` (ascenso) con FK compuesta `(id_recorrido, orden_parada)` → `parada_recorrido`. Sin descenso | No hay dónde guardar el destino |
| `parada_recorrido` | `(id_recorrido, orden, id_parada, comprometida)` | `comprometida` no significa «habilitada» |
| `viaje` | `UNIQUE (id_viaje, id_recorrido)`, que ya soporta FK compuestas. Sin configuración de paradas | Una tabla por viaje puede apoyarse en esa clave |
| `abordaje` | Guarda su propio `(id_recorrido, orden_parada)`, separado de la reserva | El ascenso real ya no pisa el reservado |
| `contratacion` / `periodo_abono` | Sin FK a un destino; `condiciones_comerciales` es texto libre | El destino de IDA del abono (AC08-01) **no tiene fuente estructurada** |
| `crear_reserva` y `cambiar_parada` | Solo validan que la parada pertenezca al recorrido (`PARADA_NO_VALIDA`) | No distinguen ascenso de descenso |
| `GET /servicios/disponibilidad?id_parada_destino` | Filtra viajes cuyo recorrido **pasa por** la parada | No persiste el destino ni valida habilitación |
| Seed | 1 recorrido, 3 paradas, 3 viajes de IDA. **Ningún viaje de VUELTA** | El orden de las paradas en VUELTA no se puede verificar con datos (§7, D6) |

## 4. Propuesta A — descenso previsto por reserva

**Cambio:** `reserva.orden_parada_descenso INTEGER NULL`, con FK compuesta `(id_recorrido, orden_parada_descenso)` →
`parada_recorrido (id_recorrido, orden)`. El ascenso reservado (`orden_parada`) no cambia.

**Por qué una columna:** el descenso es 1:1 con la reserva, usa el mismo patrón de FK que el ascenso y no agrega
joins. Una tabla aparte (relación reserva–destino) evitaría el `NULL`, pero suma un join en cada lectura y otra
integridad que mantener, sin ganar nada hoy.

**Qué significa `NULL`:** «sin destino registrado». Nunca se completa con la última parada ni con otro valor deducido.

**Cómo nace el dato, por modalidad:**

| Modalidad | Fuente del descenso | Estado |
|---|---|---|
| Ocasional, IDA | Se elige al reservar (nuevo selector en Confirmar reserva, que parte del destino ya elegido en Buscar) | Propuesto |
| VUELTA (cualquier modalidad) | Se elige al reservar, en cada viaje (AC08-04). No se deriva de la IDA | Propuesto |
| Abono, IDA | Se fija al contratar (AC08-01), pero **no hay fuente estructurada** | Fuera de esta propuesta; hace falta otro PR de modelo (D4). Mientras, queda `NULL` |
| Casual | Si comparte las opciones del laboral | Sin definir con VanFull (D3) |

**Reglas** (en el servicio; ningún `CHECK` nuevo por ahora):

1. El descenso pertenece al recorrido del viaje (la FK lo garantiza; el servicio responde 400 antes).
2. El descenso es posterior al ascenso reservado, en el orden del recorrido del viaje (no se invierte por `sentido`).
3. Si el viaje tiene paradas configuradas (§5), el descenso debe habilitar descenso.
4. El descenso previsto **no es** un descenso real: no se controla ni se registra la bajada (S10).
5. No cambia el cupo, que sigue calculándose por viaje.

**Obligatoriedad escalonada:** opcional en el contrato (cambio aditivo, no rompe clientes ni al asistente). Obligatorio
solo cuando el viaje tiene paradas configuradas y la reserva es ocasional o de VUELTA. Las reservas existentes
quedan en `NULL` y, antes de que CU-007 pueda validar el orden, hay que completarlas con un procedimiento autorizado
(D5). La lectura de la reserva expone el `NULL` explícito; no finge compatibilidad.

**Contrato (aditivo, nombres candidatos):** `ReservaCreate.orden_parada_descenso` (opcional, entero ≥ 1) y
`Reserva.orden_parada_descenso` (nullable). Los rechazos reusarían `400 PARADA_NO_VALIDA` con un motivo en `detalles`
(`fuera_del_recorrido`, `descenso_no_posterior`, `no_habilitada`).

**Efecto sobre CU-005 (mío):** `cambiar_parada` debería rechazar un nuevo ascenso que no sea anterior al descenso o
que no habilite ascenso. Es un cambio de comportamiento de una operación existente (CONTRIBUTING §1.8, acuerdo de
los tres), y se suma a la interpretación de «disponibilidad compatible» de RN-020, que **sigue sin validarse**.

**Efecto sobre AG-01:** la tool `crear_reserva` recibiría un parámetro opcional nuevo. No tocar el prompt hasta
probarlo con el modelo real: #197 mostró que un cambio de prompt puede empeorar el comportamiento.

## 5. Propuesta B — paradas habilitadas por viaje

AC08-07 dice que las habilitaciones **varían de un viaje a otro** aunque usen el mismo recorrido, y que no deben
tratarse como propiedad fija de `PARADA` o `PARADA_RECORRIDO`. Tres alternativas:

| | B1. Tabla `parada_viaje` | B2. Dos booleanos en `parada_recorrido` | B3. Plantilla por recorrido + excepciones por viaje |
|---|---|---|---|
| Cumple AC08-07 | Sí | **No**, salvo duplicar el recorrido por cada variante | Sí |
| Tablas nuevas | 1 (36 en total) | 0 | 2 |
| Complejidad | Baja: una fila por viaje y parada | La más baja | Alta: precedencia entre plantilla y excepción |
| Tablas de la línea base tocadas | Ninguna (solo agrega) | `parada_recorrido` | Ninguna (solo agrega) |

**Recomiendo B1.** B2 es la más barata pero contradice lo validado; B3 resuelve una repetición que hoy no duele.

**Esquema B1 (nombres candidatos):**

```text
parada_viaje (
  id_viaje, id_recorrido, orden,
  habilita_ascenso  BOOLEAN NOT NULL,
  habilita_descenso BOOLEAN NOT NULL,
  PRIMARY KEY (id_viaje, orden),
  FOREIGN KEY (id_viaje, id_recorrido) REFERENCES viaje (id_viaje, id_recorrido),
  FOREIGN KEY (id_recorrido, orden)    REFERENCES parada_recorrido (id_recorrido, orden)
)
```

- **Fila presente = parada configurada** para ese viaje. Un viaje sin filas es un viaje **sin configurar**: no
  significa «todo habilitado» ni «nada habilitado».
- **Viaje sin configurar:** el servicio no valida habilitación (como hoy) y CU-007 no puede validar el orden de
  ascenso y descenso; lo tiene que informar, no inventar opciones.
- **Quién escribe:** Administración o el dueño, antes de iniciar el viaje (AC08-08). La escritura es de Facundo
  (viajes y asignaciones), a confirmar. Esta propuesta **no** define esa operación. Las contingencias de RN-021 en
  curso requieren definición propia.
- **Quién lee:** reservas (yo) y abordajes (Martín). Lectura candidata: opciones de ascenso y descenso de un viaje.
  Falta decidir si es una ruta nueva o una ampliación de `GET /recorridos/{id}/paradas`, que hoy es por recorrido.

## 6. Impacto en la línea base y en el trabajo compartido

- **DER oficial:** B1 pasa de 35 a 36 tablas. CLAUDE.md declara la línea funcional cerrada; el DER y su documento
  oficial en el Drive son de Martín (Int2). Hace falta su aprobación expresa y la actualización de esa documentación.
- **Tests que fijan los números:** `test_migracion.py` y `test_modelos.py` (35 tablas y el total de FK). A y B1 suman
  3 FK (1 de `reserva` y 2 de `parada_viaje`) sobre el total que haya en ese momento.
- **Migración:** una migración nueva por cambio, nunca reescribir la inicial. **No la numero todavía:** #281 propone
  `0002` y no está mergeado. La mía se encadena a la última que entre, porque hay un test que exige una sola cabeza
  y que CU-036 siga fuera del head normal.
- **Seed:** los viajes 1 a 3 quedarían sin configurar. Para probar B hace falta un CSV de `parada_viaje`.
- **Archivos previsibles:** `schema.sql`, `models/viajes.py`, migración, `openapi.yaml` y `.json`,
  `schemas/services/routers` de reservas, `agent/tools.py`; en Flutter `reserva.dart`, `pasajero_api.dart`,
  Confirmar reserva, Mis reservas y la pantalla de cambio de parada.

## 7. Decisiones abiertas

| # | Decisión | Quién decide | Mi recomendación |
|---|---|---|---|
| D1 | Descenso como columna en `reserva` (A) o tabla aparte | Los tres | Columna |
| D2 | Habilitaciones: B1, B2 o B3. Con B1, la tabla 36 en el DER | Los tres; Martín como dueño del DER | B1 |
| D3 | ¿El casual comparte las opciones de destino del laboral? | VanFull, vía Martín | Sin recomendación: no se deduce de que ambos tengan restringido el cambio en curso |
| D4 | Fuente estructurada del destino de IDA del abono (hoy texto libre) | Los tres y VanFull | PR de modelo aparte, después de D2 |
| D5 | Procedimiento autorizado y responsable para completar las reservas sin descenso | VanFull, vía Martín | Administración, antes de validar CU-007 |
| D6 | Orden de las paradas en VUELTA: ¿cada sentido tiene su propio recorrido con su propio orden? | Los tres | Sí, un recorrido por secuencia real. Sin eso la regla «descenso posterior al ascenso» no es confiable. Bloquea el `CHECK` en la base |
| D7 | ¿Agregar `CHECK (orden_parada_descenso > orden_parada)` en la base? | Los tres | No hasta cerrar D6; mientras, la regla vive en el servicio |
| D8 | Cambio de comportamiento de `cambiar_parada` (§4) | Los tres | Sí, con A |

## 8. Cómo se entregaría (cuando se apruebe, un PR chico cada uno)

| PR | Contenido | Dueño propuesto |
|---|---|---|
| 1 | Modelo, `schema.sql`, ORM, migración, contrato aditivo y tests de migración (incluida una reserva previa con descenso `NULL`). **Sin servicios.** Sin cambio de comportamiento: columna `NULL` y tabla vacía | Martiniano |
| 2 | Reservas: guardar y validar el descenso al crear y al cambiar parada; parámetro opcional en AG-01 | Martiniano |
| 3 | Flutter: selector «¿Dónde bajás?» y el dato en Mis reservas | Martiniano |
| 4 | Escritura de `parada_viaje` y seed | Facundo (a confirmar) |
| 5 | Lectura de opciones de abordaje para CU-007 | Martiniano y Martín |

El PR 1 es lo único que Martín necesita para diseñar CU-007 sobre una estructura real. Con el cierre del 20/11 sin
confirmar, no prometo fechas para el resto.

## 9. Qué NO resuelve esta propuesta

Formato y revocación del QR; idempotencia de la operación; cola y sincronización offline; conservación de la unidad
histórica; correspondencia horaria de RN-023; cupo por tramo (hoy es por viaje); servicios especiales (AC08-15/16);
tarifa. Tampoco se registra el descenso real: no se controla (S10).

## 10. Pruebas propuestas (no ejecutadas)

- Migración desde datos previos: una reserva existente queda con descenso `NULL` y la base migrada coincide con `schema.sql`.
- Descenso: del recorrido, igual al ascenso, anterior, posterior; en viaje configurado con la parada sin habilitar descenso.
- Viaje sin configurar: reserva sin descenso aceptada; descenso informado, aceptado y guardado.
- `cambiar_parada` con descenso conocido: ascenso nuevo posterior al descenso, y no habilitado.
- Dos viajes con el mismo recorrido y habilitaciones distintas (PT08-04).
- Concurrencia: el orden de locks pasajero → viaje → reserva no cambia (CONVENCIONES §8).

## 11. Límites de esta propuesta

Lectura estática de `main` `7107233`. No corrí migraciones, pruebas ni código. No releí en el Drive las
especificaciones v1.3 de CU-005 y CU-007, ni RN-001 y RN-023, ni el DER oficial: me apoyo en lo que citan los
documentos del repo. Las aclaraciones S10 son un recuerdo de la entrevista comunicado por Martín. Ningún nombre de
tabla, columna, ruta o código de error es definitivo.
