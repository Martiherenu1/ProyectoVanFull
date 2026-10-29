"""CU-009 parcial: autorización del pasajero contra PostgreSQL aislado."""

import asyncio

import pytest
from sqlalchemy import event
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine
from sqlalchemy.pool import NullPool

from app.core.errors import ApiError
from app.core.security import UsuarioActual
from app.services import ejecucion_viajes, gps, reservas
from tests._bd import url_sqlalchemy
from tests.test_ausencias import _caso, _persona, _sql, _token
from tests.test_ausencias import entorno as entorno


def _get(e, persona, viaje, roles=("pasajero",)):
    return e["http"].get(f"/api/viajes/{viaje}/ubicacion", headers=_token(persona, roles))


def _posicion(e, viaje):
    _sql(
        e,
        "INSERT INTO posicion_gps VALUES ($1, 1, 2, now())",
        viaje,
    )


def _error(r, estado, codigo):
    assert r.status_code == estado
    assert set(r.json()) == {"error"}
    assert r.json()["error"]["codigo"] == codigo
    assert set(r.json()["error"]).issubset({"codigo", "mensaje", "detalles"})
    assert "latitud" not in r.text and "longitud" not in r.text


@pytest.mark.parametrize("reserva", ["sin_reserva", "ajena", "provisional", "cancelada"])
@pytest.mark.parametrize(
    "estado", ["en_curso", "programado", "finalizado", "cancelado", "inexistente"]
)
def test_sin_consolidada_propia_no_revela_viaje(entorno, reserva, estado):
    e = entorno
    persona, viaje, id_reserva = _caso(
        e,
        estado=reserva if reserva in ("provisional", "cancelada") else "consolidada",
        viaje_estado="en_curso" if estado == "inexistente" else estado,
    )
    _posicion(e, viaje)
    if reserva == "sin_reserva":
        _sql(e, "DELETE FROM reserva WHERE id_reserva=$1", id_reserva)
    elif reserva == "ajena":
        persona = _persona(e)
    if estado == "inexistente":
        # La reserva (si existe) es de otro viaje; el consultado no existe.
        viaje = 9223372036854775807
    _error(_get(e, persona, viaje), 403, "SIN_PERMISO")


@pytest.mark.parametrize("registro", [None, "ausencia", "abordaje"])
def test_consolidada_en_curso_con_posicion_sin_restricciones_adicionales(entorno, registro):
    e = entorno
    persona, viaje, _ = _caso(e, viaje_estado="en_curso")
    _posicion(e, viaje)
    if registro == "ausencia":
        _sql(e, "INSERT INTO ausencia (id_pasajero, id_viaje) VALUES ($1, $2)", persona, viaje)
    elif registro == "abordaje":
        _sql(
            e,
            "INSERT INTO abordaje (id_pasajero, id_viaje, id_vehiculo, id_recorrido, orden_parada) "
            "VALUES ($1, $2, $3, $4, 1)",
            persona,
            viaje,
            e["vehiculo"],
            e["recorrido"],
        )
    r = _get(e, persona, viaje)
    assert r.status_code == 200
    assert set(r.json()) == {
        "id_viaje",
        "latitud",
        "longitud",
        "fecha_hora_posicion",
        "desactualizada",
        "eta_minutos",
    }
    assert r.json()["id_viaje"] == viaje
    assert (r.json()["latitud"], r.json()["longitud"]) == (1, 2)
    assert r.json()["eta_minutos"] is None


@pytest.mark.parametrize("estado", ["programado", "finalizado", "cancelado"])
def test_consolidada_fuera_de_en_curso_precede_a_posicion(entorno, estado):
    persona, viaje, _ = _caso(entorno, viaje_estado=estado)
    _error(_get(entorno, persona, viaje), 404, "VIAJE_NO_DISPONIBLE")
    _posicion(entorno, viaje)
    _error(_get(entorno, persona, viaje), 404, "VIAJE_NO_DISPONIBLE")


@pytest.mark.parametrize("faltante", ["fila", "latitud", "longitud", "fecha_hora_posicion"])
def test_consolidada_en_curso_sin_posicion_completa(entorno, faltante):
    persona, viaje, _ = _caso(entorno, viaje_estado="en_curso")
    if faltante != "fila":
        _posicion(entorno, viaje)
        assert faltante in ("latitud", "longitud", "fecha_hora_posicion")
        _sql(entorno, f"UPDATE posicion_gps SET {faltante}=NULL WHERE id_viaje=$1", viaje)
    _error(_get(entorno, persona, viaje), 404, "UBICACION_NO_DISPONIBLE")


@pytest.mark.parametrize("estado", ["en_curso", "finalizado", "inexistente"])
def test_regresion_roles_y_autenticacion(entorno, estado):
    e = entorno
    persona, viaje, _ = _caso(e, viaje_estado="en_curso" if estado == "inexistente" else estado)
    _posicion(e, viaje)
    if estado == "inexistente":
        viaje = 9223372036854775807
    for rol in ("administrador", "dueno"):
        r = _get(e, _persona(e), viaje, (rol,))  # Sin reserva propia.
        if estado == "en_curso":
            assert r.status_code == 200 and r.json()["eta_minutos"] is None
        else:
            _error(r, 404, "VIAJE_NO_DISPONIBLE")
    _error(_get(e, persona, viaje, ("chofer",)), 403, "SIN_PERMISO")
    url = f"/api/viajes/{viaje}/ubicacion"
    for headers in ({}, {"Authorization": "Bearer invalido"}):
        _error(e["http"].get(url, headers=headers), 401, "NO_AUTENTICADO")


def test_servicio_usa_helper_sin_locks_de_reserva_y_conserva_lock_viaje(entorno, monkeypatch):
    e = entorno
    persona, viaje, _ = _caso(e, viaje_estado="en_curso")
    _posicion(e, viaje)

    async def escenario():
        motor = create_async_engine(url_sqlalchemy(e["base"]), poolclass=NullPool)
        sentencias = []
        llamadas = []
        original = gps.reservas.reserva_propia_del_viaje

        async def helper(db, usuario, id_viaje, **kwargs):
            llamadas.append((db, usuario, id_viaje, kwargs))
            return await original(db, usuario, id_viaje, **kwargs)

        monkeypatch.setattr(gps.reservas, "reserva_propia_del_viaje", helper)
        event.listen(
            motor.sync_engine,
            "before_cursor_execute",
            lambda conn, cursor, sql, params, context, many: sentencias.append(sql),
        )
        try:
            async with async_sessionmaker(motor)() as db:
                usuario = UsuarioActual(1, persona, ("pasajero",))
                resultado = await gps.consultar(db, usuario, viaje)
                assert resultado.id_viaje == viaje
                assert llamadas
                assert all(c == (db, usuario, viaje, {}) for c in llamadas)
            lecturas = [s for s in sentencias if s.lstrip().upper().startswith("SELECT")]
            assert "FROM reserva" in lecturas[0] and "FOR UPDATE" not in lecturas[0]
            assert "FOR SHARE" not in lecturas[0]
            indice_lock = next(i for i, s in enumerate(lecturas) if "FROM viaje" in s)
            assert "FOR SHARE" in lecturas[indice_lock]
            assert any("FROM reserva" in s for s in lecturas[indice_lock + 1 :])
            assert all(
                "FOR UPDATE" not in s and "FOR SHARE" not in s
                for s in lecturas
                if "FROM reserva" in s
            )
            assert not any("FROM pasajero" in s for s in lecturas)
        finally:
            await motor.dispose()

    asyncio.run(escenario())


@pytest.mark.parametrize("cancelar", [True, False], ids=["cancelada", "vigente"])
@pytest.mark.parametrize("estado_final", ["en_curso", "programado", "finalizado"])
def test_revalida_reserva_tras_cancelacion_e_inicio_coordinados(
    entorno, monkeypatch, cancelar, estado_final
):
    e = entorno
    persona, viaje, id_reserva = _caso(e, viaje_estado="programado")
    _posicion(e, viaje)

    async def escenario():
        motor = create_async_engine(url_sqlalchemy(e["base"]), poolclass=NullPool)
        fabrica = async_sessionmaker(motor, expire_on_commit=False)
        leida = asyncio.Event()
        continuar = asyncio.Event()
        original = reservas.reserva_propia_del_viaje
        primera = []
        usuario = UsuarioActual(1, persona, ("pasajero",))
        chofer = UsuarioActual(2, e["chofer"], ("chofer",))

        async def leer_y_pausar(db, actual, id_viaje, **kwargs):
            reserva = await original(db, actual, id_viaje, **kwargs)
            if not primera:
                assert reserva.estado == "consolidada"
                primera.append(reserva)  # Mantiene el objeto en el identity map del GET.
                leida.set()
                await continuar.wait()
            return reserva

        monkeypatch.setattr(reservas, "reserva_propia_del_viaje", leer_y_pausar)
        tarea = None
        try:
            async with fabrica() as consulta, fabrica() as cancelacion, fabrica() as inicio:
                tarea = asyncio.create_task(gps.consultar(consulta, usuario, viaje))
                await asyncio.wait_for(leida.wait(), 5)
                if cancelar:
                    resultado = await reservas.cancelar_reserva(cancelacion, usuario, id_reserva)
                    assert resultado.reserva.estado == "cancelada"  # Servicio ya hizo commit.
                if estado_final != "programado":
                    resultado = await ejecucion_viajes.iniciar_viaje(inicio, chofer, viaje)
                    assert resultado.estado == "en_curso"  # Commit antes de reanudar GET.
                if estado_final == "finalizado":
                    async with fabrica() as fin:
                        await ejecucion_viajes.finalizar_viaje(fin, chofer, viaje)
                # El objeto original sigue consolidado: otra consulta ORM no garantiza frescura.
                assert primera[0].estado == "consolidada"
                continuar.set()
                if cancelar or estado_final != "en_curso":
                    with pytest.raises(ApiError) as error:
                        await asyncio.wait_for(tarea, 5)
                    assert error.value.status_code == (403 if cancelar else 404)
                    assert error.value.codigo == (
                        "SIN_PERMISO" if cancelar else "VIAJE_NO_DISPONIBLE"
                    )
                else:
                    resultado = await asyncio.wait_for(tarea, 5)
                    assert (resultado.latitud, resultado.longitud) == (1, 2)
                    assert resultado.eta_minutos is None
        finally:
            continuar.set()
            if tarea is not None and not tarea.done():
                tarea.cancel()
                await asyncio.gather(tarea, return_exceptions=True)
            await motor.dispose()

    asyncio.run(asyncio.wait_for(escenario(), 15))
