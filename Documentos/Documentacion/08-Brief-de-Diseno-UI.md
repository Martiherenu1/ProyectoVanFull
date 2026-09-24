# Brief de Diseño UI — Vanfull

> **Para qué sirve:** es el insumo que se pega **al principio de cada prompt** de diseño (Claude Design) y
> el que se usa para armar el Design System. Fija las decisiones de marca y de interfaz **antes** de dibujar
> pantallas, que es la única forma de que el resultado no sea el diseño promedio que genera una IA sin dirección.
>
> **Estado:** v0.2 — **paleta anclada en la marca real** (logo y combi de VanFull, colores muestreados de los
> píxeles y verificados con contraste WCAG). Quedan abiertas las decisiones 2 a 5 de §12.
> **Autor:** Integrante 1+3 (Martiniano). **Fecha:** 2026-09-24. **Destino:** PC1 (28/09).

---

## 1. Cómo usar este documento

| Momento | Qué se usa |
|---|---|
| Armar el Design System | §4 a §7 completas |
| Diseñar **cada** pantalla | §3 + §5 (resumen de tokens) + §7 + §8 + §9 + la fila de §11 que corresponda |
| Revisar un diseño terminado | §7 (prohibiciones) + §8 (estados) como checklist |
| Pasar a Flutter | §5 (tokens → `ThemeData`) + §10 (microcopy) |

La plantilla de prompt lista para copiar está en §13.

---

## 2. El producto en cinco líneas

VanFull es una empresa **real** de transporte de pasajeros (charters). Hoy opera con **WhatsApp, Excel y
teléfono**: el pasajero avisa por mensaje que no viaja, el administrador anota a mano quién pagó, el chofer
lleva la lista impresa. El sistema centraliza reservas y cupos, cobros, seguimiento del vehículo y un agente
conversacional. **No es un producto nuevo que hay que explicar: es un trabajo que ya existe y hay que
hacer más rápido.** Eso define el tono: nada de onboarding entusiasta, nada de venta. Es una herramienta
de trabajo diario para gente que ya sabe qué es un charter.

---

## 3. Los tres contextos de uso ⭐

**Esta es la sección más importante del documento.** Es lo que ninguna herramienta puede inferir sola, y es
lo que justifica que las tres interfaces se vean distintas entre sí.

| | **Pasajero** | **Chofer** | **Administrador** |
|---|---|---|---|
| **Dónde está** | Caminando a la parada | Parado en la puerta de la van | Sentado en un escritorio |
| **Cuándo** | 6:00 AM, oscuro y con frío | 6:05 AM, la van llenándose | Todo el día |
| **Cómo sostiene el teléfono** | Una mano, apurado | Una mano, la otra ocupada, **puede tener guantes** | Mouse y teclado, pantalla grande |
| **Luz** | Oscuridad o sol directo | Sol directo | Interior |
| **Conexión** | Puede ser mala | **Puede no haber** (RNF-011/012: offline con sync ≤60 s) | Estable |
| **Qué necesita en 2 segundos** | *"¿Ya viene? ¿Cuánto falta?"* | *"¿Este sube o no?"* | *"¿Qué se rompió hoy?"* |
| **Consecuencia de diseño** | Fondo oscuro, **un dato gigante**, cero navegación profunda | **Targets de 64 px**, contraste máximo, funciona sin señal | **Densidad máxima**, tabla, todo a la vista |

**Regla derivada:** si la pantalla del pasajero y la del admin se parecen, el diseño está mal.
La asimetría entre las tres **es** la prueba de que se entendió el negocio.

---

## 4. Dirección de diseño: la referencia

La referencia visual **no es una app SaaS**. VanFull es transporte terrestre y horarios, así que el lenguaje
que le corresponde es el de la **señalética de transporte y los tableros de horarios**: terminal de ómnibus,
subte, aeropuerto. En particular los **tableros split-flap** de salidas — dorado sobre grafito, números
alineados en columna, cero decoración, información pura.

**Por qué esta referencia y no otra:**
1. Es **verdadera respecto del negocio** (horarios, paradas, estados, cupos: es literalmente un tablero).
2. Resuelve los tres contextos de §3: el contraste dorado/grafito se lee al sol y de noche, y la densidad de
   tablero es lo que el admin necesita.
3. Es un territorio visual que las herramientas de IA **no eligen por default**, así que el resultado no se
   va a parecer al de nadie más.
4. ⭐ **La marca real ya es exactamente eso.** El logo de VanFull es un dorado mostaza (`#D9A521`) con
   contorno grafito (`#5F5F61`), y la combi es blanca con una franja grafito. Dorado sobre grafito **es** la
   paleta del tablero de salidas. La referencia no se le impone al negocio: sale de él.

**Tres palabras que tiene que transmitir:** *operativo · legible · confiable.*
**Tres que NO:** *moderno · innovador · premium.*

---

## 5. Tokens de diseño

### 5.1 Color

**Los tres colores de marca están muestreados de los píxeles del logo y de la combi**, no elegidos a ojo:

| Color | Hex | Origen |
|---|---|---|
| **Dorado VanFull** | `#D9A521` | relleno de las letras del logo |
| **Grafito** | `#5F5F61` | contorno del logo |
| **Grafito oscuro** | `#414143` | franja lateral de la combi |
| **Blanco carrocería** | `#EAEBED` | chapa de la combi |

**Rampa de neutros** — gris **verdadero**, anclado en los dos grafitos reales de la marca:

```
--ink-950  #0E0E10   fondo base oscuro (pasajero, chofer)
--ink-900  #17171A   texto principal sobre claro
--ink-800  #1F1F22   superficie elevada sobre oscuro
--ink-700  #2B2B2E   borde / divisor sobre oscuro
--ink-600  #414143   ← franja real de la combi
--ink-500  #5F5F61   ← grafito real del logo · solo bordes y texto grande (3.03:1)
--ink-400  #8A8A8D   texto secundario sobre oscuro (5.60:1 · AA)
--ink-300  #B4B4B7   deshabilitado
--ink-200  #D5D6D8   borde sobre claro
--ink-100  #EAEBED   ← blanco carrocería · texto principal sobre oscuro (16.17:1 · AAA)
--ink-050  #F5F6F7   fondo base claro (admin)
--paper    #FFFFFF   superficie sobre claro
```

**Acento único — el dorado de la marca:**

```
--gold-500  #D9A521   marca · dato dominante · relleno de acción primaria
--gold-600  #B3891C   hover / pressed del relleno dorado
--gold-700  #8C6A15   el dorado COMO TEXTO, solo sobre fondo claro
```

**Tres reglas del dorado, las tres medidas:**

| Uso | Ratio | Veredicto |
|---|---|---|
| Dorado sobre fondo oscuro `#0E0E10` | **8.59:1** | ✅ AAA — es el color del dato dominante |
| Texto `--ink-900` sobre relleno dorado | **7.97:1** | ✅ AAA — así se hace el botón primario |
| Texto **blanco** sobre relleno dorado | **2.24:1** | ⛔ **falla** — sobre dorado el texto va siempre oscuro |
| Dorado como texto sobre fondo claro `#F5F6F7` | **2.07:1** | ⛔ **falla** — usar `--gold-700` (4.63:1) |

> ⚠️ **La consecuencia menos obvia:** en el tema claro del **administrador**, el dorado de marca **no se puede
> usar como texto ni para elementos chicos**. Ahí vive solo como **relleno** (con texto oscuro encima) o en
> superficies grandes. El dorado brilla sobre oscuro; sobre claro hay que oscurecerlo.

**Colores de estado — reservados. Prohibido usarlos como decoración.**
Dos valores por estado porque el sistema tiene dos temas; **todos ≥ 4.6:1** sobre su fondo:

| Estado | Sobre oscuro | Sobre claro | Significa |
|---|---|---|---|
| `--status-ok` | `#358C5A` | `#2F7D50` | abordó · pago CONFIRMADO · al día |
| `--status-alert` | `#D64F40` | `#BF4739` | ausente · sin cupo · pago RECHAZADO · deuda |
| `--status-wait` | `#5C809E` | `#51728C` | reserva provisional · pago PENDIENTE |
| `--status-stale` | `#947A4D` | `#826B44` | GPS desactualizado (>30 s, RNF-008) |

`--status-stale` es **el dorado de marca desaturado**: semánticamente es la marca degradada, y se *siente*
apagada sin ser alarmante. Es la diferencia entre "este dato está viejo" y "algo se rompió".

**Regla de color:** una pantalla usa neutros + **el dorado** y nada más. Si aparece verde o rojo es porque hay
un estado real de los datos — nunca por estética.

### 5.2 Tipografía

| Rol | Fuente | Por qué |
|---|---|---|
| **UI y texto** | **Archivo** (Google Fonts) | Grotesca con carácter de señalética, tiene versión variable y condensada |
| **Números y datos** | **IBM Plex Mono** (Google Fonts) | Horarios, importes, patentes, DNI y cupos **tienen que alinearse en columna**. Mono es la elección de tablero. |

Ambas están en el paquete `google_fonts` de Flutter.

> ⛔ **Inter está prohibida.** No porque sea mala, sino porque es la huella digital del diseño generado
> por IA: es el default de casi toda herramienta y librería de componentes.

**Escala** (cualquier cosa fuera de esta lista no existe):

```
display   44 / 48   IBM Plex Mono, 500   el dato dominante (ETA, cupo, horario, saldo)
h1        28 / 34   Archivo, 600
h2        20 / 26   Archivo, 600
h3        16 / 22   Archivo, 600
body      15 / 22   Archivo, 400
small     13 / 18   Archivo, 400
micro     11 / 14   Archivo, 600, MAYÚSCULAS, tracking 0.08em   ← etiquetas tipo señalética
data      15 / 20   IBM Plex Mono, 400   cualquier número en una lista o tabla
```

### 5.3 Espaciado, forma y densidad

```
Base 4 px. Escala: 4 · 8 · 12 · 16 · 24 · 32 · 48. Nada intermedio.

Radio:      2 px en todo (botones incluidos). Nada redondeado, nada pill.
Borde:      1 px  --ink-700 (tema oscuro) / --ink-200 (tema claro)
Elevación:  NO hay sombras difusas. Se eleva cambiando a la superficie más clara (--ink-800).

Alto de fila:     48 px pasajero  ·  64 px chofer  ·  36 px admin
Target táctil:    48 px mínimo    ·  64 px mínimo chofer (guantes)
```

### 5.4 Iconografía

**Material Symbols, estilo Sharp, relleno (`filled`), peso 500.** Nativo de Flutter.
Los bordes rectos del estilo Sharp acompañan el radio de 2 px, y el relleno evita el look de
"icono de línea fina" que es otro tell clásico.

⛔ Nada de emojis como iconos. ⛔ Nada de iconos decorativos: un icono existe solo si reemplaza una palabra.

### 5.5 Activos de marca

En `Documentos/Recursos/marca/`. El original que pasó la empresa es un PNG de 484×70 px; se **vectorizó**
(trazado de contornos sobre el bitmap) para que escale sin pixelarse, y se le fijaron los colores exactos
de §5.1.

| Archivo | Uso |
|---|---|
| `vanfull-logo.svg` | Logo sobre fondo claro (dorado + contorno grafito). **Formato preferido.** |
| `vanfull-logo-sobre-oscuro.svg` | Logo sobre fondo oscuro — el contorno pasa a `--ink-100`, porque el grafito desaparece contra el fondo |
| `vanfull-logo*.png` | Mismos dos, rasterizados a 1936×280 con fondo transparente |
| `vanfull-combi.png` | Foto de la combi rotulada — referencia, y material para la presentación |
| `vanfull-logo-original.avif` | El archivo tal como lo pasó la empresa (484×70). Se conserva como fuente. |

**Reglas de uso del logo:**
- Sobre fondo oscuro va **siempre** la variante `-sobre-oscuro`. La normal pierde el contorno.
- Área de respeto mínima alrededor: la altura de la "V".
- No se le cambia el color, no se le pone sombra, no se deforma, no se le agrega contenedor.
- El logo **no** aparece en pantallas operativas del chofer: ocupa lugar y no aporta información.

> ⚠️ El trazado es una reconstrucción fiel del PNG de baja resolución, no un redibujo de la tipografía
> original. Si la empresa tiene el archivo vectorial original (`.ai`, `.eps` o `.svg`), conviene pedirlo y
> reemplazarlo — es gratis y es mejor.

---

## 6. Reglas de composición

1. **Una pantalla = un dato dominante + una lista densa.** El dato dominante va en `display` y ocupa el
   primer tercio de la pantalla. Todo lo demás es soporte.
2. **Alinear a la izquierda.** Nada de layouts centrados (otro tell).
3. **Romper la grilla de tres.** Ninguna pantalla lleva tres tarjetas iguales en fila.
4. **Las listas son listas**, no tarjetas. Filas separadas por un divisor de 1 px, sin contenedor propio,
   sin sombra, sin radio. Es un tablero.
5. **El estado siempre se lee como texto**, no solo como color (accesibilidad y sol directo).
6. **Los números se alinean a la derecha** cuando están en columna.
7. **Cero scroll horizontal** en móvil.
8. **El header no es un hero.** Máximo dos líneas: qué pantalla es y el dato de contexto.

---

## 7. Prohibiciones ⛔

Lista cerrada. Se pega tal cual en cada prompt. Cada ítem es un *tell* documentado de diseño generado por IA.

```
⛔ Gradientes de cualquier tipo — en especial indigo/violeta→azul
⛔ Glassmorphism, blur de fondo, superficies translúcidas
⛔ Fondos "aurora", blobs, manchas difusas, mesh gradients
⛔ La fuente Inter (ni como fallback declarado)
⛔ Tres tarjetas redondeadas en fila con sombra suave e iconos de línea fina
⛔ Sombras difusas / box-shadow de desenfoque
⛔ Radios grandes (>4 px) y elementos tipo "pill"
⛔ La franja de color de 3-4 px a la izquierda de una tarjeta
⛔ Emojis usados como iconos
⛔ Bento grids
⛔ Layouts centrados
⛔ Texto con gradiente
⛔ Lorem ipsum, "John Doe", "Item 1", precios en dólares
⛔ Copy genérico: "Todo en un solo lugar", "Gestión inteligente", "Bienvenido!", "Potenciá tu…"
⛔ Ilustraciones vectoriales de stock (personitas planas)
⛔ Dark mode donde el contexto de §3 no lo pide (el admin va en claro)
```

---

## 8. Estados obligatorios de toda pantalla

Ninguna pantalla está terminada si no tiene resueltos los estados que le aplican. **Los flujos alternativos
del CU son los que generan estos estados** — de ahí se sacan, no se inventan.

| Estado | Cuándo | Qué se muestra |
|---|---|---|
| **Cargando** | siempre | Esqueleto con la forma real del contenido. Sin spinner centrado. |
| **Vacío** | lista sin datos | Qué falta y **la acción** para resolverlo. Sin ilustración. |
| **Error de negocio** | `409` | El motivo **concreto**: *"Sin cupo en el 6:15"*, no *"Error al crear la reserva"* |
| **Sin permiso** | `403` | Qué rol hace falta |
| **Sin conexión** | chofer, siempre | Qué sigue funcionando y qué queda pendiente de sincronizar (RNF-011/012) |
| **Dato desactualizado** | GPS >30 s (RNF-008) | `--status-stale` + la antigüedad exacta en segundos |
| **Límite de negocio alcanzado** | RN-017/018/019, RN-031 | La regla **antes** de que el usuario intente la acción |

---

## 9. Datos de ejemplo (fixture obligatorio)

**Prohibido el placeholder genérico.** Estos son los datos que se usan en todos los mockups.
Campos y valores tomados de `backend/db/schema.sql` y `backend/openapi/openapi.yaml`.

```
EMPRESA      VanFull
SERVICIO     UNIVERSITARIO   (enum real: UNIVERSITARIO | LABORAL | CORPORATIVO | ESPECIAL)
VEHÍCULO     Mercedes-Benz Sprinter · patente AB 412 KJ · capacidad 19
CHOFER       Rubén Cardozo
HORARIOS     05:40 · 06:15 · 07:30 · 13:20 · 18:20
SENTIDO      IDA | VUELTA   (enum real)

PARADAS (orden dentro del recorrido)   ⚠️ reemplazar por las reales del relevamiento FC-01
  1  Av. San Martín 1240
  2  Plaza Belgrano
  3  Terminal de Ómnibus
  4  Ruta 11 y Acceso Norte
  5  Facultad de Ingeniería

PASAJEROS    Camila Ferreyra · Nicolás Ávalos · Julieta Sosa · Matías Quiroga
             Rocío Benítez · Agustín Maidana
DNI          41.238.905

IMPORTES     Abono mensual  $ 38.500,00
             Viaje suelto   $  2.900,00
             Saldo deudor   $ 11.600,00
             Formato: $ con punto de miles y coma decimal. Nunca USD.

CUPO         "14 de 19"  ·  cupo_disponible es derivado (capacidad − reservas), no está en la BD (MR-R30)
```

---

## 10. Vocabulario de interfaz (microcopy)

Español de Argentina, **voseo**, tono operativo. Frases cortas, con el dato adentro.

| Concepto | Se dice | No se dice |
|---|---|---|
| Reserva `provisional` | **Provisional** | Pendiente de aprobación |
| Reserva `consolidada` | **Confirmada** | Consolidada *(término de BD, no de usuario)* |
| Sin cupo (`409`) | **Sin cupo en el 6:15** | Error al procesar la solicitud |
| Reserva duplicada (RN-031) | **Ya tenés una reserva en este viaje** | Conflicto: recurso duplicado |
| Ventana de cancelación (RN-017) | **Podés cancelar hasta las 22:15 de hoy** | Política de cancelación |
| ETA (CU-009) | **Llega a Plaza Belgrano en 8 min** | Tiempo estimado de arribo |
| GPS viejo (RNF-008) | **Última posición hace 47 s** | Datos no disponibles |
| Abordaje (CU-007) | **Escaneá el QR del pasajero** | Iniciar proceso de validación |
| Ausencia (CU-008) | **Avisar que no viajo** | Reportar ausencia |
| Deuda al día | **Al día** | Sin deudas pendientes |
| Offline (chofer) | **Sin señal — 3 abordajes se suben al recuperar conexión** | Modo offline activado |

---

## 11. Las 8 pantallas del PC1

**Alcance de diseño del PC1: estas 8.** Cubren los 3 actores y las dos funcionalidades diferenciales
(seguimiento en vivo y agente conversacional). Los 29 CU restantes quedan explícitamente fuera del alcance
de diseño del PC1: reutilizan los patrones que estas 8 dejan definidos.

| # | Pantalla | CU | Endpoint | Campos reales | Estado / regla que se ve |
|---|---|---|---|---|---|
| 1 | **Login** | CU-012 | `POST /auth/login` | email, contraseña | `401` credenciales inválidas |
| 2 | **Buscar servicio** | CU-002 | `GET /servicios/disponibilidad`, `GET /recorridos/{id}/paradas` | `fecha`, `horario`, `sentido`, **`cupo_disponible`**, `orden`, `nombre_descripcion` | Vacío (sin viajes ese día) · cupo 0 |
| 3 | **Confirmar reserva** | CU-003 | `POST /reservas` + `GET /tarifas` | `id_viaje`, `orden_parada`, `importe`, `nombre` (tarifa) | **`409` sin cupo** · **`409` ya reservado (RN-031)** |
| 4 | **Mis reservas y deuda** | CU-010 / CU-006 | `GET /pasajeros/me/reservas`, `GET /pasajeros/me/deuda` | `estado` (provisional/consolidada/cancelada), `saldo`, `estado` (al_dia) | Vacío · **ventana de cancelación RN-017** |
| 5 | **Seguimiento en vivo** ⭐ | CU-009 | `GET /viajes/{id}/ubicacion` (polling 10 s, RNF-007) | `latitud`, `longitud`, `eta_minutos`, **`desactualizada`**, `fecha_hora_posicion` | **`desactualizada: true` → `--status-stale`** · `eta_minutos: null` |
| 6 | **Chat con AG-01** ⭐ | CU-011 | `POST /chat` | mensaje, respuesta, **tool invocada** | El agente **no confirma pagos** — deriva. Fecha relativa resuelta por el backend. |
| 7 | **Chofer: lista + QR** ⭐ | CU-007 / CU-008 | `POST /abordajes`, `POST /ausencias` | `id_pasajero`, `id_viaje`, `id_vehiculo`, `orden_parada` | **Offline (RNF-011/012)** · abordaje duplicado (MR-R24) · targets 64 px |
| 8 | **Admin: viaje del día** | CU-018 | `POST /viajes`, `GET /viajes` | `estado` (programado/en_curso/finalizado/cancelado), `capacidad_planificada`, `patente`, chofer | Viaje sin vehículo ni chofer asignado (ambos son 0..1 en planificación) |

*Novena, si alcanza el tiempo:* **Pago** (CU-014, `POST /pagos`) — `medio_pago` con el enum real
(EFECTIVO · TRANSFERENCIA · BILLETERA · CUENTA_CORRIENTE · MERCADO_PAGO) y `estado` PENDIENTE/CONFIRMADO/RECHAZADO.

---

## 12. Decisiones pendientes (las cierra Martiniano)

| # | Decisión | Impacto si cambia |
|---|---|---|
| ~~1~~ | ~~Colores / logo / foto de la van reales~~ | ✅ **Cerrada (24/09).** Logo y combi recibidos; paleta muestreada de los píxeles y verificada con contraste (§5.1). Único resto: pedir el vectorial original si existe (§5.5). |
| 2 | **Ciudad y paradas reales** (relevamiento FC-01) | Reemplaza el fixture de §9 |
| 3 | **¿El panel de administración es solo web?** | Si es solo web, la densidad del admin puede ser todavía mayor |
| 4 | **Confirmar Archivo + IBM Plex Mono** | Es una propuesta; cualquier par que no sea Inter y tenga mono para datos sirve |
| 5 | **¿La UI dice "Confirmada" o "Consolidada"?** | §10 propone "Confirmada" (el término de BD no se le muestra al usuario) |

---

## 13. Plantilla de prompt

Para cada pantalla, pegar este bloque con el brief adjunto:

```
Diseñá la pantalla «<nombre>» de VanFull (app de charters).

CONTEXTO DE USO: <copiar la columna del actor de §3>

CASO DE USO <CU-0XX>: <flujo principal del CU de Int2>
FLUJOS ALTERNATIVOS: <los alternativos — de acá salen los estados>

DATOS QUE LLEGAN (contrato real, no inventar campos):
<pegar el schema del endpoint desde backend/openapi/openapi.yaml>

DATOS DE EJEMPLO: usar exclusivamente el fixture de §9. Nada de lorem ni placeholders.

ESTADOS A DIBUJAR: <los que apliquen de §8>
REGLA DE NEGOCIO VISIBLE: <la de la fila de §11>

DIRECCIÓN VISUAL: §4. TOKENS: §5, sin salirse de la escala. COMPOSICIÓN: §6.
PROHIBIDO: §7 completa.
MICROCOPY: §10, voseo argentino.
```

---

## Trazabilidad

- **Requisitos de UI:** RNF-007/008 (GPS 10 s / stale >30 s), RNF-011/012 (QR offline, sync ≤60 s)
- **Reglas visibles en UI:** RN-017/018/019 (cancelación), RN-020 (cambio de parada), RN-023 (abordaje),
  RN-024/025 (ausencia), RN-031 (una reserva por viaje), RN-026..030 (permisos por rol)
- **Modelo:** `backend/db/schema.sql` · **Contrato:** `backend/openapi/openapi.yaml`
- **Derivados que la UI muestra pero la BD no guarda** (MR-R30): `cupo_disponible`, `saldo`, deuda
