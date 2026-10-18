# VanFull — Aclaración funcional de campos editables y completitud del perfil

**Versión:** 0.2 — VALIDADA POR ANÁLISIS (MARTÍN)  
**Fecha del relevamiento:** 18/10/2026  
**Estado:** **APROBADO FUNCIONALMENTE POR MARTÍN EL 18/10/2026**. Las respuestas obtenidas de VanFull se registran como confirmaciones de negocio; **no representan** por sí solas una modificación aprobada de RF, RN, CU, DER/MR, SQL, OpenAPI ni una ampliación aprobada del PC2.  
**Origen:** [Issue #25 — CU-001: campos editables del perfil](https://github.com/Martiherenu1/ProyectoVanFull/issues/25).  
**Responsable del relevamiento:** Martín (Integrante 2, análisis funcional y trazabilidad).  
**Revisión técnica posterior:** Martiniano (módulo pasajero, perfil, autenticación y API); Facundo (intervenciones administrativas y relación con pagos); Martín (coordinación con ascenso/recorridos e integración de criterios).  
**Ubicación prevista:** `Documentos/Sesiones/PC2/ACLARACION-FUNCIONAL-CU001-ISSUE25-v0.2-VALIDADA-ANALISIS.md`.

> **Lectura obligatoria:** este documento separa **CONFIRMADO POR VANFULL**, restricciones ya vigentes, **PENDIENTE DE VALIDACIÓN** y **PROPUESTA DE IA**. No habilita, por sí mismo, cambios de implementación o de alcance.

## 1. Problemática, propósito y límites

El CU-001 permite consultar y modificar el perfil propio, pero la especificación vigente no enumeraba exactamente los campos que podía editar el pasajero. La implementación utiliza de manera provisional `email`, `telefono` y `direccion`; el DNI queda fuera del autoservicio según RN-026. El Issue #25 pide validar ese alcance con Martín.

**Propósito:** fijar las condiciones funcionales informadas por VanFull sobre campos editables, verificación de contactos, fotografía, completitud del perfil, correcciones administrativas y relación del cambio de domicilio con el punto habitual de ascenso.

**Límites:** no se definen algoritmos, proveedores, políticas de identidad digital, formatos específicos de imágenes, estructuras nuevas de datos, endpoints, ni fechas de implementación. El circuito de cambio de punto de ascenso corresponde también a las aclaraciones del [Issue #8](https://github.com/Martiherenu1/ProyectoVanFull/issues/8); aquí se documenta su interdependencia, **no** se da por aprobado un alcance adicional para PC2.

## 2. Fuentes y autoridad

| Prioridad | Fuente | Aspecto contrastado |
|---|---|---|
| 1 | Especificación CU-001 v1.3, según cita verificada en el Issue #25 | El listado exacto de campos editables estaba pendiente; el flujo alternativo A1 dirige la modificación de DNI a un administrador autorizado. **No se releyó aquí el documento íntegro de Drive.** |
| 2 | Respuestas directas de VanFull dadas por Martín durante el relevamiento del 18/10/2026 | Definiciones funcionales AC25-01 a AC25-22. |
| 3 | Línea base aprobada: RN-026; referencias del Issue #25 a RF-003 y RN-029 | Protección de datos personales y limitación de edición del DNI. Se deberá cotejar el texto íntegro vigente antes de editar la línea base. |
| 4 | `backend/db/schema.sql`, `backend/openapi/openapi.yaml`, `backend/app/services/perfil.py`, `backend/app/schemas/perfil.py`, consultados en `main` el 18/10/2026 | Estructura y comportamiento implementados **actualmente**; no son reglas de negocio por sí mismos. |
| 5 | `Documentos/Sesiones/PC2/REPARTO-PC2.md` | Reparto de responsabilidades; marca abonos, recorridos y paradas fuera del desarrollo priorizado para PC2. |

**Criterio de resolución:** ante diferencias entre confirmaciones del negocio y software/documentación, dejar constancia de la diferencia y gestionar la revisión; no sobrescribir silenciosamente los artefactos aprobados.

## 3. Matriz de aclaraciones funcionales

Todas las filas AC25 expresan **CONFIRMADO POR VANFULL — 18/10/2026**, salvo los límites o pendientes que se indican expresamente.

| ID | Aclaración funcional | Estado / precisión |
|---|---|---|
| **AC25-01** | El pasajero puede editar por autoservicio **correo de contacto, teléfono, dirección y fotografía**. | Confirmado. |
| **AC25-02** | No puede modificar directamente **nombre, apellido ni DNI**; la corrección la realiza un administrador autorizado. | Confirmado. Para DNI existe además RN-026 vigente. |
| **AC25-03** | Para corregir nombre, apellido o DNI **no es obligatoria la presentación de documentación adicional**: el administrador puede verificar los datos que ya tiene disponibles antes de corregirlos. | Confirmado. **No** significa que pueda modificar sin comprobación. |
| **AC25-04** | Perfil completo requiere **nombre, apellido, DNI, dirección, teléfono verificado, correo verificado y fotografía**. | Confirmado. |
| **AC25-05** | El pasajero con perfil incompleto puede **iniciar sesión, acceder al perfil y consultar servicios, horarios y disponibilidad**. | Confirmado. |
| **AC25-06** | El perfil incompleto **no habilita reservas, pagos ni otras operaciones** hasta completar los requisitos. | Confirmado. Alcance exacto de «otras operaciones»: pendiente para la implementación. |
| **AC25-07** | En el circuito normal de VanFull, el pasajero no habrá generado reservas ni pagos si nunca completó su perfil. | Confirmado. No resuelve migraciones o registros históricos anómalos. |
| **AC25-08** | El cambio de **correo** necesita verificación mediante código o enlace enviado al correo nuevo; el dato anterior continúa vigente hasta finalizarla. | Confirmado. |
| **AC25-09** | Verificado el nuevo correo, cambia el **correo de contacto**, no el identificador utilizado para iniciar sesión. | Confirmado. |
| **AC25-10** | El cambio de **teléfono** requiere código enviado al número nuevo; el pasajero **elige WhatsApp o SMS** como canal. | Confirmado. |
| **AC25-11** | Mientras se verifica un nuevo correo o teléfono, el dato anterior permanece vigente y el pasajero con perfil previamente completo **continúa operando normalmente**. | Confirmado. |
| **AC25-12** | La fotografía de perfil es **obligatoria**. Puede **reemplazarse**, pero no eliminarse dejando el perfil sin fotografía. | Confirmado. |
| **AC25-13** | Una nueva fotografía se aplica **inmediatamente** si supera la validación automática, sin aprobación administrativa habitual; si se rechaza, se conserva la anterior válida. | Confirmado. |
| **AC25-14** | La fotografía debe permitir **reconocer visualmente** al pasajero y contener **un único rostro claramente visible**. Se rechazan imágenes genéricas y fotografías con varias caras. | Confirmado. |
| **AC25-15** | El sistema verifica **automáticamente la presencia de un rostro visible y único** antes de aceptar la fotografía. | Confirmado funcionalmente; tecnología y alcance pendientes. **No equivale** a reconocimiento biométrico de identidad. |
| **AC25-16** | Ante un rechazo, el pasajero recibe el motivo y puede reintentar; si persiste el problema, puede pedir **revisión manual** a VanFull. | Confirmado. |
| **AC25-17** | Un administrador autorizado puede **aprobar la misma fotografía** inicialmente rechazada si constata que cumple los criterios; si no la aprueba, el pasajero debe presentar otra. | Confirmado. |
| **AC25-18** | Al actualizar el **domicilio**, el sistema propone al abonado puntos de ascenso cercanos para que seleccione uno. | Confirmado; dependencia del Issue #8. |
| **AC25-19** | Mientras no haya un nuevo punto confirmado, **permanece vigente el punto habitual anterior**, siempre que pueda seguir utilizándolo. | Confirmado. |
| **AC25-20** | Un nuevo punto habitual confirmado debe aplicarse desde el **próximo viaje de IDA no iniciado** y a reservas futuras existentes, respetando paradas comprometidas. | Confirmado, sujeto a viabilidad integral. |
| **AC25-21** | Si el nuevo punto no es viable para **todos los viajes futuros reservados afectados**, **no se aplica parcialmente**: se rechaza el cambio, se mantiene el punto anterior y no se alteran reservas; el pasajero debe formular una solicitud nueva si desea reintentar. | Confirmado. |
| **AC25-22** | Si la fotografía falta, el pasajero puede consultar la oferta informativa, pero no reservar ni operar; debe cargar fotografía para completar el perfil. | Confirmado; complementa AC25-04 a AC25-07. |

**Precisión importante:** AC25-03 no crea un requisito de adjuntar documentación obligatoria en la aplicación. Tampoco prohíbe que un administrador consulte documentación existente si la posee: el criterio confirmado es **no exigir siempre documentación adicional**.

## 4. Diferencias frente a la línea base y el software actual

| Tema | Vigente o implementado | Confirmación de VanFull | Tratamiento necesario |
|---|---|---|---|
| Campos editables | `CAMPOS_EDITABLES = ("email", "telefono", "direccion")` en `services/perfil.py`; idéntica lista en `PerfilPasajeroUpdate` de OpenAPI. | También **fotografía**. | Revisión de CU-001, contrato, schema de entrada y servicio; **no cambiado aquí**. |
| Nombre / apellido / DNI | No editables por la API actual. RN-026 y CU-001 A1 fundamentan intervención administrativa para DNI; no estaba explicitado de igual modo el procedimiento de nombre/apellido. | Corrección por administrador; sin documento adicional obligatorio, pero con comprobación de datos. | Formalizar la política y analizar operación administrativa. |
| Dirección, teléfono, email y foto | `PERSONA.direccion`, `.telefono`, `.email`, `PASAJERO.fotografia` admiten `NULL` en `schema.sql`; `PerfilPasajero` los declara opcionales. | Necesarios para considerar el perfil completo (teléfono/correo verificados). | Diferencia explícita: decidir si se implementa con validación de completitud, restricciones de BD, migraciones u otro diseño. |
| Email | Actualmente `PATCH /pasajeros/me` permite modificación directa de email; no consta verificación en ese circuito. | Validación por código o enlace al nuevo email. | Diseñar estados transitorios, emisión y confirmación; no inventar endpoints. |
| Identificador de acceso | `CUENTA_ACCESO.identificador_acceso` separado de `PERSONA.email`. | No cambia al modificar correo de contacto. | Verificar consistencia con autenticación CU-012. |
| Teléfono | Cambio directo en backend. | Verificación con elección WhatsApp o SMS. | Integraciones externas, errores, costos, privacidad y alcance pendientes. |
| Fotografía | Figura como referencia URL en `PASAJERO.fotografia`, nullable; la API actual no admite edición por autoservicio. | Obligatoria, validación automática de rostro único, revisión manual excepcional. | Diseño de carga, almacenamiento, validación, revisión, seguridad y alcance PC2. |
| Operaciones con perfil incompleto | El código observado de `services/perfil.py` no tiene control de completitud global; deben auditarse los servicios de reservas/pagos antes de afirmar que lo aplican. | Las consultas informativas siguen disponibles; reservas, pagos y operaciones requieren perfil completo. | Decidir controles transversales sin romper accesos de solo lectura. |
| Domicilio y ascenso | Reserva registra `id_recorrido` y `orden_parada` de ascenso; no representa explícitamente la gestión del punto habitual ni todas sus consecuencias. | Propuesta de puntos cercanos para abonados; cambios íntegramente viables o rechazo. | Relacionar con Issue #8, modelo y alcance; **no cambiar DER/MR en esta PR**. |

**No equiparar:** campo nullable en base de datos ≠ permiso funcional para operar con perfil incompleto; no se puede decidir una migración `NOT NULL` solamente a partir de la confirmación de completitud.

## 5. Circuitos funcionales confirmados

### F25-01 — Edición de datos de contacto

1. El pasajero autenticado ingresa al perfil propio (CU-001).
2. Puede modificar dirección directamente; el tratamiento del punto habitual de ascenso se gestiona según F25-04 si es abonado.
3. Si solicita cambiar email, se verifica el nuevo correo por código o enlace antes de sustituir el registrado.
4. Si solicita cambiar teléfono, elige WhatsApp o SMS, recibe un código en el nuevo número y lo verifica antes de sustituir el registrado.
5. Durante verificaciones pendientes, siguen vigentes los datos anteriores y las operaciones habilitadas si el perfil ya estaba completo.
6. Cambiar email de contacto **no cambia** `CUENTA_ACCESO.identificador_acceso`.

**PENDIENTE:** expiración, reenvío y límite de intentos de códigos/enlaces, conflicto de email duplicado, formato de email/teléfono, errores del proveedor y canales realmente disponibles.

### F25-02 — Alta o reemplazo de fotografía

1. Se exige fotografía para completar el perfil y operar.
2. La imagen debe ser fotografía identificable con un único rostro claramente visible.
3. El sistema intenta validarla automáticamente.
4. Si es válida, se incorpora de inmediato; si reemplaza otra, la imagen previa deja de ser la vigente.
5. Si es rechazada, se comunica motivo y el pasajero puede reintentar; si persiste el rechazo, puede pedir revisión manual.
6. El administrador puede aprobar esa misma fotografía si comprueba el cumplimiento, o rechazarla.
7. Si existía imagen válida, se conserva mientras no se acepte otra.

**PENDIENTE:** formatos, calidad, almacenamiento, seguridad, política de retención y eliminación física de imágenes, interfaz y circuitos administrativos; detección de rostro no debe interpretarse como verificación biométrica de identidad.

### F25-03 — Perfil incompleto y operaciones

1. El pasajero puede autenticarse y abrir su perfil aunque le falten datos.
2. Puede consultar servicios, horarios y cupos, pero no realizar reservas, pagos ni otras operaciones sujetas a completitud.
3. Para quedar habilitado, debe contar con los siete datos definidos por AC25-04, incluidas verificaciones de teléfono y email.
4. Si un pasajero habilitado propone cambiar datos de contacto, su perfil sigue completo mientras los anteriores estén vigentes y verificados.

**PENDIENTE:** alcance exacto de las «otras operaciones» y tratamiento excepcional de cuentas importadas o inconsistentes.

### F25-04 — Domicilio y punto habitual de ascenso del abonado

1. Al modificar dirección, se proponen al abonado puntos próximos al nuevo domicilio.
2. El punto anterior sigue vigente, si puede usarlo, hasta confirmar otro.
3. El punto nuevo debe ser viable para todos los viajes futuros ya reservados que serían afectados y respetar las paradas comprometidas.
4. Si es viable integralmente, se aplica a las próximas IDAS no iniciadas, incluidas reservas futuras existentes.
5. Si algún viaje futuro reservado no permite el nuevo punto, se **rechaza todo el cambio de punto** sin modificación parcial de reservas; se conserva el anterior. El pasajero puede solicitar otro intento.

**Precisión:** la dirección de contacto puede actualizarse aunque la solicitud de **nuevo punto de ascenso** sea rechazada; no está confirmado que deba revertirse el domicilio. El diseño de transacciones debe separar las operaciones. **PENDIENTE**: comprobar con VanFull si existe alguna excepción a este criterio derivado de respuestas distintas.

### F25-05 — Corrección de identificatorios

1. El pasajero no edita nombre, apellido ni DNI por autoservicio.
2. Solicita la corrección a VanFull.
3. Un administrador autorizado comprueba la información disponible y, si corresponde, efectúa la modificación.
4. No se exige documentación adicional de manera universal.

**PENDIENTE:** canal operativo de solicitud, criterios de comprobación y registro de quién modificó qué y cuándo; no se definieron endpoints.

## 6. Escenarios funcionales para futuras pruebas

Las siguientes pruebas son **escenarios derivados** de las aclaraciones, no especificaciones técnicas ni tests ya ejecutados.

| ID | Escenario | Resultado esperado |
|---|---|---|
| PT25-01 | Pasajero actualiza dirección del perfil. | Actualización permitida; coordinación de puntos de ascenso si es abonado. |
| PT25-02 | Pasajero intenta editar nombre directamente. | No se modifica; se informa gestión administrativa. |
| PT25-03 | Pasajero intenta editar apellido directamente. | No se modifica; se informa gestión administrativa. |
| PT25-04 | Pasajero intenta editar DNI directamente. | No se modifica; se aplica intervención administrativa (RN-026). |
| PT25-05 | Administrador corrige nombre/apellido/DNI tras comprobar datos existentes. | Puede corregir sin exigir documentación adicional universal. |
| PT25-06 | Pasajero propone nuevo correo pero aún no verifica. | Se conserva el correo anterior. |
| PT25-07 | Pasajero verifica correctamente el nuevo correo. | Cambia el contacto; no cambia el identificador de acceso. |
| PT25-08 | Verificación de correo no completada. | Correo anterior vigente. |
| PT25-09 | Pasajero cambia teléfono y elige SMS. | Se verifica por ese canal antes de actualizar. |
| PT25-10 | Pasajero cambia teléfono y elige WhatsApp. | Se verifica por ese canal antes de actualizar. |
| PT25-11 | Teléfono nuevo sin código verificado. | Teléfono anterior vigente. |
| PT25-12 | Pasajero completo modifica un contacto con verificación pendiente. | Sigue con perfil completo y operaciones habilitadas. |
| PT25-13 | Pasajero nuevo carece de fotografía. | Puede autenticarse y consultar servicios/horarios/cupos, pero no reservar ni pagar. |
| PT25-14 | Pasajero sin email verificado. | Perfil incompleto; no opera hasta completar. |
| PT25-15 | Pasajero sin teléfono verificado. | Perfil incompleto; no opera hasta completar. |
| PT25-16 | Pasajero intenta dejar el perfil sin fotografía. | No se permite eliminar la única foto válida. |
| PT25-17 | Pasajero presenta una foto con un único rostro claramente visible. | Validación satisfactoria permite aprobación automática. |
| PT25-18 | Pasajero presenta una foto con varias caras. | Rechazo de validación automática. |
| PT25-19 | Pasajero presenta imagen sin rostro visible. | Rechazo con motivo informado. |
| PT25-20 | Fotografía rechazada mientras ya existe una vigente. | Se conserva la anterior. |
| PT25-21 | Falla repetidamente la detección de un rostro real. | Puede solicitar revisión manual. |
| PT25-22 | Administrador aprueba fotografía inicialmente rechazada que cumple criterios. | Esa misma fotografía puede hacerse vigente. |
| PT25-23 | Administrador no aprueba foto rechazada. | Debe presentarse otra. |
| PT25-24 | Abonado cambia domicilio, sin confirmar nuevo ascenso. | Se conserva ascenso habitual previo si aún puede utilizarlo. |
| PT25-25 | Nuevo punto viable para todas las IDAS futuras reservadas. | Se aplica a las IDAS no iniciadas y reservas futuras afectadas. |
| PT25-26 | Nuevo punto inviable para al menos una reserva futura. | Se rechaza cambio íntegro; se mantiene punto anterior y reservas. |
| PT25-27 | Pasajero reintenta cambio de punto tras rechazo. | Debe iniciar una nueva solicitud; no existe reevaluación automática pendiente. |
| PT25-28 | Pasajero que nunca completó perfil intenta efectuar un pago. | No se permite la operación hasta completar el perfil. |

## 7. Trazabilidad e impactos entre módulos

| Necesidad / AC | RF / RN / CU relacionados | Interfaz / API actual | Datos / integración | Responsable de evaluar |
|---|---|---|---|---|
| Editar solo datos autorizados (AC25-01 a 03) | CU-001, RF-003, RN-026, RN-029 según Issue #25 | Perfil; `GET/PATCH /pasajeros/me` existentes | `persona`, `pasajero` | Martiniano (pasajero), Facundo (administración) |
| Verificación de contactos (AC25-08 a 11) | CU-001; impacto CU-012 para separación de identificadores | `PATCH /pasajeros/me` **no implementa todavía verificación** | `PERSONA.email`, `.telefono`, `CUENTA_ACCESO.identificador_acceso`; servicios de correo, WhatsApp y SMS **por definir** | Martiniano; evaluar integración/costos con equipo |
| Completitud y restricciones (AC25-04 a 07 y 22) | CU-001, CU-003 y módulos de pago; deben revisarse dependencias con las especificaciones aprobadas | Consultas de perfil y servicios existentes; validaciones globales por definir | `persona`, `pasajero` y posibles datos de verificación | Martiniano y Facundo |
| Fotografía (AC25-12 a 17) | CU-001; impacto administración para revisión manual | Lectura del atributo de foto existente, edición no contemplada en contrato actual | `PASAJERO.fotografia`; almacenamiento/detección por definir | Martiniano y Facundo |
| Domicilio y punto habitual (AC25-18 a 21) | Issue #8, CU-002/CU-003, restricciones de paradas comprometidas | No se autorizan nuevos endpoints aquí | Reserva, recorrido, paradas, planificación; DER/MR a cotejar | Martín, Martiniano, Facundo |

**Nota de API:** las rutas de tabla son **rutas existentes** verificadas. No se propone aquí nombre alguno para nuevas rutas, proveedores, eventos o tablas.

## 8. Pendientes de validación y decisiones del equipo

| ID | Pendiente | Dueño sugerido de revisión (no asignación nueva) |
|---|---|---|
| PV25-01 | Confirmar contra las versiones **íntegras y vigentes** de CU-001, RN-026, RN-029, RF-003 y demás CU afectados; determinar control de cambios de línea base. | Martín + equipo |
| PV25-02 | Determinar qué operaciones, además de reservas y pagos, quedan restringidas cuando el perfil está incompleto; distinguir lectura de operación. | Martín + Martiniano + Facundo |
| PV25-03 | Definir política de campos vacíos: `null`, cadenas vacías, normalización, errores, obligatoriedad al crear y en transiciones. | Martiniano con análisis |
| PV25-04 | Definir mecanismo, vigencia, reenvío, intentos, límites y errores de verificación de correo. | Martiniano |
| PV25-05 | Definir canal técnico de correo, verificación previa, almacenamiento de nuevo correo pendiente y colisiones con otras cuentas. | Martiniano |
| PV25-06 | Validar qué proveedores de WhatsApp y SMS son viables, su costo y su autorización para el alcance del PC2. | Equipo; Martiniano |
| PV25-07 | Definir el almacenamiento seguro de datos de verificación, auditoría y prevención de abusos. | Equipo |
| PV25-08 | Definir carga y almacenamiento de fotografías; formatos, dimensiones, tamaño, errores y reemplazo seguro. | Martiniano |
| PV25-09 | Definir tecnología de detección automática de rostro único y sus límites; **no introducir identificación biométrica** sin nueva definición expresa. | Equipo |
| PV25-10 | Establecer revisión manual excepcional: canal, responsable habilitado, trazabilidad, notificación y procedimiento de rechazo. | Facundo + Martiniano |
| PV25-11 | Resolver privacidad, retención y eliminación física de imágenes y verificaciones. | Equipo y revisión legal/docente si aplica |
| PV25-12 | Resolver cómo modelar «perfil completo» y «contacto verificado», preservando línea base MR/SQL vigente y datos anteriores incompletos. | Martín + equipo |
| PV25-13 | Confirmar si cambio de domicilio y propuesta de punto de ascenso son transacciones independientes, y cómo se gestionan fallas parciales. | Martín + equipo |
| PV25-14 | Comprobar viabilidad para todas las reservas futuras y actualizar paradas comprometidas sin afectar viajes iniciados, con control de cambios del Issue #8. | Martín + Martiniano + Facundo |
| PV25-15 | Definir comportamiento si el punto anterior ya no puede utilizarse y aún no existe nuevo punto viable. | Validación con VanFull |
| PV25-16 | Precisar canal y verificaciones administrativas para corrección de nombre/apellido/DNI sin inventar documentación obligatoria. | Facundo + análisis |
| PV25-17 | Auditar compatibilidad de los flujos actuales de autenticación, reservas, pago y perfil; acordar pruebas de regresión. | Equipo |
| PV25-18 | Confirmar qué partes son implementables en PC2 y cuáles requieren extensión posterior: verificación SMS/WhatsApp, fotos con detección de rostro, revisión manual y modificación de ascenso/recorridos. | Equipo y consigna docente |

## 9. Alcance PC2: clasificación explícita

| Capacidad | Situación funcional | Tratamiento de alcance |
|---|---|---|
| Consultar y modificar perfil propio | CU-001 priorizado en `REPARTO-PC2.md`. | **Dentro del alcance funcional de PC2**, sujeto al contrato aprobado. |
| Permitir fotografía editable | Confirmado por VanFull, hoy no implementado como edición. | **Pendiente de aprobación técnica/de alcance** para PC2. |
| Email y teléfono verificados, elección SMS/WhatsApp | Confirmado por VanFull. | **Pendiente de aprobación de integraciones, costos y alcance**; no presuponer implementable en PC2. |
| Detección de un rostro y revisión manual | Confirmado por VanFull. | **Pendiente de evaluación técnica y alcance**; alternativa de extensión futura si el equipo la aprueba. |
| Perfil completo como precondición operativa | Confirmado por VanFull. | **Pendiente de articulación** con CU-003, pagos y lineamientos aprobados. |
| Propuesta y cambio de puntos de ascenso próximos al domicilio | Confirmado por VanFull y complementa Issue #8. | **Fuera del reparto priorizado de PC2 para recorridos/abonos**; eventual incorporación exige aprobación expresa. |
| Correcciones administrativas de datos identificatorios | Confirmado por VanFull. | **Pendiente de definir** si requiere operación nueva en PC2 y cómo se instrumenta. |

**Importante:** registrar una necesidad confirmada por VanFull no basta para convertirla en una tarea técnica obligatoria antes del PC2.

## 10. Propuestas de IA — no aprobadas

1. Separar conceptualmente el **perfil de contacto** de las **solicitudes de actualización pendientes**, evitando sustituir datos antes de verificarlos. **PROPUESTA DE IA**, no define tabla ni endpoint.
2. Evaluar un mecanismo transversal y reutilizable que compruebe completitud **solo en operaciones que la requieran**, conservando acceso a consultas. **PROPUESTA DE IA**, no código aprobado.
3. Contemplar pruebas específicas de falsos rechazos de detección facial, sin añadir reconocimiento de identidad ni comparación contra documentos. **PROPUESTA DE IA**.
4. Implementar los cambios bajo control de versiones separado para contrato, datos y backend, con revisión de impacto en el frontend. **PROPUESTA DE IA**.

## 11. Control de calidad del borrador

- [x] Se distingue información aportada por VanFull de implementación actual y recomendaciones.
- [x] Se mantiene RN-026 respecto del DNI y se evita atribuirle una obligación de documentación que no está probada.
- [x] Se identifica la divergencia entre atributos opcionales de SQL y obligatoriedad funcional del perfil.
- [x] Se señalan las nuevas necesidades de verificación y de fotografía no cubiertas por la API actual.
- [x] Se conserva separación entre email de contacto e identificador de acceso.
- [x] Se enlaza el cambio de domicilio con Issue #8 y con paradas comprometidas.
- [x] Se delimitan funcionalidades que no deben incorporarse tácitamente al PC2.
- [ ] **PENDIENTE:** cotejar integralmente fuentes de Drive (CU/RN/RF vigentes) antes de un cambio de línea base.
- [x] **APROBADO FUNCIONALMENTE POR MARTÍN:** v0.1 aprobada explícitamente el 18/10/2026; v0.2 consolida el mismo contenido sin cambios sustantivos.
- [ ] **PENDIENTE:** revisión técnica de Martiniano y Facundo y decisión de alcance del equipo.
- [ ] **PENDIENTE:** implementación y pruebas; Issue #25 continúa abierto.

## 12. Próximos pasos

1. Incorporar **solamente este documento v0.2** en una PR documental de GitHub para revisión de Martiniano y Facundo.
2. Resolver pendientes técnicos/de alcance y, si corresponde, tramitar control de cambios a CU, RF, RN, DER/MR, SQL y OpenAPI antes de alterar software.
3. Definir en equipo la prioridad y viabilidad de verificación de correo/teléfono, fotografía y cambios de punto de ascenso para PC2, diferenciando extensión futura.
4. Mantener abierto el **Issue #25** hasta que se implementen y prueben las decisiones técnicas acordadas.

---

**Control de versión:** v0.2, emitida tras la aprobación funcional explícita de Martín el 18/10/2026 sobre la v0.1. Se conservan sin cambios sustantivos las aclaraciones AC25, los escenarios PT25 y los pendientes PV25; solo se actualizan el estado, la versión y los próximos pasos. **La aprobación funcional no modifica la línea base ni supone aprobación técnica o de alcance para PC2.**