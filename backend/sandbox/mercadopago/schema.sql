-- D1 candidato optativo. Requiere esquema base ya existente y DB local dedicada.
-- NO forma parte de backend/db/schema.sql ni del arranque de Render.
CREATE TABLE pago_mercadopago (
    id_operacion VARCHAR(64) PRIMARY KEY,
    id_pago BIGINT NOT NULL UNIQUE REFERENCES pago(id_pago) ON DELETE RESTRICT,
    id_receptor BIGINT NOT NULL,
    moneda VARCHAR(3) NOT NULL,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT ck_mp_operacion CHECK (id_operacion ~ '^[0-9]{1,64}$'),
    CONSTRAINT ck_mp_receptor CHECK (id_receptor > 0),
    CONSTRAINT ck_mp_moneda CHECK (moneda ~ '^[A-Z]{3}$')
);

-- Candidato Checkout. No representa un nuevo estado contable de Pago.
CREATE TABLE checkout_mercadopago (
    id_intento VARCHAR(36) PRIMARY KEY,
    id_cliente BIGINT NOT NULL,
    clave_solicitud VARCHAR(36) NOT NULL,
    id_pago BIGINT NOT NULL UNIQUE,
    id_preferencia VARCHAR(160) UNIQUE,
    url_checkout TEXT,
    estado_tecnico VARCHAR(12) NOT NULL DEFAULT 'CREANDO',
    creado_en TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (id_cliente, clave_solicitud),
    FOREIGN KEY (id_pago, id_cliente) REFERENCES pago(id_pago, id_cliente) ON DELETE RESTRICT,
    CONSTRAINT ck_checkout_estado CHECK (estado_tecnico IN ('CREANDO','LISTO','INCIERTO'))
);
