# CU-027 / #211 — propuesta mínima para Martiniano

**PROPUESTA DE IA · PENDIENTE DE VALIDACIÓN. No modifica OpenAPI ni autoriza una operación.**

Fuente aprobada: CU-027 v1.3 / RF-043, consulta administrativa sin escrituras, selección y
detalle con información/estado; sin resultados informa vacío. No define filtros concretos.
https://drive.google.com/file/d/1Kc4m4e2LH5xRc1J9HY-2hTQaiLNeRA7y/view

## Contrato mínimo propuesto, no implementado

- GET `/reservas`, sin parámetros de filtrado nuevos. La ruta hoy tiene POST del pasajero;
  agregar GET debe coordinarse, sin modificar POST ni el significado de CU-010.
- Autenticación requerida y autorización administrativa ACT-05/ACT-06, a validar con el dueño
  del servicio. No cambiar `/pasajeros/me/reservas` ni ampliar acceso al detalle existente.
- 200: array del schema `Reserva` vigente, `[]` cuando no hay resultados.
- 401/403: respuestas uniformes existentes; su definición final debe incorporarse al contrato.
- No imponer orden, límite de búsqueda o estados omitidos por inferencia. El frontend conserva
  el orden recibido y presenta provisional/consolidada/cancelada sin transformarlos.
- El detalle local usa la reserva seleccionada del listado completo. No requiere otra ruta
  para esta preparación. Si se exige una relectura actualizada por ID, acordarla expresamente.
- No cambios de modelo, escrituras, cancelación, cupos, abonos o consecuencias económicas.

## Decisiones concretas que debe validar Martiniano

Ruta, alcance de lectura y roles; schema/campos visibles; estados incluidos y orden de
presentación; volumen/paginación si corresponde; necesidad de consulta remota del detalle.
Los criterios de búsqueda definitivos siguen pendientes. La preparación actual permite
ubicar visualmente el ID en el listado y seleccionarlo, **sin inventar filtros HTTP**.

El DTO Flutter `Reserva` actual no conserva `id_pasajero`, aunque figura en el schema backend.
Se reutiliza tal cual; no se inventan nombre/contacto del pasajero ni se cambia su modelo.
Definir identificación adicional si es necesaria antes de extender el DTO administrativo.

## Frontend listo para conectar tras aprobación

`ConsultaReservasAdmin.listar()` es un puerto local, sin HTTP ni decisiones de autorización.
`ConsultarReservasAdminScreen` recibe ese puerto y una identidad opaca `alcance` que el futuro
integrador debe renovar al cambiar sesión. Invalida cargas anteriores, limpia selección y
detalle al cambiar alcance/adaptador, y descarta respuestas tras desmontar la pantalla.
El doble `ConsultaSimulada` existe solo en tests, nunca en navegación operativa.

El integrador deberá implementar el adaptador HTTP para la ruta acordada y conectarlo a la
sesión administrativa existente (401 contextual/403 sin logout y generación de sesión).
No llamar la ruta privada del pasajero para obtener reservas ajenas. No se modificó main.dart
ni se agregaron menús o una pantalla con datos falsos al producto. El componente no demuestra
permisos reales ni acredita el circuito CU-027 completo.

Validación local: listado, selección/detalle, tres estados, carga/error/vacío/reintento,
horario ausente, reconstrucción, cambio de alcance y respuesta/error después de desmontar.
