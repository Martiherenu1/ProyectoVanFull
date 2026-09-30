# Cronograma — Trabajo de Campo 3334 (2º Cuatrimestre 2026)

> Fuente: `Cronograma_VanFull.docx`, con las fechas de los puntos de control corregidas por el equipo el
> **2026-09-30**. Las semanas arrancan el **lunes** y el encuentro de cada semana es el **viernes**, así que
> cada punto de control cae el viernes de su semana.
>
> **Hoy: 2026-09-30, miércoles → Semana 9.**

| Sem | Semana del | Actividad | Entregable / hito |
|----|-----------|-----------|-------------------|
| 4 | 24/08 | Definición del problema y planificación inicial | Objetivos, alcance y límites; repositorio y tablero |
| 5 | 31/08 | Relevamiento y análisis funcional | Actores, 45 RF, 14 RNF y 31 reglas de negocio |
| 6 | 07/09 | Modelado funcional (UML) | Casos de uso, diagramas de actividad, **C4 de Contexto y de Contenedores** |
| 7 | 14/09 | Diseño de arquitectura y datos | Modelo conceptual, **DER** y modelo relacional |
| 8 | 21/09 | Diseño de IA y comunicación entre sistemas | Selección de modelos, agente y prompts, **contrato OpenAPI** |
| **9** | **28/09** | **Interfaces gráficas y consolidación del documento** ← *estamos acá* | 🎯 **1er Punto de Control — viernes 02/10** |
| 10 | 05/10 | Desarrollo del backend | Modelos, reglas de negocio y endpoints sobre PostgreSQL |
| 11 | 12/10 | Desarrollo del frontend | Pantallas Flutter conectadas al backend |
| 12 | 19/10 | Integración de funcionalidades | Frontend + backend + IA + Mercado Pago + GPS de punta a punta |
| **13** | **26/10** | **Cierre del desarrollo** | 🎯 **2do Punto de Control — viernes 30/10** |
| 14 | 02/11 | Pruebas y documentación | Pruebas funcionales, manual de instalación y de usuario |
| **15** | **09/11** | **Cierre de pruebas y documentación** | 🎯 **3er Punto de Control — viernes 13/11** |
| 16 | 16/11 | Cierre | **Cierre y aprobación — viernes 20/11** |

## Por qué estas fechas y no otras

Circulaban **tres versiones** del cronograma con fechas distintas:

- El `Cronograma de Actividades - Proyecto VanFull` que el equipo mandó en agosto ubicaba el 1er punto de
  control el **23/10**, con una nota al pie admitiendo que había ajustado fechas por un supuesto error de
  tipeo en la plantilla. **Está mal:** el PC1 se entregó el 28/09 y se presenta el 02/10.
- Una versión anterior de este archivo tenía las semanas correctas pero sin la fecha del encuentro.
- La planilla `Cronograma` de la cátedra que aparece en el Drive compartido tiene fechas de **martes**, así
  que corresponde a otra materia o a otra comisión. No aplica.

**Vale esta tabla.** Las semanas son las de la planificación original; las fechas de los tres puntos de
control las confirmó el equipo el 30/09 sobre la base de que los encuentros son los viernes.

## Estado al 2026-09-30

- **Semanas 4 a 8: cerradas.** El PC1 cubre relevamiento, modelado, arquitectura y datos, IA y contrato.
- **Semana 9, en curso.** Interfaces gráficas terminadas (10 pantallas) y documento del MVC consolidado.
  Falta pegar el cronograma y ensayar la presentación.
- **El desarrollo arranca la semana 10 (05/10):** el orden es `models/` → `services/` → `routers/` → tests.
  El backend hoy solo tiene `/health`.
