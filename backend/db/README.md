# Modelo de datos SQL — Vanfull

`schema.sql` es el **modelo físico (DDL PostgreSQL)** de Vanfull, derivado del **Modelo Relacional
aprobado por el equipo** (35 tablas, 5 bloques). Cubre el requisito **"Modelo de datos SQL"** del PC1.

## Bloques (35 tablas)

1. **Personas, clientes y acceso** (12): `persona`, `pasajero`, `chofer`, `cliente`, `cliente_individual`,
   `cliente_persona_juridica`, `cliente_corporativo`, `contacto_corporativo`, `pasajero_corporativo`,
   `cuenta_acceso`, `rol_acceso`, `cuenta_rol`.
2. **Servicios y contratación** (6): `servicio`, `tarifa`, `contratacion`, `abono_mensual`, `periodo_abono`, `periodo_abono_viaje`.
3. **Viajes, recorridos y operación** (12): `recorrido`, `parada`, `parada_recorrido`, `vehiculo`, `viaje`,
   `posicion_gps`, `reserva`, `registro_lista_espera`, `nomina_pasajeros`, `integrante_nomina`, `abordaje`, `ausencia`.
4. **Cuenta corriente, pagos y comprobantes** (4): `cuenta_corriente`, `pago`, `movimiento_cuenta`, `comprobante`.
5. **Trazabilidad operativa** (1): `evento_operativo`.

## Decisiones del modelo físico (las que el MR dejó diferidas)

- **PK**: `BIGINT GENERATED ALWAYS AS IDENTITY` (sintéticos numéricos).
- **Dominios enumerados**: `CHECK` (portable) donde el catálogo está documentado (tipo_servicio, sentido,
  estados de pago/viaje/reserva/habilitación, medio_pago, tipo de comprobante). Los **roles** usan tabla
  catálogo (`rol_acceso`) según el MR.
- **Importes** `NUMERIC(12,2)`; **coordenadas** `NUMERIC(9,6)`; fechas `DATE`, horas `TIME`, marcas `TIMESTAMPTZ`.
- **FKs compuestas** para integridad real: reserva/abordaje → `viaje(id_viaje,id_recorrido)`,
  `parada_recorrido(id_recorrido,orden)`, `periodo_abono_viaje`; movimiento → `pago`/`contratacion` por cliente.
- **XOR** de respaldo de reserva (PeríodoAbono ⊻ Contratación) resuelto con `CHECK`.
- **Derivados NO persistidos**: saldo, deuda y cupo disponible se calculan (MR-R30). `posicion_gps` = solo última posición.

## Reglas de negocio NO expresables en DDL

Se validan en el backend (FastAPI), no acá: mínimo 2 paradas por recorrido, mínimo 1 representante corporativo,
capacidad suficiente del vehículo, límite de deuda (RN-006), períodos de pago de abonos, etc.

## Cómo cargarlo

```bash
# Levantar solo la base
docker compose up -d db
# Aplicar el schema
docker compose exec -T db psql -U vanfull -d vanfull -v ON_ERROR_STOP=1 -f - < backend/db/schema.sql
# Verificar
docker compose exec -T db psql -U vanfull -d vanfull -c "\dt"
```

## Validación

Sintaxis validada con `sqlglot` (dialecto postgres): 35 `CREATE TABLE` + 54 FKs + seed de roles.

**El esquema fue ejecutado correctamente contra PostgreSQL 16** mediante Docker Compose, verificando la
creación completa de las 35 tablas y sus 54 claves foráneas, y el seed de los 5 roles. Además se comprobó
que las restricciones **rechazan datos inválidos**: un `tipo_servicio` fuera del dominio permitido es
rechazado por la base, no por la aplicación.

## Próximo paso

Este DDL es la base de los **modelos ORM (SQLAlchemy 2.0)** y de las **migraciones Alembic**.
