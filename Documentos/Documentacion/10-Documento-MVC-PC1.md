# VanFull — Documento con el MVC

**Trabajo de Campo · Proyecto Integrador con IA y Agentes**
Licenciatura en Sistemas | Ingeniería en Informática

**Primer Punto de Control — Análisis, Diseño y Planificación**
Entrega: 28/09/2026 · Versión 1.0

**Equipo:** Integrante 1 · Integrante 2 · Integrante 3

**Repositorio del proyecto:** https://github.com/Martiherenu1/ProyectoVanFull

**Estado congelado de esta entrega (tag `pc1`):** https://github.com/Martiherenu1/ProyectoVanFull/tree/pc1

---

## Índice

1. Presentación general del Proyecto
2. Arquitectura de la solución
3. Modelo — Datos y relaciones
4. Vista — Interfaces gráficas
5. Controlador — Comunicación Vista-Controlador y reglas de negocio
6. Modelos de IA y agentes
7. Modelo de desarrollo
8. Anexos

---

## Trazabilidad con la consigna

Esta tabla indica dónde encontrar cada uno de los puntos solicitados para el Primer Punto de Control.

| Solicitado en la consigna | Sección |
|---|---|
| Presentación general del Proyecto (Objetivos, antecedentes, justificación, alcances y límites) | 1 |
| Alcances y Límites | 1.4 |
| Arquitectura de la solución | 2 |
| Modelo Conceptual: Frontend, Backend (Negocios), Base de Datos | 2.2 |
| Modelo flujo - Gráficos: UML, C4 Model | 2.3 |
| Modelo: mermaid.js | 2.4 |
| Modelo de Datos y relaciones | 3 |
| Modelo de datos SQL | 3.4 y Anexo A |
| Modelo de Desarrollo utilizado con interfaces gráficas — interfaces | 4 |
| Comunicación V-C: Open API (Formato Json) | 5 y Anexo B |
| Modelos de IA utilizados y justificación | 6.1 |
| Agentes IA implementados | 6.2 |
| Selección de modelos (chat) y agentes IA - Prompts | 6.1 y 6.3 |
| Modelo de Desarrollo utilizado con interfaces gráficas — modelo | 7 |

---

# 1. Presentación general del Proyecto

> **PENDIENTE — Integrante 2.** Esta sección se redacta a partir del material ya producido en las carpetas
> `00_Control_y_Decisiones`, `01_Relevamiento_y_AS-IS` y `02_Alcance_RF_RNF_Reglas` del Drive. Se sugiere
> cubrir los cuatro puntos que nombra la consigna, en este orden:
>
> **1.1 Objetivos** — qué se propone lograr el sistema.
>
> **1.2 Antecedentes** — VanFull es una empresa real de transporte de pasajeros en combi (charters) que hoy
> opera con WhatsApp, Excel y teléfono: el pasajero avisa por mensaje que no viaja, el administrador anota a
> mano quién pagó, y el chofer lleva la lista impresa. Conviene desarrollar este punto con detalle, porque es
> lo que distingue al proyecto de un ejercicio académico. Material: entrevista y AS-IS consolidado, carpeta `01`.
>
> **1.3 Justificación** — qué problemas concretos resuelve la centralización y qué costos evita.
>
> **1.4 Alcances y límites** — resumen de los 45 requisitos funcionales, 14 requisitos no funcionales con sus
> métricas y 31 reglas de negocio, y de manera explícita **qué queda fuera del MVP**. Material: carpeta `02`.

---

# 2. Arquitectura de la solución

## 2.1 Visión general

VanFull es una aplicación **Web y Mobile** construida sobre una arquitectura **cliente-servidor por capas**.
El cliente es una única base de código Flutter que se despliega en las dos plataformas; el servidor es una API
REST en Python con FastAPI; la persistencia es PostgreSQL.

| Componente | Tecnología | Responsabilidad |
|---|---|---|
| Cliente Web y Mobile | Flutter | Presentación e interacción |
| API y lógica de negocio | Python · FastAPI | Autenticación, permisos, reglas de negocio, orquestación |
| Persistencia | PostgreSQL | Datos e integridad referencial |
| Agente conversacional | OpenRouter (MiniMax M3 / Nemotron 3 Super) | Interpretación de lenguaje natural |
| Cartografía y rutas | Google Maps Routes API | Recorridos, distancias y estimaciones |
| Pagos | Mercado Pago (sandbox) | Cobro y confirmación automática |
| Mensajería | WhatsApp | Canal alternativo de atención |

## 2.2 Modelo conceptual: Frontend, Backend y Base de Datos

**Frontend.** Flutter, con una sola base de código para Web y Mobile. No contiene reglas de negocio críticas:
valida formatos y mejora la experiencia, pero **ninguna decisión de negocio se toma en el cliente**. Un cupo,
un permiso o un pago nunca se resuelven en el dispositivo.

**Backend (Negocios).** FastAPI, organizado en cuatro capas con responsabilidades separadas:

| Capa | Responsabilidad |
|---|---|
| `routers/` | Reciben la petición HTTP y delegan. No contienen lógica de negocio. |
| `schemas/` | Contrato de entrada y salida (Pydantic). Validan forma, no reglas. |
| `services/` | **Las 31 reglas de negocio.** Es el corazón del sistema. |
| `models/` | Mapeo objeto-relacional. La única capa que toca PostgreSQL. |

**Base de Datos.** PostgreSQL con un esquema de 35 tablas. Las restricciones que pueden expresarse en el motor
se expresan allí (claves foráneas, `CHECK`, unicidad), de modo que la integridad no dependa exclusivamente de
la aplicación. El detalle está en la sección 3.

## 2.3 El mapeo MVC

El patrón Modelo-Vista-Controlador se materializa así en esta solución:

| Capa del patrón | En VanFull | Dónde |
|---|---|---|
| **Modelo** | El esquema de PostgreSQL y las reglas de negocio que lo gobiernan | `backend/db/schema.sql` · `services/` · sección 3 |
| **Vista** | La aplicación Flutter para Web y Mobile, en sus tres interfaces por actor | Sección 4 |
| **Controlador** | La API REST de FastAPI: los routers y el contrato OpenAPI que los describe | `backend/openapi/openapi.yaml` · sección 5 |

El agente conversacional **no constituye una cuarta capa paralela**: se apoya sobre el Controlador, consumiendo
exactamente los mismos endpoints que consume la Vista.

## 2.4 Principio de arquitectura: la IA no accede a los datos

La decisión de diseño más importante del sistema es la separación entre el componente de IA y las reglas de
negocio:

> El modelo de lenguaje **interpreta la intención** del usuario y **elige una herramienta**.
> **FastAPI valida y ejecuta.** El agente **no** accede directamente a PostgreSQL.

El fundamento es que un modelo de lenguaje es un componente **no determinístico**: ante la misma entrada puede
producir salidas distintas, y puede ser inducido a comportamientos no previstos mediante *prompt injection*.
Aislarlo detrás de una capa de validación determinística garantiza que ninguna respuesta del modelo pueda
otorgar un cupo inexistente, saltear un permiso o confirmar un pago.

**Diagrama de la solución (mermaid.js):**

```
flowchart TB
    subgraph Vista
        A[App Flutter<br/>Web y Mobile]
        W[WhatsApp]
    end
    subgraph Controlador
        R[FastAPI · routers]
        S[services<br/>31 reglas de negocio]
        CH[POST /chat<br/>orquestador de tools]
    end
    subgraph Modelo
        DB[(PostgreSQL<br/>35 tablas)]
    end
    LLM[OpenRouter<br/>MiniMax M3 / Nemotron]
    MP[Mercado Pago]
    GM[Google Maps Routes]

    A --> R
    W --> CH
    A --> CH
    CH -->|tool elegida| LLM
    LLM -->|nombre + argumentos| CH
    CH --> S
    R --> S
    S --> DB
    S --> MP
    S --> GM
    LLM -.->|sin acceso| DB
```

> **Nota para el armado del documento:** pegar este código en https://mermaid.live, exportar la imagen y
> reemplazar el bloque por el diagrama renderizado, dejando el código como anexo.

## 2.5 Diagramas C4 y UML

> **PENDIENTE — Integrante 2.** Insertar aquí los diagramas ya producidos en la carpeta
> `05_Arquitectura_API_Datos` del Drive: **C4 de Contexto** y **C4 de Contenedores**, cada uno con una breve
> lectura de qué muestra. Agregar también, desde la carpeta `04_Modelo_y_UML`, los diagramas de casos de uso
> por actor y los diagramas de actividad de los flujos principales.

## 2.6 Requisitos no funcionales que condicionan la arquitectura

| Requisito | Métrica | Consecuencia arquitectónica |
|---|---|---|
| Disponibilidad | 99% | Fallback de modelo de IA; degradación controlada |
| Tiempo de respuesta | 95% de operaciones ≤ 2 s; pesadas ≤ 5 s | Valores derivados calculados, no almacenados |
| Concurrencia | 100 usuarios simultáneos (pico de prueba 150) | API asíncrona (SQLAlchemy 2.0 async) |
| Escalabilidad | Soportar al menos el doble de la carga prevista | Capas desacopladas |
| Seguimiento GPS | Actualización cada 10 s; precisión ≤ 50 m; dato obsoleto > 30 s | Polling cada 10 s en el MVP; solo se almacena la última posición |
| Abordaje sin conexión | Sincronización ≤ 60 s sin duplicados | Registro local en el dispositivo del chofer y restricción de unicidad en la base |
| Recuperación | RTO ≤ 1 h · RPO ≤ 15 min | Política de respaldos |

---

# 3. Modelo — Datos y relaciones

## 3.1 Panorama

El modelo de datos consta de **35 tablas** organizadas en cinco bloques temáticos:

| Bloque | Contenido |
|---|---|
| 1 · Personas, clientes y acceso | `persona`, `pasajero`, `chofer`, `cliente` y sus especializaciones, `cuenta_acceso`, `rol_acceso`, `cuenta_rol` |
| 2 · Servicios y contratación | `servicio`, `tarifa`, `contratacion`, `abono_mensual`, `periodo_abono` |
| 3 · Viajes, recorridos y operación | `recorrido`, `parada`, `parada_recorrido`, `vehiculo`, `viaje`, `posicion_gps`, `reserva`, `abordaje`, `ausencia` |
| 4 · Cuenta corriente, pagos y comprobantes | `cuenta_corriente`, `pago`, `movimiento_cuenta`, `comprobante` |
| 5 · Operación y auditoría | `evento_operativo`, `nomina_pasajeros` |

## 3.2 Diagrama Entidad-Relación

> **PENDIENTE — Integrante 2.** Insertar el DER / Modelo Relacional oficial de la carpeta
> `05_Arquitectura_API_Datos`, con la lectura de las relaciones principales y las cardinalidades.

## 3.3 Decisiones de diseño

Más allá del inventario de tablas, el modelo toma cinco decisiones que conviene explicitar porque tienen
consecuencias directas sobre la corrección del sistema.

**Claves foráneas compuestas.** Una reserva no referencia simplemente a un viaje y a una parada por separado:
referencia al par `(viaje, recorrido)` y al par `(recorrido, orden de parada)`. De este modo la base **impide
por construcción** que una reserva quede asociada a una parada que no pertenece al recorrido de su viaje. Si
las claves fueran simples, esa coherencia dependería de que la aplicación nunca se equivoque.

**Restricción XOR en el respaldo de la reserva (MR-R13).** Toda reserva se respalda por un período de abono
**o** por una contratación directa, **exactamente una de las dos**. Se expresa con una restricción `CHECK` que
hace imposible almacenar una reserva sin respaldo o con respaldo doble.

**Unicidad de reserva y de abordaje.** Un pasajero tiene como máximo **una reserva por viaje** (MR-R15) y
**un abordaje por viaje** (MR-R24). La segunda restricción es la que permite que el escaneo de códigos QR
funcione sin conexión: aunque el dispositivo del chofer envíe el mismo abordaje dos veces al recuperar la
señal, la base lo rechaza. La sincronización sin duplicados (RNF-012) no depende de la aplicación.

**Valores derivados que deliberadamente no se almacenan (MR-R30).** El saldo de la cuenta corriente, la deuda
del pasajero y el cupo disponible de un viaje **no son columnas**: se calculan. Almacenarlos crearía una
segunda fuente de verdad que puede desincronizarse de los movimientos y las reservas que los originan. El
costo es un cálculo por consulta; el beneficio es que el dato no puede ser incorrecto.

**Roles resueltos con tablas de la aplicación.** Los permisos se modelan con `rol_acceso` y `cuenta_rol` en una
relación N:M, y no con roles del motor de base de datos. La razón es doble: los usuarios del sistema no son
usuarios de PostgreSQL, y las reglas RN-027 a RN-030 son **contextuales** — un chofer accede a la nómina *del
viaje que tiene asignado*, no a todas. Un `GRANT` no puede expresar esa condición.

## 3.4 Modelo de datos SQL y verificación

El modelo lógico se tradujo a un **DDL ejecutable para PostgreSQL** que implementa las 35 tablas, **54 claves
foráneas** (incluidas las compuestas), las restricciones `CHECK` de dominio, la restricción XOR y el catálogo
inicial de roles.

El esquema **se ejecutó contra un PostgreSQL 16 real** en un entorno Docker. La verificación confirmó la
creación de las 35 tablas, las 54 claves foráneas y los 5 roles, y comprobó que las restricciones rechazan
efectivamente los datos inválidos: un tipo de servicio fuera del dominio permitido es rechazado por la base,
no por la aplicación.

El archivo completo se incluye como **Anexo A**.

---

# 4. Vista — Interfaces gráficas

## 4.1 El criterio: tres contextos de uso, tres interfaces

Las interfaces de VanFull no derivan de una plantilla sino del **contexto físico** en que cada actor usa el
sistema. Esa es la decisión de la que se desprenden la densidad, el tamaño de los controles, el contraste y
hasta el tema de color.

| | Pasajero | Chofer | Administrador |
|---|---|---|---|
| Dónde está | Caminando hacia la parada | Parado en la puerta de la combi | Sentado en un escritorio |
| Cuándo | 6:00 de la mañana | 6:05, con la combi llenándose | Durante toda la jornada |
| Manos disponibles | Una, apurado | Una, la otra ocupada, posiblemente con guantes | Mouse y teclado |
| Condición de luz | Oscuridad o sol directo | Sol directo | Interior |
| Conexión | Puede ser mala | **Puede no haber** | Estable |
| Qué necesita saber en dos segundos | ¿Cuánto falta para que llegue? | ¿Este pasajero sube o no? | ¿Qué se rompió hoy? |
| Tema de color | Oscuro | Oscuro | Claro |
| Alto de fila | 48 px | **64 px** | 36 px |

De aquí se deriva que los controles del chofer midan 64 píxeles (debe poder tocarlos con guantes y una sola
mano), que su pantalla funcione **sin conexión**, y que el panel del administrador use tema claro y alta
densidad porque necesita ver seis viajes simultáneamente. **Si las tres interfaces se parecieran entre sí, el
diseño estaría mal.**

## 4.2 Sistema de diseño

Se construyó un sistema de diseño previo a las pantallas, con tres características:

**La paleta procede de la marca real.** Los colores se obtuvieron **muestreando los píxeles** del logotipo y de
la fotografía de la combi rotulada de la empresa: dorado `#D9A521`, grafito `#5F5F61`, franja `#414143` y
blanco de carrocería `#EAEBED`. No son colores elegidos por afinidad.

**El contraste está verificado.** Cada combinación se midió según WCAG. La verificación detectó tres límites
que quedaron documentados como reglas: el texto blanco sobre dorado alcanza solo 2,24:1 y está prohibido; el
dorado de marca como texto sobre fondo claro alcanza 2,07:1 y requiere una variante oscurecida; y los cuatro
colores de estado necesitan **dos valores cada uno**, uno por tema, para superar 4,6:1.

**La densidad es un token.** Los altos de fila y los tamaños mínimos de área táctil de la tabla anterior están
definidos como valores del sistema, de modo que ninguna pantalla los decida por su cuenta.

> **PENDIENTE — Integrante 3.** Insertar la lámina del sistema de diseño: paleta, escala tipográfica y
> componentes.

## 4.3 Las diez pantallas

El alcance de diseño del PC1 son **diez pantallas** que cubren los tres actores. Los 27 casos de uso restantes
reutilizan estos mismos patrones y no se diseñaron para este punto de control.

| # | Pantalla | Caso de uso | Actor |
|---|---|---|---|
| 1 | Inicio de sesión | CU-012 | Pasajero |
| 2 | Buscar servicio y disponibilidad | CU-002 | Pasajero |
| 3 | Confirmar reserva | CU-003 | Pasajero |
| 4 | Mis reservas y deuda | CU-010 · CU-006 | Pasajero |
| 5 | Registrar un pago | CU-014 | Pasajero |
| 6 | Seguimiento en vivo | CU-009 | Pasajero |
| 7 | Asistente conversacional | CU-011 | Pasajero |
| 8 | Lista de pasajeros del viaje | CU-008 | Chofer |
| 9 | Escaneo de código QR | CU-007 | Chofer |
| 10 | Viajes del día | CU-018 | Administrador |

> **PENDIENTE — Integrante 3.** Insertar las diez capturas, agrupadas por actor, cada una con su epígrafe.

## 4.4 Los estados que no son el camino feliz

Las pantallas no muestran únicamente el flujo exitoso. Cada una resuelve los estados de error y degradación
que se desprenden de los flujos alternativos de su caso de uso:

| Estado | Dónde se ve | Regla que lo origina |
|---|---|---|
| Sin cupo al confirmar (`409`) | Pantalla 3 | RN-001 — el cupo se verifica en el backend en el instante de confirmar |
| Reserva duplicada (`409`) | Pantalla 3 | RN-031 — una reserva por pasajero y viaje |
| Ventana de cancelación por vencer | Pantallas 3 y 4 | RN-017 a RN-019 |
| Posición de GPS obsoleta | Pantalla 6 | RNF-008 — más de 30 segundos de antigüedad |
| Sin conexión, con abordajes pendientes | Pantallas 8 y 9 | RNF-011 y RNF-012 |
| Código QR de un pasajero que ya abordó | Pantalla 9 | MR-R24 — la restricción de unicidad, visible en pantalla |

La última fila es significativa: una restricción del modelo relacional tiene una pantalla que la explica en
lenguaje natural al chofer. Modelo y Vista quedan así verificablemente alineados.

## 4.5 Prototipo navegable

Las pantallas no son imágenes estáticas: nueve de las diez son **recorribles**, con los enlaces funcionando
entre ellas y una barra de navegación inferior. El recorrido del pasajero puede transitarse completo, desde el
inicio de sesión hasta el seguimiento del vehículo. El enlace figura en el **Anexo E**.

---

# 5. Controlador — Comunicación Vista-Controlador y reglas de negocio

## 5.1 Contract-first

El contrato de la API **se definió antes de implementar el backend**. La razón es práctica: con el contrato
acordado, el equipo de Vista, el de Controlador y el del agente de IA pueden avanzar en paralelo sin
bloquearse mutuamente y sin romperse entre sí.

El contrato está escrito en **OpenAPI 3.0.3**: 21 rutas, **22 operaciones** y 22 esquemas, validado con
`openapi-spec-validator`. Se entrega en formato YAML y JSON (**Anexo B**).

Cuando el backend esté implementado, FastAPI expondrá su propio `/openapi.json` generado automáticamente, que
deberá coincidir con este contrato. Esa comparación es una verificación explícita del diseño.

## 5.2 Convenciones del contrato

**Autenticación.** JWT mediante `bearerAuth`. Son públicos `/auth/login`, las consultas de servicios y los
webhooks; el resto requiere token.

**Autorización por rol.** El backend valida los permisos endpoint por endpoint según `rol_acceso`
(RN-026 a RN-030).

**Errores uniformes.** Todas las respuestas de error comparten la forma `{ error: { codigo, mensaje, detalles } }`.

**Códigos HTTP coherentes con el negocio.** `400` para validación de forma, `401` sin autenticación, `403` sin
permiso, `404` inexistente y **`409` para conflictos de negocio**. La distinción importa: que no haya cupo no
es una petición mal formada, es un conflicto con el estado del sistema, y por eso no es un `400`.

## 5.3 Operaciones

| Caso de uso | Endpoint | Requisitos y reglas |
|---|---|---|
| CU-012 · Sesión | `POST /auth/login` · `POST /auth/logout` | RF-045 |
| CU-001 · Perfil del pasajero | `GET` y `PATCH /pasajeros/me` | RF-001 · RF-003 · RN-026 |
| CU-002 · Servicios y disponibilidad | `GET /servicios/disponibilidad` · `GET /servicios` · `GET /recorridos/{id}/paradas` | RF-004 · RN-001 |
| RF-028 · Tarifa aplicable | `GET /tarifas` | RN-010 a RN-014 |
| CU-003 · Crear reserva | `POST /reservas` | RF-005 · RN-001 · RN-002 · RN-031 |
| CU-004 · Cancelar reserva | `POST /reservas/{id}/cancelacion` | RF-006 · RN-017 a RN-019 |
| CU-005 · Cambio de parada | `POST /reservas/{id}/cambio-parada` | RF-008 · RN-020 |
| CU-006 · Consultar deuda | `GET /pasajeros/me/deuda` | RF-010 |
| CU-007 · Abordaje por QR | `POST /abordajes` | RF-014 · RF-015 · RN-023 · RNF-011 · RNF-012 |
| CU-008 · Informar ausencia | `POST /ausencias` | RF-016 · RN-024 · RN-025 |
| CU-009 · Ubicación y estimación | `GET /viajes/{id}/ubicacion` | RF-022 · RN-030 · RNF-007 · RNF-008 |
| CU-010 · Reservas propias | `GET /pasajeros/me/reservas` · `GET /reservas/{id}` | RF-043 |
| CU-011 · Agente conversacional | `POST /chat` | RF-029 · RF-032 |
| CU-014 · Registrar pago | `POST /pagos` | RF-009 · RN-016 |
| CU-016 · Confirmar o rechazar pago | `POST /pagos/{id}/confirmacion` | RF-011 · RN-015 |
| CU-018 · Gestionar viajes | `POST /viajes` · `GET /viajes` | RF-017 · RF-018 · RN-001 |
| CU-036 · Webhook de Mercado Pago | `POST /webhooks/mercadopago` | RF-012 · RN-015 |

Los casos de uso restantes siguen el mismo patrón —recurso, roles y errores— y se incorporarán en la segunda
versión del contrato.

## 5.4 Dónde viven las reglas de negocio

Las 31 reglas de negocio se validan en la capa `services/` del backend. **Nunca en el cliente Flutter y nunca
en el agente de IA.** Esta es la contrapartida directa del principio enunciado en la sección 2.4: si las reglas
vivieran en la Vista, bastaría con consumir la API desde otro cliente para saltearlas; si vivieran en el
agente, un *prompt* suficientemente astuto podría eludirlas.

---

# 6. Modelos de IA y agentes

## 6.1 Modelos de IA utilizados y justificación

La solución usa **OpenRouter** como gateway, lo que permite rutear entre modelos con una interfaz común y
aplicar una política de *fallback* sin modificar la arquitectura.

| Rol | Modelo | Identificador |
|---|---|---|
| Principal | MiniMax M3 Free | `minimax/minimax-m3:free` |
| Fallback | NVIDIA Nemotron 3 Super Free | `nvidia/nemotron-3-super-120b-a12b:free` |

**Los modelos no se eligieron por preferencia sino por evidencia.** Se construyó una prueba de concepto con una
batería común de **diez casos de prueba (TC-01 a TC-10)** y se evaluaron los candidatos con una **matriz de
criterios ponderada**:

| Criterio | Peso |
|---|---|
| Selección correcta de la herramienta | 25% |
| Exactitud de los argumentos | 20% |
| Seguridad y respeto de permisos y reglas | 15% |
| Ausencia de alucinación de datos operativos | 15% |
| Comprensión y respuesta en español | 10% |
| Respuesta estructurada y utilizable | 5% |
| Latencia | 5% |
| Disponibilidad y ausencia de errores | 5% |

**Resultado:** MiniMax M3 obtuvo **95,5 / 100** y Nemotron 3 Super **94,5 / 100**. Ambos alcanzaron 10 de 10
peticiones con respuesta correcta, 90% de acierto en la selección de herramienta y 90% en los argumentos, con
latencias de aproximadamente 2,5 y 2,8 segundos. Se descartaron GLM 5.2, Gemma y GPT-OSS por indisponibilidad
durante la ventana de prueba.

**Un hallazgo de la prueba cambió el diseño:** las **fechas relativas** —cuando el usuario dice «mañana»— **no
deben delegarse al modelo**. El backend inyecta la fecha y hora de forma determinística antes de ejecutar
cualquier herramienta. Delegar esa resolución al modelo introducía errores que ninguna validación posterior
podría detectar, porque la petición resultante es sintácticamente válida.

Se deja constancia, además, de la distinción entre la **IA usada para desarrollar el proyecto** (asistentes de
análisis, diseño y programación, siempre con revisión humana obligatoria) y la **IA que forma parte del
producto**, que es la que documenta esta sección.

## 6.2 Agentes IA implementados

**AG-01 — Agente Conversacional VanFull**

| Atributo | Definición |
|---|---|
| Objetivo | Atender consultas en lenguaje natural y ejecutar acciones habilitadas mediante herramientas controladas del backend |
| Usuarios | Pasajeros y clientes autorizados, desde la aplicación y desde WhatsApp — el mismo agente en ambos canales |
| Acceso a datos | Indirecto, solo a través de servicios de FastAPI. Sin acceso a PostgreSQL |
| Acciones críticas | Las valida el backend: no ignora cupos, permisos, reglas de pago ni privacidad |
| Ante error del proveedor | Reintenta con el modelo de respaldo; si no hay respuesta válida, informa la indisponibilidad y deriva a un humano |
| Canal de entrada | `POST /chat`, donde el backend orquesta el ciclo de herramientas |

**AG-02**, un asistente de operación para administradores, queda declarado como **extensión futura fuera del
alcance del MVP**.

**Las once herramientas y su trazabilidad.** Cada herramienta se corresponde con un caso de uso y con un
endpoint del contrato:

| Herramienta | Caso de uso | Endpoint |
|---|---|---|
| `consultar_disponibilidad()` | CU-002 | `GET /servicios/disponibilidad` |
| `consultar_horarios()` | CU-002 | `GET /servicios` |
| `consultar_recorridos()` | CU-002 | `GET /recorridos` |
| `consultar_paradas()` | CU-002 | `GET /recorridos/{id}/paradas` |
| `consultar_tarifa()` | RF-028 | `GET /tarifas` |
| `consultar_deuda()` | CU-006 | `GET /pasajeros/me/deuda` |
| `consultar_estado_pago()` | CU-006 | `GET /pasajeros/me/pagos` |
| `consultar_reserva()` | CU-010 | `GET /reservas/{id}` |
| `crear_reserva()` | CU-003 | `POST /reservas` |
| `cancelar_reserva()` | CU-004 | `POST /reservas/{id}/cancelacion` |
| `consultar_ubicacion_vehiculo()` | CU-009 | `GET /viajes/{id}/ubicacion` |
| `derivar_humano()` | RF-032 | Interno de `/chat` |

Ninguna herramienta hace algo que no esté respaldado por un caso de uso y validado por el backend. Reservar o
cancelar por chat reutiliza CU-003 y CU-004 con exactamente las mismas validaciones que cualquier otro canal.

**Flujo de una interacción:**

```
Usuario -> POST /chat
        -> Backend inyecta fecha, hora y contexto del usuario
        -> Modelo (MiniMax; si falla, Nemotron) elige herramienta y argumentos
        -> Backend ejecuta la herramienta = servicio FastAPI (valida reglas, permisos, cupo)
        -> El resultado vuelve al modelo
        -> Respuesta en lenguaje natural
        -> Si no puede resolverse de forma segura, o el usuario lo pide: derivar_humano()
```

## 6.3 Prompt base

```
Sos el asistente conversacional de VanFull.
Fecha actual del sistema: <provista por backend>.
- Atendé únicamente consultas vinculadas con VanFull.
- Nunca inventes cupos, horarios, tarifas, pagos ni deudas.
- Para datos operativos usá las herramientas disponibles.
- No reveles datos personales de terceros.
- No modifiques estados de pago.
- No permitas reservas por encima del cupo.
- Las reglas de negocio las valida el backend.
- Si faltan datos esenciales, pedilos antes de ejecutar una acción.
- Si el usuario pide atención humana, usá derivar_humano().
- Rechazá solicitudes ajenas a VanFull de manera breve.
```

## 6.4 Seguridad del agente

- No se envían al modelo documentos de identidad, fotografías ni datos de contacto de terceros: se usan
  identificadores internos y el mínimo contexto necesario.
- El backend autoriza antes de devolver reservas, ubicación, deuda o estado de pagos (RN-026 a RN-030).
- **La confirmación de pagos es humana** (RN-015). El agente no puede modificarla, y así se lo indica al
  usuario cuando lo intenta.
- La prueba de concepto incluyó casos de seguridad específicos: rechazo de alteración de pagos (TC-07),
  privacidad e inyección de *prompt* (TC-08), consultas fuera de alcance (TC-09) y derivación (TC-10).
- Ante un fallo del proveedor o de una herramienta se registra el error y se aplica el respaldo o la
  derivación. **Nunca se inventa una respuesta.**

---

# 7. Modelo de desarrollo

## 7.1 Control de versiones

El proyecto es un **monorepo** en Git alojado en GitHub, con rama principal `main`. La raíz contiene el código
y la configuración; toda la documentación que no es código vive en `Documentos/`.

El criterio de qué se guarda dónde: **Google Drive** para la documentación oficial del equipo, **Git** para el
código y los artefactos versionables (`.md`, `.sql`, `.yaml`, `.puml`). Los archivos binarios de ofimática
quedan fuera del repositorio porque Git no puede compararlos ni fusionarlos. Las credenciales nunca se
versionan.

## 7.2 Flujo de trabajo

```
Issue -> Branch -> Desarrollo -> Commit -> Pull Request -> Revisión -> Merge
```

Un issue por cada funcionalidad, defecto o tarea técnica, atado a un caso de uso o requisito. Una rama por
tarea; nunca se commitea directo a `main`. El Pull Request es la unidad de revisión y lo revisa un compañero.
Los merges se hacen con `--no-ff`, de modo que el historial conserve visible cada unidad de trabajo. `main` se
mantiene siempre en estado desplegable.

Las ramas siguen `<tipo>/<descripcion-corta>` y los commits la convención **Conventional Commits**, con
referencia al caso de uso o regla en el cuerpo del mensaje.

## 7.3 Trazabilidad

La cadena que debe poder recorrerse para cualquier funcionalidad:

```
CU -> operación -> endpoint -> servicio -> datos -> prueba
```

## 7.4 Calidad

| Herramienta | Para qué |
|---|---|
| **ruff** | Lint y formato de Python |
| **pytest** | Pruebas automatizadas |
| **Docker Compose** | Entorno reproducible: PostgreSQL y API |

Antes de dar una tarea por terminada se verifica que exista un requisito que justifique el cambio, que respete
actores y permisos, que las reglas se validen en el backend, que el contrato OpenAPI esté actualizado si la API
cambió, que existan pruebas y que `ruff` y `pytest` pasen.

## 7.5 Planificación

> **PENDIENTE — Equipo.** Insertar el cronograma de las 16 semanas con el estado actual y los hitos de los
> tres puntos de control. Material: `Cronograma_VanFull` y la carpeta `00` del Drive.

---

# 8. Anexos

| Anexo | Contenido | Ubicación |
|---|---|---|
| **A** | Modelo de datos SQL — DDL completo de 35 tablas | Repositorio, tag `pc1`: `backend/db/schema.sql` |
| **B** | Contrato OpenAPI, en YAML y JSON | Repositorio, tag `pc1`: `backend/openapi/` |
| **C** | IA y agentes — documento consolidado | Drive, carpeta `07_PC1_Integracion_Final` |
| **D** | Modelo de desarrollo — documento completo | Drive, carpeta `07_PC1_Integracion_Final` |
| **E** | Prototipo navegable de las diez pantallas | Enlace en el Anexo del Drive |
| **F** | Sistema de diseño — tokens, componentes y marca | Enlace en el Anexo del Drive |
| **G** | Especificaciones de los 37 casos de uso | Drive, carpeta `03_Actores_y_Casos_de_Uso` |
| **H** | Diagramas C4, UML y DER | Drive, carpetas `04_Modelo_y_UML` y `05_Arquitectura_API_Datos` |

**Repositorio del proyecto:** https://github.com/Martiherenu1/ProyectoVanFull

**Estado congelado de esta entrega:** https://github.com/Martiherenu1/ProyectoVanFull/tree/pc1
