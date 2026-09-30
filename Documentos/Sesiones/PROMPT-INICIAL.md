# Prompts de arranque por tipo de tarea

> **Para qué sirve.** Copiar y pegar el bloque que corresponda al empezar un chat nuevo de Claude Code sobre
> esta carpeta. `CLAUDE.md` ya se carga solo; estos prompts agregan **solo lo de esa tarea** y, sobre todo,
> dicen **qué no hay que leer**, que es lo que evita que se gasten 45.000 tokens en ubicarse.

---

## La estructura, si tenés que armar uno nuevo

```
Tarea: <una frase, en infinitivo>

Leé: <los 1-3 archivos imprescindibles>
No leas: <lo que la tarea NO toca>

Estado que importa: <una o dos líneas, o "está en CONTEXTO.md">
Restricciones: <lo que no se puede tocar en esta tarea>
Cierre: <qué tiene que quedar hecho y verificado>
```

Cinco líneas alcanzan. Un prompt inicial largo es el mismo problema que quiere resolver.

---

## 1 · Documentación y entregables

```
Tarea: <qué documento o sección actualizar>.

Leé: Documentos/Sesiones/CONTEXTO.md y el documento que vamos a tocar.
No leas: backend/, frontend/, ni los otros documentos salvo que aparezca una contradicción.

Restricciones: no modificar cantidades ni identificadores de RF/RNF/RN/CU/actores/tablas.
Si un número no cierra, avisame antes de cambiarlo.

Cierre: mostrame el diff antes de commitear. Si el documento tiene copia en el Drive,
decime qué archivo tengo que subir y a qué carpeta.
```

## 2 · Revisión cruzada de Integrante 2

```
Tarea: aplicar la revisión que me pasó Int2. Te la pego abajo.

Leé: Documentos/Sesiones/CONTEXTO.md y solo los archivos que la revisión nombra.
Primero hacé `git fetch` y mirá si pusheó algo que yo no tenga.

Restricciones: su revisión puede estar escrita con información vieja. Antes de aplicar cada punto,
verificá el estado real y decime si alguno ya está hecho o ya no corresponde.

Cierre: informe con archivos modificados, commits, validaciones corridas con su resultado,
SHA final de main, y qué queda pendiente y de quién.

<pego acá su mensaje>
```

## 3 · Interfaces gráficas (artifact de diseño)

```
Tarea: <qué pantalla y qué cambio>.

Leé: Documentos/Documentacion/08-Brief-de-Diseno-UI.md y §10 de CONTEXTO.md (tiene los links).
No leas: el documento del MVC ni backend/.

Restricciones: respetá los tokens y las prohibiciones del brief. Las pantallas no pueden afirmar
reglas de negocio que no estén en los 31 RN aprobados; los datos son ilustrativos.
Toda pantalla que cambie me obliga a re-exportar el PDF y volver a subirlo: juntá todos los
cambios de pantallas en una sola publicación.

Cierre: decime qué pantallas cambiaron y si hay que re-exportar el PDF del Anexo 4.
```

## 4 · Backend — código

```
Tarea: <capa y dominio, p. ej. "models/ del bloque de viajes y reservas">.

Leé: backend/db/schema.sql (o la parte que corresponda), backend/openapi/openapi.yaml,
y §3 y §11 de CONTEXTO.md.
No leas: Documentos/Documentacion/ salvo el 07 si la tarea toca al agente.

Restricciones: el orden es models → services → routers → tests, no adelantarse.
Las reglas de negocio van en services/, nunca en routers/ ni en el frontend.
El contrato OpenAPI manda: si hay que cambiarlo, avisame primero.

Cierre: explicame qué hace cada archivo nuevo antes de commitear. Si no podés correr
los tests en esta máquina, decilo explícitamente en vez de suponer que pasan.
```

## 5 · Frontend Flutter

```
Tarea: <qué pantalla implementar>.

Leé: 08-Brief-de-Diseno-UI.md (tokens y densidades), el .dc.html de esa pantalla en el artifact,
y el endpoint que usa en backend/openapi/openapi.yaml.
No leas: el resto de las pantallas ni Documentos/Documentacion/10.

Restricciones: el frontend no decide reglas. Validación de forma, sí; cupos, permisos y pagos, no.
Las densidades por actor son 48 / 64 / 36 px, no las unifiques.

Cierre: mostrame el widget antes de commitear.
```

## 6 · Consulta, sin cambios

```
Pregunta: <la pregunta>.

Leé solo lo necesario para contestar y decime en qué archivo lo encontraste.
No modifiques nada. Si la respuesta no está escrita en el repo, decí que no está
en vez de inferirla.
```

---

## Cuándo abrir un chat nuevo

**Sí, chat nuevo:**

- Cambia el conjunto de archivos (documentación → backend, backend → artifact de diseño).
- Se cerró un entregable: se pusheó, se subió al Drive, se presentó.
- Cambia la superficie de herramientas (Drive y Word → pytest y Docker → publicar el artifact).
- **Se compactó el contexto.** Seguí hasta el próximo corte natural y ahí cortá.

**No, seguí en el mismo:**

- `models/` → `services/` → `routers/` del mismo dominio.
- Rondas sucesivas de revisión de Int2: el cruce entre rondas es el valor.
- Preguntas de seguimiento sobre lo que se acaba de hacer.
- Un bug en algo que se tocó en esa misma sesión.

**La señal de que ya te pasaste:** Claude vuelve a leer un archivo que ya leyó en esa sesión, o te pregunta
algo que ya le dijiste. Ahí se perdió detalle en la compactación y conviene cortar.

---

## Mantenimiento

| Cuándo | Qué |
|---|---|
| Al cerrar cada sesión | Actualizar `CONTEXTO.md`: estado, decisiones nuevas, pendientes que se cerraron |
| Cuando se logra algo contable | Una línea en `HITOS.md` |
| Cuando un dato de entorno cuesta descubrirse | Agregarlo a `CLAUDE.md` |
| Cuando un pendiente se decide | Sacarlo de los pendientes de `CONTEXTO.md` y anotarlo como cerrado |
| Cuando `CONTEXTO.md` pase de ~250 líneas | Podarlo: es un documento de arranque, no un historial |

**La regla que sostiene todo esto:** un dato vive **en un solo lugar**. Si el mismo número está en tres
documentos, en algún momento dos van a estar mal — y eso ya pasó en este proyecto con las 11 tools, los
22 schemas y el flujo del QR.
