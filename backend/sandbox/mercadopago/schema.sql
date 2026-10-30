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
