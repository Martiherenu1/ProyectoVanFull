# Prompt · Contexto vivo (para Facundo y Martín, y para cualquier agente del equipo)

> Es un **complemento** del prompt PC2 de cada uno, no lo reemplaza. Se pega como un mensaje más en el chat
> donde ya está corriendo el agente (o se suma al principio del prompt PC2 si todavía no empezó). Es el mismo
> comportamiento que sigue el agente de Martiniano.

```text
CONTEXTO VIVO: cómo mantenés el contexto del proyecto mientras trabajás

Además del método de CONTRIBUTING.md, vas a llevar un archivo de contexto de mi área y lo vas a mantener
al día vos, sin que te lo pida cada vez. La razón: tres personas y tres agentes trabajan en paralelo, y
lo que no queda escrito en el repositorio se pierde cuando se cierra el chat.

1. DÓNDE VIVE EL CONTEXTO (en el repo, no en la memoria del chat)
   - CLAUDE.md y CONTRIBUTING.md: reglas y método. No se tocan desde una tarea de área.
   - Documentos/Sesiones/CONTEXTO.md: contexto general del proyecto. Cambia poco y se toca solo con un PR
     de docs chico y aparte.
   - Documentos/Sesiones/PC2/CONTEXTO-<mi-área>.md: el contexto VIVO de mi área. Es tuyo para mantener.
       · Martín:  CONTEXTO-chofer-y-viaje.md
       · Facundo: CONTEXTO-administracion-y-flutter.md
     Si no existe, lo creás en tu primera tarea. Hay un ejemplo en CONTEXTO-pasajero-y-base-comun.md.
   Si tu herramienta tiene memoria propia, ahí van mis preferencias de trabajo; el estado del proyecto
   va en el repo, que es lo que ven los otros dos.

2. QUÉ LLEVA (secciones fijas, en este orden)
   - Estado: dos o tres líneas, con fecha absoluta (no "ayer").
   - Hecho: lo que ya está en main, con el número de PR.
   - En curso: rama, Issue y qué falta.
   - Decisiones: fecha, qué se decidió, quién, por qué, y dónde quedó registrada (PR o Issue).
   - Pendientes: cada uno con su Issue. Lo que no se pudo verificar va marcado "SIN VERIFICAR".
   - Entorno y trampas: lo que costó descubrir (comandos, versiones, errores que se repiten).
   - Para otras áreas: qué endpoints o pantallas mías ya se pueden usar, y qué necesito de las demás.

3. CUÁNDO SE ACTUALIZA
   - Al empezar la sesión: lo leés y lo contrastás con el repo (git log, gh pr list, gh issue list). Si el
     archivo dice una cosa y el código otra, manda el código y corregís el archivo.
   - En el mismo PR que cambia algo: el último commit de la rama es docs(contexto): ... con lo que cambió.
     No esperes al cierre de la sesión: se olvida, y el revisor no lo ve.
   - Al cerrar la tarea: en el informe final decime qué secciones actualizaste.

4. QUÉ NO ESCRIBÍS
   - Lo que el repo ya registra: el código, el historial de git, la estructura de schema.sql.
   - Claves, tokens o contraseñas, ni siquiera de prueba.
   - Nada inventado: reglas, campos o rutas que no estén en la línea base. Si es una duda, es un pendiente
     con su Issue, marcado PENDIENTE DE VALIDACIÓN.
   - Un historial. Es un documento de arranque: tope de unas 150 líneas. Lo cerrado se resume en una línea
     o se borra.

5. REGLAS PARA NO PISARSE
   - Solo editás el contexto de tu área. Los de las otras dos los leés para integrar, pero no los tocás.
   - Si un dato cruza áreas (un endpoint nuevo, un cambio de contrato), lo escribís en tu archivo y abrís un
     Issue para el dueño del otro lado. No edites su archivo.
   - Lo que cambia CONTEXTO.md o CONTRIBUTING.md se propone en un PR de docs aparte (rama docs/...), no
     adentro de una tarea de código.
   - Estos archivos pasan por el mismo ciclo: me mostrás el diff y esperás mi visto bueno antes de commitear.

6. TRAMPAS DE ENTORNO QUE YA APARECIERON (sumá las tuyas al archivo)
   - Docker Desktop tiene que estar abierto: si el motor está apagado, ruff, pytest y la base no corren.
   - ruff format sobre todo el directorio reformatea archivos de otros. Corrélo solo sobre los archivos de
     tu tarea.
   - En Git Bash de Windows, git show origin/main:ruta/archivo falla por la conversión de rutas. Usá
     MSYS_NO_PATHCONV=1.
   - Los números de Issue son los que da GitHub, no el orden en que los listaste: verificalos con
     gh issue list antes de citarlos en un PR o en un archivo de contexto.
```

## Por qué existe

- **Evita que el estado dependa de un chat.** Hasta ahora se actualizaba `CONTEXTO.md` "al cerrar la sesión", y
  con tres personas editando el mismo archivo se pisan y se desactualiza.
- **Un archivo por área** elimina los conflictos de merge: cada uno edita solo el suyo.
- **Actualizar en el mismo PR** hace que la revisión incluya el contexto.
- Los tres agentes parten de las mismas reglas y dejan el mismo tipo de rastro, así que cuando integren la demo
  cruzada pueden leer lo que cada área ofrece sin preguntarle a nadie.

## Para decidir (Martiniano)

Si el equipo lo acepta, la regla "un archivo de contexto por área, actualizado en el mismo PR" debería quedar
en `CONTRIBUTING.md`, porque es lo único que obliga a los tres. Es un cambio al método: según §1.8 lo propone un
PR y lo revisa el equipo.
