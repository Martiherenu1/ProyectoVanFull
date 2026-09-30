# VanFull — instrucciones del proyecto

Plataforma **Web + Mobile** para VanFull, empresa **real** de charters que hoy opera con WhatsApp + Excel +
teléfono. Trabajo de Campo, 4º año. Equipo de 3: **Martiniano + su compañero** cubren Integrante 1 (datos,
backend, API) **+** Integrante 3 (IA/agentes, Flutter, modelo de desarrollo); **Integrante 2 (Martín Defez)**
produce análisis, casos de uso, UML/C4 y el DER, y hace revisión cruzada.

## Cómo trabajar conmigo

1. **Explicar antes de hacer:** qué archivo, por qué, y qué hace cada parte.
2. **Pasos chicos y revisables**, un concepto por vez.
3. **Mostrar el contenido o el diff antes** de commitear, mergear o subir algo al Drive.
4. **Explicar los comandos** que se corren, no solo pegar el resultado.
5. Verificar en vez de suponer. Si algo no se pudo verificar, decirlo.

## La regla de arquitectura que gobierna todo

Cliente-servidor por capas. **La IA no accede a la base de datos**: invoca *tools* de FastAPI.
**FastAPI es la autoridad** de reglas, permisos, cupos y pagos. Capas del backend:
`routers/` (finos, sin lógica) → `schemas/` (Pydantic) → `services/` (**las 31 RN**) → `models/` (SQLAlchemy).

**No inventar reglas de negocio ni identificadores.** La línea funcional está cerrada: 45 RF, 14 RNF, 31 RN,
9 actores, 37 CU, 35 tablas. Si algo no está aprobado, es un pendiente, no una inferencia.

## Dónde está el contexto (no leer todo: leer lo que haga falta)

| Para qué | Archivo |
|---|---|
| **Arrancar cualquier sesión** | `Documentos/Sesiones/CONTEXTO.md` — estado, decisiones y pendientes |
| Prompts de arranque por tipo de tarea | `Documentos/Sesiones/PROMPT-INICIAL.md` |
| Convenciones de commits y ramas | `CONTRIBUTING.md` |
| Línea funcional (RF/RNF/RN/CU) resumida | `Documentos/Documentacion/06-Notas-Ingesta-Drive-2026-09-08.md` |
| Reglas de diseño de UI | `Documentos/Documentacion/08-Brief-de-Diseno-UI.md` |
| IA y agentes (AG-01, 13 tools) | `Documentos/Documentacion/07-IA-y-Agentes-Consolidado.md` |
| Entregable del PC1 | `Documentos/Documentacion/10-Documento-MVC-PC1.md` |
| Logros para el CV | `Documentos/HITOS.md` |

**Drive del equipo** (documentación oficial, dueño martindefez@gmail.com) y **artifacts de diseño**: los IDs y
los links están en `CONTEXTO.md`. El Drive es la documentación oficial; **GitHub es código y artefactos
versionables**. Los `.docx` no se versionan en el repo.

## Esta máquina: lo que hay y lo que no

**Hay:** `node` con el paquete `docx` · `git` · `java` 19 · Docker · Drive por MCP.

**Ojo con Python.** El `python` del shell (msys2) **no tiene pip ni pyyaml**. El que tiene `pyyaml`,
`openapi_spec_validator` y `jsonschema` es el **Python 3.13** de
`~/AppData/Local/Programs/Python/Python313/python`. Antes de asumir cualquiera de los dos, comprobar con
`python -c "import yaml"`. Esto es por máquina: en otra computadora del equipo puede ser distinto.

**No hay:** `zip` (usar `zipfile` de Python) · LibreOffice (`soffice`) ni `pdftoppm` → **no se puede renderizar
un .docx ni un PDF acá** · `pytest` ni `fastapi` → **no se puede correr la suite**; las aserciones de
`tests/test_health.py` sobre las tools se verifican importando `backend/app/agent/tools.py` directo ·
`plantuml.jar` → no se puede regenerar el DER.

**Drive por MCP:** `update_file` **solo cambia metadatos** (título, carpeta), no contenido. Para reemplazar un
binario hay que generarlo local y pedirle a Martiniano que lo suba — nunca reconstruir base64 a mano.
`search_files` devuelve **5 resultados por página**, hay que paginar. Los `.puml` y `.drawio` llegan como
`octet-stream`: usar `download_file_content` y decodificar.

## Git

Flujo **rama → commit → merge `--no-ff` → push**. Conventional Commits, mencionando el CU o la RN que
justifica el cambio. `.env` nunca se sube. El tag **`pc1`** es la foto de la entrega; se congela después de la
presentación y de ahí en más cada cambio lleva tag nuevo.

Mover un tag con `--force` **lo bloquea el clasificador de permisos**: hay que pasarle el comando a Martiniano.

## Al cerrar una sesión

Actualizar `Documentos/Sesiones/CONTEXTO.md` con lo que cambió, y `Documentos/HITOS.md` si hubo un logro
contable. Si aparece un dato de entorno nuevo que costó descubrir, agregarlo acá.
