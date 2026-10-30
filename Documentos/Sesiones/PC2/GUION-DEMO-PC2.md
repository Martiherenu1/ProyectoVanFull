# Guion de la demo del PC2 y checklist previo

> **Presentación: viernes 30/10/2026, reunión a las 18:30.** Borrador del 29/10, actualizado el 30/10 para acordar entre los tres: el orden y
> los tiempos son una propuesta. Cada afirmación dice si está verificada; lo que no, figura como tal.
> Las contraseñas **no** van acá: están en `backend/db/seed/contrasenas-de-prueba.csv` (y en el archivo
> fuera del repo con el que se re-sembró Neon).

## 1. Con qué datos se llega (seed)

| Qué | Dato |
|---|---|
| Cuentas | `pasajero1@vanfull.test`, `pasajero2@vanfull.test`, `chofer1@vanfull.test`, `admin1@vanfull.test` |
| Viajes del 30/10 (ida) | **1** 07:30 (chofer 3, vehículo 1) · **2** 12:30 (vehículo 1, **sin chofer**) · **3** 18:00 (chofer 3, **sin vehículo**) |
| Qué se puede iniciar | Solo el **viaje 1**: iniciar exige chofer **y** vehículo (ADJ-03). Los viajes 2 y 3 son para probar la asignación de CU-018 |
| Reservas, pagos, posiciones | Ninguno: el seed no los carga |
| Segundo chofer / vehículo | Persona 5 y chofer 5 (sin cuenta de acceso), vehículo 2 (`VF030AA`), para reasignar |

**Neon se re-sembró el 29/10/2026 a las 18:44 (Argentina)** con `--reiniciar` (seed `08442e2`, `main` `8217c9c`) y se
verificó en solo lectura: viaje 1 programado con chofer 3 y vehículo 1, choferes 3 y 5, vehículos 1 y 2, 4 cuentas y
reservas, pagos y posiciones en cero. Lo de arriba es lo que hay. Las cuentas conservan sus contraseñas. **Todo lo que se
pruebe a partir de ahí ensucia esa base:** quien quiera dejarla limpia vuelve a correr el reinicio.

**Cuidado con reservar y cancelar el mismo viaje:** la base guarda una sola fila por pasajero y viaje, aunque esté
cancelada, y reactivarla no está definido (MR-R15). Si un pasajero cancela una reserva, no puede reservar ese mismo
viaje de nuevo (`RESERVA_CANCELADA_PREVIA`, 409). Para la demo, **no probar reserva y cancelación con la cuenta y el viaje
que se van a usar en vivo**; usar otra cuenta u otro viaje.

**Ya quemado por las pruebas del 29/10 (noche):**
- El par **`pasajero2` + viaje 2** (reservó y canceló), y pagos de prueba registrados y confirmados para el cliente 2.
- **Viaje 1 y `pasajero1`:** en el ensayo GPS integrado con el celular, Martín reservó con `pasajero1`, inició el viaje 1 y lo
  **finalizó** (`frontend/technical/gps-probe.md`, #250). Un viaje finalizado no se puede volver a iniciar, así que **con la base
  como está no se puede repetir en vivo iniciar viaje + GPS + ver ubicación**.
- **Ensayo de CU-008 (30/10), hecho por Martiniano con `pasajero2` en el viaje 3.** Consulta de solo lectura a Neon (hora de
  Argentina): reserva 3 creada 13:27:24, **ausencia 1 informada 13:27:38**, reserva 3 cancelada 13:31:21 por Martiniano (la
  cancelación no formaba parte del ensayo). Con eso `pasajero2` queda quemado también en el viaje 3: dos reservas canceladas
  (la 2 del viaje 2 y la 3 del viaje 3). Una sola fila de ausencia, un solo evento `ausencia_informada` y cero pares
  pasajero+viaje repetidos. No se comprobó a mano el HTTP 200 del reintento, y el cupo no sirve de prueba de la ausencia
  porque la cancelación posterior también lo libera.
- Los viajes 2 y 3 tienen un evento `viaje_actualizado` el 30/10 a la 01:02 y la 01:03 (alguien los modificó; sin atribuir
  ni detalle). El reinicio los devuelve al seed.
- El ensayo GPS del 29/10 se da por bueno con sus limitaciones documentadas: no se hace otra pasada y no se toca el viaje 1.

**Para dejarla lista: reiniciar Neon DESPUÉS del último ensayo de Martín y antes de la demo.** Lo corre Martiniano con su
script (vuelve el viaje 1 a programado con chofer 3 y vehículo 1, y vacía reservas, pagos y posiciones; el reinicio deja
vírgenes también el viaje 3 y `pasajero2`). Hay que avisar a los otros dos cuando termine, y no ensayar nada más sobre la
base después.

## 2. Una hora antes: checklist

0. **Reiniciar Neon si no se hizo** (ver sección 1) y recién entonces seguir. Después del reinicio no se prueba nada más con las
   cuentas ni los viajes de la demo.
1. **Despertar Render.** La API y el modelo duermen: el login tardó 35 s y el primer mensaje del asistente 27 a 51 s
   en frío (medido el 28 y 29/10). Abrir `https://vanfull-api.onrender.com/api/health` y hacer un login.
2. **Un solo mensaje de calentamiento al asistente** (por ejemplo «hola»). **No más:** la cuenta gratuita de
   OpenRouter permite **50 pedidos por día** (se renueva a las 21:00 de Argentina) y un mensaje gasta de 2 a 4.
   Si se agota, el asistente avisa que alcanzó su límite (#233) y manda a Buscar y Mis reservas.
3. **Confirmar qué corre.** Commit desplegado en Render (se lee en el panel, Events; con #251 y #253 debería ser `bfad030` o
   posterior) y SHA de `sitio-web`
   (el workflow `Web` se corre **desde `main`**). Después del último merge, relanzar `Web` una vez.
   **Qué redeploya qué** (`render.yaml`): la API se redespliega solo si cambió algo bajo `backend/` y la CI de `main`
   está en verde; la documentación y el frontend **no** la tocan. El sitio (`sitio-web`) solo cambia cuando alguien corre
   `Web`. **Horario acordado (30/10):** último merge que toque `frontend/` o `backend/` a las **17:15**; de 17:15 a 17:30
   se relanza `Web` desde `main` y se ensaya CU-008 y el circuito del pasajero; a las **17:30** el reinicio de Neon, y
   después, su verificación; a las **17:40** se despierta Render, se envía un solo mensaje al asistente y se lee el commit
   desplegado; silencio desde las 18:00. Web publicada al mediodía: `sitio-web` `f104f03`, compilado de `main` `67b5fa4`
   (incluye CU-008, #257).
4. **Recargar con Ctrl+Shift+R** en cada navegador de la demo: Flutter Web guarda el sitio en caché y puede mostrar
   la versión anterior.
5. **El viaje 1 sin tocar.** Nadie lo modifica ni lo reasigna hasta el ensayo de GPS.

## 3. Circuito propuesto (en este orden)

El orden importa por una regla: **el pasajero reserva ANTES de que el chofer inicie el viaje** (no se puede
reservar uno `en_curso`), y ve la ubicación solo con una reserva propia consolidada (RN-030).

| # | Quién | Qué se muestra | Estado |
|---|---|---|---|
| 1 | Pasajero | Login → **Buscar** (30/10, ida: 3 viajes) → **Confirmar reserva** del viaje 1 (pide «¿Dónde subís?») → **Mis reservas** | **Verificado en Render el 29/10** por API (viaje 3, `pasajero2`): crear la reserva (201, queda `consolidada`), el cupo baja en 1, aparece en Mis reservas, y cancelarla devuelve el lugar. **Visto en la web publicada** por Martiniano (29/10, noche; `pasajero2`, viaje 2): login, Buscar, Confirmar reserva, Mis reservas, Ver ubicación (sin sesión cerrada) y cancelación, sin diferencias con lo esperado |
| 2 | Pasajero | **Asistente**: una consulta de disponibilidad y la derivación a una persona | Verificado el 29/10 con el modelo real. Reservar y cancelar por el chat **no se probó** con el modelo real |
| 2b | Pasajero | **Informar ausencia** (CU-008) desde **Mis reservas**, con la reserva abierta y consolidada | Implementado (#257). **Ensayado el 30/10** por Martiniano en la web publicada, y la base confirma una ausencia registrada (ver sección 1). El botón queda activo después de avisar: la pantalla solo muestra el mensaje «Tu aviso de ausencia está registrado»; repetir el aviso no duplica (una fila y un evento). No cancela la reserva ni tiene efecto económico. Para mostrarlo en vivo hace falta una reserva nueva con una cuenta que no haya tocado ese viaje |
| 3 | Admin | **Viajes del día** y asignación de chofer y vehículo (CU-018) | **Visto en la web publicada** (Viajes del día del 30/10, con el selector de fecha). Asignar o reasignar chofer y vehículo **no se probó** en Render |
| 4 | Pasajero → Admin | Registrar el pago (pasajero) → **Pagos a confirmar** (admin, CU-016) → **Deuda por cliente** (CU-015) y **Reservas** (CU-027) | **Probado en la web publicada** por Martiniano (registrar el pago como pasajero, Pagos pendientes, confirmar, Consultar reservas y Consultar deuda), sin diferencias con lo esperado. **Ojo con la deuda:** reservar NO genera deuda (la tarifa, RF-028/#9, está fuera por decisiones pendientes): el saldo quedó en `0.0 al_dia` antes, durante y después de reservar y cancelar. Solo sube con un movimiento `DEUDOR`, que ninguna pantalla crea. Para mostrar una deuda que baja hay que cargar ese movimiento a mano; si no, presentar el paso como «registro y confirmación del pago» |
| 5 | Chofer | **Lista del viaje** → iniciar el viaje 1 → publicar posición (GPS) | **Visto en solo lectura** (`chofer1`: lista del 30/10 y detalle del viaje 1, sin iniciarlo). **Ensayo con el celular informado por Martín (29/10, #250):** iniciar el viaje y publicar posición contra Render. Con ubicación precisa la Web avanzó cada ~10 s, siguió avanzando con el celular bloqueado en una prueba breve y, al finalizar, retiró el mapa. Con ubicación solo aproximada la posición no avanzaba (limitación observada en ese dispositivo). Es evidencia manual, no una medición de RNF-008. **Requiere que el chofer active la ubicación precisa antes de la demo** |
| 6 | Pasajero | **Mis reservas → Ver ubicación** del viaje 1 | Implementado (#222). Con el viaje sin iniciar se vio en pantalla «Ubicación no disponible para esta sesión o viaje» (RN-030). Martín lo vio con una posición real (ensayo del 29/10); con viaje en curso y sin posición responde «Todavía no hay una posición disponible». Para repetirlo en vivo hace falta el reinicio de Neon |

## 4. Qué se declara parcial (no se muestra como completo)

CU-003 sin lista de espera · CU-007 en el contrato pero **sin implementar**, y CU-005 con backend (#243, con la interpretación de «disponibilidad compatible» pendiente de validar, #242) pero **sin pantalla** · CU-014 sin comprobantes ni adjuntos ·
CU-015 solo lectura (RN-004/005/006 pendientes) · CU-018 sin reintegros (RN-019) · CU-027 sin filtros ·
CU-030 sin avisos de demora · CU-008 sin estado visible tras avisar (el botón sigue activo) y sin recuperar el lugar ·
**Mercado Pago:** CU-036 y Checkout Pro (#251, #253) están implementados y probados con un simulador local, y entraron a
`main` **apagados por flag**: no se muestran ni se usan en la demo. Facu informó una compra con cuentas ficticias (no
verificada por el resto del equipo). El webhook auténtico y la confirmación integrada están **pendientes** (decisiones
D1 a D6, entre ellas D5 sobre `live_mode`) y no se tocan antes de la demo; no se presenta como «circuito completo». El pago
que se muestra en vivo es el manual (el pasajero lo registra y administración lo confirma) · ETA vacío en CU-009 (pendiente explícito: faltan definiciones de destino, coordenadas de paradas y proveedor) ·
RNF-008 parcial (dos brechas de borde reproducidas en 29/30/31 s, a definir por #39 después de la demo) ·
los 17 CU sin contrato (CU-013, 017, 019 a 026, 028, 031 a 035, 037). Detalle en `backend/openapi/README.md`.

## 5. Si algo falla en vivo

| Falla | Qué hacer |
|---|---|
| El asistente responde «alcanzó su límite» o deriva | Es el cupo diario o el modelo gratuito: seguir con Buscar y Mis reservas, que no dependen de él |
| Cancelar una reserva no aplica penalidad | Es lo esperado: RN-017 fuera de término «no está definido» (#75). El mensaje de la API lo dice |
| Primer login o primera pantalla lentos | Es el arranque en frío de Render: esperar 30 a 50 s, no recargar varias veces |
| La web muestra una pantalla vieja | Ctrl+Shift+R; si sigue, Clear site data |
| «Ver ubicación» dice que no hay posición | El chofer todavía no publicó: pedir que envíe una posición y actualizar |
| No se puede iniciar el viaje | Falta chofer o vehículo (ADJ-03): usar el viaje 1 |
