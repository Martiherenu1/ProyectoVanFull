# Prompt PC2 · Martiniano — Pasajero (frontend + backend) y base común del backend

> Para un agente de IA abierto en la raíz del repositorio. Se pega completo como primer mensaje del chat.

```text
ROL
Desarrollás el área del PASAJERO de VanFull para el PC2 (viernes 30/10), frontend y backend, y además
armás la base común del backend que usan los otros dos integrantes (Martín: chofer y viaje en curso;
Facundo: administración). Trabajamos juntos: quiero entender cada cosa que se hace.

LEÉ PRIMERO, EN ESTE ORDEN
1. CLAUDE.md: reglas del proyecto.
2. CONTRIBUTING.md: el método de trabajo. Es obligatorio y manda sobre cualquier otra indicación.
3. Documentos/Sesiones/PC2/REPARTO-PC2.md: qué es tuyo, qué no, y qué falta en el contrato.
4. Documentos/Sesiones/CONTEXTO.md: §3 (arquitectura), §7 (decisiones), §11 (estado del código) y §13.
5. backend/db/schema.sql, backend/openapi/openapi.yaml y backend/openapi/README.md.
No leas el resto de Documentos/Documentacion/ salvo el 07 si la tarea toca al agente.

CÓMO TRABAJÁS (resumen de CONTRIBUTING.md)
- Al empezar cada sesión: git switch main && git pull, gh issue list --label pasajero (y --label comun),
  y me decís en qué estado está todo antes de proponer nada.
- Cada tarea: Issue con su CU → verificar antes de hacer (buscar si ya existe, leer lo que vas a tocar
  y lo que lo usa, confirmar que es de mi área) → rama → pasos chicos, un concepto por commit →
  checks (ruff, pytest, contrato, migración) → te muestro el diff y espero tu visto bueno →
  commit con el CU/RN y "Refs #issue" → PR con la plantilla → revisión de otro integrante → merge.
- Si dos fuentes no coinciden (contrato, schema.sql, especificación del CU, RN), parás y me avisás.
- Si no pudiste correr una prueba, decilo. Nunca des por bueno algo que no se ejecutó.

TU ÁREA
- CU: 012 (sesión, para todos los roles), 001, 002, 003, 004, 010, 006 (pantalla) y 011 (asistente).
- Backend (sos dueño): autenticación y roles, perfil, servicios y disponibilidad, tarifas, reservas,
  lista de espera FIFO y el agente AG-01 (/chat y el ejecutor de sus 13 tools). Las tools de deuda y de
  ubicación usan los servicios de Facundo y de Martín: se llaman, no se reescriben.
- Contrato a completar: CU-003 no tiene la lista de espera.
- Pantallas, en frontend/lib/screens/pasajero/: login, buscar servicio, confirmar reserva, mis reservas
  y deuda, pago (el backend de pagos es de Facundo) y asistente. Con mocks hasta que el endpoint exista.
- Clave de OpenRouter: solo en backend/.env, nunca en el repo.

PASO 0 · ENTORNO
Comprobá docker info y qué Python hay con pip. Proponeme cómo correr backend y pruebas (docker compose
o un venv) y esperá que elija antes de instalar nada.

PASO 1 · BASE COMÚN (bloquea a los otros dos: va primero)
1. models/ de las 35 tablas de schema.sql, SQLAlchemy 2.0 async, un archivo por bloque (son 5).
   Decisiones del §7 de CONTEXTO: PK BIGINT identity, CHECK para enums, NUMERIC para importes,
   derivados no persistidos.
2. Primera migración de Alembic. Verificá contra PostgreSQL que crea lo mismo que schema.sql.
3. Autenticación: /auth/login y /auth/logout del contrato, JWT, roles con rol_acceso + cuenta_rol.
4. Un helper para registrar evento_operativo, y la convención de services/ y routers/ que van a copiar
   los demás. Es el modelo a seguir: tiene que quedar claro y explicado.
5. backend/db/seed/ con el script que carga los datos de prueba.
6. Integración continua en GitHub Actions (ruff, pytest, validación del contrato) y las etiquetas
   pasajero, chofer, admin y comun. Verificá que la CI pase en verde antes de darla por terminada.
Cada punto es un Issue y un PR. Avisame cuando cada uno esté en main, porque desbloquea a los demás.

PASO 2 · TU CIRCUITO
Reservas: services/ con sus RN → routers/ → pruebas → pantallas. Después, el asistente AG-01.

CIERRE DE CADA TAREA
Qué quedó hecho, qué se probó y cómo, qué no se pudo verificar, qué endpoints ya pueden usar Martín y
Facundo, y qué sigue.
```
