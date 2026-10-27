"""Creación de viajes por administración (CU-018) contra PostgreSQL real."""

import asyncio
from datetime import date, time
from pathlib import Path

import pytest
import yaml
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine
from sqlalchemy.pool import NullPool

from app.core.errors import ApiError
from app.core.security import UsuarioActual, crear_token
from app.schemas.viajes import ViajeCreate, ViajeUpdate
from app.services import ejecucion_viajes as servicio_ejecucion
from app.services import viajes as servicio_viajes
from app.services.ejecucion_viajes import TIPO_VIAJE_INICIADO, iniciar_viaje
from app.services.viajes import (
    TIPO_VIAJE_ACTUALIZADO,
    TIPO_VIAJE_CREADO,
    actualizar_viaje,
    crear_viaje,
)
from tests._bd import base_migrada, cliente_api, consultar, ejecutar_sql, url_sqlalchemy

RUTA = "/api/viajes"
CONTRATO = Path(__file__).resolve().parents[1] / "openapi" / "openapi.yaml"


def _uno(base: str, sql: str, *args):
    return asyncio.run(consultar(base, sql, *args))[0][0]


def _con(roles: list[str]) -> dict[str, str]:
    return {"Authorization": f"Bearer {crear_token(1, 1, roles)}"}


def _en_sesion(base: str, funcion):
    async def _correr():
        motor = create_async_engine(url_sqlalchemy(base), poolclass=NullPool)
        try:
            async with async_sessionmaker(motor, expire_on_commit=False)() as db:
                return await funcion(db)
        finally:
            await motor.dispose()

    return asyncio.run(_correr())


@pytest.fixture(scope="module")
def entorno():
    with base_migrada() as base:
        id_servicio = _uno(
            base,
            "INSERT INTO servicio (tipo_servicio) VALUES ('UNIVERSITARIO') RETURNING id_servicio",
        )
        id_recorrido = _uno(base, "INSERT INTO recorrido DEFAULT VALUES RETURNING id_recorrido")
        id_parada = _uno(
            base,
            "INSERT INTO parada (nombre_descripcion) VALUES ('Parada CU018') RETURNING id_parada",
        )
        asyncio.run(
            ejecutar_sql(
                base,
                "INSERT INTO parada_recorrido (id_recorrido, orden, id_parada) VALUES ($1, 1, $2)",
                id_recorrido,
                id_parada,
            )
        )
        id_vehiculo = _uno(
            base,
            "INSERT INTO vehiculo (patente, capacidad) VALUES ('VF018AA', 20) "
            "RETURNING id_vehiculo",
        )
        id_vehiculo_chico = _uno(
            base,
            "INSERT INTO vehiculo (patente, capacidad) VALUES ('VF018BB', 1) RETURNING id_vehiculo",
        )
        id_chofer = _uno(
            base,
            "INSERT INTO persona (nombre, apellido, dni) "
            "VALUES ('Chofer', 'Prueba', 'CU018') RETURNING id_persona",
        )
        asyncio.run(
            ejecutar_sql(
                base,
                "INSERT INTO chofer (id_persona, registro_conducir) VALUES ($1, 'REG-CU018')",
                id_chofer,
            )
        )
        id_cliente = _uno(
            base,
            "INSERT INTO cliente (naturaleza_cliente) VALUES ('INDIVIDUAL') RETURNING id_cliente",
        )
        id_contratacion = _uno(
            base,
            "INSERT INTO contratacion (id_cliente, id_servicio) VALUES ($1, $2) "
            "RETURNING id_contratacion",
            id_cliente,
            id_servicio,
        )
        pasajeros = []
        for numero in (1, 2):
            id_pasajero = _uno(
                base,
                "INSERT INTO persona (nombre, apellido, dni) "
                "VALUES ('Pasajero', 'CU018', $1) RETURNING id_persona",
                f"CU018-P{numero}",
            )
            asyncio.run(
                ejecutar_sql(base, "INSERT INTO pasajero (id_persona) VALUES ($1)", id_pasajero)
            )
            pasajeros.append(id_pasajero)
        with cliente_api(base) as http:
            yield {
                "base": base,
                "http": http,
                "id_servicio": id_servicio,
                "id_recorrido": id_recorrido,
                "id_vehiculo": id_vehiculo,
                "id_vehiculo_chico": id_vehiculo_chico,
                "id_chofer": id_chofer,
                "id_contratacion": id_contratacion,
                "pasajeros": pasajeros,
            }


@pytest.fixture(autouse=True)
def _sin_viajes(entorno):
    asyncio.run(
        ejecutar_sql(
            entorno["base"],
            "DELETE FROM reserva; DELETE FROM evento_operativo; DELETE FROM viaje",
        )
    )


def _datos_validos(entorno) -> dict:
    return {
        "id_servicio": entorno["id_servicio"],
        "id_recorrido": entorno["id_recorrido"],
        "fecha": "2026-10-30",
        "sentido": "IDA",
    }


def _viaje_para_listado(
    entorno,
    *,
    fecha="2026-10-30",
    horario="07:30",
    estado="programado",
    asignado=False,
) -> int:
    return _uno(
        entorno["base"],
        "INSERT INTO viaje (id_servicio, id_recorrido, id_vehiculo, id_chofer, fecha, "
        "horario, sentido, estado) VALUES ($1, $2, $3, $4, $5::text::date, $6::text::time, "
        "'IDA', $7) RETURNING id_viaje",
        entorno["id_servicio"],
        entorno["id_recorrido"],
        entorno["id_vehiculo"] if asignado else None,
        entorno["id_chofer"] if asignado else None,
        fecha,
        horario,
        estado,
    )


def _agregar_reservas_consolidadas(entorno, id_viaje: int, cantidad: int) -> None:
    for id_pasajero in entorno["pasajeros"][:cantidad]:
        asyncio.run(
            ejecutar_sql(
                entorno["base"],
                "INSERT INTO reserva (id_pasajero, id_viaje, id_recorrido, orden_parada, "
                "id_contratacion_directa, estado) VALUES ($1, $2, $3, 1, $4, 'consolidada')",
                id_pasajero,
                id_viaje,
                entorno["id_recorrido"],
                entorno["id_contratacion"],
            )
        )


def test_administrador_lista_todos_los_estados_en_orden(entorno):
    sin_horario = _viaje_para_listado(entorno, horario=None, estado="cancelado")
    tarde = _viaje_para_listado(entorno, horario="18:00", estado="finalizado")
    temprano_1 = _viaje_para_listado(entorno, estado="programado", asignado=True)
    temprano_2 = _viaje_para_listado(entorno, estado="en_curso")
    _viaje_para_listado(entorno, fecha="2026-10-31")

    respuesta = entorno["http"].get(f"{RUTA}?fecha=2026-10-30", headers=_con(["administrador"]))

    assert respuesta.status_code == 200
    filas = respuesta.json()
    assert [fila["id_viaje"] for fila in filas] == [temprano_1, temprano_2, tarde, sin_horario]
    assert {fila["estado"] for fila in filas} == {
        "programado",
        "en_curso",
        "finalizado",
        "cancelado",
    }
    assert filas[0]["id_vehiculo"] == entorno["id_vehiculo"]
    assert filas[0]["id_chofer"] == entorno["id_chofer"]
    assert "id_vehiculo" not in filas[1]
    assert "id_chofer" not in filas[1]
    assert "horario" not in filas[-1]


def test_dueno_recibe_lista_vacia_si_no_hay_viajes(entorno):
    respuesta = entorno["http"].get(f"{RUTA}?fecha=2026-10-30", headers=_con(["dueno"]))

    assert respuesta.status_code == 200
    assert respuesta.json() == []


@pytest.mark.parametrize(
    "consulta",
    [
        "",
        "?fecha=",
        "?fecha=2026-02-30",
        "?fecha=30-10-2026",
        "?fecha=2026-10-30T00:00:00",
    ],
)
def test_fecha_obligatoria_y_valida_para_listar(entorno, consulta):
    respuesta = entorno["http"].get(f"{RUTA}{consulta}", headers=_con(["administrador"]))

    assert respuesta.status_code == 400
    assert respuesta.json()["error"]["codigo"] == "VALIDACION"


@pytest.mark.parametrize(
    ("headers", "estado", "codigo"),
    [({}, 401, "NO_AUTENTICADO"), (_con(["pasajero"]), 403, "SIN_PERMISO")],
)
def test_solo_administrador_o_dueno_pueden_listar(entorno, headers, estado, codigo):
    respuesta = entorno["http"].get(f"{RUTA}?fecha=2026-10-30", headers=headers)

    assert respuesta.status_code == estado
    assert respuesta.json()["error"]["codigo"] == codigo


def test_el_servicio_crea_el_viaje_programado_y_su_evento(entorno):
    async def operacion(db):
        return await crear_viaje(
            db,
            ViajeCreate(
                id_servicio=entorno["id_servicio"],
                id_recorrido=entorno["id_recorrido"],
                fecha=date(2026, 10, 30),
                horario=time(7, 30),
                sentido="IDA",
                capacidad_planificada=18,
            ),
        )

    creado = _en_sesion(entorno["base"], operacion)
    fila = asyncio.run(
        consultar(
            entorno["base"],
            "SELECT estado, capacidad_planificada FROM viaje WHERE id_viaje = $1",
            creado.id_viaje,
        )
    )[0]
    evento = asyncio.run(
        consultar(
            entorno["base"],
            "SELECT tipo_evento, id_viaje FROM evento_operativo WHERE id_viaje = $1",
            creado.id_viaje,
        )
    )
    assert fila == ("programado", 18)
    assert evento == [(TIPO_VIAJE_CREADO, creado.id_viaje)]


def test_administrador_crea_un_viaje_con_vehiculo_y_chofer(entorno):
    datos = {
        **_datos_validos(entorno),
        "id_vehiculo": entorno["id_vehiculo"],
        "id_chofer": entorno["id_chofer"],
        "horario": "07:30",
        "capacidad_planificada": 18,
    }
    respuesta = entorno["http"].post(RUTA, json=datos, headers=_con(["administrador"]))

    assert respuesta.status_code == 201
    cuerpo = respuesta.json()
    assert cuerpo == {
        "id_viaje": cuerpo["id_viaje"],
        "id_servicio": entorno["id_servicio"],
        "id_recorrido": entorno["id_recorrido"],
        "id_vehiculo": entorno["id_vehiculo"],
        "id_chofer": entorno["id_chofer"],
        "fecha": "2026-10-30",
        "horario": "07:30",
        "sentido": "IDA",
        "estado": "programado",
        "capacidad_planificada": 18,
    }


def test_dueno_puede_crearlo_con_asignaciones_pendientes(entorno):
    respuesta = entorno["http"].post(RUTA, json=_datos_validos(entorno), headers=_con(["dueno"]))

    assert respuesta.status_code == 201
    cuerpo = respuesta.json()
    assert cuerpo["estado"] == "programado"
    assert "id_vehiculo" not in cuerpo
    assert "id_chofer" not in cuerpo
    assert "horario" not in cuerpo
    assert asyncio.run(
        consultar(
            entorno["base"],
            "SELECT id_vehiculo, id_chofer, horario FROM viaje WHERE id_viaje = $1",
            cuerpo["id_viaje"],
        )
    ) == [(None, None, None)]


@pytest.mark.parametrize(
    ("headers", "estado"),
    [({}, 401), (_con(["pasajero"]), 403)],
)
def test_solo_administrador_o_dueno_pueden_crear(entorno, headers, estado):
    respuesta = entorno["http"].post(RUTA, json=_datos_validos(entorno), headers=headers)
    assert respuesta.status_code == estado
    assert asyncio.run(consultar(entorno["base"], "SELECT count(*) FROM viaje")) == [(0,)]
    assert asyncio.run(consultar(entorno["base"], "SELECT count(*) FROM evento_operativo")) == [
        (0,)
    ]


def test_una_referencia_inexistente_responde_404_sin_escribir(entorno):
    datos = {**_datos_validos(entorno), "id_servicio": 999_999}
    respuesta = entorno["http"].post(RUTA, json=datos, headers=_con(["administrador"]))

    assert respuesta.status_code == 404
    assert respuesta.json()["error"]["codigo"] == "SERVICIO_NO_ENCONTRADO"
    assert asyncio.run(consultar(entorno["base"], "SELECT count(*) FROM viaje")) == [(0,)]
    assert asyncio.run(consultar(entorno["base"], "SELECT count(*) FROM evento_operativo")) == [
        (0,)
    ]


def test_capacidad_planificada_negativa_es_400(entorno):
    datos = {**_datos_validos(entorno), "capacidad_planificada": -1}
    respuesta = entorno["http"].post(RUTA, json=datos, headers=_con(["administrador"]))
    assert respuesta.status_code == 400
    assert respuesta.json()["error"]["codigo"] == "VALIDACION"


def test_la_respuesta_no_agrega_campos_fuera_del_contrato(entorno):
    declarados = set(
        yaml.safe_load(CONTRATO.read_text(encoding="utf-8"))["components"]["schemas"]["Viaje"][
            "properties"
        ]
    )
    respuesta = entorno["http"].post(
        RUTA, json=_datos_validos(entorno), headers=_con(["administrador"])
    )
    assert respuesta.status_code == 201
    assert set(respuesta.json()) <= declarados


def test_administrador_actualiza_los_campos_permitidos_y_registra_evento(entorno):
    id_viaje = _viaje_para_listado(entorno)
    respuesta = entorno["http"].patch(
        f"{RUTA}/{id_viaje}",
        json={
            "id_vehiculo": entorno["id_vehiculo"],
            "id_chofer": entorno["id_chofer"],
            "fecha": "2026-10-31",
            "horario": "08:45",
            "sentido": "VUELTA",
            "capacidad_planificada": 18,
        },
        headers=_con(["administrador"]),
    )

    assert respuesta.status_code == 200
    assert respuesta.json() == {
        "id_viaje": id_viaje,
        "id_servicio": entorno["id_servicio"],
        "id_recorrido": entorno["id_recorrido"],
        "id_vehiculo": entorno["id_vehiculo"],
        "id_chofer": entorno["id_chofer"],
        "fecha": "2026-10-31",
        "horario": "08:45",
        "sentido": "VUELTA",
        "estado": "programado",
        "capacidad_planificada": 18,
    }
    assert asyncio.run(
        consultar(
            entorno["base"],
            "SELECT tipo_evento FROM evento_operativo WHERE id_viaje = $1",
            id_viaje,
        )
    ) == [(TIPO_VIAJE_ACTUALIZADO,)]


def test_dueno_puede_dejar_asignaciones_y_opcionales_pendientes(entorno):
    id_viaje = _viaje_para_listado(entorno, asignado=True)
    respuesta = entorno["http"].patch(
        f"{RUTA}/{id_viaje}",
        json={
            "id_vehiculo": None,
            "id_chofer": None,
            "horario": None,
            "capacidad_planificada": None,
        },
        headers=_con(["dueno"]),
    )

    assert respuesta.status_code == 200
    assert "id_vehiculo" not in respuesta.json()
    assert "id_chofer" not in respuesta.json()
    assert "horario" not in respuesta.json()
    assert "capacidad_planificada" not in respuesta.json()
    assert asyncio.run(
        consultar(
            entorno["base"],
            "SELECT id_vehiculo, id_chofer, horario, capacidad_planificada "
            "FROM viaje WHERE id_viaje = $1",
            id_viaje,
        )
    ) == [(None, None, None, None)]


@pytest.mark.parametrize("estado_viaje", ["en_curso", "finalizado", "cancelado"])
def test_no_actualiza_viajes_que_no_estan_programados(entorno, estado_viaje):
    id_viaje = _viaje_para_listado(entorno, estado=estado_viaje)
    respuesta = entorno["http"].patch(
        f"{RUTA}/{id_viaje}",
        json={"fecha": "2026-10-31"},
        headers=_con(["administrador"]),
    )

    assert respuesta.status_code == 409
    assert respuesta.json()["error"]["codigo"] == "ESTADO_VIAJE_INVALIDO"
    assert asyncio.run(
        consultar(entorno["base"], "SELECT fecha FROM viaje WHERE id_viaje = $1", id_viaje)
    ) == [(date(2026, 10, 30),)]
    assert asyncio.run(consultar(entorno["base"], "SELECT count(*) FROM evento_operativo")) == [
        (0,)
    ]


@pytest.mark.parametrize(
    ("headers", "estado", "codigo"),
    [({}, 401, "NO_AUTENTICADO"), (_con(["pasajero"]), 403, "SIN_PERMISO")],
)
def test_solo_administrador_o_dueno_pueden_actualizar(entorno, headers, estado, codigo):
    id_viaje = _viaje_para_listado(entorno)
    respuesta = entorno["http"].patch(
        f"{RUTA}/{id_viaje}", json={"fecha": "2026-10-31"}, headers=headers
    )

    assert respuesta.status_code == estado
    assert respuesta.json()["error"]["codigo"] == codigo
    assert asyncio.run(
        consultar(entorno["base"], "SELECT fecha FROM viaje WHERE id_viaje = $1", id_viaje)
    ) == [(date(2026, 10, 30),)]


def test_actualizar_viaje_inexistente_responde_404(entorno):
    respuesta = entorno["http"].patch(
        f"{RUTA}/999999",
        json={"fecha": "2026-10-31"},
        headers=_con(["administrador"]),
    )
    assert respuesta.status_code == 404
    assert respuesta.json()["error"]["codigo"] == "VIAJE_NO_ENCONTRADO"


@pytest.mark.parametrize(
    ("campo", "codigo"),
    [("id_vehiculo", "VEHICULO_NO_ENCONTRADO"), ("id_chofer", "CHOFER_NO_ENCONTRADO")],
)
def test_referencia_inexistente_no_modifica_el_viaje(entorno, campo, codigo):
    id_viaje = _viaje_para_listado(entorno)
    respuesta = entorno["http"].patch(
        f"{RUTA}/{id_viaje}",
        json={campo: 999999},
        headers=_con(["administrador"]),
    )

    assert respuesta.status_code == 404
    assert respuesta.json()["error"]["codigo"] == codigo
    assert asyncio.run(
        consultar(
            entorno["base"],
            "SELECT id_vehiculo, id_chofer FROM viaje WHERE id_viaje = $1",
            id_viaje,
        )
    ) == [(None, None)]


@pytest.mark.parametrize("campo", ["id_servicio", "id_recorrido"])
def test_servicio_y_recorrido_no_forman_parte_del_update(entorno, campo):
    id_viaje = _viaje_para_listado(entorno)
    respuesta = entorno["http"].patch(
        f"{RUTA}/{id_viaje}",
        json={campo: 999999},
        headers=_con(["administrador"]),
    )
    assert respuesta.status_code == 400
    assert respuesta.json()["error"]["codigo"] == "VALIDACION"


@pytest.mark.parametrize("datos", [{}, {"fecha": None}, {"sentido": None}])
def test_update_requiere_un_campo_y_no_acepta_requeridos_nulos(entorno, datos):
    id_viaje = _viaje_para_listado(entorno)
    respuesta = entorno["http"].patch(
        f"{RUTA}/{id_viaje}", json=datos, headers=_con(["administrador"])
    )
    assert respuesta.status_code == 400
    assert respuesta.json()["error"]["codigo"] == "VALIDACION"


@pytest.mark.parametrize("datos", [{"capacidad_planificada": 1}, {"id_vehiculo": "chico"}])
def test_no_reduce_capacidad_por_debajo_de_reservas_existentes(entorno, datos):
    id_viaje = _viaje_para_listado(entorno)
    _agregar_reservas_consolidadas(entorno, id_viaje, 2)
    if datos.get("id_vehiculo") == "chico":
        datos = {"id_vehiculo": entorno["id_vehiculo_chico"]}

    respuesta = entorno["http"].patch(
        f"{RUTA}/{id_viaje}", json=datos, headers=_con(["administrador"])
    )

    assert respuesta.status_code == 409
    assert respuesta.json()["error"] == {
        "codigo": "CAPACIDAD_INSUFICIENTE",
        "mensaje": "La capacidad no alcanza para las reservas existentes.",
        "detalles": {"ocupados": 2, "capacidad": 1},
    }
    assert asyncio.run(
        consultar(
            entorno["base"],
            "SELECT id_vehiculo, capacidad_planificada FROM viaje WHERE id_viaje = $1",
            id_viaje,
        )
    ) == [(None, None)]


def test_actualizacion_es_atomica_si_falla_el_evento(entorno, monkeypatch):
    id_viaje = _viaje_para_listado(entorno)

    async def fallar_evento(*_args, **_kwargs):
        raise RuntimeError("fallo simulado")

    monkeypatch.setattr(servicio_viajes, "registrar_evento", fallar_evento)

    async def operacion(db):
        await actualizar_viaje(
            db,
            id_viaje,
            ViajeUpdate(fecha=date(2026, 10, 31)),
        )

    with pytest.raises(RuntimeError, match="fallo simulado"):
        _en_sesion(entorno["base"], operacion)

    assert asyncio.run(
        consultar(entorno["base"], "SELECT fecha FROM viaje WHERE id_viaje = $1", id_viaje)
    ) == [(date(2026, 10, 30),)]
    assert asyncio.run(consultar(entorno["base"], "SELECT count(*) FROM evento_operativo")) == [
        (0,)
    ]


def test_inicio_concurrente_impide_actualizar_el_viaje(entorno, monkeypatch):
    id_viaje = _viaje_para_listado(entorno, asignado=True)
    inicio_bloqueado = asyncio.Event()
    continuar_inicio = asyncio.Event()
    original = servicio_ejecucion.registrar_evento

    async def pausar_inicio(db, **datos):
        await original(db, **datos)
        inicio_bloqueado.set()
        await continuar_inicio.wait()

    monkeypatch.setattr(servicio_ejecucion, "registrar_evento", pausar_inicio)

    async def ejecutar_carrera():
        motor = create_async_engine(url_sqlalchemy(entorno["base"]), poolclass=NullPool)
        try:
            fabrica = async_sessionmaker(motor, expire_on_commit=False)
            async with fabrica() as db_inicio, fabrica() as db_update:
                usuario = UsuarioActual(
                    id_cuenta_acceso=1,
                    id_persona=entorno["id_chofer"],
                    roles=("chofer",),
                )
                tarea_inicio = asyncio.create_task(iniciar_viaje(db_inicio, usuario, id_viaje))
                await inicio_bloqueado.wait()
                tarea_update = asyncio.create_task(
                    actualizar_viaje(
                        db_update,
                        id_viaje,
                        ViajeUpdate(fecha=date(2026, 10, 31)),
                    )
                )
                await asyncio.sleep(0)
                continuar_inicio.set()
                iniciado = await tarea_inicio
                with pytest.raises(ApiError) as error:
                    await tarea_update
                return iniciado, error.value
        finally:
            await motor.dispose()

    iniciado, error = asyncio.run(ejecutar_carrera())
    assert iniciado.estado == "en_curso"
    assert error.codigo == "ESTADO_VIAJE_INVALIDO"
    assert asyncio.run(
        consultar(
            entorno["base"],
            "SELECT estado, fecha FROM viaje WHERE id_viaje = $1",
            id_viaje,
        )
    ) == [("en_curso", date(2026, 10, 30))]
    assert asyncio.run(
        consultar(
            entorno["base"],
            "SELECT tipo_evento FROM evento_operativo WHERE id_viaje = $1",
            id_viaje,
        )
    ) == [(TIPO_VIAJE_INICIADO,)]
