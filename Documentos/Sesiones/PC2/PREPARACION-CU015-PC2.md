# CU-015 / #212 / #218 — consulta administrativa publicada en #218

**Cobertura parcial:** consulta conectada de punta a punta en código y probada con HTTP
simulado/PostgreSQL local. Continuación publicada en #218, sin merge hacia main ni prueba
manual del despliegue. La gestión RN-004/005/006 permanece pendiente.

## Contrato acordado

**DEFINIDO POR EL EQUIPO:** contrato comunicado por el usuario como acordado con Martiniano:
GET `/api/clientes/{id_cliente}/deuda`, solo administrador y dueno. 200 reutiliza Deuda
(saldo, estado); cliente sin cuenta devuelve 0.00/al_dia; inexistente responde
404 CLIENTE_NO_ENCONTRADO, otros roles 403 SIN_PERMISO. No autoriza editar saldo.
OpenAPI conserva x-cobertura parcial y JSON regenerado/validado.

## Implementación

- `services/deuda.py` comparte cálculo por id_cliente. MR-R30 conserva suma de movimientos,
  sin filtros económicos nuevos ni persistencia del saldo; CU-006 conserva identificación propia.
- Flutter reutiliza Deuda/ResumenDeudaAdmin, HTTP y sesión existentes. «Consultar deuda» abre
  identificación por ID y consulta visual, con carga, error/reintento y sin datos. Elegir otro
  cliente elimina la respuesta anterior; cero informado se distingue de ausencia de información.
- Respuestas tardías no afectan otra sesión ni una pantalla desmontada. 401/403 siguen la
  protección común administrativa; 404 se muestra en la consulta. Sin selector de clientes
  basado en endpoints adicionales ni permisos nuevos en otros roles.
- Main actualizado 4aea002, con #210/#214/#222; sus rutas y botones se conservan. Controles
  administrativos probados a 320 y 1440 px. Cambios de otras ramas no mergeadas preservados.

## Pendientes

**RN-004/005/006 NO IMPLEMENTADAS:** suspensión/advertencia y eventual pérdida de cupo,
habilitación excepcional por cinco días, evaluación de límite mensual. Deben coordinarse
contrato/comportamiento y datos necesarios con el equipo antes de implementarlas.
La consulta no deriva suspensión, habilitación ni límites desde el saldo; no ofrece acciones.
CU-015 no se declara completo como gestión de consecuencias.

## Validación

Estado de publicación verificado el 29/10/2026: código revisado en `5f8a6d6`,
[CI #300](https://github.com/Martiherenu1/ProyectoVanFull/actions/runs/40902318550)
aprobada en Backend y Flutter. Esta evidencia remota se distingue de los resultados locales
que siguen; no se repitieron pruebas locales para esta corrección documental.
Suite Flutter local de publicación informada: 733/733 aprobadas.

25 pruebas backend aprobadas (CU-006 existente, CU-015/permisos/cálculo/sin cuenta/404/solo lectura
 y rutas contractuales) en bases temporales del PostgreSQL de testing existente, sin producción.
57 pruebas Flutter focalizadas aprobadas (adaptador, pantalla, sesión, navegación y responsive).
Flutter analyze sin problemas; Ruff check/format correctos; YAML/JSON OpenAPI válidos e iguales.

Fuentes vigentes: [CU-015 v1.3](https://drive.google.com/file/d/1Kc4m4e2LH5xRc1J9HY-2hTQaiLNeRA7y/view),
[RF-010](https://docs.google.com/document/d/1sA_3o6trf_B2B7H5JyI1yQQhFIzO-8rh/edit),
[RN-004/005/006](https://docs.google.com/document/d/1aG6RTv1lTyY36PkyYyYl46NW4PKYvYMb/edit).
