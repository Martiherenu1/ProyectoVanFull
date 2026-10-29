# CU-027 / #211 — contrato real y conexión Flutter

La propuesta inicial queda superada por el contrato mergeado en **PR #224**.
**DEFINIDO POR EL EQUIPO:** GET `/api/reservas`, administrador/dueno, autenticación bearer.
200 devuelve array Reserva con id_pasajero; incluye provisionales, consolidadas y canceladas,
por id_reserva ascendente. Sin resultados devuelve []; errores 401/403 uniformes.
No filtros, paginación, nombres, contactos ni importes adicionales.

## Contraste con CU-027 v1.3 / RF-043

El análisis previo de la especificación aprobada exige localizar/seleccionar/consultar reservas,
mostrar información y estado, informar ausencia de resultados y no modificarlas. No enumera
filtros concretos: el contrato #224 deja criterios de búsqueda adicionales pendientes.
La interfaz permite localizar visualmente la reserva por ID y seleccionar su detalle.
No amplía GET /reservas/{id}: esa ruta sigue siendo del pasajero y exige propiedad.
ACT-05/ACT-06 están en el CU; la interfaz del dueño continúa fuera del reparto PC2.

## Implementación integrada en main (#217)

- ReservasAdminApi consume solo GET /reservas con el HTTP/sesión existente, sin parámetros.
- ReservaAdmin compone Reserva existente y conserva idPasajero obligatorio. No cambia modelo
  ni contratos del pasajero; listado y detalle muestran ese identificador, sin inferir identidad personal.
- Pantalla conserva orden recibido, estados, horario nulo, carga/vacío/error/reintento/actualizar.
  El detalle usa el resultado seleccionado, sin nuevas peticiones ni acciones de escritura.
- Navegación administrativa real, protección común 401/403, generación de sesión y descarte de
  respuestas antiguas al cambiar cuenta/alcance, cerrar o renovar adaptador.
- Main bceb929 integra #217/#224 y CU-015/#218 junto a #210/#214/#222. Las referencias anteriores
  a a01df1e y #218 Draft corresponden a preparación histórica, no al estado vigente.

54 pruebas Flutter focalizadas aprobadas, incluidos adaptador HTTP, id_pasajero, los tres
estados, detalle local, respuesta tardía, permisos, reintento, navegación y controles 320/1440 px.
Analyze y diff check correctos. Backend/OpenAPI/modelo del pasajero intactos; Ruff no aplica.
PR #217 mergeado el 29/10/2026. Sin prueba real del despliegue; merge no acredita cobertura integral.
CI #302 sobre `2829032` aprobada en Backend y Flutter:
https://github.com/Martiherenu1/ProyectoVanFull/actions/runs/40904507118.
Suite Flutter local de publicación informada: 724/724, separada de la CI remota.
Resolución final 6bdf303: 42 focalizadas y analyze aprobados; CI #304 verde según PR #217. Sin nuevas suites en el cierre #225.
Criterios adicionales de búsqueda siguen pendientes; CU-027 mantiene cobertura parcial.

Fuente ya contrastada: [CU-027 v1.3 aprobado](https://drive.google.com/file/d/1Kc4m4e2LH5xRc1J9HY-2hTQaiLNeRA7y/view).
Contrato real: backend/openapi/openapi.yaml, GET /reservas (PR #224).
