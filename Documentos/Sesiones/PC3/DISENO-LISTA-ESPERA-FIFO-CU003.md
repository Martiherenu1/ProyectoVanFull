# Diseño — lista de espera FIFO de CU-003 (registro e incorporación)

**Estado:** PROPUESTA DE DISEÑO PARA REVISIÓN. No está aprobada por Martín ni por Facundo y no implementa nada.
**Issue:** #34 · **Autor:** Martiniano (pasajero y base común) · **Fecha:** 15/11/2026
**Qué cierra:** el hueco que REPARTO-PC2 marca en CU-003 («no tiene la lista de espera»).

## 1. Resumen

El Issue #34 planteaba una operación de contrato y dejaba la incorporación FIFO bloqueada por #7, #9 y #33. Al leer el
código aparecen tres cosas que cambian ese cuadro:

1. **Ya no está bloqueada por #7 y #33.** `crear_reserva` ya resuelve al ocasional: una contratación por reserva y
   estado `consolidada`. La incorporación puede reusar ese mismo tramo. #9 (tarifa) sigue fuera, igual que en CU-003.
2. **`registro_lista_espera` no guarda la parada.** Tiene pasajero, viaje, fecha de solicitud y estado. Sin la parada
   de ascenso no se puede crear la reserva al incorporar (`reserva.orden_parada` es `NOT NULL`). **Hace falta un
   cambio de modelo**, que el Issue no veía.
3. **No se puede incorporar dentro de la transacción que libera el lugar** sin romper el orden de locks (§4).

Recomiendo una **primera entrega acotada**: registrarse y ser incorporado cuando alguien **cancela** su reserva
(CU-004). La liberación por ausencia y por cambio de capacidad quedan declaradas como pendientes (§5).

## 2. Qué dice la especificación (citada por el Issue #34; no la releí en el Drive)

- **A1:** sin cupo, el sistema ofrece registrar al interesado en lista de espera; si acepta, queda registrado.
- **A1.1:** al liberarse un cupo toma el registro activo de menor fecha y hora de solicitud (FIFO), **vuelve a
  verificar la disponibilidad** y, si corresponde, registra la reserva con el estado aplicable; el interesado deja de
  estar en la lista.
- FIFO está decidido (CONTEXTO §13, ADJ cerrados). `06-Notas §6.3` todavía lista la «prioridad de lista de espera»
  como pendiente; prevalece el CONTEXTO, que es posterior.

## 3. Qué hay hoy (verificado el 15/11 sobre `main` `7107233`, lectura estática)

| Elemento | Hoy | Consecuencia |
|---|---|---|
| `registro_lista_espera` | `id_pasajero`, `id_viaje`, `fecha_hora_solicitud`, `estado` (default `en_espera`, sin `CHECK`); `UNIQUE (id_pasajero, id_viaje)` | Sin parada ni recorrido |
| Escritores | **Ninguno** en la app. Solo lo lee `services/viajes.py` (Facundo): un registro `en_espera` bloquea cancelar el viaje (`VIAJE_CON_COMPROMISOS`, #180) | La tabla está vacía en la práctica (no verifiqué Neon). Facundo depende del valor exacto `en_espera` |
| Cupo | Derivado, nunca guardado (MR-R30): capacidad menos reservas consolidadas sin aviso de ausencia | No existe un evento «se liberó un lugar»: hay que engancharse en cada operación que libera |
| `crear_reserva` | Valida viaje, parada, RN-031, reserva previa y cupo; responde 409 `CUPO_NO_DISPONIBLE` con `lista_espera: true` | El 409 ya avisa que existe lista, pero no hay a dónde ir |
| `cancelar_reserva` | Locks pasajero → viaje → reserva; calcula `cupo_liberado` | Es el punto de liberación de la primera entrega |
| Flutter | `ReservaRechazada.listaEspera` ya se parsea en Confirmar reserva y no se usa | La pantalla puede ofrecer el botón sin cambiar el adaptador de errores |

## 4. El problema de los locks

CONVENCIONES §8 fija **pasajero → viaje → reserva** y prohíbe pedir un lock anterior después de uno posterior.
`cancelar_reserva` ya tiene al pasajero que cancela (Q) y al viaje. Incorporar al primero de la cola (P) en esa misma
transacción exige el lock de **P después del viaje**: si P hace a la vez `crear_reserva` (pasajero P → viaje), hay
deadlock.

| Alternativa | Cómo | Costo |
|---|---|---|
| **L-A. Después del commit** (recomendada) | La cancelación hace su `commit`. Después, una unidad de trabajo aparte (`promover_siguiente`) toma pasajero(P) → viaje → registro(P), vuelve a verificar y crea la reserva | Hay una ventana corta entre ambos `commit`: una reserva directa puede ganarle el lugar a la cola |
| L-B. En la misma transacción | Leer la cabeza de la cola sin lock, bloquear pasajeros en orden de id, después viaje y reserva, y volver a leer la cabeza | Atómica, pero extiende §8 (orden entre pasajeros), obliga a reintentos y a que Martín y Facundo lo adopten en sus operaciones |

Con **L-A** la promoción es idempotente y reentrante: verifica el estado bajo lock, así que ejecutarla dos veces o
tarde no hace daño. Si el proceso cae entre los dos `commit`, el lugar queda libre y se promueve en la próxima
liberación. No hay tareas de fondo en el hosting gratuito, y esto lo declaro, no lo oculto.

Orden de locks propuesto para el registro, a sumar a §8: **pasajero → viaje → registro**, siempre el registro al
final. Registrarse toma pasajero → viaje; promover toma pasajero(P) → viaje → registro(P).

## 5. Propuesta

### 5.1 Modelo (cambio en una tabla existente; no suma tablas)

`registro_lista_espera` suma `id_recorrido` y `orden_parada` (la parada de ascenso elegida al anotarse), con:
- FK compuesta `(id_viaje, id_recorrido)` → `viaje` (ya existe el `UNIQUE` que la soporta);
- FK compuesta `(id_recorrido, orden_parada)` → `parada_recorrido`.

Es el mismo patrón que `reserva`. Como nada escribe hoy la tabla, no hay datos que migrar, pero eso lo tengo que
confirmar contra Neon antes de decidir `NOT NULL` o nullable.

**Relación con #283 (descenso):** si se aprueba el descenso por reserva, el registro necesitaría también
`orden_parada_descenso`. Conviene decidir #283 primero y hacer **un solo PR de modelo**.

### 5.2 Contrato

- **`POST /viajes/{id_viaje}/lista-espera`** (rol `pasajero`; el id sale del token). Cuerpo: `orden_parada`.
  - `201` con el registro; `200` con el mismo registro si ya estaba en espera (patrón de CU-008, para respuestas perdidas).
  - `404` viaje inexistente. `400` `PARADA_NO_VALIDA`.
  - `409`: hay cupo (se reserva directo), `VIAJE_NO_RESERVABLE`, `RESERVA_DUPLICADA_DEL_DIA`, `RESERVA_CANCELADA_PREVIA`.
    Son las mismas validaciones de `crear_reserva` **menos el cupo**, para no anotar a quien nunca podría ser incorporado.
  - Códigos nuevos candidatos: `CUPO_DISPONIBLE`. Nombres para discusión.
- El `409` de `POST /reservas` deja de decir que la lista no tiene operación.
- `x-cobertura: parcial`: la incorporación solo se dispara al cancelar.

### 5.3 Servicio

- Se extrae de `crear_reserva` una validación común (`todo menos el cupo`) y el tramo que inserta contratación,
  reserva y evento. El registro y la incorporación **reusan** esas piezas; no copian reglas.
- `registrar_en_lista_espera(db, usuario, id_viaje, orden_parada)`.
- `promover_siguiente(db, id_viaje) -> bool`, que repite mientras haya cupo y cola, una transacción por registro:
  1. cabeza de la cola: `en_espera`, por `fecha_hora_solicitud` y después por id;
  2. locks pasajero(P) → viaje → registro(P); relee todo;
  3. si el viaje no está `programado` o el cupo es 0, termina;
  4. si P ya no es elegible (RN-031, reserva previa), **se omite** y se sigue con el siguiente;
  5. crea la reserva `consolidada`, marca el registro y registra un evento sobre la reserva.
- `cancelar_reserva` llama a `promover_siguiente` **después** de su `commit`, solo si `cupo_liberado`. Si la
  promoción falla, la cancelación ya quedó firme y el error no se propaga.

### 5.4 Flutter

- Confirmar reserva: ante `listaEspera` ofrece «Anotarme en la lista de espera» (hoy muestra «Sin cupo» y nada más).
- El texto debe ser **exacto**: «Si otro pasajero cancela su reserva, te reservamos el lugar». No «si se libera un
  lugar», porque la ausencia y el cambio de capacidad no están enganchados (§5.5).
- Mis reservas muestra la reserva incorporada como cualquier otra (refresca al volver).

### 5.5 Qué queda fuera, declarado

| Fuera | Por qué |
|---|---|
| Liberación por **aviso de ausencia** (CU-008, Martín) | El «criterio de liberación de cupo por ausencia» sigue pendiente (CONTEXTO §13) y la liberación es temporal |
| **Cambio de capacidad** al asignar un vehículo (CU-018, Facundo) | Es su servicio; hay que acordarlo con él |
| Aviso al incorporado | CU-037 no está definido. El pasajero lo ve al refrescar Mis reservas |
| Posición en la cola, vencimientos | La v1.3 no los define |
| Asistente (AG-01) | No tiene tool para anotarse; el 409 le llega como hoy |
| Tarifa y deuda | #9, igual que CU-003 |

## 6. Decisiones abiertas

| # | Decisión | Quién decide | Recomendación |
|---|---|---|---|
| L1 | Primera entrega: registro + incorporación solo al **cancelar** | Los tres | Sí |
| L2 | Incorporar después del commit (L-A) o en la misma transacción (L-B) | Los tres, porque toca §8 | L-A |
| L3 | Equidad: aceptar la ventana de L-A, o bloquear reservas directas mientras haya cola | Los tres | Aceptar la ventana. Bloquear obliga a definir qué pasa con registros que nunca se pueden incorporar |
| L4 | Estado al incorporar: valor nuevo (`incorporado`) o borrar la fila | Facundo debe confirmar | `incorporado`: conserva la evidencia FIFO y su código solo cuenta `en_espera` |
| L5 | Registro no incorporable: se omite y sigue `en_espera` (puede trabar la cancelación del viaje, #180) | Facundo | Omitir, y avisarle |
| L6 | Registro repetido: `200` con el mismo registro o `409` | Los tres | `200` |
| L7 | **Salir de la lista** y **ver que se está en ella**: la v1.3 no los define | Los tres; VanFull si hace falta | Segundo PR. Mientras, el pasajero incorporado puede cancelar sin penalidad (hoy no hay) |
| L8 | Cambio de modelo en `registro_lista_espera` (§5.1) y su relación con #283 | Los tres; Martín como dueño del DER | Un solo PR de modelo, después de decidir #283 |
| L9 | Enganchar la **ausencia** y la **capacidad** | Martín / Facundo, y VanFull para la ausencia | Fuera de la primera entrega |

## 7. Entrega propuesta (un PR chico cada uno, cuando se apruebe)

| PR | Contenido |
|---|---|
| 1 | Modelo, `schema.sql`, ORM, migración, contrato y tests de migración. Sin servicios |
| 2 | Servicio: validación común extraída, registro y `promover_siguiente`, enganche en `cancelar_reserva`; locks documentados en §8; pruebas de concurrencia |
| 3 | Flutter: botón y texto exacto |
| 4 | Salir de la lista y verla (L7) |

## 8. Pruebas propuestas (no ejecutadas)

- Registro: sin cupo (201), con cupo (409), repetido (200), viaje no reservable, duplicado del día, cancelada previa, parada ajena.
- FIFO: tres anotados en orden; se libera un lugar; entra el primero. Dos lugares liberados: entran los dos primeros.
- El primero no es elegible: se omite y entra el segundo.
- Cancelar dos reservas a la vez: sin doble incorporación ni deadlock.
- Incorporar a la vez que una reserva directa toma el último lugar: no se supera la capacidad.
- Incorporar contra el inicio del viaje: no se crea reserva si dejó de estar `programado`.
- La cancelación firme aunque la promoción falle.
- `cupo_liberado = false` (provisional, o ausencia ya avisada): no promueve.

## 9. Límites de este diseño

Lectura estática de `main` `7107233`. No corrí nada. **No releí A1 y A1.1 en el Drive**: me apoyo en lo que cita el
Issue #34. No verifiqué si Neon tiene filas en `registro_lista_espera`. Ningún nombre de columna, ruta o código es
definitivo. La ventana de L-A y el hecho de que no haya tareas de fondo son límites reales de la primera entrega.
