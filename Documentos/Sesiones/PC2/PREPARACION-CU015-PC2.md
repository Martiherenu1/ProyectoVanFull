# CU-015 / #212 — consulta visual parcial

**Preparación independiente; no funcional de punta a punta.** Sin menú, HTTP, backend,
permisos nuevos o cambios del contrato compartido. No acredita cumplimiento de CU-015 completo.

## Parte preparada

- `ConsultarDeudaAdminScreen`: identifica cliente por ID, consulta explícita, carga, errores
  y reintento; distingue ausencia de información de saldo cero informado.
- Reutiliza `ResumenDeudaAdmin`, `Deuda`, tema y formato de importe existentes. No recalcula
  saldo ni traduce deuda a suspensión/habilitación. No hay edición de importes.
- `ConsultaDeudaAdmin.consultar(idCliente)` es un puerto local, **no un endpoint aprobado**.
  El adaptador simulado existe solo en tests y no se ofrece en navegación operativa.
- Editar el cliente limpia la consulta anterior; cambiar alcance/adaptador elimina identificación
  y resultados. Respuestas tardías o tras desmontar la pantalla no se aplican.
- El integrador futuro debe renovar la identidad opaca `alcance` al cambiar sesión y utilizar
  la consulta administrativa autorizada que acuerde el equipo; no reutilizar CU-006 para datos ajenos.

## Acciones separadas y bloqueadas

CU-015 v1.3/RF-010 exige gestión de consecuencias además de consulta. RN-004 contempla
advertencia/suspensión y eventual pérdida de cupo; RN-005 habilitación excepcional por cinco
días; RN-006 límite absoluto de un mes de abono y dentro del mes corriente, sin excepciones.
El saldo es derivado (MR-R30); no se habilita una operación de edición manual.

Falta acordar con Martiniano/Martín contrato de consulta por cliente, campos de situación y
consecuencias, acciones permitidas, autorización, almacenamiento/expiración de habilitación y
referencia de abono/mes para RN-006. El modelo `Deuda` actual solo expone saldo y estado de deuda;
no informa límites ni suspensión. No se crean botones para esas acciones ni se simula su ejecución.

No se inventa ruta HTTP, método de actualización, cambio de estado o regla económica. El backend
vigente GET /pasajeros/me/deuda corresponde a CU-006 y conserva su autorización de propiedad.

## Fuentes y verificación

- [CU-015 v1.3 aprobado](https://drive.google.com/file/d/1Kc4m4e2LH5xRc1J9HY-2hTQaiLNeRA7y/view).
- [RF-010](https://docs.google.com/document/d/1sA_3o6trf_B2B7H5JyI1yQQhFIzO-8rh/edit).
- [RN-004/005/006](https://docs.google.com/document/d/1aG6RTv1lTyY36PkyYyYl46NW4PKYvYMb/edit).

12 pruebas focalizadas de pantalla/componente aprobadas con adaptador simulado; ninguna
consulta a cuentas reales. Base main a8696de en rama propia #212, sin #210/#214/#216/#217.
Trabajos de otras ramas preservados por separado; Draft condicionado a verificaciones completas.
