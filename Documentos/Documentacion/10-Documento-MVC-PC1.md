# VanFull — Documento con el MVC

**Trabajo de Campo · Proyecto Integrador con IA y Agentes**

Licenciatura en Sistemas | Ingeniería en Informática

**Primer Punto de Control — Análisis, Diseño y Planificación**

Entrega: 28 de septiembre de 2026 · Versión 1.1

**Equipo:** Martin Defez - Martiniano Hereñú - Facundo Barrientos

Repositorio del proyecto: https://github.com/Martiherenu1/ProyectoVanFull

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
| Propuestas evaluadas | 1.5 |
| Propuesta seleccionada | 1.6 |
| Alcances y Límites | 1.4 |
| Análisis | 1.7 |
| Arquitectura de la solución | 2 |
| Modelo Conceptual: Frontend, Backend, Base de Datos | 2.2 |
| Gráficos: UML y C4 Model | 2.5 |
| Diagramas de actividad (UML) | 2.7 |
| Diagramas de componentes y de despliegue | 2.8 |
| Modelo en mermaid.js | 2.4 |
| Modelo de Datos y relaciones | 3 |
| Modelo de datos SQL | 3.4 y Anexo A |
| Interfaces gráficas | 4 |
| Comunicación V-C: Open API en formato JSON | 5 y Anexo B |
| Modelos de IA utilizados y justificación | 6.1 |
| Agentes IA implementados | 6.2 |
| Prompts | 6.3 |
| Informe sobre IA para diseño | 6.5 |
| Modelo de Desarrollo | 7 |

---

# 1. Presentación general del Proyecto

## 1.1 Objetivos

El objetivo general del sistema VanFull es **centralizar y digitalizar la gestión operativa y administrativa
del servicio de transporte**, integrando en una misma solución la información de pasajeros y empresas,
reservas y disponibilidad, abonos y pagos, viajes, recorridos y paradas, vehículos y choferes, abordajes,
comunicaciones y seguimiento. La solución busca reducir especialmente los problemas priorizados por VanFull:
**control de reservas, control de pagos y notificaciones a clientes**, incorporando además mecanismos de
autoservicio y las integraciones requeridas para el proyecto académico.

## 1.2 Antecedentes

VanFull es una **empresa familiar de transporte de pasajeros con aproximadamente veinte años de actividad**.
Presta servicios universitarios, laborales, corporativos, ocasionales, especiales y turísticos. En la
operatoria actual, gran parte de la gestión se apoya en **WhatsApp, planillas de Excel y comunicaciones
telefónicas**. La disponibilidad de cupos se controla con sumatorias manuales, la verificación de pagos se
hace uno por uno, y parte de la información de clientes puede quedar distribuida entre conversaciones y
planillas. El relevamiento también identificó al **tránsito** como una dificultad operativa para organizar
los recorridos. Ante la consulta sobre los principales problemas a resolver, VanFull priorizó el control de
reservas, el control de pagos y las notificaciones a clientes.

## 1.3 Justificación

La propuesta se justifica porque los procesos actuales **dependen de controles manuales y de información
distribuida**, lo que incrementa la carga administrativa y el riesgo de inconsistencias en operaciones
críticas. Centralizar la información permite disponer de una **única fuente operativa** para cupos, reservas,
pagos, viajes y comunicaciones; aplicar las reglas de negocio de forma uniforme; habilitar autoservicio para
los usuarios autorizados; y brindar trazabilidad entre lo que pide el negocio y lo que se implementó en la
interfaz, la API y los datos. La solución también permite incorporar seguimiento GPS, optimización de
recorridos, notificaciones y un agente conversacional **sin trasladar las decisiones de negocio al modelo de
IA**: las validaciones permanecen en el backend.

## 1.4 Alcances y límites

La frontera funcional vigente está formalizada en la Etapa 02 y mantiene **45 Requisitos Funcionales**
(RF-001 a RF-045), **14 Requisitos No Funcionales** (RNF-001 a RNF-014) y **31 Reglas de Negocio** (RN-001 a
RN-031). **Dentro del alcance** están la gestión de pasajeros y clientes corporativos, reservas y lista de
espera, abonos, pagos y deuda, viajes y recorridos, choferes y vehículos, abordaje mediante QR, seguimiento
GPS, optimización de recorridos, notificaciones, chatbot y WhatsApp, reportes, y el soporte a comprobantes y
facturación dentro de los límites aprobados.

En pagos se mantiene la línea base: cuando Mercado Pago informa válidamente una operación **aprobada o
acreditada**, el backend puede confirmar el pago automáticamente; cuando el medio no dispone de una
acreditación automática válida, la confirmación o el rechazo corresponde a **una persona autorizada**. El
agente AG-01 no confirma pagos.

**Entre los límites vigentes** están: no integrar tecnológicamente Uber u otros transportes externos; no
permitir que el pasajero modifique libremente su DNI; no exponer al chofer datos privados de contacto ni
permitirle confirmar manualmente el abordaje; no incorporar en esta primera versión un módulo completo de
mantenimiento, combustible ni el QR de recepción y entrega de vehículos; y no comprometer una integración
fiscal concreta ni el uso productivo obligatorio de Mercado Pago. Los aspectos legales de privacidad y
retención, la política técnica de seguridad y otros pendientes expresamente documentados **continúan abiertos
y no se resuelven por inferencia**.

## 1.5 Propuestas evaluadas

Antes de empezar, el equipo armó **tres propuestas de proyecto**. Las tres cumplen lo que pide la consigna (aplicación Web y Mobile, servidor, base de datos e inteligencia artificial con agentes) y se compararon con los mismos criterios: factibilidad técnica, alcance, disponibilidad de datos, valor para el negocio, uso real de la IA y facilidad de demostrarlo.

|  | Propuesta 1 · Transporte | Propuesta 2 · Canchas de fútbol | Propuesta 3 · Carne envasada |
|---|---|---|---|
| **Qué es** | Gestión y reserva de viajes de pasajeros, tomando como caso a VanFull | Gestión de complejos deportivos y reserva de canchas | Venta y gestión de carne envasada al vacío |
| **Quién la usa** | Pasajeros, conductores y administradores | Clientes y administradores | Clientes y administradores |
| **Qué resuelve** | Consultar horarios y cupos, reservar ida y vuelta, cancelar y recibir avisos; administrar vehículos, recorridos, reservas y pagos | Buscar sedes cercanas, ver disponibilidad y reservar; administrar sedes, horarios, precios y mantenimientos | Ver catálogo y stock, armar un pedido y seguir su entrega; administrar productos, precios y pedidos |
| **Papel de la IA** | Chatbot y agente de planificación: consulta disponibilidad real, sugiere horarios alternativos, detecta sobrecupos y analiza la demanda; puede preparar una reserva que el pasajero confirma | Chatbot que consulta sedes, horarios y precios, y prepara una reserva que el usuario confirma | Asistente que recomienda cortes y cantidades según las personas, y prepara un carrito que el cliente confirma |
| **Pagos** | Pago simulado | Pago simulado | Pago simulado |

La comparación se hizo en dos instancias. Primero, una **factibilidad de desarrollo** sobre 5:

| Propuesta | Factibilidad | Lectura |
|---|---|---|
| Complejo deportivo | **4,5 / 5** | La más factible. Riesgo: reglas de cancelación, pagos y superposición de turnos |
| Carne envasada | 4,1 / 5 | Alcance controlable. Riesgo: que la IA quede como un agregado |
| Transporte (VanFull) | 3,8 / 5 | Mayor potencial de impacto e innovación. Riesgo: la geolocalización, los recorridos y la asignación pueden ampliar mucho el alcance |

Después, una **comparación general** por aspecto, con estrellas de 1 a 5:

| Aspecto | Transporte | Canchas | Carne |
|---|---|---|---|
| Problema real | 3 | 3 | 3 |
| Web y Mobile justificadas | 3 | 3 | 3 |
| Base de datos interesante | 4 | 4 | 3 |
| Complejidad funcional | Alta | Media / Alta | Media |
| IA fácil de justificar | **4** | 3 | 2 |
| Agentes de IA | **4** | 4 | 3 |
| Innovación posible | **4** | 3 | 3 |
| Facilidad de desarrollo | 2 | 4 | 4 |
| Facilidad para probar | 3 | 5 | 4 |
| Potencial para la demostración final | 5 | 5 | 4 |
| **Riesgo del proyecto** | **Alto** | Bajo / Medio | Bajo / Medio |

**Conclusión del análisis, tal como quedó escrita entonces:** la opción más factible y controlada era el complejo deportivo; la de mayor diferencial de IA y de impacto real era VanFull, a condición de acotar el MVP a reservas, cupos, panel operativo y un agente de planificación simple.

## 1.6 Propuesta seleccionada

**El equipo eligió la Propuesta 1: el sistema de gestión y reserva de transporte, con VanFull como caso real.**

**Por qué VanFull.** Es el proyecto con más diferencial de IA y más impacto real: la IA se justifica de forma natural en cupos, horarios, demanda y comunicación con los pasajeros, y era el aspecto en que la propuesta puntuaba más alto. Tiene un caso real: VanFull es una empresa existente, con una operación que hoy se apoya en WhatsApp, planillas y llamadas, y con un dueño al que se pudo entrevistar (el relevamiento está en la carpeta 01 del Drive). Tiene una demostración final fuerte (5 de 5, empatada con la mejor) y reúne muchas de las capas que pide el trabajo: una base de datos con relaciones complejas, agentes con herramientas, seguimiento de la combi y pagos.

**Qué costó esa elección.** Se eligió sabiendo que no era la opción más fácil: tenía la menor factibilidad de desarrollo (3,8 sobre 5) y el único riesgo clasificado como alto. La comparación ya advertía que la geolocalización, los recorridos y la asignación podían ampliar mucho el alcance, y el proyecto final incluye seguimiento GPS y optimización de recorridos. Se controló cerrando la línea funcional (45 requisitos funcionales, 14 no funcionales, 31 reglas de negocio, 37 casos de uso) y dejando por escrito los límites (sección 1.4). El alcance final terminó siendo más amplio que el mínimo que recomendaba la comparación inicial, pero acotado y con cada decisión registrada.

**Qué cambió entre la propuesta y el proyecto.** La propuesta era una idea inicial y algunas decisiones se precisaron al avanzar. Para que el documento sea transparente, se deja el cambio a la vista:

| Aspecto | En la propuesta | En el proyecto |
|---|---|---|
| **Backend** | Java + Spring Boot | **Python + FastAPI**. |
| **Base de datos** | PostgreSQL + PostGIS | **PostgreSQL 16**: el modelo (35 tablas) no usa tipos geográficos; el recorrido y el tiempo estimado los calcula Google Maps (Routes API) |
| **Acceso a datos** | No se definía | SQLAlchemy 2.0 asíncrono y Alembic para las migraciones |
| **Pagos** | Pago simulado | **Mercado Pago en modo de prueba**, con confirmación automática solo cuando el proveedor informa un pago aprobado o acreditado |
| **Contrato entre capas** | OpenAPI / JSON | Igual, entregado en YAML y en JSON (22 operaciones, 23 esquemas) |
| **IA** | Chatbot y agente de planificación, sin modelo definido | Agente AG-01 de 13 herramientas, sobre OpenRouter: MiniMax M3 (principal) y Nemotron 3 Super (respaldo), elegidos con una prueba medida |
| **Mensajería** | No figuraba | WhatsApp como canal alternativo de atención |
| **Diagramas** | Mermaid.js | Se mantiene (sección 2.4), junto con C4 y UML |

**Tecnologías adoptadas:** Flutter (Web y Mobile), Python + FastAPI, PostgreSQL 16, SQLAlchemy 2.0 + Alembic, OpenAPI (YAML y JSON), OpenRouter (MiniMax M3 y Nemotron 3 Super), Google Maps Platform (Routes API), Mercado Pago (modo de prueba), WhatsApp, Git y GitHub, y Docker (entorno de desarrollo). Alojamiento previsto, sin costo: Neon (base), Render (servidor) y GitHub Pages (versión web).

## 1.7 Análisis

El análisis parte de una **entrevista directa con el dueño de VanFull (25/08/2026)** y de las aclaraciones posteriores de esa misma entrevista. Lo que sigue lo resume; el detalle completo está en las carpetas 01 y 02 del Drive.

### Cómo se trabajó

Cada afirmación se clasificó según su origen, con esta jerarquía de fuentes: lo que exigen los profesores, lo que confirmó VanFull, lo que definió el equipo, las propuestas de IA (que solo valen una vez aprobadas) y lo pendiente de validación. Así se evita tomar como un hecho algo que alguien solo supuso. Y cada requisito conserva su trazabilidad: **problemática → necesidad → comportamiento confirmado → requisito → regla de negocio → caso de uso → diseño técnico.**

### Cómo funciona VanFull hoy

| Aspecto | Situación actual |
|---|---|
| **Empresa** | Familiar, con unos 20 años de actividad. Presta servicios universitarios, laborales, charters, ocasionales, traslados a aeropuertos, servicios a empresas y turismo |
| **Flota y personal** | 15 vehículos (14 de 19 o 24 pasajeros y 1 de 45), unos 11 choferes y 2 personas en administración y coordinación |
| **Herramientas** | No tiene un sistema propio: usa WhatsApp para comunicarse y un Excel con varios libros como sistema administrativo central |
| **Reservas** | El pasajero consulta por WhatsApp o teléfono, VanFull verifica el cupo a mano, informa la tarifa, acepta de palabra y después carga los datos en Excel |
| **Cupos** | Se controlan con sumatorias manuales. Si la unidad está completa no se vende más y se arma una lista de espera |
| **Pagos** | Efectivo, transferencia, billeteras virtuales y cuenta corriente, verificados uno por uno. No usa Mercado Pago por sus comisiones |
| **Abonos mensuales** | Se paga del 1 al 10; del 11 al 13 hay advertencia y posible suspensión; pasado el 13 se puede perder el cupo |
| **Recorridos** | Los de charter se arman con los puntos de ascenso de los pasajeros contratados y quedan relativamente fijos; hay un transbordo en Bella Vista |

### Problemas detectados

VanFull priorizó tres: **control de reservas, control de pagos y notificaciones a clientes.** El análisis detectó además errores de disponibilidad por el conteo manual, tiempo dedicado a la facturación, información dispersa entre mensajes, dificultad para identificar los pagos hechos por terceros (por ejemplo, padres que pagan por sus hijos), tareas repetitivas por WhatsApp, comunicación manual ante cambios y problemas de tránsito para organizar los recorridos.

### Qué pidió VanFull para el sistema

El control de cupos y el **código QR de abordaje** son las dos funciones que el dueño destacó para una primera versión. Además pidió: registrar el abordaje aunque se pierda la conexión, seguimiento GPS de la combi, propuestas de recorridos optimizados, un chatbot (en WhatsApp y en la aplicación), notificaciones automáticas, un control estructurado de la deuda, que las empresas clientes den de alta a sus propios pasajeros, reportes exportables a Excel y PDF, y la gestión digital de vehículos y choferes.

### Actores y casos de uso

Se identificaron **9 actores**: pasajero, pasajero empresarial, representante corporativo, chofer, administrador, dueño o superadministrador, y tres sistemas externos (Mercado Pago, WhatsApp y el servicio de mapas, geolocalización y tránsito). Sus necesidades se tradujeron en **37 casos de uso**, agrupados por actor principal:

| Actor principal | Casos de uso | Cantidad |
|---|---|---|
| Pasajero y acceso | CU-001 a CU-012 | 12 |
| Administración | CU-013 a CU-028 | 16 |
| Chofer | CU-029 y CU-030 | 2 |
| Dueño | CU-031 y CU-032 | 2 |
| Clientes corporativos | CU-033 a CU-035 | 3 |
| Integraciones y soporte | CU-036 y CU-037 | 2 |
| **Total** |  | **37** |

### Requisitos y reglas

La línea funcional quedó cerrada con **45 requisitos funcionales, 14 requisitos no funcionales y 31 reglas de negocio**. Los no funcionales tienen métricas verificables:

| Aspecto | Métrica aprobada |
|---|---|
| **Disponibilidad** (RNF-001) | 99 % mensual |
| **Velocidad** (RNF-002 y 003) | 95 % de las operaciones habituales en 2 segundos o menos; las pesadas o con integraciones, hasta 5 segundos |
| **Carga** (RNF-004 a 006) | 100 usuarios simultáneos, probado hasta con 150, y capacidad de duplicar la carga sin rediseñar |
| **Seguimiento GPS** (RNF-007 a 010) | Actualización cada 10 segundos; más de 30 segundos se marca como desactualizada; precisión de hasta 50 metros; recupera la posición al volver la señal |
| **Abordaje sin conexión** (RNF-011 y 012) | Sincroniza en 60 segundos o menos al recuperar la conexión, sin duplicados |
| **Recuperación** (RNF-013 y 014) | Volver a funcionar en 1 hora como máximo y perder como mucho 15 minutos de datos |

Algunas **reglas de negocio** son las que más condicionan el diseño: no superar el cupo de la unidad (RN-001); distinguir la reserva provisional de la consolidada (RN-002); que la deuda de un abono no supere un mes (RN-006); las condiciones de cancelación (RN-017 a RN-019); que las tarifas, los descuentos especiales y los reportes reservados sean exclusivos del dueño (RN-027); que el GPS lo vean solo quienes están vinculados al servicio y solo mientras dura (RN-030); y que un pasajero no tenga dos viajes de ida ni dos de vuelta el mismo día (RN-031).

### Decisiones que se tomaron durante el análisis

**El código QR lo escanea el pasajero, no el chofer.** El QR identifica a la unidad; el chofer solo consulta la lista y no registra abordajes.

**Los pagos tienen dos caminos.** Cuando Mercado Pago informa un pago aprobado o acreditado, el sistema lo confirma solo; los demás medios los confirma una persona autorizada. El asistente de IA nunca confirma pagos.

**La lista de espera funciona por orden de llegada (FIFO).**

**Un viaje puede planificarse sin vehículo o sin chofer asignado, pero ambos deben estarlo antes de iniciarlo.**

### Pendientes que no se resolvieron por inferencia

Quedan abiertos, y están escritos como tales: la **validación contable y fiscal** de la facturación; la **privacidad y protección de datos** (fotos y datos del DNI, CUIL, contactos de emergencia, ubicación) y los plazos de conservación; la **política técnica de seguridad** (autenticación, sesiones, cifrado, recuperación de cuenta); la **auditoría de cambios**, que es una propuesta y no está aprobada; y la **configuración de WhatsApp** (cuenta, plantillas, costos). Mercado Pago se usa en modo de prueba, porque VanFull hoy no lo utiliza en producción.

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

La imagen renderizada de ese código está pegada en el documento del Drive, con el código debajo.

## 2.5 Diagramas C4 y de casos de uso

Los diagramas de esta sección **conectan la visión funcional con la arquitectura**. En el documento principal
van el C4 de Contexto, el C4 de Contenedores y el Diagrama General de Casos de Uso. Las vistas parciales por actor quedan en la carpeta `03` del Drive como evidencia detallada del modelado
aprobado; los diagramas de actividad de los casos de uso prioritarios se incluyen en la sección 2.7.

**C4 Nivel 1 — Contexto.** Ubica al sistema dentro de su entorno: los usuarios humanos y los sistemas
externos con los que se relaciona —Mercado Pago, WhatsApp y los servicios de mapas, geolocalización, tránsito
y rutas—, **sin describir todavía la implementación interna**. Documenta la frontera del sistema y las
integraciones externas aprobadas. *(Figura 1 del documento.)*

**C4 Nivel 2 — Contenedores.** Descompone la solución en sus piezas principales: la aplicación Flutter
Web/Mobile, el backend FastAPI, la base PostgreSQL y los componentes de integración. La decisión central es
que **la lógica de negocio y las autorizaciones se concentran en el backend**; ni la interfaz ni el agente de
IA acceden directamente a la base de datos. *(Figura 2.)*

**Diagrama General de Casos de Uso.** Representa la interacción de los **9 actores** aprobados con los
**37 casos de uso** de la línea base funcional. Muestra la cobertura del sistema y la participación de
pasajeros, choferes, administración, clientes corporativos e integraciones externas, sin sustituir las
especificaciones detalladas de cada CU. *(Figura 3.)*

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

## 2.7 Diagramas de actividad

Los diagramas de actividad muestran, paso a paso, el flujo de los casos de uso prioritarios: qué hace cada actor, qué hace el sistema y dónde el recorrido se bifurca según las reglas de negocio. Se incluyen **ocho**, correspondientes al modelado aprobado (carpeta 04 del Drive).

Cada columna es un actor, los rombos son decisiones y las notas amarillas indican reglas o requisitos relacionados. Los diagramas son extensos y se insertan a tamaño de página: para leer el detalle conviene ampliar la imagen en pantalla, que conserva su resolución original.

| Diagrama | Caso de uso | Quién interviene |
|---|---|---|
| DA-CU003 | CU-003 · Crear reserva | Pasajero |
| DA-CU004 | CU-004 · Cancelar reserva | Pasajero |
| DA-CU007 | CU-007 · Registrar abordaje mediante QR | Pasajero |
| DA-CU017 | CU-017 · Gestionar créditos, devoluciones y reintegros | Administrador / Dueño |
| DA-CU018 | CU-018 · Gestionar viajes y asignaciones | Administrador / Dueño |
| DA-CU020 | CU-020 · Optimizar recorrido | Administrador / Dueño; servicio de mapas, tránsito y rutas |
| DA-CU028 | CU-028 · Gestionar abonos mensuales | Administrador / Dueño |
| DA-CU030 | CU-030 · Ejecutar viaje | Chofer; servicio de mapas, geolocalización, tránsito y rutas |

### DA-CU003 · Crear reserva

*(Diagrama de actividad DA-CU003: figura en el documento del Drive; original en la carpeta `04`.)*

### DA-CU020 · Optimizar recorrido

*(Diagrama de actividad DA-CU020: figura en el documento del Drive; original en la carpeta `04`.)*

### DA-CU028 · Gestionar abonos mensuales

*(Diagrama de actividad DA-CU028: figura en el documento del Drive; original en la carpeta `04`.)*

### DA-CU030 · Ejecutar viaje

*(Diagrama de actividad DA-CU030: figura en el documento del Drive; original en la carpeta `04`.)*

### DA-CU004 · Cancelar reserva

*(Diagrama de actividad DA-CU004: figura en el documento del Drive; original en la carpeta `04`.)*

### DA-CU007 · Registrar abordaje mediante QR

*(Diagrama de actividad DA-CU007: figura en el documento del Drive; original en la carpeta `04`.)*

### DA-CU017 · Gestionar créditos, devoluciones y reintegros

*(Diagrama de actividad DA-CU017: figura en el documento del Drive; original en la carpeta `04`.)*

### DA-CU018 · Gestionar viajes y asignaciones

*(Diagrama de actividad DA-CU018: figura en el documento del Drive; original en la carpeta `04`.)*

## 2.8 Diagramas de componentes y de despliegue

Estos dos diagramas completan la vista de la arquitectura de la sección 2.5: el de componentes muestra las piezas del sistema y cómo se hablan, y el de despliegue muestra dónde corre cada pieza. En ambos, **la línea llena indica lo que ya existe en el repositorio y la punteada lo que está planificado y todavía no tiene código**, para no mostrar como hecho algo que no lo está.

### Diagrama de componentes

*(Figura en el documento del Drive: Diagrama de componentes de VanFull.)*

**Qué muestra.** La aplicación Flutter (con sus cuatro tipos de usuario) y WhatsApp hablan con el backend FastAPI. Dentro del backend, los routers reciben el pedido, los services aplican las 31 reglas de negocio y los models son la única capa que habla con PostgreSQL. El asistente AG-01 usa herramientas que pasan por los services y llama a OpenRouter. La inteligencia artificial no accede a la base de datos.

### Diagrama de despliegue

*(Figura en el documento del Drive: Diagrama de despliegue de VanFull.)*

**Qué muestra.** En desarrollo, cada integrante levanta el servidor y la base con Docker Compose. Para la entrega se planificó un alojamiento sin costo: la base en Neon, el servidor en Render y la versión web en GitHub Pages. Los planes gratuitos se duermen cuando no tienen tráfico, así que hay que despertarlos antes de cada demostración. Si el producto se vende, se pasa a un plan pago cambiando una variable de configuración.

---

# 3. Modelo — Datos y relaciones

## 3.1 Panorama

El modelo de datos tiene **35 tablas**, agrupadas en cinco bloques:

- **Personas, clientes y acceso:** personas, pasajeros, choferes, clientes y los permisos de cada cuenta.
- **Servicios y contratación:** los servicios que ofrece la empresa, las tarifas, los abonos mensuales.
- **Viajes, recorridos y operación:** recorridos, paradas, vehículos, viajes, reservas, abordajes y ausencias.
- **Cuenta corriente y pagos:** la cuenta de cada cliente, los pagos y los comprobantes.
- **Trazabilidad operativa y nóminas:** eventos operativos vinculados a reservas, pagos o viajes, y las nóminas de pasajeros cuando corresponda. Este registro brinda trazabilidad operativa y no constituye una auditoría general del sistema.

## 3.2 Diagrama Entidad-Relación

El DER representa la estructura conceptual de persistencia que respalda la operación de VanFull y **mantiene
alineación con el Modelo Relacional aprobado**. Organiza personas y accesos; servicios y contratación;
viajes, recorridos y operación; cuenta corriente, pagos y comprobantes; y trazabilidad operativa. Entre las
relaciones relevantes están Viaje–Recorrido, Recorrido–Parada, Reserva–Viaje, PeriodoAbono–Viaje y la
separación entre Pago, MovimientoCuenta y Comprobante.

**Corrección transversal del 30/09/2026, decidida por el equipo.** La relación Pago–Comprobante para el
RECIBO se representa como **Pago 1 ↔ 0..1 Recibo**. Todo pago en estado `CONFIRMADO` exige **exactamente un**
recibo; los pagos `PENDIENTE` o `RECHAZADO` no requieren recibo. **Esta corrección es gráfica y documental:
no modifica el Modelo Relacional aprobado ni `schema.sql`**, que ya eran compatibles.

En el documento del Drive, la **Figura 4** muestra el DER completo, en una página horizontal propia.
Son 35 entidades en cinco bloques: a tamaño de página funciona como mapa de la estructura, no como
lectura de detalle. La versión legible está en la carpeta `05` del Drive (Anexo H) y, sobre todo, en el
modelo SQL del **Anexo A**, que es la fuente autoritativa.

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
| Señal | Puede ser mala | Puede perderla | Buena |
| Qué necesita saber ya | ¿Cuánto falta para que llegue? | ¿Ya subieron todos? | ¿Qué problema hay hoy? |
| Fondo de pantalla | Oscuro | Oscuro | Claro |
| Alto de cada fila | 48 puntos | **64 puntos** | 36 puntos |

De acá salen las decisiones concretas: **los botones del chofer son más grandes** porque los toca parado y
con una sola mano; **la pantalla del pasajero funciona sin señal** al momento de abordar, porque en la ruta
a veces no hay; y **el panel del administrador es más compacto** porque necesita ver seis viajes juntos.

Para la pantalla del chofer, en cambio, **no se diseñó funcionamiento sin conexión.** Si el chofer pierde
señal la consulta no se actualiza, y la contingencia que confirmó la empresa es comunicarse por WhatsApp o
por teléfono. Lo aclaramos porque es una decisión, no un olvido: el abordaje sin señal lo resuelve el
teléfono del pasajero, no el del chofer.

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

El sistema de diseño completo —paleta con sus contrastes medidos, tipografías y componentes— está en el **Anexo F**.

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
| 9 | Lista de pasajeros del viaje (solo consulta) | CU-029 | Chofer |
| 10 | Viajes del día | CU-018 | Administrador |

En el documento del Drive, las diez capturas están agrupadas por actor en grillas de dos columnas,
numeradas igual que la tabla de arriba. La del chofer y la del administrador van juntas, para que se
vea de una que son distintas a propósito.

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
| CU-014 · Registrar un pago | Registrar el pago y determinar el mecanismo de acreditación |
| CU-016 · Confirmar o rechazar un pago | Confirmación administrativa de pagos que no tienen acreditación automática válida |
| CU-018 · Programar viajes | Crear el viaje. Durante la planificación el vehículo y el chofer pueden quedar sin asignar; ambos deben estarlo antes de iniciar la ejecución. Listar los viajes queda para la próxima versión del acuerdo |
| CU-036 · Procesar notificación de Mercado Pago | Recibir el resultado del proveedor y confirmar automáticamente el pago cuando la operación fue aprobada o acreditada |

Esta versión cubre **16 de los 37 casos de uso**, más el requisito de tarifas. Los restantes siguen el mismo
patrón y se agregarán en la próxima.

**Cuatro cosas están cubiertas en parte, y conviene decirlo:** de CU-018 solo está la creación del viaje
—modificar, cancelar y reasignar quedan para la próxima versión—, y de CU-003 falta la operación para
anotarse en la lista de espera que el propio mensaje de error anuncia. La pantalla del administrador,
además, supone una operación para **listar** los viajes del día que todavía no está en el acuerdo.

**Y la pantalla del chofer (CU-029) tampoco tiene operación en este acuerdo.** La diseñamos porque el caso
de uso está especificado y aprobado, pero la consulta de la operación asignada queda para la próxima
versión del contrato. Es la misma decisión de alcance que las otras tres, y preferimos escribirla.

## 5.4 Cómo se confirma un pago

VanFull contempla **dos mecanismos de confirmación**. Los pagos que requieren comprobación manual, como
transferencias o efectivo, permanecen pendientes hasta que una persona autorizada los confirme o rechace. En
cambio, cuando Mercado Pago informa válidamente que una operación fue aprobada o acreditada, **el backend
confirma automáticamente el pago**. Esta automatización pertenece a la integración con el proveedor de pagos
y **no al agente de inteligencia artificial**, que no confirma pagos en ningún caso.

## 5.5 Dónde viven las reglas de negocio

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

**Las trece herramientas que puede usar.** Cada herramienta corresponde a un caso de uso, así que el asistente
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
| Consultar estado del viaje | Ver el estado operativo de un viaje |
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
- **El asistente no confirma pagos, nunca.** Según el medio, la confirmación la produce automáticamente la
  integración con Mercado Pago o la hace una persona autorizada. Cuando un usuario le pide al asistente que
  dé un pago por confirmado, le explica que no puede y le indica cómo hacerlo.
- La prueba incluyó casos pensados para engañarlo: pedirle que altere un pago, pedirle datos de otra
  persona, y preguntarle cosas ajenas a VanFull. Los rechazó.
- Si falla un modelo o una herramienta, se registra el error y se deriva. **Nunca se inventa una respuesta.**

## 6.5 Informe sobre la IA usada en el diseño y el desarrollo

La consigna pide un informe con las propuestas, discusiones y conclusiones sobre las herramientas de inteligencia artificial que se usaron **en el diseño**. Este informe cubre las que el equipo usó para **analizar, diseñar y programar** VanFull. La IA que forma parte del producto (el asistente AG-01 y sus modelos) está en las secciones 6.1 a 6.4.

### Herramientas usadas

| Herramienta | Para qué se usó | Dónde consta |
|---|---|---|
| **Claude Code** | Programación y documentación sobre el repositorio: backend, API, datos y documento del MVC. Los commits registran los modelos usados: Claude Opus 4.8, Opus 5, Opus 5.5 y Sonnet 5.5 | Historial de git; notas de ingesta (§0) |
| **Claude Design** | Las 10 pantallas y el sistema de diseño | Brief de diseño UI |
| **Prompt Cowboy** | Generar el prompt inicial de las sesiones con Claude Code, donde se explicó cómo se iba a trabajar | Declarado por el equipo |
| **ChatGPT** (GPT-5.6) | Relevamiento, análisis funcional, ingeniería de requisitos, modelado, trazabilidad y revisión documental. También, como apoyo conversacional para entender cómo se conectan las partes del proyecto, revisar la entrega contra la consigna y ordenar borradores | Stack y referencias; artefactos de análisis y modelado |
| **ChatGPT Work** | Tres trabajos extensos: el análisis de la entrevista con VanFull, la explicación del MVC aplicado al proyecto y la actualización de los casos de uso y los artefactos de la Etapa 04 | AS-IS consolidado; Stack y referencias |
| **Gemini** | Disponible en plan pago. Se comparó en la práctica con ChatGPT y no se adoptó | Declarado por el equipo |
| **Claude** (familia Opus), en chat | No se usó durante el PC1 | Stack y referencias |
| **Codex** | No se usó hasta ahora. Está previsto para la implementación durante el desarrollo | Notas de ingesta (§0) |

### Propuestas y elección de herramientas

No hay registro de una discusión formal del equipo sobre qué herramienta usar, y tampoco se hizo una matriz comparativa ni un benchmark. Cada elección se basó en la experiencia previa y en cómo resultó la herramienta en la práctica.

**Para programar y diseñar.** No se consideraron otras herramientas. Se eligieron Claude Code y Claude Design porque ya se había trabajado con ellas, para poder usar archivos de instrucciones reutilizables (skills.md) y por su manejo del consumo de tokens. Además, se las considera de las mejores valoradas para el desarrollo de software.

**Para analizar y modelar.** Las alternativas consideradas en la práctica fueron ChatGPT y Gemini, ambas disponibles en planes pagos. Se eligió ChatGPT porque ofrecía un lenguaje más natural y respuestas más detalladas para el relevamiento y el análisis, y porque resultó más adecuado para el trabajo con diagramas en PlantUML, archivos draw.io e imágenes PNG, donde se encontraron más limitaciones con Gemini. Gemini quedó disponible como alternativa, sin adoptarse.

**Para entender el proyecto.** ChatGPT también se usó como apoyo conversacional: permitía plantear una duda, pedir una explicación más simple y profundizar hasta comprender el tema. Se valoró además que pudiera trabajar sobre la documentación existente, para que las respuestas estuvieran relacionadas con VanFull y con las decisiones del equipo, y no solo con conceptos generales. No se consideró necesario elegir una única herramienta para todas las tareas: la elección depende del tipo de trabajo y de la posibilidad de revisar el resultado.

**Para tareas extensas.** ChatGPT Work se usó en tres casos: el análisis de la entrevista con VanFull, la explicación del MVC aplicado al proyecto y la actualización de los casos de uso y los artefactos de la Etapa 04. El más relevante fue el análisis de la entrevista. En todos se mantuvo el mismo límite: la IA podía organizar, comparar, detectar contradicciones o proponer, pero no reemplazar la entrevista, las correcciones docentes ni las decisiones del equipo.

**Lo que no se usó.** Claude en chat no se usó durante el PC1. Codex tampoco: está previsto para la implementación y, cuando se use, se sumará lo que se aprenda con él. En el análisis no hizo falta ninguno de los dos, porque ese trabajo no consistió en generar código.

| Herramienta evaluada | Para qué se evaluó | Qué se tuvo en cuenta | Decisión |
|---|---|---|---|
| **Claude Code y Claude Design** | Programar, documentar y diseñar las pantallas | Experiencia previa, archivos de instrucciones reutilizables (skills.md) y manejo de tokens | **Elegidas; no se evaluaron otras** |
| **ChatGPT** | Relevamiento, análisis funcional, requisitos, UML, modelado, revisión y documentación | Calidad de redacción en español, nivel de detalle y capacidad para asistir con PlantUML, draw.io y PNG | **Elegida como herramienta principal de análisis** |
| **Gemini** | Alternativa para análisis y diseño | Según la experiencia de uso, respuestas menos naturales y detalladas, y más limitaciones con los diagramas e imágenes del proyecto | **No adoptada** |
| **ChatGPT Work** | Análisis documental extenso y actualización transversal de artefactos | Conveniencia para tareas largas con varias fuentes; necesidad de verificar cada resultado contra la fuente primaria | **Usada en tres trabajos puntuales** |
| **Claude en chat / Codex** | Posible uso en razonamiento y programación | No eran necesarios para las tareas del PC1 | **No usados en el PC1** |

### Cómo se usó en el diseño

- **Análisis.** La fuente primaria fue siempre la entrevista con el dueño. El informe previo que produjo la IA se usó solo como insumo para localizar contradicciones, no como fuente de información de VanFull.
- **Interfaces.** Antes de pedir una sola pantalla se escribió un brief de diseño con los contextos de uso de cada persona, la dirección visual, una lista de prohibiciones y una plantilla de prompt. Cada pantalla se pidió con su caso de uso, los datos reales del contrato (con la instrucción de no inventar campos) y datos de ejemplo reales.
- **Arquitectura, datos y API.** El contrato OpenAPI se escribió antes de programar, y el modelo SQL se ejecutó contra un PostgreSQL real y se comprobó que rechaza datos inválidos: no se dio por bueno solo lo que "se veía bien".
- **Programación.** La IA trabaja con reglas fijas escritas en el repositorio: explicar antes de hacer, pasos chicos, mostrar el cambio antes de incorporarlo, verificar en vez de suponer, y decir qué no se pudo verificar.

### Qué se hizo con cada herramienta

#### Claude Code y Claude Design

El historial del repositorio muestra el recorrido, con las fechas de los commits firmados:

- **Repositorio y modelo de desarrollo (08/09).** Estructura del monorepo, servidor FastAPI, Docker y convenciones.
- **Modelo de datos (21/09).** Las 35 tablas, ejecutadas y verificadas sobre PostgreSQL 16.
- **Contrato de la API (21/09).** OpenAPI en YAML y en JSON, validado con una herramienta.
- **Documentación de IA y agentes (21/09).** El agente AG-01 y sus herramientas.
- **Interfaces (24 y 25/09).** El brief de diseño, las 10 pantallas y el sistema de diseño.
- **Documento del MVC (26 al 30/09).** Redacción, consolidación y cierre del PC1.
- **Correcciones por la revisión cruzada (28/09 al 01/10).** Del contrato, del modelo y de las pantallas.
- **Decisión de alojamiento (02/10).** Comparación de Neon, Supabase, Render, Railway y Firebase con los límites de cada plan, tomados de su documentación oficial.
- **Documento v1.1 (08/10).** Propuestas, análisis, diagramas de actividad, de componentes y de despliegue.

#### ChatGPT

Se usó para organizar y revisar el relevamiento; consolidar el AS-IS; elaborar y revisar el alcance, los requisitos funcionales y no funcionales y las reglas de negocio; trabajar sobre los actores y los 37 casos de uso; revisar el modelo conceptual y los diagramas de actividad; asistir en el DER y el modelo relacional; mantener la trazabilidad; preparar controles de cambio; y hacer revisiones cruzadas entre requisitos, modelo, contrato de la API, interfaces y documentación.

También se usó para consultar dudas técnicas y comprender las decisiones del proyecto: el papel de FastAPI, la diferencia entre una API, el backend y la base de datos, y cómo una acción hecha en una pantalla llega al servidor y cómo este consulta o modifica los datos. Se usó para revisar la entrega del primer punto de control, comparando las indicaciones de la cátedra con el documento y con el material del proyecto, lo que ayudó a identificar qué apartados estaban cubiertos y cuáles requerían una explicación adicional o diagramas. Y se usó para elaborar borradores, que necesitaban una lectura posterior para verificar que expresaran correctamente el funcionamiento de VanFull.

#### ChatGPT Work

Se reservó para trabajos más extensos, que requerían comparar varias fuentes o actualizar varios artefactos relacionados. En el análisis de la entrevista, su resultado se usó como apoyo para detectar contradicciones y pendientes, y cada afirmación relevante se contrastó con la entrevista y con las decisiones aprobadas.

### Errores de la IA detectados y corregidos

Todos se encontraron al contrastar con el entregable real o con la fuente, no solo al releer el texto. Una respuesta bien redactada puede parecer correcta aunque contenga supuestos equivocados: por eso no alcanza con que la IA explique algo con seguridad, y cuando una respuesta era demasiado técnica se pidieron explicaciones más concretas y ejemplos de VanFull.

**Con Claude Code.**

- Afirmó que una decisión (ADJ-03) ya estaba propagada al documento del MVC; solo lo estaba en el archivo .md y no en el Word entregado. Se había verificado contra el repositorio y no contra el entregable.
- Afirmó que el Word del Drive "no se había modificado" desde cierta fecha, cuando ya tenía las imágenes pegadas. Se vio por el tamaño del archivo.
- Dijo que la carátula del Word no tenía los nombres del equipo, porque leyó el .md; el Word sí los tenía.
- Dijo que los reportes quedaban fuera del alcance; el apartado 1.4 los incluye como parte del alcance.
- Al regenerar el Word desde la v1.0 iba a pisar dos ediciones manuales hechas en el documento. Se detectó comparando con la versión vigente antes de entregarla.
- En las pantallas, la fecha "jueves 25/09" era un viernes. Se vio al verificar el calendario.

**Con ChatGPT y ChatGPT Work.**

- Con ChatGPT, una respuesta plausible podía conservar una regla o interpretación desactualizada si no se contrastaba con toda la línea base. Un caso concreto fue la semántica de pagos: en documentación previa permanecía la idea de que la confirmación final era siempre humana, pero el control de cambio aprobado establecía que Mercado Pago confirma automáticamente cuando informa válidamente una operación aprobada o acreditada. La contradicción se detectó en la revisión y se corrigió en los artefactos correspondientes.
- Con ChatGPT Work no hay documentado un error puntual atribuible exclusivamente a la herramienta que pueda separarse con certeza del resto de las revisiones. Su principal riesgo durante el análisis de la entrevista era que una inferencia útil se confundiera con información confirmada.

**En pantallas y documentos hechos con ayuda de IA.**

- **Reglas inventadas en las pantallas.** Tres pantallas afirmaban reglas que no existen en la línea funcional: un bloqueo tras cuatro intentos, una cancelación "ocho horas antes" y que un viaje sin vehículo no acepta reservas nuevas (el proyecto permite planificar un viaje y completar después la asignación de vehículo y chofer). Se quitaron. Un mensaje o un botón también puede introducir una regla de negocio, aunque parezca un detalle de presentación.
- **El flujo del código QR, invertido.** Una pantalla mostraba al chofer escaneando, cuando quien escanea el QR del vehículo es el pasajero. Se detectó el 28/09 en la revisión cruzada y se corrigió en las pantallas, el brief y el documento.
- **Una nota que contradecía al agente.** El documento de IA decía que AG-01 "solo consulta", pero tiene 13 herramientas e incluye crear y cancelar reservas.
- **Cifras que se desalinearon entre documentos** (11 contra 13 herramientas, 22 contra 23 esquemas). De ahí salió la regla de que un dato vive en un solo lugar.
- **Un contrato desactualizado.** El archivo JSON conservaba una descripción vieja de POST /viajes; se regeneró desde el YAML y se verificó que los dos fueran equivalentes.

### Qué decidió el equipo y no la IA

Estas decisiones constan en los documentos y no las tomó la IA:

- El stack y la arquitectura base (Flutter, FastAPI, PostgreSQL, OpenRouter), el monorepo y que el contrato OpenAPI se escribe antes de programar.
- Las reglas de trabajo con la IA: explicar antes de hacer, pasos chicos, ver el cambio antes de incorporarlo, y que cada commit y cada fusión los aprueba una persona antes de incorporarse.
- El alcance de las pantallas: diez de los 37 casos de uso, con los tres tipos de usuario.
- Las fechas válidas de los puntos de control: el cronograma preparado con IA traía las fechas de inicio de cada semana y se corrigieron a los viernes de encuentro (02/10, 30/10 y 13/11).
- El alojamiento sin costo (Neon, Render y GitHub Pages), después de comparar las opciones.
- Qué se incorpora al documento y qué no: por ejemplo, se sacaron dos fragmentos que la IA había redactado en la tabla de la propuesta seleccionada (la marca de pendiente del backend y la mención a PostGIS). Qué propuestas de la IA se aceptan como insumo, cuáles se rechazan y cuáles quedan como pendientes.
- Exigir trazabilidad entre artefactos y revisar los cambios contra la fuente de mayor autoridad antes de darlos por cerrados.
- Los requisitos, las reglas de negocio, los casos de uso y los ajustes transversales aprobados son decisiones del equipo, no de la IA.

Una propuesta de la IA debía coincidir con la documentación y con las decisiones del equipo antes de convertirse en parte del trabajo.

### Conclusiones

**Por herramienta.**

- **ChatGPT.** Sirvió para analizar, ordenar y explicar. Se recomienda para análisis, modelado, revisión y generación de propuestas cuando se le da una base documental clara y se conserva la revisión humana. Una respuesta convincente puede traer una regla desactualizada o un supuesto equivocado, y hay que contrastarla con la documentación.
- **ChatGPT Work.** Resultó especialmente útil para tareas largas que combinan varias fuentes, como el análisis de la entrevista y la actualización transversal de artefactos. Su resultado se usó para detectar contradicciones y pendientes, y cada afirmación relevante se contrastó con la fuente.
- **Claude Code.** Rinde cuando tiene reglas escritas y contexto en archivos. Por eso se escribieron CLAUDE.md, CONTEXTO.md y los prompts de arranque por tipo de tarea: un chat nuevo no arranca de cero, y se definió cuándo conviene abrir uno. El riesgo principal fue darlo por hecho sin verificar el entregable real; se corrigió exigiendo contrastar con el archivo final y decir explícitamente lo que no se pudo verificar (por ejemplo, que no se podían correr las pruebas ni renderizar el Word en esa máquina).
- **Claude Design.** Necesita un brief. Sin contexto de uso y sin prohibiciones explícitas produce el diseño promedio que genera cualquier IA; con el brief, las tres pantallas resultaron distintas a propósito.
- **Codex.** No se usó hasta ahora; todavía no hay experiencia que evaluar.

**Lo que muestra el historial del proyecto.**

- **La IA acelera, pero no decide.** Toda salida pasó por revisión humana antes de convertirse en requisito, regla o código. Una sugerencia de la IA no es una decisión del proyecto.
- **Un error que se repitió fue afirmar como hecho algo que nadie aprobó** (las tres reglas de las pantallas, por ejemplo). Por eso la regla de trabajo es que lo que no está aprobado es un pendiente, no una inferencia.
- **Verificar contra la fuente y ejecutar validaciones sirve.** Varios errores se encontraron contrastando contra el contrato, el modelo de datos o la línea funcional, y corriendo validaciones, no solo releyendo el texto.
- **Queda registro.** Al 08/10/2026, de los 30 commits propios del repositorio (sin contar las fusiones), 28 llevan la firma Co-Authored-By de Claude: se puede rastrear qué cambios se hicieron con ayuda de IA.
- **Ninguna IA se usó como fuente primaria**, y no se aceptó un requisito, una regla, una relación de datos o un comportamiento solo porque la respuesta fuera razonable. Las herramientas se repartieron por tipo de trabajo: ChatGPT para el análisis y para entender, Claude para el repositorio y las pantallas.

**Recomendación.** Pedir siempre el cambio mostrado antes de incorporarlo, y no aceptar una afirmación de "ya está hecho" sin una verificación que se pueda repetir.

**Lo que no se hizo.** No hubo una comparación formal de herramientas: cada elección se basó en la experiencia previa y en el uso. Estas conclusiones valen para el PC1; cuando Codex entre en el desarrollo habrá que sumar lo que se aprenda con él.

### Gobernanza

Revisión humana obligatoria antes de incorporar cualquier salida de IA. Según el modelo de desarrollo (sección 7.2), cada cambio entra por una rama y lo revisa un compañero antes de incorporarse. Se respeta una jerarquía de fuentes: lo que exigen los profesores, lo que confirmó VanFull, lo que decidió el equipo, y recién después las propuestas de IA, que solo valen una vez aprobadas.

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

La planificación sigue el calendario del cuatrimestre: **el trabajo sobre VanFull ocupa de la semana 4 a la
16**, que es cuando arranca la definición del problema. Las semanas van de lunes a viernes y el encuentro es
el viernes, así que cada punto de control cae el viernes de su semana.

| Sem | Semana del | Actividad | Hito |
|---|---|---|---|
| 4 | 24/08 | Definición del problema y planificación inicial | Objetivos, alcance y límites; repositorio y tablero |
| 5 | 31/08 | Relevamiento y análisis funcional | Actores, 45 RF, 14 RNF y 31 reglas de negocio |
| 6 | 07/09 | Modelado funcional | Casos de uso, diagramas de actividad, C4 de Contexto y de Contenedores |
| 7 | 14/09 | Diseño de arquitectura y datos | Modelo conceptual, DER y modelo relacional |
| 8 | 21/09 | Diseño de IA y comunicación entre sistemas | Selección de modelos, agente y prompts, contrato OpenAPI |
| **9** | **28/09** | **Interfaces gráficas y consolidación del documento** — *estamos acá* | **1er Punto de Control · viernes 02/10** |
| 10 | 05/10 | Desarrollo del backend | Modelos, reglas de negocio y endpoints sobre PostgreSQL |
| 11 | 12/10 | Desarrollo del frontend | Pantallas Flutter conectadas al backend |
| 12 | 19/10 | Integración de funcionalidades | Frontend, backend, IA, Mercado Pago y GPS de punta a punta |
| **13** | **26/10** | **Cierre del desarrollo** | **2do Punto de Control · viernes 30/10** |
| 14 | 02/11 | Pruebas y documentación | Pruebas funcionales, manual de instalación y de usuario |
| **15** | **09/11** | **Cierre de pruebas y documentación** | **3er Punto de Control · viernes 13/11** |
| 16 | 16/11 | Cierre | Cierre y aprobación · viernes 20/11 |

**Estamos en la semana 9.** Las semanas 4 a 8 están cerradas y su resultado es este documento. El desarrollo
del backend arranca la semana 10, el 5 de octubre, en el orden modelos → reglas de negocio → endpoints →
pruebas.

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

Esta sección es **para nosotros**, no para entregar. Es el guion de qué mostrar el viernes 2 de octubre.

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
