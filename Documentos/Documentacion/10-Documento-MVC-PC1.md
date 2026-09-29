# VanFull — Documento con el MVC

**Trabajo de Campo · Proyecto Integrador con IA y Agentes**

Licenciatura en Sistemas | Ingeniería en Informática

**Primer Punto de Control — Análisis, Diseño y Planificación**

Entrega: 28 de septiembre de 2026 · Versión 1.0

**Equipo:** Integrante 1 · Integrante 2 · Integrante 3

Repositorio del proyecto: https://github.com/Martiherenu1/ProyectoVanFull

---

## Estado de este documento

Este borrador tiene las secciones de fondo escritas. **Lo que falta está marcado en amarillo a lo largo del
documento**, y es esto:

| Qué falta | Dónde | Quién |
|---|---|---|
| Escribir la sección completa | 1 · Presentación general | Integrante 2 |
| Pegar la imagen del diagrama de arquitectura | 2.4 | Integrante 3 |
| Pegar los diagramas C4 y de casos de uso | 2.5 | Integrante 2 |
| Pegar el diagrama Entidad-Relación | 3.2 | Integrante 2 |
| Pegar la lámina de colores y tipografía | 4.2 | Integrante 3 |
| Pegar las diez capturas de pantalla | 4.3 | Integrante 3 |
| Pegar el cronograma de las 16 semanas | 7.5 | Equipo |

Son **siete cosas**, y seis de las siete son pegar algo que ya existe.

---

## Índice

1. Presentación general del Proyecto
2. Arquitectura de la solución
3. Modelo — Datos y relaciones
4. Vista — Interfaces gráficas
5. Controlador — La comunicación entre la pantalla y el servidor
6. Modelos de IA y agentes
7. Modelo de desarrollo
8. Anexos
9. Guía para la presentación

---

## Dónde está cada cosa que pide la consigna

| Lo que pide la consigna | Sección |
|---|---|
| Presentación general del Proyecto | 1 |
| Alcances y Límites | 1.4 |
| Arquitectura de la solución | 2 |
| Modelo Conceptual: Frontend, Backend, Base de Datos | 2.2 |
| Gráficos: UML y C4 Model | 2.5 |
| Modelo en mermaid.js | 2.4 |
| Modelo de Datos y relaciones | 3 |
| Modelo de datos SQL | 3.4 y Anexo A |
| Interfaces gráficas | 4 |
| Comunicación V-C: Open API en formato JSON | 5 y Anexo B |
| Modelos de IA utilizados y justificación | 6.1 |
| Agentes IA implementados | 6.2 |
| Prompts | 6.3 |
| Modelo de Desarrollo | 7 |

---

# 1. Presentación general del Proyecto

> FALTA — Integrante 2. Esta sección se escribe con el material que ya está en las carpetas 00, 01 y 02 del Drive. Hay que cubrir los cuatro puntos que nombra la consigna: 1.1 Objetivos, 1.2 Antecedentes, 1.3 Justificación y 1.4 Alcances y límites.

Guía de qué va en cada punto:

**1.1 Objetivos.** Qué se propone lograr el sistema.

**1.2 Antecedentes.** VanFull es una empresa real de transporte de pasajeros en combi. Hoy trabaja con
**WhatsApp, Excel y teléfono**: el pasajero avisa por mensaje que no viaja, el administrador anota a mano
quién pagó, y el chofer sube a la combi con la lista impresa. Conviene contar esto con detalle, porque es lo
que hace que el proyecto no parezca un ejercicio inventado. El material está en la entrevista y el
relevamiento de la carpeta 01.

**1.3 Justificación.** Qué problemas concretos resuelve centralizar todo esto en un sistema.

**1.4 Alcances y límites.** Resumen de los **45 requisitos funcionales, 14 requisitos no funcionales y 31
reglas de negocio**, y sobre todo **qué queda afuera** de esta primera versión.

---

# 2. Arquitectura de la solución

## 2.1 Visión general

VanFull es una aplicación **Web y Mobile**. El usuario usa una aplicación en su celular o en la computadora,
esa aplicación le pide los datos a un servidor, y el servidor los guarda en una base de datos. Es la
arquitectura **cliente-servidor**, organizada en capas.

| Parte | Con qué está hecha | De qué se encarga |
|---|---|---|
| La aplicación (Web y Mobile) | Flutter | Mostrar la información y recibir lo que el usuario hace |
| El servidor | Python con FastAPI | Verificar permisos, aplicar las reglas del negocio y coordinar todo |
| La base de datos | PostgreSQL | Guardar los datos sin que se corrompan |
| El asistente conversacional | OpenRouter (MiniMax M3 y Nemotron) | Entender lo que el usuario escribe en lenguaje común |
| Mapas y recorridos | Google Maps | Calcular distancias y tiempos de llegada |
| Cobros | Mercado Pago | Cobrar y avisar cuando el pago se acreditó |
| Mensajería | WhatsApp | Canal alternativo de atención |

Flutter permite escribir **una sola vez** la aplicación y que funcione tanto en el navegador como en el
celular, que era un requisito del proyecto.

## 2.2 Modelo conceptual: Frontend, Backend y Base de Datos

**Frontend (lo que el usuario ve).** La aplicación hecha en Flutter. **No toma decisiones importantes.**
Valida que un campo no esté vacío y muestra las cosas ordenadas, pero si hay lugar en una combi o si un
pasajero puede cancelar una reserva **no se decide en el celular**, se decide en el servidor.

**Backend (el negocio).** El servidor hecho con FastAPI. Está dividido en cuatro capas, cada una con un
trabajo distinto:

- **Routers:** reciben el pedido que llega de la aplicación y lo derivan. No tienen lógica propia.
- **Schemas:** definen qué datos entran y qué datos salen, y verifican que tengan la forma correcta.
- **Services:** acá viven **las 31 reglas de negocio**. Es el corazón del sistema.
- **Models:** la única capa que le habla a la base de datos.

La ventaja de separarlo así es que si mañana cambia una regla, se cambia en un solo lugar.

**Base de datos.** PostgreSQL, con 35 tablas. Todo lo que se puede prohibir desde la base misma se prohíbe
ahí, de modo que **un dato incorrecto no pueda guardarse aunque el programa tenga un error**. El detalle está
en la sección 3.

## 2.3 El mapeo MVC

El patrón **Modelo-Vista-Controlador** organiza un sistema separando los datos, lo que se ve y lo que
coordina. En VanFull queda así:

| Capa | Qué es en VanFull |
|---|---|
| **Modelo** | La base de datos PostgreSQL y las reglas de negocio que la gobiernan |
| **Vista** | La aplicación Flutter, en sus tres versiones según quién la use |
| **Controlador** | El servidor FastAPI, que recibe los pedidos y decide qué responder |

El asistente de inteligencia artificial **no es una cuarta capa**: se apoya sobre el Controlador y usa
exactamente los mismos caminos que usa la aplicación.

## 2.4 La decisión más importante: la IA no toca la base de datos

**El asistente de IA no puede acceder a la base de datos.** Interpreta lo que el usuario pide y elige una
herramienta; después **el servidor verifica y ejecuta**.

La razón es que un modelo de inteligencia artificial **no es predecible**: ante la misma pregunta puede
contestar distinto cada vez, y alguien podría intentar engañarlo escribiéndole instrucciones disfrazadas
dentro de un mensaje. Si el modelo tuviera acceso directo a los datos, un mensaje bien armado podría
conseguir un lugar en una combi llena o dar un pago por cobrado.

Poniéndolo detrás del servidor, **el modelo puede equivocarse todo lo que quiera y el sistema sigue siendo
correcto**, porque quien decide es el servidor.

**Diagrama de la arquitectura (hecho en mermaid.js):**

```
flowchart TB
    subgraph Vista
        A[App Flutter<br/>Web y Mobile]
        W[WhatsApp]
    end
    subgraph Controlador
        R[FastAPI - routers]
        S[services<br/>31 reglas de negocio]
        CH[POST /chat<br/>orquestador]
    end
    subgraph Modelo
        DB[(PostgreSQL<br/>35 tablas)]
    end
    LLM[OpenRouter<br/>MiniMax / Nemotron]
    MP[Mercado Pago]
    GM[Google Maps]

    A --> R
    W --> CH
    A --> CH
    CH --> LLM
    LLM --> CH
    CH --> S
    R --> S
    S --> DB
    S --> MP
    S --> GM
    LLM -.->|sin acceso| DB
```

> FALTA — Integrante 3. Copiar ese código en la página mermaid.live, exportar la imagen y pegarla acá. El código puede quedar debajo de la imagen.

## 2.5 Diagramas C4 y de casos de uso

> FALTA — Integrante 2. Pegar acá los diagramas que ya están en la carpeta 05 del Drive: el C4 de Contexto y el C4 de Contenedores, cada uno con dos o tres renglones explicando qué muestra. Y de la carpeta 04, los diagramas de casos de uso por actor y los de actividad de los flujos principales.

## 2.6 Requisitos que condicionaron la arquitectura

Algunos requisitos no funcionales obligaron a tomar decisiones concretas:

| Requisito | Medida exigida | Qué obligó a hacer |
|---|---|---|
| Disponibilidad | 99% | Tener un segundo modelo de IA de respaldo |
| Velocidad de respuesta | 95% de las operaciones en 2 segundos o menos | Calcular ciertos valores en el momento en vez de guardarlos |
| Usuarios simultáneos | 100 al mismo tiempo, probado con 150 | Un servidor que atiende varios pedidos a la vez sin bloquearse |
| Seguimiento por GPS | Actualizar cada 10 segundos; avisar si el dato tiene más de 30 | La aplicación le pregunta al servidor cada 10 segundos |
| Abordaje sin señal | Sincronizar en menos de 60 segundos y sin duplicados | Guardar en el teléfono del pasajero y que la base rechace repetidos |
| Recuperación ante fallas | Volver a funcionar en 1 hora, perder como máximo 15 minutos de datos | Política de copias de seguridad |

---

# 3. Modelo — Datos y relaciones

## 3.1 Panorama

El modelo de datos tiene **35 tablas**, agrupadas en cinco bloques:

- **Personas, clientes y acceso:** personas, pasajeros, choferes, clientes y los permisos de cada cuenta.
- **Servicios y contratación:** los servicios que ofrece la empresa, las tarifas, los abonos mensuales.
- **Viajes, recorridos y operación:** recorridos, paradas, vehículos, viajes, reservas, abordajes y ausencias.
- **Cuenta corriente y pagos:** la cuenta de cada cliente, los pagos y los comprobantes.
- **Operación y auditoría:** el registro de lo que va pasando y las nóminas de pasajeros.

## 3.2 Diagrama Entidad-Relación

> FALTA — Integrante 2. Pegar el diagrama Entidad-Relación que ya está en la carpeta 05 del Drive, con una explicación de las relaciones principales.

## 3.3 Decisiones de diseño

Más allá de la lista de tablas, el modelo toma cinco decisiones que vale la pena explicar, porque son las que
evitan que se guarden datos incorrectos.

**Que una reserva no pueda apuntar a una parada equivocada.** Una reserva no guarda "el viaje" y "la parada"
por separado, sino la combinación de las dos. Así **la base misma impide** que alguien reserve en una parada
que no pertenece al recorrido de ese viaje. Si estuvieran separadas, esa coherencia dependería de que el
programa nunca se equivoque.

**Que toda reserva tenga un respaldo, y uno solo.** Una reserva se respalda **o** con un abono mensual **o**
con una contratación directa, nunca con las dos ni con ninguna. Está escrito como una condición dentro de la
base, así que es imposible guardar una reserva sin respaldo.

**Una reserva y un abordaje por viaje.** Un pasajero puede tener como mucho una reserva en cada viaje, y
puede abordar una sola vez. Esta segunda regla es la que hace que **el escaneo del código QR funcione sin
señal**: aunque el teléfono del pasajero mande el mismo abordaje dos veces cuando vuelve la conexión, la
base lo rechaza. No hay que programar nada para evitar el duplicado.

**Lo que a propósito no se guarda.** El saldo de la cuenta, la deuda de un pasajero y los lugares
disponibles de un viaje **no son columnas de la base**: se calculan cuando se necesitan. Guardarlos sería
crear una segunda versión de la verdad que tarde o temprano deja de coincidir con los pagos y las reservas
que la originan. Cuesta un cálculo por consulta, pero **el dato nunca puede estar mal**.

**Los permisos se manejan con tablas propias.** Los roles de usuario no son roles del motor de base de datos,
sino tablas del sistema. Por dos razones: los pasajeros no son usuarios de PostgreSQL, y los permisos
dependen del contexto — un chofer ve la lista **del viaje que tiene asignado**, no de todos. Eso no se puede
expresar con los permisos del motor.

## 3.4 El modelo de datos en SQL

El modelo se tradujo a un archivo SQL que crea las 35 tablas, las **54 relaciones entre tablas** y todas las
condiciones descritas arriba.

**Y se probó de verdad:** el archivo se ejecutó contra una base PostgreSQL real. Se verificó que las 35
tablas y las 54 relaciones se crearan correctamente, y se comprobó que la base **rechaza los datos
inválidos** — al intentar cargar un tipo de servicio que no existe, lo rechaza la base, no el programa.

El archivo completo está en el **Anexo A**.

---

# 4. Vista — Interfaces gráficas

## 4.1 Tres personas distintas usan el sistema en situaciones distintas

Las pantallas de VanFull no salieron de una plantilla. Salieron de preguntarse **dónde está parada cada
persona cuando usa el sistema**.

| | Pasajero | Chofer | Administrador |
|---|---|---|---|
| Dónde está | Caminando a la parada | Parado en la puerta de la combi | Sentado en un escritorio |
| A qué hora | 6 de la mañana | 6:05, con la combi llenándose | Todo el día |
| Manos libres | Una, apurado | Una, la otra ocupada, quizá con guantes | Las dos, con mouse y teclado |
| Luz | Oscuro o sol directo | Sol directo | Interior |
| Señal | Puede ser mala | **Puede no haber** | Buena |
| Qué necesita saber ya | ¿Cuánto falta para que llegue? | ¿Ya subieron todos? | ¿Qué problema hay hoy? |
| Fondo de pantalla | Oscuro | Oscuro | Claro |
| Alto de cada fila | 48 puntos | **64 puntos** | 36 puntos |

De acá salen las decisiones concretas: **los botones del chofer son más grandes** porque los toca parado y
con una sola mano; **la pantalla del pasajero funciona sin señal** al momento de abordar, porque en la ruta
a veces no hay; y **el panel del administrador es más compacto** porque necesita ver seis viajes juntos.

**Si las tres pantallas se parecieran entre sí, el diseño estaría mal.** Que sean distintas es el resultado
de haber mirado el problema.

## 4.2 Colores y tipografía

Antes de dibujar las pantallas se definieron los colores y las tipografías, para que todas las pantallas
sean consistentes entre sí.

**Los colores salen de la marca real de la empresa.** Se tomaron del logotipo y de la foto de la combi
rotulada: el dorado de las letras, el gris del contorno y el blanco de la carrocería. No son colores
elegidos por gusto.

**Se verificó que todos los textos se lean.** Se midió el contraste de cada combinación de color contra el
estándar de accesibilidad. La verificación encontró tres combinaciones que **no se leían bien** y quedaron
prohibidas o corregidas: texto blanco sobre dorado, el dorado como texto sobre fondo claro, y los colores de
estado, que necesitaron un valor distinto según el fondo sea claro u oscuro.

> FALTA — Integrante 3. Pegar acá la lámina con la paleta de colores y la escala de tipografías.

## 4.3 Las diez pantallas

Se diseñaron **diez pantallas**, que cubren a los tres tipos de usuario. Los demás casos de uso repiten
estos mismos patrones y no se dibujaron para esta entrega.

| # | Pantalla | Caso de uso | Quién la usa |
|---|---|---|---|
| 1 | Iniciar sesión | CU-012 | Pasajero |
| 2 | Buscar servicio y ver lugares disponibles | CU-002 | Pasajero |
| 3 | Confirmar la reserva | CU-003 | Pasajero |
| 4 | Mis reservas y mi deuda | CU-010 y CU-006 | Pasajero |
| 5 | Registrar un pago | CU-014 | Pasajero |
| 6 | Seguir la combi en vivo | CU-009 | Pasajero |
| 7 | Abordar escaneando el QR de la combi | CU-007 | Pasajero |
| 8 | Asistente conversacional | CU-011 | Pasajero |
| 9 | Lista de pasajeros del viaje (solo consulta) | CU-008 | Chofer |
| 10 | Viajes del día | CU-018 | Administrador |

> FALTA — Integrante 3. Pegar las diez capturas, agrupadas por tipo de usuario, cada una con un epígrafe que diga qué pantalla es.

## 4.4 Las pantallas también muestran los errores

Un error común al diseñar es dibujar solamente el caso en que todo sale bien. Acá cada pantalla resuelve
también **qué pasa cuando algo falla**:

| Situación | En qué pantalla | Por qué pasa |
|---|---|---|
| Se quedó sin lugar justo al confirmar | 3 | Los lugares se verifican en el servidor en el momento exacto de confirmar |
| Ya tenía una reserva en ese viaje | 3 | Una reserva por viaje |
| Se está por vencer el plazo para cancelar | 3 y 4 | Hay una ventana de tiempo para cancelar sin cargo |
| La ubicación de la combi está vieja | 6 | Si el dato tiene más de 30 segundos, se avisa |
| El pasajero escanea sin señal | 7 | El abordaje queda guardado en su teléfono y se registra después |
| Escanea el QR de una combi que no es la suya | 7 | El sistema valida viaje, parada y horario antes de aceptar |
| Escanea cuando ya había abordado | 7 | Un abordaje por viaje |

La última fila vale la pena mirarla: **una regla del modelo de datos tiene una pantalla que se la explica al
pasajero en castellano**. El Modelo y la Vista quedan conectados de forma comprobable, no solo declarada.

**Una aclaración sobre el código QR**, porque es fácil suponer lo contrario: **el QR está pegado en la combi
y lo escanea el pasajero**. El código identifica a la **unidad**, no a la persona — el sistema sabe quién es
el pasajero porque tiene la sesión iniciada, y el servidor verifica que tenga reserva en ese viaje y en esa
parada antes de registrar nada. El chofer **no escanea y no registra abordajes a mano**: su pantalla es de
consulta y se actualiza sola a medida que los pasajeros suben.

## 4.5 Las pantallas se pueden recorrer

Las pantallas no son dibujos sueltos: **nueve de las diez están enlazadas entre sí** y se pueden recorrer
como si fuera la aplicación de verdad, desde iniciar sesión hasta seguir la combi. El enlace está en el
**Anexo E**.

---

# 5. Controlador — La comunicación entre la pantalla y el servidor

## 5.1 Primero el acuerdo, después el programa

Antes de escribir una sola línea del servidor, **se escribió el acuerdo de cómo se van a comunicar la
aplicación y el servidor**: qué pedidos existen, qué datos lleva cada uno y qué responde.

La ventaja es práctica: con ese acuerdo cerrado, **quien hace las pantallas, quien hace el servidor y quien
hace el asistente pueden trabajar al mismo tiempo** sin esperarse y sin romperse entre ellos.

El acuerdo está escrito en **OpenAPI**, que es el formato estándar para describir este tipo de comunicación:
**22 operaciones** y 23 esquemas. Se entrega en los dos formatos, YAML y JSON (**Anexo B**).

## 5.2 Reglas que sigue toda la comunicación

**Quién sos.** Al iniciar sesión el servidor entrega una credencial que la aplicación manda en cada pedido
siguiente. Sin esa credencial, casi nada se puede consultar.

**Qué podés hacer.** El servidor revisa el rol de cada usuario antes de responder. Un pasajero ve sus
reservas, no las de otro.

**Los errores se avisan todos igual**, con un código y un mensaje, así la aplicación los puede mostrar de
forma consistente.

**Cada tipo de problema tiene su código.** Y hay una distinción que conviene explicar: cuando **no hay lugar
en la combi**, el pedido estaba perfectamente bien escrito — el problema es que la situación cambió. Por eso
no se responde "pedido mal formado" sino **"conflicto"**, que es un código distinto. Parece un detalle, pero
es lo que le permite a la aplicación mostrar *"Se ocupó el último lugar"* en vez de *"Error"*.

## 5.3 Las operaciones

| Caso de uso | Operación |
|---|---|
| CU-012 · Iniciar y cerrar sesión | Login y logout |
| CU-001 · Ver y editar mi perfil | Consultar y modificar los datos del pasajero |
| CU-002 · Buscar servicios y lugares disponibles | Consultar viajes, servicios y paradas del recorrido |
| CU-003 · Reservar | Crear la reserva |
| CU-004 · Cancelar la reserva | Cancelar |
| CU-005 · Cambiar de parada | Cambiar la parada de la reserva |
| CU-006 · Consultar mi deuda | Consultar deuda |
| CU-007 · Abordar escaneando el QR de la combi | Registrar abordaje (lo llama el pasajero) |
| CU-008 · Avisar que no viajo | Registrar ausencia |
| CU-009 · Ver dónde está la combi | Consultar ubicación y tiempo estimado |
| CU-010 · Ver mis reservas | Consultar reservas propias |
| CU-011 · Hablar con el asistente | Enviar mensaje al asistente |
| CU-014 · Registrar un pago | Registrar pago |
| CU-016 · Confirmar o rechazar un pago | Confirmar pago (administración) |
| CU-018 · Programar y ver viajes | Crear y consultar viajes |
| CU-036 · Aviso automático de Mercado Pago | Recibir el aviso de pago acreditado |

Esta versión cubre **16 de los 37 casos de uso**, más el requisito de tarifas. Los restantes siguen el mismo
patrón y se agregarán en la próxima.

**Dos están cubiertos en parte, y conviene decirlo:** de CU-018 solo está la creación del viaje —modificar,
cancelar y reasignar quedan para la próxima versión—, y de CU-003 falta la operación para anotarse en la
lista de espera que el propio mensaje de error anuncia. La pantalla del administrador, además, supone una
operación para **listar** los viajes del día que todavía no está en el acuerdo.

## 5.4 Dónde viven las reglas de negocio

**Las 31 reglas viven en el servidor.** No en la aplicación y no en el asistente de IA.

El motivo es concreto: si las reglas estuvieran en la aplicación, cualquiera podría saltearlas entrando al
sistema desde otro lado. Y si estuvieran en el asistente, un mensaje bien escrito podría convencerlo de
ignorarlas.

---

# 6. Modelos de IA y agentes

## 6.1 Qué modelos usamos y por qué

El sistema usa **OpenRouter**, un servicio que permite conectarse a varios modelos de inteligencia
artificial con una sola forma de llamarlos, y cambiar de uno a otro si uno falla.

- **Modelo principal:** MiniMax M3
- **Modelo de respaldo:** NVIDIA Nemotron 3 Super

**No los elegimos porque nos gustaran, los elegimos midiendo.** Armamos una prueba con **diez casos
distintos** y evaluamos a cada candidato con una planilla de criterios, donde cada criterio pesa según lo
importante que sea:

| Qué se midió | Cuánto pesa |
|---|---|
| Que elija la herramienta correcta | 25% |
| Que le pase los datos correctos a esa herramienta | 20% |
| Que respete los permisos y las reglas | 15% |
| Que no invente datos | 15% |
| Que entienda y conteste bien en español | 10% |
| Que la respuesta sea clara y usable | 5% |
| Cuánto tarda | 5% |
| Que no se caiga | 5% |

**Resultado:** MiniMax sacó **95,5 sobre 100** y Nemotron **94,5**. Los dos respondieron correctamente las
diez veces, acertaron la herramienta en el 90% de los casos y tardaron alrededor de 2,5 segundos. Se
descartaron otros tres modelos porque no estaban disponibles durante la prueba.

**La prueba cambió una decisión del diseño.** Descubrimos que **cuando el usuario dice "mañana", no hay que
dejar que el modelo interprete qué día es**. El servidor le pasa la fecha ya calculada. Si lo resuelve el
modelo, a veces se equivoca de día — y el error es invisible, porque el pedido que genera está perfectamente
bien formado. Eso no lo podríamos haber sabido sin probar.

Aclaramos además que **hay dos usos distintos de IA en este trabajo**: la que usamos nosotros para analizar,
diseñar y programar, que siempre pasa por revisión nuestra; y la que forma parte del producto, que es la que
describe esta sección.

## 6.2 El agente que implementamos

**AG-01 es el asistente conversacional de VanFull.** Atiende al pasajero en lenguaje común, desde la
aplicación y desde WhatsApp, y puede resolverle consultas y acciones.

Sus características principales:

- **No accede a la base de datos.** Todo lo hace a través del servidor.
- **No puede saltear ninguna regla.** Los lugares, los permisos y los pagos los verifica el servidor.
- **Si un modelo falla, prueba con el otro.** Y si ninguno responde, avisa e ingresa a la persona a
  atención humana.

Dejamos declarado un segundo agente, **AG-02**, para asistir a los administradores, **fuera del alcance de
esta primera versión**.

**Las once herramientas que puede usar.** Cada herramienta corresponde a un caso de uso, así que el asistente
no puede hacer nada que no esté previsto:

| Herramienta | Para qué |
|---|---|
| Consultar disponibilidad | Ver cuántos lugares quedan |
| Consultar horarios | Ver las salidas del día |
| Consultar recorridos | Ver los recorridos que hay |
| Consultar paradas | Ver las paradas de un recorrido |
| Consultar tarifa | Ver cuánto sale |
| Consultar deuda | Ver cuánto debe el pasajero |
| Consultar estado de pago | Ver si un pago se acreditó |
| Consultar reserva | Ver una reserva |
| Crear reserva | Reservar un lugar |
| Cancelar reserva | Cancelar una reserva |
| Consultar ubicación | Ver dónde está la combi |
| Derivar a un humano | Pasar la conversación a una persona |

Reservar o cancelar desde el chat **pasa por las mismas verificaciones** que hacerlo desde la aplicación.

**Cómo funciona una conversación, paso a paso:**

1. El usuario escribe un mensaje.
2. El servidor le agrega la fecha y hora actuales y quién es el usuario.
3. El modelo lee todo eso y decide qué herramienta usar.
4. **El servidor ejecuta esa herramienta y verifica las reglas.**
5. El resultado vuelve al modelo, que redacta la respuesta en lenguaje común.
6. Si no puede resolverlo de forma segura, pasa la conversación a una persona.

## 6.3 Las instrucciones que le damos al modelo

Estas son las instrucciones fijas que recibe el asistente antes de cada conversación:

```
Sos el asistente conversacional de VanFull.
Fecha actual del sistema: la provee el servidor.
- Atendé únicamente consultas vinculadas con VanFull.
- Nunca inventes cupos, horarios, tarifas, pagos ni deudas.
- Para datos operativos usá las herramientas disponibles.
- No reveles datos personales de terceros.
- No modifiques estados de pago.
- No permitas reservas por encima del cupo.
- Las reglas de negocio las valida el backend.
- Si faltan datos esenciales, pedilos antes de ejecutar una acción.
- Si el usuario pide atención humana, derivá la conversación.
- Rechazá solicitudes ajenas a VanFull de manera breve.
```

## 6.4 Cuidados de seguridad

- **No le mandamos al modelo datos personales** como documentos o fotos. Usa identificadores internos.
- **El servidor revisa los permisos** antes de devolver cualquier dato de una persona.
- **Confirmar un pago lo hace una persona, no el asistente.** Cuando un usuario le pide que dé un pago por
  confirmado, el asistente le explica que no puede y le indica cómo hacerlo.
- La prueba incluyó casos pensados para engañarlo: pedirle que altere un pago, pedirle datos de otra
  persona, y preguntarle cosas ajenas a VanFull. Los rechazó.
- Si falla un modelo o una herramienta, se registra el error y se deriva. **Nunca se inventa una respuesta.**

---

# 7. Modelo de desarrollo

## 7.1 Cómo guardamos el código

El código está en un repositorio de **Git alojado en GitHub**, público. Todo el proyecto vive en un solo
repositorio: el servidor, la aplicación y la documentación técnica.

Separamos las cosas así: **Google Drive** guarda la documentación oficial del equipo y **GitHub** guarda el
código y los archivos que conviene versionar. Las contraseñas y claves **nunca** se suben.

## 7.2 Cómo trabajamos

```
Issue -> Rama -> Desarrollo -> Commit -> Pull Request -> Revisión -> Merge
```

Para cada tarea se abre un **issue** (una ficha que describe qué hay que hacer), se trabaja en una **rama
aparte** para no romper lo que funciona, y cuando está lista se abre un **Pull Request** que **revisa un
compañero** antes de incorporarlo. Nadie sube cambios directamente a la rama principal, y esa rama se
mantiene siempre en un estado que funciona.

Los mensajes de los commits siguen una convención fija y **mencionan el caso de uso o la regla** que
justifica el cambio, para poder rastrear después por qué se hizo cada cosa.

## 7.3 Trazabilidad

Para cualquier funcionalidad se puede seguir la cadena completa:

```
Caso de uso -> operación -> servidor -> servicio -> datos -> prueba
```

## 7.4 Cómo controlamos la calidad

- **ruff** revisa que el código Python esté bien escrito y con formato uniforme.
- **pytest** corre las pruebas automáticas.
- **Docker** levanta la base de datos y el servidor iguales en la computadora de cualquiera del equipo.

Antes de dar una tarea por terminada revisamos que exista un requisito que la justifique, que las reglas se
verifiquen en el servidor, que el acuerdo de comunicación esté actualizado si la API cambió, que tenga
pruebas y que las herramientas de control pasen sin errores.

## 7.5 Planificación

> FALTA — Equipo. Pegar el cronograma de las 16 semanas, marcando en qué semana estamos y dónde caen los tres puntos de control.

---

# 8. Anexos

| Anexo | Qué es | Dónde está |
|---|---|---|
| **A** | El modelo de datos en SQL, completo | En el repositorio |
| **B** | El acuerdo de comunicación, en YAML y en JSON | En el repositorio |
| **C** | IA y agentes, documento completo | En esta misma carpeta del Drive |
| **D** | Modelo de desarrollo, documento completo | En esta misma carpeta del Drive |
| **E** | Las diez pantallas, para recorrer | Enlace |
| **F** | Colores, tipografías y componentes | Enlace |
| **G** | Las especificaciones de los 37 casos de uso | Carpeta 03 del Drive |
| **H** | Diagramas C4, UML y Entidad-Relación | Carpetas 04 y 05 del Drive |

Repositorio: https://github.com/Martiherenu1/ProyectoVanFull

---

# 9. Guía para la presentación

Esta sección es **para nosotros**, no para entregar. Es el guion de qué mostrar el 28 de septiembre.

## Las cuatro cosas que hay que decir sí o sí

**1. Que el problema es real.** VanFull existe y hoy trabaja con WhatsApp, Excel y papel. No inventamos un
caso.

**2. Que el modelo de datos está probado, no dibujado.** El archivo SQL se ejecutó contra una base
PostgreSQL de verdad y se verificó que rechaza los datos inválidos. Es la diferencia con un diagrama que
nunca se corrió.

**3. Que los modelos de IA los elegimos midiendo.** Diez casos de prueba y una planilla de criterios
ponderados. Y que esa prueba nos cambió una decisión de diseño, la de las fechas relativas.

**4. Que la IA no puede romper nada.** El asistente no toca la base de datos. Aunque el modelo se equivoque
o alguien intente engañarlo, quien decide es el servidor.

## Orden sugerido para mostrar

1. El problema y la empresa (sección 1) — **2 minutos**
2. La arquitectura, con el diagrama (sección 2) — **3 minutos**
3. El modelo de datos y las decisiones (sección 3) — **4 minutos**
4. **Las pantallas, recorriéndolas en vivo** (sección 4) — **5 minutos**
5. El asistente y cómo elegimos los modelos (sección 6) — **4 minutos**
6. Cómo trabajamos en equipo (sección 7) — **2 minutos**

## Lo que conviene mostrar en vivo y no en diapositiva

- **El recorrido de las pantallas.** Están enlazadas: se puede ir de iniciar sesión hasta seguir la combi.
  Impacta mucho más que capturas sueltas.
- **La pantalla del chofer al lado de la del administrador.** Se ve de una que son distintas a propósito.
- **El error de "sin lugar" al confirmar una reserva.** Muestra que pensamos los casos en que algo falla.

## Si preguntan por algo que no hicimos

Decirlo directamente. **Está bien que el alcance tenga límites y esté escrito cuál es.** Diseñamos diez
pantallas de treinta y siete casos de uso, y está explicado por qué. El acuerdo de comunicación cubre las
operaciones principales y las demás quedan para la próxima versión. Eso es alcance definido, no trabajo
faltante.
