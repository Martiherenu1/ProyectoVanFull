"""Gestión administrativa de pasajeros (CU-013): /api/pasajeros contra un PostgreSQL real."""

import asyncio
from pathlib import Path

import pytest
import yaml

from app.core.security import crear_token
from tests._bd import base_migrada, cliente_api, consultar, ejecutar_sql

RUTA = "/api/pasajeros"
CONTRATO = Path(__file__).resolve().parents[1] / "openapi" / "openapi.yaml"


def _persona(base: str, dni: str, *, pasajero: bool = True, **datos) -> int:
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
    return id_persona


def _con(id_persona: int, *roles: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {crear_token(id_persona, id_persona, list(roles))}"}


@pytest.fixture(scope="module")
def entorno():
    with base_migrada() as base:
        ids = {
            "admin": _persona(base, "1", pasajero=False, nombre="Admin"),
            "ana": _persona(
                base,
                "100",
                nombre="Ana",
                apellido="Gómez",
                email="ana@prueba.test",
                categoria="universitario",
            ),
            "beto": _persona(base, "200", nombre="Beto", apellido="Pérez"),
            "chofer": _persona(base, "300", pasajero=False, nombre="Carlos", apellido="Chofer"),
        }
        with cliente_api(base) as cliente:
            yield base, cliente, ids


@pytest.fixture
def admin(entorno):
    return _con(entorno[2]["admin"], "administrador")


@pytest.fixture(autouse=True)
def _restaurar(entorno):
    """Cada prueba parte del mismo estado de Ana y Beto, aunque otra los haya modificado."""
    base, _, ids = entorno
    asyncio.run(
        ejecutar_sql(
            base,
            "UPDATE persona SET nombre = 'Ana', apellido = 'Gómez', dni = '100', "
            "email = 'ana@prueba.test' WHERE id_persona = $1",
            ids["ana"],
        )
    )
    asyncio.run(
        ejecutar_sql(
            base,
            "UPDATE pasajero SET estado_habilitacion = 'habilitado', categoria = 'universitario' "
            "WHERE id_persona = $1",
            ids["ana"],
        )
    )
    asyncio.run(
        ejecutar_sql(
            base,
            "DELETE FROM pasajero WHERE id_persona IN (SELECT id_persona FROM persona WHERE dni LIKE '9%')",
        )
    )
    asyncio.run(ejecutar_sql(base, "DELETE FROM persona WHERE dni LIKE '9%'"))


def _estado(base: str, id_persona: int) -> str:
    return asyncio.run(
        consultar(
            base, "SELECT estado_habilitacion FROM pasajero WHERE id_persona = $1", id_persona
        )
    )[0][0]


# --- permisos ------------------------------------------------------------------------------


def test_sin_token_es_401(entorno):
    _, cliente, ids = entorno
    assert cliente.get(RUTA).status_code == 401
    assert cliente.get(f"{RUTA}/{ids['ana']}").status_code == 401


@pytest.mark.parametrize("rol", ["pasajero", "chofer"])
def test_otros_roles_son_403_en_todas_las_operaciones(entorno, rol):
    _, cliente, ids = entorno
    h = _con(ids["ana"], rol)
    alta = {"nombre": "X", "apellido": "Y", "dni": "901"}
    for respuesta in (
        cliente.get(RUTA, headers=h),
        cliente.post(RUTA, json=alta, headers=h),
        cliente.get(f"{RUTA}/{ids['beto']}", headers=h),
        cliente.patch(f"{RUTA}/{ids['beto']}", json={"nombre": "Z"}, headers=h),
        cliente.post(f"{RUTA}/{ids['beto']}/baja", headers=h),
    ):
        assert respuesta.status_code == 403
        assert respuesta.json()["error"]["codigo"] == "SIN_PERMISO"


def test_el_dueno_tambien_puede(entorno):
    _, cliente, ids = entorno
    respuesta = cliente.get(f"{RUTA}/{ids['ana']}", headers=_con(ids["admin"], "dueno"))
    assert respuesta.status_code == 200


def test_el_perfil_propio_sigue_resolviendose_antes_que_la_ruta_con_id(entorno):
    """`/pasajeros/me` no puede caer en `/pasajeros/{id_persona}` (ni dar 400 por 'me' no entero)."""
    _, cliente, ids = entorno
    respuesta = cliente.get(f"{RUTA}/me", headers=_con(ids["ana"], "pasajero"))
    assert respuesta.status_code == 200
    assert respuesta.json()["dni"] == "100"


# --- consulta ------------------------------------------------------------------------------


def test_consulta_un_pasajero_con_su_estado(entorno, admin):
    _, cliente, ids = entorno
    respuesta = cliente.get(f"{RUTA}/{ids['ana']}", headers=admin)
    assert respuesta.status_code == 200
    assert respuesta.json() == {
        "id_persona": ids["ana"],
        "nombre": "Ana",
        "apellido": "Gómez",
        "dni": "100",
        "email": "ana@prueba.test",
        "categoria": "universitario",
        "estado_habilitacion": "habilitado",
    }


def test_un_pasajero_inexistente_es_404(entorno, admin):
    _, cliente, _ = entorno
    respuesta = cliente.get(f"{RUTA}/999999", headers=admin)
    assert respuesta.status_code == 404
    assert respuesta.json()["error"]["codigo"] == "PASAJERO_NO_ENCONTRADO"


def test_una_persona_que_no_es_pasajero_es_404(entorno, admin):
    _, cliente, ids = entorno
    assert cliente.get(f"{RUTA}/{ids['chofer']}", headers=admin).status_code == 404


def test_un_id_invalido_es_400(entorno, admin):
    _, cliente, _ = entorno
    for malo in ("0", "-3", "abc"):
        respuesta = cliente.get(f"{RUTA}/{malo}", headers=admin)
        assert respuesta.status_code == 400
        assert respuesta.json()["error"]["codigo"] == "VALIDACION"


def test_la_lista_trae_solo_pasajeros_ordenados(entorno, admin):
    _, cliente, ids = entorno
    cuerpo = cliente.get(RUTA, headers=admin).json()
    assert cuerpo["total"] == 2
    # Orden por apellido: Gómez (Ana) antes que Pérez (Beto). Admin y chofer no son pasajeros.
    assert [p["id_persona"] for p in cuerpo["items"]] == [ids["ana"], ids["beto"]]


def test_busca_por_dni_nombre_o_apellido_sin_distinguir_mayusculas(entorno, admin):
    _, cliente, ids = entorno
    for q, esperado in (("100", ids["ana"]), ("beto", ids["beto"]), ("GÓM", ids["ana"])):
        items = cliente.get(RUTA, params={"q": q}, headers=admin).json()["items"]
        assert [p["id_persona"] for p in items] == [esperado]


def test_los_comodines_del_usuario_no_funcionan_como_tales(entorno, admin):
    _, cliente, _ = entorno
    assert cliente.get(RUTA, params={"q": "%"}, headers=admin).json()["total"] == 0
    assert cliente.get(RUTA, params={"q": "_"}, headers=admin).json()["total"] == 0


def test_pagina_y_informa_el_total_sin_paginar(entorno, admin):
    _, cliente, ids = entorno
    cuerpo = cliente.get(RUTA, params={"limite": 1, "desplazamiento": 1}, headers=admin).json()
    assert cuerpo["total"] == 2
    assert [p["id_persona"] for p in cuerpo["items"]] == [ids["beto"]]


@pytest.mark.parametrize("params", [{"limite": 0}, {"limite": 101}, {"desplazamiento": -1}])
def test_paginacion_invalida_es_400(entorno, admin, params):
    _, cliente, _ = entorno
    assert cliente.get(RUTA, params=params, headers=admin).status_code == 400


def test_la_respuesta_no_trae_campos_que_el_contrato_no_declara(entorno, admin):
    _, cliente, ids = entorno
    contrato = yaml.safe_load(CONTRATO.read_text(encoding="utf-8"))
    declarados = set(contrato["components"]["schemas"]["PasajeroAdmin"]["properties"])
    assert set(cliente.get(f"{RUTA}/{ids['ana']}", headers=admin).json()) <= declarados


# --- alta ----------------------------------------------------------------------------------


def test_registra_un_pasajero_habilitado_y_lo_persiste(entorno, admin):
    base, cliente, _ = entorno
    respuesta = cliente.post(
        RUTA,
        json={
            "nombre": "  Nuevo  ",
            "apellido": "Pasajero",
            "dni": "900",
            "email": "nuevo@prueba.test",
            "categoria": "laboral",
        },
        headers=admin,
    )
    assert respuesta.status_code == 201
    cuerpo = respuesta.json()
    assert cuerpo["nombre"] == "Nuevo"
    assert cuerpo["estado_habilitacion"] == "habilitado"
    assert cuerpo["categoria"] == "laboral"
    assert _estado(base, cuerpo["id_persona"]) == "habilitado"


def test_el_alta_no_crea_cuenta_de_acceso(entorno, admin):
    base, cliente, _ = entorno
    id_persona = cliente.post(
        RUTA, json={"nombre": "Sin", "apellido": "Cuenta", "dni": "902"}, headers=admin
    ).json()["id_persona"]
    cuentas = asyncio.run(
        consultar(base, "SELECT count(*) FROM cuenta_acceso WHERE id_persona = $1", id_persona)
    )[0][0]
    assert cuentas == 0


def test_dni_repetido_es_409_y_no_deja_nada_a_medias(entorno, admin):
    base, cliente, ids = entorno
    respuesta = cliente.post(
        RUTA, json={"nombre": "Otra", "apellido": "Ana", "dni": "100"}, headers=admin
    )
    assert respuesta.status_code == 409
    assert respuesta.json()["error"]["codigo"] == "DNI_DUPLICADO"
    assert asyncio.run(consultar(base, "SELECT count(*) FROM persona WHERE dni = '100'"))[0][0] == 1


def test_el_dni_de_un_chofer_tambien_es_409(entorno, admin):
    _, cliente, _ = entorno
    respuesta = cliente.post(
        RUTA, json={"nombre": "Carlos", "apellido": "Chofer", "dni": "300"}, headers=admin
    )
    assert respuesta.status_code == 409
    assert respuesta.json()["error"]["codigo"] == "DNI_DUPLICADO"


@pytest.mark.parametrize(
    "cuerpo",
    [
        {"apellido": "Y", "dni": "903"},
        {"nombre": "X", "dni": "903"},
        {"nombre": "X", "apellido": "Y"},
        {"nombre": "   ", "apellido": "Y", "dni": "903"},
        {"nombre": "X", "apellido": "Y", "dni": "9" * 21},
        {"nombre": "X", "apellido": "Y", "dni": "903", "estado_habilitacion": "baja"},
    ],
)
def test_alta_con_datos_invalidos_es_400(entorno, admin, cuerpo):
    _, cliente, _ = entorno
    respuesta = cliente.post(RUTA, json=cuerpo, headers=admin)
    assert respuesta.status_code == 400
    assert respuesta.json()["error"]["codigo"] == "VALIDACION"


# --- modificación --------------------------------------------------------------------------


def test_administracion_puede_cambiar_el_dni(entorno, admin):
    """CU-013 A1. El pasajero no puede (RN-026, `test_perfil.py`)."""
    base, cliente, ids = entorno
    respuesta = cliente.patch(f"{RUTA}/{ids['ana']}", json={"dni": "901"}, headers=admin)
    assert respuesta.status_code == 200
    assert respuesta.json()["dni"] == "901"
    assert (
        asyncio.run(consultar(base, "SELECT dni FROM persona WHERE id_persona = $1", ids["ana"]))[
            0
        ][0]
        == "901"
    )


def test_modifica_datos_de_persona_y_la_categoria_juntos(entorno, admin):
    base, cliente, ids = entorno
    respuesta = cliente.patch(
        f"{RUTA}/{ids['ana']}",
        json={"nombre": "Ana María", "email": "nueva@prueba.test", "categoria": "laboral"},
        headers=admin,
    )
    assert respuesta.status_code == 200
    cuerpo = respuesta.json()
    assert (cuerpo["nombre"], cuerpo["email"], cuerpo["categoria"]) == (
        "Ana María",
        "nueva@prueba.test",
        "laboral",
    )
    # Lo que no se envió queda como estaba.
    assert (cuerpo["apellido"], cuerpo["dni"]) == ("Gómez", "100")


def test_repetir_el_propio_dni_no_es_conflicto(entorno, admin):
    _, cliente, ids = entorno
    respuesta = cliente.patch(f"{RUTA}/{ids['ana']}", json={"dni": "100"}, headers=admin)
    assert respuesta.status_code == 200


def test_cambiar_al_dni_de_otro_es_409_y_no_modifica_nada(entorno, admin):
    base, cliente, ids = entorno
    respuesta = cliente.patch(
        f"{RUTA}/{ids['ana']}", json={"nombre": "Cambiada", "dni": "200"}, headers=admin
    )
    assert respuesta.status_code == 409
    assert respuesta.json()["error"]["codigo"] == "DNI_DUPLICADO"
    fila = asyncio.run(
        consultar(base, "SELECT nombre, dni FROM persona WHERE id_persona = $1", ids["ana"])
    )[0]
    assert tuple(fila) == ("Ana", "100")


@pytest.mark.parametrize(
    "cuerpo",
    [
        {},
        {"estado_habilitacion": "suspendido"},
        {"fotografia": "http://x/y.png"},
        {"nombre": None},
        {"email": ""},
    ],
)
def test_modificacion_invalida_es_400(entorno, admin, cuerpo):
    """Sin cambios, campo desconocido (el estado no se cambia por acá), null o vacío."""
    _, cliente, ids = entorno
    respuesta = cliente.patch(f"{RUTA}/{ids['ana']}", json=cuerpo, headers=admin)
    assert respuesta.status_code == 400
    assert respuesta.json()["error"]["codigo"] == "VALIDACION"


def test_modificar_un_pasajero_inexistente_es_404(entorno, admin):
    _, cliente, _ = entorno
    assert cliente.patch(f"{RUTA}/999999", json={"nombre": "X"}, headers=admin).status_code == 404


# --- baja ----------------------------------------------------------------------------------


def test_la_baja_es_logica_y_conserva_los_datos(entorno, admin):
    base, cliente, ids = entorno
    respuesta = cliente.post(f"{RUTA}/{ids['ana']}/baja", headers=admin)
    assert respuesta.status_code == 200
    assert respuesta.json()["estado_habilitacion"] == "baja"
    assert _estado(base, ids["ana"]) == "baja"
    # Sigue existiendo: la consulta la encuentra y mantiene sus datos.
    assert cliente.get(f"{RUTA}/{ids['ana']}", headers=admin).json()["dni"] == "100"


def test_repetir_la_baja_es_409(entorno, admin):
    _, cliente, ids = entorno
    assert cliente.post(f"{RUTA}/{ids['ana']}/baja", headers=admin).status_code == 200
    segunda = cliente.post(f"{RUTA}/{ids['ana']}/baja", headers=admin)
    assert segunda.status_code == 409
    assert segunda.json()["error"]["codigo"] == "PASAJERO_YA_DADO_DE_BAJA"


def test_dar_de_baja_un_pasajero_inexistente_es_404(entorno, admin):
    _, cliente, _ = entorno
    assert cliente.post(f"{RUTA}/999999/baja", headers=admin).status_code == 404
