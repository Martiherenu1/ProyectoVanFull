# Guion de la demo del PC2 y checklist previo

> **Presentación: viernes 30/10/2026, ~18:00.** Borrador del 29/10 para acordar entre los tres: el orden y
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

## 2. Una hora antes: checklist

1. **Despertar Render.** La API y el modelo duermen: el login tardó 35 s y el primer mensaje del asistente 27 a 51 s
   en frío (medido el 28 y 29/10). Abrir `https://vanfull-api.onrender.com/api/health` y hacer un login.
2. **Un solo mensaje de calentamiento al asistente** (por ejemplo «hola»). **No más:** la cuenta gratuita de
   OpenRouter permite **50 pedidos por día** (se renueva a las 21:00 de Argentina) y un mensaje gasta de 2 a 4.
   Si se agota, el asistente avisa que alcanzó su límite (#233) y manda a Buscar y Mis reservas.
3. **Confirmar qué corre.** Commit desplegado en Render (se lee en el panel, Events) y SHA de `sitio-web`
   (el workflow `Web` se corre **desde `main`**). Después del último merge, relanzar `Web` una vez.
4. **Recargar con Ctrl+Shift+R** en cada navegador de la demo: Flutter Web guarda el sitio en caché y puede mostrar
   la versión anterior.
5. **El viaje 1 sin tocar.** Nadie lo modifica ni lo reasigna hasta el ensayo de GPS.

## 3. Circuito propuesto (en este orden)

El orden importa por una regla: **el pasajero reserva ANTES de que el chofer inicie el viaje** (no se puede
reservar uno `en_curso`), y ve la ubicación solo con una reserva propia consolidada (RN-030).

| # | Quién | Qué se muestra | Estado |
|---|---|---|---|
| 1 | Pasajero | Login → **Buscar** (30/10, ida: 3 viajes) → **Confirmar reserva** del viaje 1 (pide «¿Dónde subís?») → **Mis reservas** | **Verificado en Render el 29/10** por API (viaje 3, `pasajero2`): crear la reserva (201, queda `consolidada`), el cupo baja en 1, aparece en Mis reservas, y cancelarla devuelve el lugar. Falta verlo en la pantalla |
| 2 | Pasajero | **Asistente**: una consulta de disponibilidad y la derivación a una persona | Verificado el 29/10 con el modelo real. Reservar y cancelar por el chat **no se probó** con el modelo real |
| 3 | Admin | **Viajes del día** y asignación de chofer y vehículo (CU-018) | Integrado en `main`; no probado en Render con datos reales |
| 4 | Pasajero → Admin | Registrar el pago (pasajero) → **Pagos a confirmar** (admin, CU-016) → **Deuda por cliente** (CU-015) y **Reservas** (CU-027) | Integrado en `main`; el circuito completo no se probó en Render. **Ojo con la deuda:** reservar NO genera deuda (la tarifa, RF-028/#9, está fuera por decisiones pendientes): el saldo quedó en `0.0 al_dia` antes, durante y después de reservar y cancelar. Solo sube con un movimiento `DEUDOR`, que ninguna pantalla crea. Para mostrar una deuda que baja hay que cargar ese movimiento a mano; si no, presentar el paso como «registro y confirmación del pago» |
| 5 | Chofer | **Lista del viaje** → iniciar el viaje 1 → publicar posición (GPS) | Ensayo parcial; el circuito real con el celular sigue pendiente (ensayo de Martín) |
| 6 | Pasajero | **Mis reservas → Ver ubicación** del viaje 1 | Implementado (#222); falta verlo con una posición real. Sin posición responde «Todavía no hay una posición disponible» |

## 4. Qué se declara parcial (no se muestra como completo)

CU-003 sin lista de espera · CU-007 en el contrato pero **sin implementar**, y CU-005 con backend (#243, con la interpretación de «disponibilidad compatible» pendiente de validar, #242) pero **sin pantalla** · CU-014 sin comprobantes ni adjuntos ·
CU-015 solo lectura (RN-004/005/006 pendientes) · CU-018 sin reintegros (RN-019) · CU-027 sin filtros ·
CU-030 sin avisos de demora · CU-036 solo preparación interna, **webhook inactivo** · ETA vacío en CU-009 ·
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
