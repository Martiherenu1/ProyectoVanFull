"""Registro y decisión administrativa de pagos (CU-014 y CU-016) con PostgreSQL real."""

import asyncio

import pytest
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine
from sqlalchemy.pool import NullPool

from app.core.security import UsuarioActual, crear_token
from app.schemas.pagos import PagoCreate
from app.services import pagos as servicio_pagos
from app.services.pagos import decidir_pago_pendiente
from tests._bd import base_migrada, cliente_api, consultar, ejecutar_sql, url_sqlalchemy

RUTA_REGISTRO = "/api/pagos"
RUTA = "/api/pagos/{}/confirmacion"


@pytest.mark.parametrize("rol", ["administrador", "dueno"])
def test_lista_pendientes_sin_efectos_y_excluye_decididos(entorno, rol):
    base, cliente, pagos = entorno
    cliente.post(
        RUTA.format(pagos["principal"]), json={"decision": "CONFIRMADO"}, headers=_con_rol(rol)
    )
    cliente.post(RUTA.format(pagos["otro"]), json={"decision": "RECHAZADO"}, headers=_con_rol(rol))
    antes = asyncio.run(
        consultar(
            base,
            "SELECT (SELECT count(*) FROM comprobante), (SELECT count(*) FROM movimiento_cuenta), (SELECT count(*) FROM evento_operativo)",
        )
    )
    respuesta = cliente.get("/api/pagos/pendientes", headers=_con_rol(rol))
    assert respuesta.status_code == 200
    assert [p["id_pago"] for p in respuesta.json()] == [pagos["atomico"]]
    assert respuesta.json()[0]["estado"] == "PENDIENTE"
    assert respuesta.json()[0]["id_cliente"] == pagos["id_cliente"]
    assert (
        asyncio.run(
            consultar(
                base,
                "SELECT (SELECT count(*) FROM comprobante), (SELECT count(*) FROM movimiento_cuenta), (SELECT count(*) FROM evento_operativo)",
            )
        )
        == antes
    )


def test_lista_pendientes_vacia_y_orden_estable(entorno):
    base, cliente, pagos = entorno
    respuesta = cliente.get("/api/pagos/pendientes", headers=_con_rol("administrador"))
    assert [p["id_pago"] for p in respuesta.json()] == [
        pagos[n] for n in ("principal", "otro", "atomico")
    ]
    for nombre in ("principal", "otro", "atomico"):
        cliente.post(
            RUTA.format(pagos[nombre]),
            json={"decision": "RECHAZADO"},
            headers=_con_rol("administrador"),
        )
    assert cliente.get("/api/pagos/pendientes", headers=_con_rol("administrador")).json() == []


def test_listado_pendientes_exige_permiso(entorno):
    _, cliente, _ = entorno
    assert cliente.get("/api/pagos/pendientes").status_code == 401
    for rol in ("pasajero", "chofer"):
        assert cliente.get("/api/pagos/pendientes", headers=_con_rol(rol)).status_code == 403


def _con_rol(rol: str) -> dict[str, str]:
    token = crear_token(1, 1, [rol])
    return {"Authorization": f"Bearer {token}"}


@pytest.fixture(scope="module")
def entorno():
    with base_migrada() as base:
        id_cliente = asyncio.run(
            consultar(
                base,
                "INSERT INTO cliente (naturaleza_cliente) VALUES ('INDIVIDUAL') RETURNING id_cliente",
            )
        )[0][0]
        asyncio.run(
            ejecutar_sql(base, "INSERT INTO cuenta_corriente (id_cliente) VALUES ($1)", id_cliente)
        )
        pagos = {}
        for nombre, medio in (
            ("principal", "TRANSFERENCIA"),
            ("otro", "EFECTIVO"),
            ("atomico", "BILLETERA"),
        ):
            pagos[nombre] = asyncio.run(
                consultar(
                    base,
                    "INSERT INTO pago (id_cliente, importe, medio_pago) "
                    "VALUES ($1, 1250.50, $2) RETURNING id_pago",
                    id_cliente,
                    medio,
                )
            )[0][0]
        pagos["id_cliente"] = id_cliente
        with cliente_api(base) as cliente:
            yield base, cliente, pagos


@pytest.fixture(autouse=True)
def _restaurar(entorno):
    base, _, pagos = entorno
    asyncio.run(ejecutar_sql(base, "DELETE FROM evento_operativo"))
    asyncio.run(ejecutar_sql(base, "DELETE FROM movimiento_cuenta"))
    asyncio.run(ejecutar_sql(base, "DELETE FROM comprobante"))
    asyncio.run(
        ejecutar_sql(
            base,
            "DELETE FROM pago WHERE id_pago NOT IN ($1, $2, $3)",
            pagos["principal"],
            pagos["otro"],
            pagos["atomico"],
        )
    )
    asyncio.run(ejecutar_sql(base, "UPDATE pago SET estado = 'PENDIENTE'"))


def _estado(base: str, id_pago: int) -> str:
    return asyncio.run(consultar(base, "SELECT estado FROM pago WHERE id_pago = $1", id_pago))[0][0]


def _datos_registro(pagos: dict[str, int], **cambios) -> dict:
    datos = {
        "id_cliente": pagos["id_cliente"],
        "importe": 875.25,
        "medio_pago": "TRANSFERENCIA",
    }
    datos.update(cambios)
    return datos


def test_administrador_registra_pago_pendiente_sin_impacto_contable(entorno):
    base, cliente, pagos = entorno

    respuesta = cliente.post(
        RUTA_REGISTRO,
        json=_datos_registro(pagos),
        headers=_con_rol("administrador"),
    )

    assert respuesta.status_code == 201
    cuerpo = respuesta.json()
    assert cuerpo["id_cliente"] == pagos["id_cliente"]
    assert cuerpo["importe"] == 875.25
    assert cuerpo["medio_pago"] == "TRANSFERENCIA"
    assert cuerpo["estado"] == "PENDIENTE"
    assert cuerpo["fecha_hora"]
    assert asyncio.run(
        consultar(
            base, "SELECT tipo_evento FROM evento_operativo WHERE id_pago = $1", cuerpo["id_pago"]
        )
    ) == [("pago_registrado",)]
    assert asyncio.run(
        consultar(base, "SELECT count(*) FROM comprobante WHERE id_pago = $1", cuerpo["id_pago"])
    ) == [(0,)]
    assert asyncio.run(
        consultar(
            base,
            "SELECT count(*) FROM movimiento_cuenta WHERE id_pago = $1",
            cuerpo["id_pago"],
        )
    ) == [(0,)]


def test_dueno_puede_registrar_pago(entorno):
    _, cliente, pagos = entorno
    respuesta = cliente.post(
        RUTA_REGISTRO,
        json=_datos_registro(pagos, medio_pago="EFECTIVO"),
        headers=_con_rol("dueno"),
    )
    assert respuesta.status_code == 201
    assert respuesta.json()["estado"] == "PENDIENTE"


@pytest.mark.parametrize("rol", ["chofer", "representante_corporativo"])
def test_otros_roles_no_pueden_registrar_pago(entorno, rol):
    base, cliente, pagos = entorno
    antes = asyncio.run(consultar(base, "SELECT count(*) FROM pago"))[0][0]

    respuesta = cliente.post(
        RUTA_REGISTRO,
        json=_datos_registro(pagos),
        headers=_con_rol(rol),
    )

    assert respuesta.status_code == 403
    assert respuesta.json()["error"]["codigo"] == "SIN_PERMISO"
    assert asyncio.run(consultar(base, "SELECT count(*) FROM pago"))[0][0] == antes


def _crear_pasajero(base: str, dni: str, *, cliente: bool, cuenta: bool) -> dict:
    """Pasajero con o sin cliente individual y cuenta corriente, y su encabezado de autorización."""
    id_persona = asyncio.run(
        consultar(
            base,
            "INSERT INTO persona (nombre, apellido, dni) VALUES ('Prueba', 'Pago', $1) "
            "RETURNING id_persona",
            dni,
        )
    )[0][0]
    asyncio.run(ejecutar_sql(base, "INSERT INTO pasajero (id_persona) VALUES ($1)", id_persona))
    id_cliente = None
    if cliente:
        id_cliente = asyncio.run(
            consultar(
                base,
                "INSERT INTO cliente (naturaleza_cliente) VALUES ('INDIVIDUAL') RETURNING id_cliente",
            )
        )[0][0]
        asyncio.run(
            ejecutar_sql(
                base,
                "INSERT INTO cliente_individual (id_cliente, id_persona) VALUES ($1, $2)",
                id_cliente,
                id_persona,
            )
        )
    if cuenta:
        asyncio.run(
            ejecutar_sql(base, "INSERT INTO cuenta_corriente (id_cliente) VALUES ($1)", id_cliente)
        )
    token = crear_token(id_persona, id_persona, ["pasajero"])
    return {"id_cliente": id_cliente, "headers": {"Authorization": f"Bearer {token}"}}


@pytest.fixture(scope="module")
def pasajeros(entorno):
    base, _, _ = entorno
    return {
        "con_cuenta": _crear_pasajero(base, "90000001", cliente=True, cuenta=True),
        "sin_cuenta": _crear_pasajero(base, "90000002", cliente=True, cuenta=False),
        "sin_cliente": _crear_pasajero(base, "90000003", cliente=False, cuenta=False),
    }


def _cantidad_pagos(base: str) -> int:
    return asyncio.run(consultar(base, "SELECT count(*) FROM pago"))[0][0]


def test_pasajero_registra_pago_de_su_cuenta_sin_indicar_cliente(entorno, pasajeros):
    base, cliente, _ = entorno
    propio = pasajeros["con_cuenta"]

    respuesta = cliente.post(
        RUTA_REGISTRO,
        json={"importe": 5800, "medio_pago": "TRANSFERENCIA"},
        headers=propio["headers"],
    )

    assert respuesta.status_code == 201
    cuerpo = respuesta.json()
    assert cuerpo["id_cliente"] == propio["id_cliente"]
    assert cuerpo["estado"] == "PENDIENTE"
    assert asyncio.run(
        consultar(
            base, "SELECT tipo_evento FROM evento_operativo WHERE id_pago = $1", cuerpo["id_pago"]
        )
    ) == [("pago_registrado",)]


def test_pasajero_puede_indicar_su_propio_cliente(entorno, pasajeros):
    _, cliente, _ = entorno
    propio = pasajeros["con_cuenta"]
    respuesta = cliente.post(
        RUTA_REGISTRO,
        json={"id_cliente": propio["id_cliente"], "importe": 100, "medio_pago": "EFECTIVO"},
        headers=propio["headers"],
    )
    assert respuesta.status_code == 201
    assert respuesta.json()["id_cliente"] == propio["id_cliente"]


def test_pasajero_no_registra_pagos_de_otro_cliente(entorno, pasajeros):
    base, cliente, pagos = entorno
    antes = _cantidad_pagos(base)

    respuesta = cliente.post(
        RUTA_REGISTRO,
        json=_datos_registro(pagos),
        headers=pasajeros["con_cuenta"]["headers"],
    )

    assert respuesta.status_code == 403
    assert respuesta.json()["error"]["codigo"] == "SIN_PERMISO"
    assert _cantidad_pagos(base) == antes


@pytest.mark.parametrize(
    "caso, codigo",
    [("sin_cliente", "CLIENTE_NO_ENCONTRADO"), ("sin_cuenta", "CUENTA_CORRIENTE_NO_ENCONTRADA")],
)
def test_pasajero_sin_cuenta_corriente_es_404(entorno, pasajeros, caso, codigo):
    base, cliente, _ = entorno
    antes = _cantidad_pagos(base)

    respuesta = cliente.post(
        RUTA_REGISTRO,
        json={"importe": 100, "medio_pago": "EFECTIVO"},
        headers=pasajeros[caso]["headers"],
    )

    assert respuesta.status_code == 404
    assert respuesta.json()["error"]["codigo"] == codigo
    assert _cantidad_pagos(base) == antes


def test_administracion_sin_cliente_es_400(entorno):
    base, cliente, _ = entorno
    antes = _cantidad_pagos(base)

    respuesta = cliente.post(
        RUTA_REGISTRO,
        json={"importe": 100, "medio_pago": "EFECTIVO"},
        headers=_con_rol("administrador"),
    )

    assert respuesta.status_code == 400
    assert respuesta.json()["error"]["detalles"] == {"campos_faltantes": ["id_cliente"]}
    assert _cantidad_pagos(base) == antes


@pytest.mark.parametrize("rol", ["administrador", "dueno"])
@pytest.mark.parametrize(
    "caso, codigo",
    [("inexistente", "CLIENTE_NO_ENCONTRADO"), ("sin_cuenta", "CUENTA_CORRIENTE_NO_ENCONTRADA")],
)
def test_administracion_con_cliente_sin_cuenta_es_404(entorno, pasajeros, rol, caso, codigo):
    base, cliente, pagos = entorno
    antes = _cantidad_pagos(base)
    id_cliente = 2_000_000_000 if caso == "inexistente" else pasajeros["sin_cuenta"]["id_cliente"]

    respuesta = cliente.post(
        RUTA_REGISTRO,
        json=_datos_registro(pagos, id_cliente=id_cliente),
        headers=_con_rol(rol),
    )

    assert respuesta.status_code == 404
    assert respuesta.json()["error"]["codigo"] == codigo
    assert _cantidad_pagos(base) == antes
    assert asyncio.run(consultar(base, "SELECT count(*) FROM evento_operativo")) == [(0,)]


def test_registrar_pago_sin_token_es_401(entorno):
    _, cliente, pagos = entorno
    respuesta = cliente.post(RUTA_REGISTRO, json=_datos_registro(pagos))
    assert respuesta.status_code == 401
    assert respuesta.json()["error"]["codigo"] == "NO_AUTENTICADO"


@pytest.mark.parametrize(
    "cuerpo",
    [
        {},
        {"id_cliente": 1, "importe": -1, "medio_pago": "EFECTIVO"},
        {"id_cliente": 1, "importe": 100, "medio_pago": "CHEQUE"},
    ],
)
def test_datos_invalidos_no_registran_pago(entorno, cuerpo):
    base, cliente, _ = entorno
    antes = asyncio.run(consultar(base, "SELECT count(*) FROM pago"))[0][0]

    respuesta = cliente.post(RUTA_REGISTRO, json=cuerpo, headers=_con_rol("administrador"))

    assert respuesta.status_code == 400
    assert respuesta.json()["error"]["codigo"] == "VALIDACION"
    assert asyncio.run(consultar(base, "SELECT count(*) FROM pago"))[0][0] == antes


@pytest.mark.parametrize(
    "campo, valor",
    [("tipo", "parcial"), ("evidencia_pago", "https://ejemplo.test/comprobante")],
)
def test_campos_sin_persistencia_se_rechazan_explicitamente(entorno, campo, valor):
    base, cliente, pagos = entorno
    antes = asyncio.run(consultar(base, "SELECT count(*) FROM pago"))[0][0]

    respuesta = cliente.post(
        RUTA_REGISTRO,
        json=_datos_registro(pagos, **{campo: valor}),
        headers=_con_rol("administrador"),
    )

    assert respuesta.status_code == 400
    assert respuesta.json()["error"] == {
        "codigo": "VALIDACION",
        "mensaje": "Los campos enviados todavía no pueden conservarse con el modelo vigente.",
        "detalles": {"campos_pendientes": [campo]},
    }
    assert asyncio.run(consultar(base, "SELECT count(*) FROM pago"))[0][0] == antes


def test_registro_es_atomico_si_falla_el_evento(entorno, monkeypatch):
    base, _, pagos = entorno
    monkeypatch.setattr(servicio_pagos, "TIPO_PAGO_REGISTRADO", "x" * 51)

    async def operacion():
        motor = create_async_engine(url_sqlalchemy(base), poolclass=NullPool)
        try:
            async with async_sessionmaker(motor, expire_on_commit=False)() as db:
                with pytest.raises(ValueError):
                    await servicio_pagos.registrar_pago(
                        db,
                        UsuarioActual(1, 1, ("administrador",)),
                        PagoCreate(**_datos_registro(pagos, importe=321.45)),
                    )
        finally:
            await motor.dispose()

    asyncio.run(operacion())
    assert asyncio.run(consultar(base, "SELECT count(*) FROM pago WHERE importe = 321.45")) == [
        (0,)
    ]


def test_pago_registrado_puede_confirmarse_mediante_cu016(entorno):
    base, cliente, pagos = entorno
    registrado = cliente.post(
        RUTA_REGISTRO,
        json=_datos_registro(pagos, importe=640.50),
        headers=_con_rol("administrador"),
    ).json()

    respuesta = cliente.post(
        RUTA.format(registrado["id_pago"]),
        json={"decision": "CONFIRMADO"},
        headers=_con_rol("administrador"),
    )

    assert respuesta.status_code == 200
    assert respuesta.json()["estado"] == "CONFIRMADO"
    assert asyncio.run(
        consultar(
            base,
            "SELECT naturaleza, importe FROM movimiento_cuenta WHERE id_pago = $1",
            registrado["id_pago"],
        )
    ) == [("ACREEDOR", 640.50)]
    assert asyncio.run(
        consultar(base, "SELECT tipo FROM comprobante WHERE id_pago = $1", registrado["id_pago"])
    ) == [("RECIBO",)]
    assert asyncio.run(
        consultar(
            base,
            "SELECT tipo_evento FROM evento_operativo WHERE id_pago = $1 ORDER BY id_evento_operativo",
            registrado["id_pago"],
        )
    ) == [("pago_registrado",), ("pago_confirmado",)]


def test_administrador_confirma_pago_y_genera_movimiento_recibo_y_evento(entorno):
    base, cliente, pagos = entorno
    id_pago = pagos["principal"]

    respuesta = cliente.post(
        RUTA.format(id_pago),
        json={"decision": "CONFIRMADO"},
        headers=_con_rol("administrador"),
    )

    assert respuesta.status_code == 200
    cuerpo = respuesta.json()
    assert set(cuerpo) == {
        "id_pago",
        "id_cliente",
        "importe",
        "medio_pago",
        "estado",
        "fecha_hora",
    }
    assert cuerpo["id_pago"] == id_pago
    assert cuerpo["id_cliente"] > 0
    assert cuerpo["importe"] == 1250.5
    assert cuerpo["medio_pago"] == "TRANSFERENCIA"
    assert cuerpo["estado"] == "CONFIRMADO"
    assert cuerpo["fecha_hora"]
    assert asyncio.run(
        consultar(base, "SELECT tipo, id_pago FROM comprobante WHERE id_pago = $1", id_pago)
    ) == [("RECIBO", id_pago)]
    assert asyncio.run(
        consultar(
            base,
            "SELECT naturaleza, id_cliente, id_pago, importe "
            "FROM movimiento_cuenta WHERE id_pago = $1",
            id_pago,
        )
    ) == [("ACREEDOR", cuerpo["id_cliente"], id_pago, 1250.50)]
    assert asyncio.run(
        consultar(
            base,
            "SELECT tipo_evento, id_pago FROM evento_operativo WHERE id_pago = $1",
            id_pago,
        )
    ) == [("pago_confirmado", id_pago)]


def test_dueno_puede_rechazar_y_no_genera_movimiento_ni_recibo(entorno):
    base, cliente, pagos = entorno
    id_pago = pagos["principal"]

    respuesta = cliente.post(
        RUTA.format(id_pago),
        json={"decision": "RECHAZADO"},
        headers=_con_rol("dueno"),
    )

    assert respuesta.status_code == 200
    assert respuesta.json()["estado"] == "RECHAZADO"
    assert asyncio.run(
        consultar(base, "SELECT count(*) FROM comprobante WHERE id_pago = $1", id_pago)
    ) == [(0,)]
    assert asyncio.run(
        consultar(base, "SELECT count(*) FROM movimiento_cuenta WHERE id_pago = $1", id_pago)
    ) == [(0,)]
    assert asyncio.run(
        consultar(
            base,
            "SELECT tipo_evento FROM evento_operativo WHERE id_pago = $1",
            id_pago,
        )
    ) == [("pago_rechazado",)]


@pytest.mark.parametrize("rol", ["pasajero", "chofer", "representante_corporativo"])
def test_otros_roles_no_pueden_decidir_y_no_modifican_el_pago(entorno, rol):
    base, cliente, pagos = entorno
    id_pago = pagos["principal"]

    respuesta = cliente.post(
        RUTA.format(id_pago), json={"decision": "CONFIRMADO"}, headers=_con_rol(rol)
    )

    assert respuesta.status_code == 403
    assert respuesta.json()["error"]["codigo"] == "SIN_PERMISO"
    assert _estado(base, id_pago) == "PENDIENTE"


def test_sin_token_es_401(entorno):
    _, cliente, pagos = entorno
    respuesta = cliente.post(RUTA.format(pagos["principal"]), json={"decision": "CONFIRMADO"})
    assert respuesta.status_code == 401
    assert respuesta.json()["error"]["codigo"] == "NO_AUTENTICADO"


def test_pago_inexistente_es_404(entorno):
    _, cliente, _ = entorno
    respuesta = cliente.post(
        RUTA.format(999_999),
        json={"decision": "CONFIRMADO"},
        headers=_con_rol("administrador"),
    )
    assert respuesta.status_code == 404
    assert respuesta.json()["error"]["codigo"] == "PAGO_PENDIENTE_NO_ENCONTRADO"


@pytest.mark.parametrize("estado", ["CONFIRMADO", "RECHAZADO"])
def test_un_pago_ya_decidido_no_se_vuelve_a_modificar(entorno, estado):
    base, cliente, pagos = entorno
    id_pago = pagos["principal"]
    asyncio.run(
        ejecutar_sql(base, "UPDATE pago SET estado = $1 WHERE id_pago = $2", estado, id_pago)
    )

    respuesta = cliente.post(
        RUTA.format(id_pago),
        json={"decision": "CONFIRMADO" if estado == "RECHAZADO" else "RECHAZADO"},
        headers=_con_rol("administrador"),
    )

    assert respuesta.status_code == 404
    assert _estado(base, id_pago) == estado
    assert asyncio.run(
        consultar(base, "SELECT count(*) FROM evento_operativo WHERE id_pago = $1", id_pago)
    ) == [(0,)]


@pytest.mark.parametrize("cuerpo", [{}, {"decision": "APROBADO"}, {"decision": None}])
def test_decision_invalida_es_400_y_no_modifica_nada(entorno, cuerpo):
    base, cliente, pagos = entorno
    id_pago = pagos["principal"]

    respuesta = cliente.post(RUTA.format(id_pago), json=cuerpo, headers=_con_rol("administrador"))

    assert respuesta.status_code == 400
    assert respuesta.json()["error"]["codigo"] == "VALIDACION"
    assert _estado(base, id_pago) == "PENDIENTE"


def test_confirmacion_es_atomica_si_falla_el_recibo(entorno):
    """Una falla del comprobante revierte estado, movimiento y evento."""
    base, _, pagos = entorno
    id_pago = pagos["atomico"]
    asyncio.run(
        ejecutar_sql(
            base,
            "INSERT INTO comprobante (tipo, id_pago) VALUES ('RECIBO', $1)",
            id_pago,
        )
    )

    async def operacion():
        motor = create_async_engine(url_sqlalchemy(base), poolclass=NullPool)
        try:
            async with async_sessionmaker(motor, expire_on_commit=False)() as db:
                with pytest.raises(IntegrityError):
                    await decidir_pago_pendiente(db, id_pago, "CONFIRMADO")
        finally:
            await motor.dispose()

    asyncio.run(operacion())
    assert _estado(base, id_pago) == "PENDIENTE"
    assert asyncio.run(
        consultar(base, "SELECT count(*) FROM evento_operativo WHERE id_pago = $1", id_pago)
    ) == [(0,)]
    assert asyncio.run(
        consultar(base, "SELECT count(*) FROM movimiento_cuenta WHERE id_pago = $1", id_pago)
    ) == [(0,)]
