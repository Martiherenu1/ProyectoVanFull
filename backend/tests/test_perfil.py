"""Perfil del pasajero (CU-001): GET y PATCH /api/pasajeros/me contra un PostgreSQL real."""

import asyncio
from pathlib import Path

import pytest
import yaml

from app.core.security import crear_token
from tests._bd import base_migrada, cliente_api, consultar, ejecutar_sql

RUTA = "/api/pasajeros/me"
CONTRATO = Path(__file__).resolve().parents[1] / "openapi" / "openapi.yaml"


def _crear(base: str, dni: str, roles: list[str], *, pasajero: bool = True, **datos) -> dict:
    """Inserta una persona (y su pasajero) y devuelve sus ids y un token."""
    id_persona = asyncio.run(
        consultar(
            base,
            "INSERT INTO persona (nombre, apellido, dni, email, telefono, direccion) "
            "VALUES ($1, $2, $3, $4, $5, $6) RETURNING id_persona",
            datos.get("nombre", "Nombre"),
            datos.get("apellido", "Apellido"),
            dni,
            datos.get("email"),
            datos.get("telefono"),
            datos.get("direccion"),
        )
    )[0][0]
    if pasajero:
        asyncio.run(
            ejecutar_sql(
                base,
                "INSERT INTO pasajero (id_persona, categoria) VALUES ($1, $2)",
                id_persona,
                datos.get("categoria"),
            )
        )
    id_cuenta = id_persona  # el token solo necesita un id de cuenta; este endpoint no lo consulta
    return {
        "id_persona": id_persona,
        "token": crear_token(id_cuenta, id_persona, roles),
    }


def _con(persona: dict) -> dict[str, str]:
    return {"Authorization": f"Bearer {persona['token']}"}


@pytest.fixture(scope="module")
def entorno():
    with base_migrada() as base:
        personas = {
            "ana": _crear(
                base,
                "100",
                ["pasajero"],
                nombre="Ana",
                apellido="Prueba",
                email="ana@prueba.test",
                telefono="1111",
                direccion="Calle 1",
                categoria="universitario",
            ),
            "beto": _crear(
                base, "200", ["pasajero"], nombre="Beto", email="beto@prueba.test", telefono="2222"
            ),
            "sin_datos": _crear(base, "300", ["pasajero"], nombre="Sin", apellido="Datos"),
            "chofer": _crear(base, "400", ["chofer"], pasajero=False),
            "sin_pasajero": _crear(base, "500", ["pasajero"], pasajero=False),
        }
        with cliente_api(base) as cliente:
            yield base, cliente, personas


def _en_base(base: str, id_persona: int) -> dict:
    fila = asyncio.run(
        consultar(
            base,
            "SELECT nombre, apellido, dni, email, telefono, direccion FROM persona WHERE id_persona = $1",
            id_persona,
        )
    )[0]
    return dict(
        zip(("nombre", "apellido", "dni", "email", "telefono", "direccion"), fila, strict=True)
    )


@pytest.fixture(autouse=True)
def _restaurar(entorno):
    """Cada prueba parte del mismo estado de Ana, aunque otra la haya modificado."""
    base, _, personas = entorno
    asyncio.run(
        ejecutar_sql(
            base,
            "UPDATE persona SET email = 'ana@prueba.test', telefono = '1111', direccion = 'Calle 1' "
            "WHERE id_persona = $1",
            personas["ana"]["id_persona"],
        )
    )


# --- GET -----------------------------------------------------------------------------------


def test_devuelve_el_perfil_propio(entorno):
    _, cliente, personas = entorno
    respuesta = cliente.get(RUTA, headers=_con(personas["ana"]))
    assert respuesta.status_code == 200
    assert respuesta.json() == {
        "id_persona": personas["ana"]["id_persona"],
        "nombre": "Ana",
        "apellido": "Prueba",
        "dni": "100",
        "email": "ana@prueba.test",
        "telefono": "1111",
        "direccion": "Calle 1",
        "categoria": "universitario",
        "estado_habilitacion": "habilitado",
    }


def test_cada_pasajero_ve_solo_el_suyo(entorno):
    _, cliente, personas = entorno
    beto = cliente.get(RUTA, headers=_con(personas["beto"])).json()
    assert beto["id_persona"] == personas["beto"]["id_persona"]
    assert beto["dni"] == "200"
    assert "ana@prueba.test" not in str(beto)


def test_los_datos_no_cargados_no_aparecen_en_vez_de_ir_como_null(entorno):
    """El contrato declara los campos como `type: string`, sin `nullable`."""
    _, cliente, personas = entorno
    cuerpo = cliente.get(RUTA, headers=_con(personas["sin_datos"])).json()
    assert None not in cuerpo.values()
    assert not {"email", "telefono", "direccion", "categoria", "fotografia"} & set(cuerpo)


def test_la_respuesta_no_trae_campos_que_el_contrato_no_declara(entorno):
    _, cliente, personas = entorno
    contrato = yaml.safe_load(CONTRATO.read_text(encoding="utf-8"))
    declarados = set(contrato["components"]["schemas"]["PerfilPasajero"]["properties"])
    cuerpo = cliente.get(RUTA, headers=_con(personas["ana"])).json()
    assert set(cuerpo) <= declarados


def test_sin_token_es_401(entorno):
    _, cliente, _ = entorno
    assert cliente.get(RUTA).status_code == 401


def test_un_rol_que_no_es_pasajero_es_403(entorno):
    _, cliente, personas = entorno
    respuesta = cliente.get(RUTA, headers=_con(personas["chofer"]))
    assert respuesta.status_code == 403
    assert respuesta.json()["error"]["codigo"] == "SIN_PERMISO"


def test_una_cuenta_con_el_rol_pero_sin_pasajero_es_404(entorno):
    _, cliente, personas = entorno
    respuesta = cliente.get(RUTA, headers=_con(personas["sin_pasajero"]))
    assert respuesta.status_code == 404
    assert respuesta.json()["error"]["codigo"] == "PASAJERO_NO_ENCONTRADO"


# --- PATCH ---------------------------------------------------------------------------------


def test_modifica_los_datos_habilitados_y_los_persiste(entorno):
    base, cliente, personas = entorno
    nuevos = {"email": "ana.nueva@prueba.test", "telefono": "9999", "direccion": "Calle 99"}
    respuesta = cliente.patch(RUTA, json=nuevos, headers=_con(personas["ana"]))
    assert respuesta.status_code == 200
    assert {k: respuesta.json()[k] for k in nuevos} == nuevos
    en_base = _en_base(base, personas["ana"]["id_persona"])
    assert {k: en_base[k] for k in nuevos} == nuevos
    # Y lo que no se tocó sigue igual.
    assert (en_base["nombre"], en_base["apellido"], en_base["dni"]) == ("Ana", "Prueba", "100")


def test_un_cambio_parcial_deja_el_resto_como_estaba(entorno):
    base, cliente, personas = entorno
    respuesta = cliente.patch(RUTA, json={"telefono": "5555"}, headers=_con(personas["ana"]))
    assert respuesta.status_code == 200
    en_base = _en_base(base, personas["ana"]["id_persona"])
    assert (en_base["telefono"], en_base["email"], en_base["direccion"]) == (
        "5555",
        "ana@prueba.test",
        "Calle 1",
    )


@pytest.mark.parametrize(
    "intento",
    [
        {"dni": "999"},
        {"nombre": "Otro"},
        {"estado_habilitacion": "baja"},
        {"id_persona": 1},
        {"categoria": "empresarial"},
    ],
)
def test_un_dato_no_habilitado_es_403_y_no_se_modifica_nada(entorno, intento):
    base, cliente, personas = entorno
    antes = _en_base(base, personas["ana"]["id_persona"])
    # Se manda junto a un dato habilitado: tampoco ese se aplica.
    cuerpo = {**intento, "telefono": "0000"}
    respuesta = cliente.patch(RUTA, json=cuerpo, headers=_con(personas["ana"]))
    assert respuesta.status_code == 403
    error = respuesta.json()["error"]
    assert error["codigo"] == "DATO_NO_MODIFICABLE"
    # CU-001 A1: el sistema informa que el cambio debe hacerlo un administrador autorizado.
    assert "administrador autorizado" in error["mensaje"]
    assert error["detalles"]["campos"] == sorted(intento)
    assert _en_base(base, personas["ana"]["id_persona"]) == antes


def test_un_pasajero_no_modifica_a_otro(entorno):
    base, cliente, personas = entorno
    beto_antes = _en_base(base, personas["beto"]["id_persona"])
    # Aunque mande el id de otro, el endpoint solo mira el del token.
    cliente.patch(
        RUTA,
        json={"telefono": "7777", "id_persona": personas["beto"]["id_persona"]},
        headers=_con(personas["ana"]),
    )
    assert _en_base(base, personas["beto"]["id_persona"]) == beto_antes


@pytest.mark.parametrize(
    "cuerpo",
    [
        {"email": ""},
        {"telefono": None},
        {"email": "a" * 121},
        {"telefono": "1" * 31},
        {"direccion": "d" * 201},
        {"email": 123},
    ],
)
def test_un_valor_invalido_es_400_y_no_se_modifica_nada(entorno, cuerpo):
    base, cliente, personas = entorno
    antes = _en_base(base, personas["ana"]["id_persona"])
    respuesta = cliente.patch(RUTA, json=cuerpo, headers=_con(personas["ana"]))
    assert respuesta.status_code == 400
    assert respuesta.json()["error"]["codigo"] == "VALIDACION"
    assert _en_base(base, personas["ana"]["id_persona"]) == antes


def test_un_cuerpo_vacio_no_cambia_nada(entorno):
    base, cliente, personas = entorno
    antes = _en_base(base, personas["ana"]["id_persona"])
    respuesta = cliente.patch(RUTA, json={}, headers=_con(personas["ana"]))
    assert respuesta.status_code == 200
    assert _en_base(base, personas["ana"]["id_persona"]) == antes


def test_patch_sin_token_es_401_y_con_otro_rol_es_403(entorno):
    _, cliente, personas = entorno
    assert cliente.patch(RUTA, json={"telefono": "1"}).status_code == 401
    assert (
        cliente.patch(RUTA, json={"telefono": "1"}, headers=_con(personas["chofer"])).status_code
        == 403
    )
