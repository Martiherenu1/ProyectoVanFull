"""Confirmación y rechazo manual de pagos (CU-016) contra un PostgreSQL real."""

import asyncio

import pytest
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine
from sqlalchemy.pool import NullPool

from app.core.security import crear_token
from app.services.pagos import decidir_pago_pendiente
from tests._bd import base_migrada, cliente_api, consultar, ejecutar_sql, url_sqlalchemy

RUTA = "/api/pagos/{}/confirmacion"


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
        with cliente_api(base) as cliente:
            yield base, cliente, pagos


@pytest.fixture(autouse=True)
def _restaurar(entorno):
    base, _, _ = entorno
    asyncio.run(ejecutar_sql(base, "DELETE FROM evento_operativo"))
    asyncio.run(ejecutar_sql(base, "DELETE FROM comprobante"))
    asyncio.run(ejecutar_sql(base, "UPDATE pago SET estado = 'PENDIENTE'"))


def _estado(base: str, id_pago: int) -> str:
    return asyncio.run(consultar(base, "SELECT estado FROM pago WHERE id_pago = $1", id_pago))[0][0]


def test_administrador_confirma_pago_y_genera_recibo_y_evento(entorno):
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
            "SELECT tipo_evento, id_pago FROM evento_operativo WHERE id_pago = $1",
            id_pago,
        )
    ) == [("pago_confirmado", id_pago)]


def test_dueno_puede_rechazar_y_no_genera_recibo(entorno):
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
    """Una falla del comprobante revierte también el nuevo estado y no deja evento."""
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
