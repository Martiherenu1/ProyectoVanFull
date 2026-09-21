-- =============================================================================
-- VanFull — Modelo de datos SQL (DDL PostgreSQL)
-- =============================================================================
-- Derivado del Modelo Relacional aprobado por el equipo (35 tablas, 5 bloques):
--   Documentos/Documentacion/06-Notas-Ingesta-Drive-2026-09-08.md §1
--   Drive: VanFull_MR_Entidades_y_Relaciones_Revision_Equipo.md + Modelo Relacional Version Consolidada.puml
--
-- Este archivo implementa el MODELO FÍSICO (etapa que el MR dejó explícitamente
-- diferida). Decisiones físicas tomadas por el equipo técnico (Integrante 1):
--   * PK: identificadores sintéticos numéricos -> BIGINT GENERATED ALWAYS AS IDENTITY.
--   * Dominios enumerados con CHECK (portable, simple) SOLO donde el catálogo está
--     documentado; los roles usan tabla catálogo (ROL_ACCESO) según el MR.
--   * Importes -> NUMERIC(12,2); coordenadas -> NUMERIC(9,6); montos siempre exactos.
--   * Fechas -> DATE; horas -> TIME; marcas temporales -> TIMESTAMPTZ.
--   * Valores derivados (saldo, deuda, cupo disponible) NO se persisten (MR-R30).
--   * POSICION_GPS conserva solo la última posición, sin historial (MR-R31).
--   * NOTIFICACION no es entidad (MR-R32).
-- Reglas de negocio multi-fila (min. 2 paradas por recorrido, min. 1 representante,
-- capacidad suficiente, etc.) se validan en el backend (FastAPI), no en el DDL.
-- =============================================================================

-- Idempotencia para desarrollo: recrear limpio.
DROP SCHEMA IF EXISTS public CASCADE;
CREATE SCHEMA public;

-- =============================================================================
-- BLOQUE 1 — PERSONAS, CLIENTES Y ACCESO
-- =============================================================================

CREATE TABLE persona (
    id_persona   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre       VARCHAR(80)  NOT NULL,
    apellido     VARCHAR(80)  NOT NULL,
    dni          VARCHAR(20)  NOT NULL UNIQUE,
    direccion    VARCHAR(200),
    telefono     VARCHAR(30),
    email        VARCHAR(120)
);

CREATE TABLE pasajero (
    id_persona          BIGINT PRIMARY KEY,               -- PK/FK -> persona
    categoria           VARCHAR(30),                      -- universitario/laboral/eventual/empresarial (catálogo a confirmar)
    estado_habilitacion VARCHAR(20) NOT NULL DEFAULT 'habilitado'
        CHECK (estado_habilitacion IN ('habilitado', 'suspendido', 'baja')),
    fotografia          VARCHAR(500)                      -- referencia/URL; estrategia de almacenamiento a definir
);

CREATE TABLE chofer (
    id_persona                  BIGINT PRIMARY KEY,       -- PK/FK -> persona
    cuil                        VARCHAR(20),
    registro_conducir           VARCHAR(40),
    fecha_vencimiento_registro  DATE
);

CREATE TABLE cliente (
    id_cliente        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    naturaleza_cliente VARCHAR(20) NOT NULL
        CHECK (naturaleza_cliente IN ('INDIVIDUAL', 'PERSONA_JURIDICA'))
);

CREATE TABLE cliente_individual (
    id_cliente  BIGINT PRIMARY KEY,                       -- PK/FK -> cliente
    id_persona  BIGINT NOT NULL UNIQUE                    -- FK -> persona
);

CREATE TABLE cliente_persona_juridica (
    id_cliente    BIGINT PRIMARY KEY,                     -- PK/FK -> cliente
    razon_social  VARCHAR(150) NOT NULL,
    cuit          VARCHAR(20)  NOT NULL UNIQUE,
    direccion     VARCHAR(200)
);

CREATE TABLE cliente_corporativo (
    id_cliente  BIGINT PRIMARY KEY,                       -- PK/FK -> cliente (coexiste con individual/jurídica)
    estado      VARCHAR(30) NOT NULL DEFAULT 'activo'
);

CREATE TABLE contacto_corporativo (
    id_cliente_corporativo  BIGINT  NOT NULL,             -- PK/FK -> cliente_corporativo
    id_persona              BIGINT  NOT NULL,             -- PK/FK -> persona
    cargo                   VARCHAR(80),
    es_representante        BOOLEAN NOT NULL DEFAULT FALSE,
    PRIMARY KEY (id_cliente_corporativo, id_persona)
);

CREATE TABLE pasajero_corporativo (
    id_cliente_corporativo  BIGINT NOT NULL,              -- PK/FK -> cliente_corporativo
    id_pasajero             BIGINT NOT NULL,              -- PK/FK -> pasajero
    estado_vinculo          VARCHAR(30) NOT NULL DEFAULT 'activo',
    PRIMARY KEY (id_cliente_corporativo, id_pasajero)
);

CREATE TABLE cuenta_acceso (
    id_cuenta_acceso     BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_persona           BIGINT       NOT NULL UNIQUE,    -- FK -> persona
    identificador_acceso VARCHAR(120) NOT NULL UNIQUE,    -- email/usuario de login
    estado               VARCHAR(20)  NOT NULL DEFAULT 'activo'
);

CREATE TABLE rol_acceso (
    id_rol_acceso BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    rol           VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE cuenta_rol (
    id_cuenta_acceso BIGINT NOT NULL,                     -- PK/FK -> cuenta_acceso
    id_rol_acceso    BIGINT NOT NULL,                     -- PK/FK -> rol_acceso
    PRIMARY KEY (id_cuenta_acceso, id_rol_acceso)
);

-- =============================================================================
-- BLOQUE 2 — SERVICIOS Y CONTRATACIÓN
-- =============================================================================

CREATE TABLE servicio (
    id_servicio   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tipo_servicio VARCHAR(20) NOT NULL
        CHECK (tipo_servicio IN ('UNIVERSITARIO', 'LABORAL', 'CORPORATIVO', 'ESPECIAL'))
);

CREATE TABLE tarifa (
    id_tarifa      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre         VARCHAR(120)  NOT NULL,
    importe        NUMERIC(12,2) NOT NULL CHECK (importe >= 0),
    tipo           VARCHAR(40),
    fecha_creacion DATE NOT NULL DEFAULT CURRENT_DATE,
    fecha_vigencia DATE
);

CREATE TABLE contratacion (
    id_contratacion         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_cliente              BIGINT NOT NULL,              -- FK -> cliente
    id_servicio             BIGINT NOT NULL,              -- FK -> servicio
    id_tarifa               BIGINT,                       -- FK -> tarifa (opcional)
    importe_acordado        NUMERIC(12,2) CHECK (importe_acordado IS NULL OR importe_acordado >= 0),
    condiciones_comerciales TEXT,
    UNIQUE (id_contratacion, id_cliente)                  -- soporte de FK compuesta (movimiento_cuenta)
);

CREATE TABLE abono_mensual (
    id_abono_mensual BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_contratacion  BIGINT NOT NULL UNIQUE,              -- FK -> contratacion (1:0..1)
    id_pasajero      BIGINT NOT NULL,                     -- FK -> pasajero (beneficiario)
    modalidad        VARCHAR(20)
        CHECK (modalidad IS NULL OR modalidad IN ('IDA', 'VUELTA', 'IDA_VUELTA')),
    dias_semanales   VARCHAR(30),                         -- días contratados (ej: "L,M,X,J,V")
    estado           VARCHAR(30) NOT NULL DEFAULT 'activo'
);

CREATE TABLE periodo_abono (
    id_periodo_abono BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_abono_mensual BIGINT NOT NULL,                     -- FK -> abono_mensual
    periodo          VARCHAR(7) NOT NULL,                 -- 'YYYY-MM'
    estado           VARCHAR(30) NOT NULL DEFAULT 'vigente',
    UNIQUE (id_abono_mensual, periodo)
);

CREATE TABLE periodo_abono_viaje (
    id_periodo_abono BIGINT NOT NULL,                     -- PK/FK -> periodo_abono
    id_viaje         BIGINT NOT NULL,                     -- PK/FK -> viaje
    PRIMARY KEY (id_periodo_abono, id_viaje)
);

-- =============================================================================
-- BLOQUE 3 — VIAJES, RECORRIDOS Y OPERACIÓN
-- =============================================================================

CREATE TABLE recorrido (
    id_recorrido BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY
);

CREATE TABLE parada (
    id_parada         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre_descripcion VARCHAR(150),
    direccion         VARCHAR(200),
    latitud           NUMERIC(9,6),
    longitud          NUMERIC(9,6)
);

CREATE TABLE parada_recorrido (
    id_recorrido BIGINT  NOT NULL,                        -- PK/FK -> recorrido
    orden        INTEGER NOT NULL,                        -- PK; único por recorrido
    id_parada    BIGINT  NOT NULL,                        -- FK -> parada
    comprometida BOOLEAN NOT NULL DEFAULT FALSE,
    PRIMARY KEY (id_recorrido, orden)
);

CREATE TABLE vehiculo (
    id_vehiculo    BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    patente        VARCHAR(10) NOT NULL UNIQUE,
    marca          VARCHAR(50),
    modelo         VARCHAR(50),
    capacidad      INTEGER NOT NULL CHECK (capacidad > 0),
    disponibilidad BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE viaje (
    id_viaje             BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_servicio          BIGINT NOT NULL,                 -- FK -> servicio
    id_recorrido         BIGINT NOT NULL,                 -- FK -> recorrido
    id_vehiculo          BIGINT,                          -- FK -> vehiculo (0..1 en planificación)
    id_chofer            BIGINT,                          -- FK -> chofer (0..1 en planificación)
    fecha                DATE   NOT NULL,
    horario              TIME,
    sentido              VARCHAR(10) NOT NULL CHECK (sentido IN ('IDA', 'VUELTA')),
    estado               VARCHAR(20) NOT NULL DEFAULT 'programado'
        CHECK (estado IN ('programado', 'en_curso', 'finalizado', 'cancelado')),
    capacidad_planificada INTEGER CHECK (capacidad_planificada IS NULL OR capacidad_planificada >= 0),
    UNIQUE (id_viaje, id_recorrido),                      -- soporte de FK compuesta (reserva/abordaje)
    UNIQUE (id_viaje, id_vehiculo)                        -- soporte de FK compuesta (abordaje)
);

CREATE TABLE posicion_gps (
    id_viaje            BIGINT PRIMARY KEY,               -- PK/FK -> viaje (solo última posición)
    latitud             NUMERIC(9,6),
    longitud            NUMERIC(9,6),
    fecha_hora_posicion TIMESTAMPTZ
);

CREATE TABLE reserva (
    id_reserva              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_pasajero             BIGINT NOT NULL,              -- FK -> pasajero
    id_viaje                BIGINT NOT NULL,              -- parte de FK compuesta -> viaje
    id_recorrido            BIGINT NOT NULL,              -- parte de FK compuesta -> viaje y parada_recorrido
    orden_parada            INTEGER NOT NULL,             -- parte de FK compuesta -> parada_recorrido
    id_periodo_abono        BIGINT,                       -- respaldo por abono (XOR)
    id_contratacion_directa BIGINT,                       -- respaldo directo (XOR)
    estado                  VARCHAR(20) NOT NULL DEFAULT 'provisional'
        CHECK (estado IN ('provisional', 'consolidada', 'cancelada')),
    UNIQUE (id_pasajero, id_viaje),                       -- máx. una reserva por pasajero+viaje (MR-R15)
    -- Respaldo exactamente uno: PeriodoAbono XOR Contratación directa (MR-R13)
    CHECK ((id_periodo_abono IS NOT NULL) <> (id_contratacion_directa IS NOT NULL))
);

CREATE TABLE registro_lista_espera (
    id_registro_lista_espera BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_pasajero          BIGINT NOT NULL,                 -- FK -> pasajero
    id_viaje             BIGINT NOT NULL,                 -- FK -> viaje
    fecha_hora_solicitud TIMESTAMPTZ NOT NULL DEFAULT now(),  -- FIFO (MR-R20)
    estado               VARCHAR(20) NOT NULL DEFAULT 'en_espera',
    UNIQUE (id_pasajero, id_viaje)                        -- único por pasajero+viaje (MR-R19)
);

CREATE TABLE nomina_pasajeros (
    id_viaje BIGINT PRIMARY KEY                           -- PK/FK -> viaje (solo servicios ESPECIALES)
);

CREATE TABLE integrante_nomina (
    id_integrante_nomina BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_viaje BIGINT      NOT NULL,                        -- FK -> nomina_pasajeros
    nombre   VARCHAR(80) NOT NULL,
    apellido VARCHAR(80) NOT NULL,
    dni      VARCHAR(20) NOT NULL,
    UNIQUE (id_viaje, dni)                                -- MR-R23
);

CREATE TABLE abordaje (
    id_abordaje  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_pasajero  BIGINT  NOT NULL,                        -- FK -> pasajero
    id_viaje     BIGINT  NOT NULL,                        -- FK compuesta -> viaje
    id_vehiculo  BIGINT  NOT NULL,                        -- FK compuesta -> viaje (vehículo del viaje)
    id_recorrido BIGINT  NOT NULL,                        -- FK compuesta -> viaje y parada_recorrido
    orden_parada INTEGER NOT NULL,                        -- FK compuesta -> parada_recorrido
    UNIQUE (id_pasajero, id_viaje)                        -- máx. un abordaje válido por pasajero+viaje (MR-R24)
);

CREATE TABLE ausencia (
    id_ausencia BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_pasajero BIGINT NOT NULL,                          -- FK -> pasajero
    id_viaje    BIGINT NOT NULL,                          -- FK -> viaje
    UNIQUE (id_pasajero, id_viaje)                        -- máx. una ausencia por pasajero+viaje (MR-R25)
);

-- =============================================================================
-- BLOQUE 4 — CUENTA CORRIENTE, PAGOS Y COMPROBANTES
-- =============================================================================

CREATE TABLE cuenta_corriente (
    id_cliente BIGINT PRIMARY KEY                         -- PK/FK -> cliente (1:1). El saldo es derivado (MR-R30)
);

CREATE TABLE pago (
    id_pago    BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_cliente BIGINT       NOT NULL,                     -- FK -> cuenta_corriente
    importe    NUMERIC(12,2) NOT NULL CHECK (importe >= 0),
    fecha_hora TIMESTAMPTZ  NOT NULL DEFAULT now(),
    medio_pago VARCHAR(20)  NOT NULL
        CHECK (medio_pago IN ('EFECTIVO', 'TRANSFERENCIA', 'BILLETERA', 'CUENTA_CORRIENTE', 'MERCADO_PAGO')),
    estado     VARCHAR(20)  NOT NULL DEFAULT 'PENDIENTE'
        CHECK (estado IN ('PENDIENTE', 'CONFIRMADO', 'RECHAZADO')),
    UNIQUE (id_pago, id_cliente)                          -- soporte de FK compuesta (movimiento_cuenta)
);

CREATE TABLE movimiento_cuenta (
    id_movimiento_cuenta BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_cliente      BIGINT       NOT NULL,                -- FK -> cuenta_corriente
    id_contratacion BIGINT,                               -- FK compuesta -> contratacion (opcional)
    id_pago         BIGINT UNIQUE,                        -- FK compuesta -> pago (opcional, 0..1)
    naturaleza      VARCHAR(20)  NOT NULL
        CHECK (naturaleza IN ('DEUDOR', 'ACREEDOR')),
    estado          VARCHAR(20)  NOT NULL DEFAULT 'pendiente',
    importe         NUMERIC(12,2) NOT NULL CHECK (importe >= 0),
    fecha_hora      TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE TABLE comprobante (
    id_comprobante       BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tipo                 VARCHAR(20) NOT NULL
        CHECK (tipo IN ('RECIBO', 'FACTURA', 'NOTA_DE_CREDITO', 'NOTA_DE_DEBITO')),
    id_pago              BIGINT UNIQUE,                   -- FK -> pago (RECIBO)
    id_contratacion      BIGINT,                          -- FK -> contratacion (FACTURA)
    id_movimiento_cuenta BIGINT UNIQUE                    -- FK -> movimiento_cuenta (NC/ND)
);

-- =============================================================================
-- BLOQUE 5 — TRAZABILIDAD OPERATIVA
-- =============================================================================

CREATE TABLE evento_operativo (
    id_evento_operativo BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tipo_evento    VARCHAR(50) NOT NULL,
    fecha_hora     TIMESTAMPTZ NOT NULL DEFAULT now(),
    detalle_evento TEXT,
    id_reserva     BIGINT,                                -- FK -> reserva (opcional)
    id_pago        BIGINT,                                -- FK -> pago (opcional)
    id_viaje       BIGINT,                                -- FK -> viaje (opcional)
    -- A lo sumo un origen directo entre reserva/pago/viaje (MR-R29)
    CHECK (
        (CASE WHEN id_reserva IS NOT NULL THEN 1 ELSE 0 END
       + CASE WHEN id_pago    IS NOT NULL THEN 1 ELSE 0 END
       + CASE WHEN id_viaje   IS NOT NULL THEN 1 ELSE 0 END) <= 1
    )
);

-- =============================================================================
-- CLAVES FORÁNEAS (incluidas las compuestas)
-- =============================================================================

-- Bloque 1
ALTER TABLE pasajero              ADD FOREIGN KEY (id_persona) REFERENCES persona (id_persona);
ALTER TABLE chofer                ADD FOREIGN KEY (id_persona) REFERENCES persona (id_persona);
ALTER TABLE cliente_individual    ADD FOREIGN KEY (id_cliente) REFERENCES cliente (id_cliente);
ALTER TABLE cliente_individual    ADD FOREIGN KEY (id_persona) REFERENCES persona (id_persona);
ALTER TABLE cliente_persona_juridica ADD FOREIGN KEY (id_cliente) REFERENCES cliente (id_cliente);
ALTER TABLE cliente_corporativo   ADD FOREIGN KEY (id_cliente) REFERENCES cliente (id_cliente);
ALTER TABLE contacto_corporativo  ADD FOREIGN KEY (id_cliente_corporativo) REFERENCES cliente_corporativo (id_cliente);
ALTER TABLE contacto_corporativo  ADD FOREIGN KEY (id_persona) REFERENCES persona (id_persona);
ALTER TABLE pasajero_corporativo  ADD FOREIGN KEY (id_cliente_corporativo) REFERENCES cliente_corporativo (id_cliente);
ALTER TABLE pasajero_corporativo  ADD FOREIGN KEY (id_pasajero) REFERENCES pasajero (id_persona);
ALTER TABLE cuenta_acceso         ADD FOREIGN KEY (id_persona) REFERENCES persona (id_persona);
ALTER TABLE cuenta_rol            ADD FOREIGN KEY (id_cuenta_acceso) REFERENCES cuenta_acceso (id_cuenta_acceso);
ALTER TABLE cuenta_rol            ADD FOREIGN KEY (id_rol_acceso) REFERENCES rol_acceso (id_rol_acceso);

-- Bloque 2
ALTER TABLE contratacion   ADD FOREIGN KEY (id_cliente)  REFERENCES cliente (id_cliente);
ALTER TABLE contratacion   ADD FOREIGN KEY (id_servicio) REFERENCES servicio (id_servicio);
ALTER TABLE contratacion   ADD FOREIGN KEY (id_tarifa)   REFERENCES tarifa (id_tarifa);
ALTER TABLE abono_mensual  ADD FOREIGN KEY (id_contratacion) REFERENCES contratacion (id_contratacion);
ALTER TABLE abono_mensual  ADD FOREIGN KEY (id_pasajero) REFERENCES pasajero (id_persona);
ALTER TABLE periodo_abono  ADD FOREIGN KEY (id_abono_mensual) REFERENCES abono_mensual (id_abono_mensual);
ALTER TABLE periodo_abono_viaje ADD FOREIGN KEY (id_periodo_abono) REFERENCES periodo_abono (id_periodo_abono);
ALTER TABLE periodo_abono_viaje ADD FOREIGN KEY (id_viaje) REFERENCES viaje (id_viaje);

-- Bloque 3
ALTER TABLE parada_recorrido ADD FOREIGN KEY (id_recorrido) REFERENCES recorrido (id_recorrido);
ALTER TABLE parada_recorrido ADD FOREIGN KEY (id_parada)    REFERENCES parada (id_parada);
ALTER TABLE viaje ADD FOREIGN KEY (id_servicio)  REFERENCES servicio (id_servicio);
ALTER TABLE viaje ADD FOREIGN KEY (id_recorrido) REFERENCES recorrido (id_recorrido);
ALTER TABLE viaje ADD FOREIGN KEY (id_vehiculo)  REFERENCES vehiculo (id_vehiculo);
ALTER TABLE viaje ADD FOREIGN KEY (id_chofer)    REFERENCES chofer (id_persona);
ALTER TABLE posicion_gps ADD FOREIGN KEY (id_viaje) REFERENCES viaje (id_viaje);
ALTER TABLE reserva ADD FOREIGN KEY (id_pasajero) REFERENCES pasajero (id_persona);
ALTER TABLE reserva ADD FOREIGN KEY (id_viaje, id_recorrido) REFERENCES viaje (id_viaje, id_recorrido);
ALTER TABLE reserva ADD FOREIGN KEY (id_recorrido, orden_parada) REFERENCES parada_recorrido (id_recorrido, orden);
ALTER TABLE reserva ADD FOREIGN KEY (id_periodo_abono, id_viaje) REFERENCES periodo_abono_viaje (id_periodo_abono, id_viaje);
ALTER TABLE reserva ADD FOREIGN KEY (id_contratacion_directa) REFERENCES contratacion (id_contratacion);
ALTER TABLE registro_lista_espera ADD FOREIGN KEY (id_pasajero) REFERENCES pasajero (id_persona);
ALTER TABLE registro_lista_espera ADD FOREIGN KEY (id_viaje) REFERENCES viaje (id_viaje);
ALTER TABLE nomina_pasajeros ADD FOREIGN KEY (id_viaje) REFERENCES viaje (id_viaje);
ALTER TABLE integrante_nomina ADD FOREIGN KEY (id_viaje) REFERENCES nomina_pasajeros (id_viaje);
ALTER TABLE abordaje ADD FOREIGN KEY (id_pasajero) REFERENCES pasajero (id_persona);
ALTER TABLE abordaje ADD FOREIGN KEY (id_viaje, id_recorrido) REFERENCES viaje (id_viaje, id_recorrido);
ALTER TABLE abordaje ADD FOREIGN KEY (id_viaje, id_vehiculo) REFERENCES viaje (id_viaje, id_vehiculo);
ALTER TABLE abordaje ADD FOREIGN KEY (id_recorrido, orden_parada) REFERENCES parada_recorrido (id_recorrido, orden);
ALTER TABLE ausencia ADD FOREIGN KEY (id_pasajero) REFERENCES pasajero (id_persona);
ALTER TABLE ausencia ADD FOREIGN KEY (id_viaje) REFERENCES viaje (id_viaje);

-- Bloque 4
ALTER TABLE cuenta_corriente ADD FOREIGN KEY (id_cliente) REFERENCES cliente (id_cliente);
ALTER TABLE pago ADD FOREIGN KEY (id_cliente) REFERENCES cuenta_corriente (id_cliente);
ALTER TABLE movimiento_cuenta ADD FOREIGN KEY (id_cliente) REFERENCES cuenta_corriente (id_cliente);
ALTER TABLE movimiento_cuenta ADD FOREIGN KEY (id_pago, id_cliente) REFERENCES pago (id_pago, id_cliente);
ALTER TABLE movimiento_cuenta ADD FOREIGN KEY (id_contratacion, id_cliente) REFERENCES contratacion (id_contratacion, id_cliente);
ALTER TABLE comprobante ADD FOREIGN KEY (id_pago) REFERENCES pago (id_pago);
ALTER TABLE comprobante ADD FOREIGN KEY (id_contratacion) REFERENCES contratacion (id_contratacion);
ALTER TABLE comprobante ADD FOREIGN KEY (id_movimiento_cuenta) REFERENCES movimiento_cuenta (id_movimiento_cuenta);

-- Bloque 5
ALTER TABLE evento_operativo ADD FOREIGN KEY (id_reserva) REFERENCES reserva (id_reserva);
ALTER TABLE evento_operativo ADD FOREIGN KEY (id_pago)    REFERENCES pago (id_pago);
ALTER TABLE evento_operativo ADD FOREIGN KEY (id_viaje)   REFERENCES viaje (id_viaje);

-- =============================================================================
-- SEED mínimo: catálogo de roles de acceso (según CU/actores aprobados)
-- =============================================================================
INSERT INTO rol_acceso (rol) VALUES
    ('pasajero'),
    ('chofer'),
    ('administrador'),
    ('dueno'),
    ('representante_corporativo');
