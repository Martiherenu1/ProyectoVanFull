"""Pasajeros de la organización (CU-033): /api/organizaciones contra un PostgreSQL real."""

import asyncio
from pathlib import Path

import pytest
import yaml

from app.core.security import crear_token
from tests._bd import base_migrada, cliente_api, consultar, ejecutar_sql

RUTA = "/api/organizaciones"
CONTRATO = Path(__file__).resolve().parents[1] / "openapi" / "openapi.yaml"


def _uno(base: str, sql: str, *args):
    return asyncio.run(consultar(base, sql, *args))[0][0]


def _persona(base: str, dni: str, *, pasajero: bool = False, **datos) -> int:
    id_persona = _uno(
        base,
        "INSERT INTO persona (nombre, apellido, dni, email) VALUES ($1, $2, $3, $4) "
        "RETURNING id_persona",
        datos.get("nombre", "Nombre"),
        datos.get("apellido", "Apellido"),
        dni,
        datos.get("email"),
    )
    if pasajero:
        asyncio.run(ejecutar_sql(base, "INSERT INTO pasajero (id_persona) VALUES ($1)", id_persona))
    return id_persona


def _empresa(base: str, razon_social: str, cuit: str) -> int:
    id_cliente = _uno(
        base,
        "INSERT INTO cliente (naturaleza_cliente) VALUES ('PERSONA_JURIDICA') RETURNING id_cliente",
    )
    asyncio.run(
        ejecutar_sql(
            base,
            "INSERT INTO cliente_persona_juridica (id_cliente, razon_social, cuit) "
            "VALUES ($1, $2, $3)",
            id_cliente,
            razon_social,
            cuit,
        )
    )
    asyncio.run(
        ejecutar_sql(base, "INSERT INTO cliente_corporativo (id_cliente) VALUES ($1)", id_cliente)
    )
    return id_cliente


def _con(id_persona: int, *roles: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {crear_token(id_persona, id_persona, list(roles))}"}


def _contacto(base: str, id_cliente: int, id_persona: int, representante: bool, cargo=None):
    asyncio.run(
        ejecutar_sql(
            base,
            "INSERT INTO contacto_corporativo "
            "(id_cliente_corporativo, id_persona, cargo, es_representante) VALUES ($1, $2, $3, $4)",
            id_cliente,
            id_persona,
            cargo,
            representante,
        )
    )


def _vincular(base: str, id_cliente: int, id_pasajero: int):
    asyncio.run(
        ejecutar_sql(
            base,
            "INSERT INTO pasajero_corporativo (id_cliente_corporativo, id_pasajero) VALUES ($1, $2)",
            id_cliente,
            id_pasajero,
        )
    )


@pytest.fixture(scope="module")
def entorno():
    with base_migrada() as base:
        ids = {
            "admin": _persona(base, "1", nombre="Admin"),
            "ana": _persona(base, "100", pasajero=True, nombre="Ana", apellido="Gómez"),
            "beto": _persona(base, "200", pasajero=True, nombre="Beto", apellido="Pérez"),
            "cami": _persona(base, "150", pasajero=True, nombre="Cami", apellido="Sola"),
            "rep_acme": _persona(base, "400", nombre="Rita", apellido="Representa"),
            "rep_dos": _persona(base, "410", nombre="Dora", apellido="Doble"),
            "no_rep": _persona(base, "420", nombre="Nico", apellido="Contacto"),
            "acme": _empresa(base, "Acme SA", "30-1"),
            "beta": _empresa(base, "Beta SRL", "30-2"),
        }
        with cliente_api(base) as cliente:
            yield base, cliente, ids


@pytest.fixture(autouse=True)
def _restaurar(entorno):
    """Cada prueba parte de lo mismo: Rita representa a Acme, Dora a Acme y Beta (con cargo), Nico
    es contacto de Acme sin representarla; Ana es de Acme, Beto de Beta y Cami de ninguna."""
    base, _, ids = entorno
    for sql in (
        "DELETE FROM contacto_corporativo",
        "DELETE FROM pasajero_corporativo",
        "DELETE FROM pasajero WHERE id_persona IN (SELECT id_persona FROM persona WHERE dni LIKE '9%')",
        "DELETE FROM persona WHERE dni LIKE '9%'",
        "UPDATE persona SET nombre = 'Ana', apellido = 'Gómez', email = NULL, telefono = NULL, "
        f"direccion = NULL WHERE id_persona = {ids['ana']}",
        "UPDATE persona SET nombre = 'Beto', apellido = 'Pérez', email = NULL, telefono = NULL, "
        f"direccion = NULL WHERE id_persona = {ids['beto']}",
    ):
        asyncio.run(ejecutar_sql(base, sql))
    _contacto(base, ids["acme"], ids["rep_acme"], True, "Gerente")
    _contacto(base, ids["acme"], ids["rep_dos"], True)
    _contacto(base, ids["beta"], ids["rep_dos"], True, "Directora")
    _contacto(base, ids["acme"], ids["no_rep"], False, "Asistente")
    _vincular(base, ids["acme"], ids["ana"])
    _vincular(base, ids["beta"], ids["beto"])


@pytest.fixture
def rep(entorno):
    return _con(entorno[2]["rep_acme"], "representante_corporativo")


def _datos(base: str, id_persona: int):
    filas = asyncio.run(
        consultar(
            base,
            "SELECT nombre, apellido, dni, email, telefono, direccion FROM persona "
            "WHERE id_persona = $1",
            id_persona,
        )
    )
    return tuple(filas[0])


# --- permisos ------------------------------------------------------------------------------


def test_sin_token_es_401(entorno):
    _, cliente, ids = entorno
    assert cliente.get(RUTA).status_code == 401
    assert cliente.get(f"{RUTA}/{ids['acme']}/pasajeros").status_code == 401


@pytest.mark.parametrize("rol", ["administrador", "dueno", "pasajero", "chofer"])
def test_otros_roles_son_403_en_todas_las_operaciones(entorno, rol):
    """Administración gestiona estos mismos datos por CU-013 y CU-023, no por acá."""
    _, cliente, ids = entorno
    h = _con(ids["rep_acme"], rol)
    pasajeros = f"{RUTA}/{ids['acme']}/pasajeros"
    respuestas = (
        cliente.get(RUTA, headers=h),
        cliente.get(pasajeros, headers=h),
        cliente.post(pasajeros, json={"nombre": "N", "apellido": "A", "dni": "901"}, headers=h),
        cliente.patch(f"{pasajeros}/{ids['ana']}", json={"nombre": "Z"}, headers=h),
    )
    assert [r.status_code for r in respuestas] == [403] * 4
    assert {r.json()["error"]["codigo"] for r in respuestas} == {"SIN_PERMISO"}


# --- organizaciones que represento ---------------------------------------------------------


def test_lista_solo_las_empresas_que_representa(entorno, rep):
    _, cliente, ids = entorno
    r = cliente.get(RUTA, headers=rep)
    assert r.status_code == 200
    assert r.json() == {
        "items": [{"id_cliente": ids["acme"], "razon_social": "Acme SA", "cargo": "Gerente"}],
        "total": 1,
    }


def test_representante_de_varias_empresas_las_ve_ordenadas(entorno):
    _, cliente, ids = entorno
    r = cliente.get(RUTA, headers=_con(ids["rep_dos"], "representante_corporativo"))
    assert [(o["razon_social"], o.get("cargo")) for o in r.json()["items"]] == [
        ("Acme SA", None),
        ("Beta SRL", "Directora"),
    ]
    assert r.json()["total"] == 2


def test_un_contacto_que_no_es_representante_no_ve_ninguna(entorno):
    """`es_representante` es lo que cuenta: ser contacto de la empresa no alcanza."""
    _, cliente, ids = entorno
    r = cliente.get(RUTA, headers=_con(ids["no_rep"], "representante_corporativo"))
    assert r.status_code == 200
    assert r.json() == {"items": [], "total": 0}


# --- listar --------------------------------------------------------------------------------


def test_lista_solo_los_pasajeros_de_su_empresa(entorno, rep):
    _, cliente, ids = entorno
    r = cliente.get(f"{RUTA}/{ids['acme']}/pasajeros", headers=rep)
    assert r.status_code == 200
    assert r.json() == {
        "items": [
            {
                "id_persona": ids["ana"],
                "nombre": "Ana",
                "apellido": "Gómez",
                "dni": "100",
                "estado_habilitacion": "habilitado",
            }
        ],
        "total": 1,
    }


def test_la_lista_se_ordena_y_se_pagina(entorno, rep):
    base, cliente, ids = entorno
    for dni, apellido in (("901", "Zeta"), ("902", "Alfa"), ("903", "Medio")):
        _vincular(base, ids["acme"], _persona(base, dni, pasajero=True, apellido=apellido))
    url = f"{RUTA}/{ids['acme']}/pasajeros"
    completa = cliente.get(url, headers=rep).json()
    assert [p["apellido"] for p in completa["items"]] == ["Alfa", "Gómez", "Medio", "Zeta"]
    assert completa["total"] == 4
    pagina = cliente.get(url, params={"limite": 2, "desplazamiento": 1}, headers=rep).json()
    assert [p["apellido"] for p in pagina["items"]] == ["Gómez", "Medio"]
    assert pagina["total"] == 4


@pytest.mark.parametrize("params", [{"limite": 0}, {"limite": 101}, {"desplazamiento": -1}])
def test_parametros_de_pagina_invalidos_son_400(entorno, rep, params):
    _, cliente, ids = entorno
    r = cliente.get(f"{RUTA}/{ids['acme']}/pasajeros", params=params, headers=rep)
    assert (r.status_code, r.json()["error"]["codigo"]) == (400, "VALIDACION")


@pytest.mark.parametrize("quien", ["beta", "no_rep_de_acme", "inexistente"])
def test_una_empresa_que_no_representa_es_404(entorno, rep, quien):
    """A3: ajena, sin ser representante o inexistente responden igual: no se confirma nada."""
    _, cliente, ids = entorno
    h = _con(ids["no_rep"], "representante_corporativo") if quien == "no_rep_de_acme" else rep
    id_cliente = 999999 if quien == "inexistente" else ids["acme" if quien != "beta" else "beta"]
    r = cliente.get(f"{RUTA}/{id_cliente}/pasajeros", headers=h)
    assert (r.status_code, r.json()["error"]["codigo"]) == (404, "ORGANIZACION_NO_ENCONTRADA")


def test_un_identificador_no_positivo_es_400(entorno, rep):
    _, cliente, _ = entorno
    assert cliente.get(f"{RUTA}/0/pasajeros", headers=rep).status_code == 400


# --- registrar -----------------------------------------------------------------------------


def test_registra_el_pasajero_y_lo_asocia_a_su_empresa(entorno, rep):
    base, cliente, ids = entorno
    r = cliente.post(
        f"{RUTA}/{ids['acme']}/pasajeros",
        json={"nombre": "  Luis ", "apellido": "Nuevo", "dni": "910", "email": "l@acme.test"},
        headers=rep,
    )
    assert r.status_code == 201
    cuerpo = r.json()
    assert (cuerpo["nombre"], cuerpo["apellido"], cuerpo["dni"], cuerpo["email"]) == (
        "Luis",
        "Nuevo",
        "910",
        "l@acme.test",
    )
    assert cuerpo["estado_habilitacion"] == "habilitado"
    assert "categoria" not in cuerpo
    id_nuevo = cuerpo["id_persona"]
    assert _uno(base, "SELECT count(*) FROM pasajero WHERE id_persona = $1", id_nuevo) == 1
    assert (
        _uno(
            base,
            "SELECT count(*) FROM pasajero_corporativo "
            "WHERE id_cliente_corporativo = $1 AND id_pasajero = $2 AND estado_vinculo = 'activo'",
            ids["acme"],
            id_nuevo,
        )
        == 1
    )
    en_lista = cliente.get(f"{RUTA}/{ids['acme']}/pasajeros", headers=rep).json()
    assert id_nuevo in [p["id_persona"] for p in en_lista["items"]]


def test_registra_en_la_empresa_que_elige_entre_las_que_representa(entorno):
    base, cliente, ids = entorno
    h = _con(ids["rep_dos"], "representante_corporativo")
    r = cliente.post(
        f"{RUTA}/{ids['beta']}/pasajeros",
        json={"nombre": "Bea", "apellido": "Beta", "dni": "911"},
        headers=h,
    )
    assert r.status_code == 201
    asociadas = asyncio.run(
        consultar(
            base,
            "SELECT id_cliente_corporativo FROM pasajero_corporativo WHERE id_pasajero = $1",
            r.json()["id_persona"],
        )
    )
    assert [fila[0] for fila in asociadas] == [ids["beta"]]


def test_dni_repetido_es_409_y_no_crea_nada(entorno, rep):
    """Vale también para el DNI de alguien que no es pasajero (por ejemplo, un administrador)."""
    base, cliente, ids = entorno
    for dni in ("100", "1"):
        r = cliente.post(
            f"{RUTA}/{ids['acme']}/pasajeros",
            json={"nombre": "Otro", "apellido": "Otro", "dni": dni},
            headers=rep,
        )
        assert (r.status_code, r.json()["error"]["codigo"]) == (409, "DNI_DUPLICADO")
        assert _uno(base, "SELECT count(*) FROM persona WHERE dni = $1", dni) == 1
    assert _uno(base, "SELECT count(*) FROM pasajero_corporativo") == 2


@pytest.mark.parametrize(
    "cuerpo",
    [
        {"apellido": "A", "dni": "912"},
        {"nombre": "N", "dni": "912"},
        {"nombre": "N", "apellido": "A"},
        {"nombre": "", "apellido": "A", "dni": "912"},
        {"nombre": "N", "apellido": "A", "dni": "912", "categoria": "estudiante"},
        {"nombre": "N", "apellido": "A", "dni": "912", "estado_habilitacion": "baja"},
    ],
)
def test_alta_con_datos_invalidos_es_400(entorno, rep, cuerpo):
    base, cliente, ids = entorno
    r = cliente.post(f"{RUTA}/{ids['acme']}/pasajeros", json=cuerpo, headers=rep)
    assert (r.status_code, r.json()["error"]["codigo"]) == (400, "VALIDACION")
    assert _uno(base, "SELECT count(*) FROM persona WHERE dni = '912'") == 0


def test_no_registra_en_una_empresa_ajena(entorno, rep):
    base, cliente, ids = entorno
    r = cliente.post(
        f"{RUTA}/{ids['beta']}/pasajeros",
        json={"nombre": "N", "apellido": "A", "dni": "913"},
        headers=rep,
    )
    assert (r.status_code, r.json()["error"]["codigo"]) == (404, "ORGANIZACION_NO_ENCONTRADA")
    assert _uno(base, "SELECT count(*) FROM persona WHERE dni = '913'") == 0


# --- modificar -----------------------------------------------------------------------------


def test_modifica_los_datos_permitidos(entorno, rep):
    base, cliente, ids = entorno
    r = cliente.patch(
        f"{RUTA}/{ids['acme']}/pasajeros/{ids['ana']}",
        json={"nombre": "Ana María", "telefono": "11-5555", "direccion": "Calle 1"},
        headers=rep,
    )
    assert r.status_code == 200
    assert (r.json()["nombre"], r.json()["telefono"], r.json()["dni"]) == (
        "Ana María",
        "11-5555",
        "100",
    )
    assert _datos(base, ids["ana"]) == ("Ana María", "Gómez", "100", None, "11-5555", "Calle 1")


@pytest.mark.parametrize(
    "cuerpo",
    [
        {"dni": "999"},
        {"nombre": "Otro", "dni": "999"},
        {"categoria": "estudiante"},
        {"estado_habilitacion": "baja"},
        {"nombre": "Otro", "dni": "999", "categoria": "x"},
    ],
)
def test_un_dato_no_habilitado_es_403_y_no_modifica_nada(entorno, rep, cuerpo):
    """A4 y RN-026: el DNI lo cambia un administrador; si viene uno no habilitado no se aplica ninguno."""
    base, cliente, ids = entorno
    antes = _datos(base, ids["ana"])
    r = cliente.patch(f"{RUTA}/{ids['acme']}/pasajeros/{ids['ana']}", json=cuerpo, headers=rep)
    assert (r.status_code, r.json()["error"]["codigo"]) == (403, "DATO_NO_MODIFICABLE")
    assert set(r.json()["error"]["detalles"]["campos"]) <= {
        "dni",
        "categoria",
        "estado_habilitacion",
    }
    assert "nombre" in r.json()["error"]["detalles"]["campos_editables"]
    assert _datos(base, ids["ana"]) == antes
    assert (
        _uno(base, "SELECT estado_habilitacion FROM pasajero WHERE id_persona = $1", ids["ana"])
        == "habilitado"
    )


@pytest.mark.parametrize("cuerpo", [{}, {"nombre": None}, {"email": ""}, {"telefono": "x" * 31}])
def test_cuerpo_vacio_o_invalido_es_400(entorno, rep, cuerpo):
    base, cliente, ids = entorno
    antes = _datos(base, ids["ana"])
    r = cliente.patch(f"{RUTA}/{ids['acme']}/pasajeros/{ids['ana']}", json=cuerpo, headers=rep)
    assert (r.status_code, r.json()["error"]["codigo"]) == (400, "VALIDACION")
    assert _datos(base, ids["ana"]) == antes


@pytest.mark.parametrize("quien", ["de_otra_empresa", "sin_empresa", "inexistente"])
def test_un_pasajero_que_no_es_de_la_empresa_es_404_y_no_se_modifica(entorno, rep, quien):
    """A3: ni siquiera se distingue «existe pero es de otra empresa» de «no existe»."""
    base, cliente, ids = entorno
    id_pasajero = {"de_otra_empresa": ids["beto"], "sin_empresa": ids["cami"]}.get(quien, 999999)
    antes = _datos(base, id_pasajero) if quien != "inexistente" else None
    r = cliente.patch(
        f"{RUTA}/{ids['acme']}/pasajeros/{id_pasajero}", json={"nombre": "Hack"}, headers=rep
    )
    assert (r.status_code, r.json()["error"]["codigo"]) == (404, "PASAJERO_NO_ENCONTRADO")
    if antes:
        assert _datos(base, id_pasajero) == antes


def test_lo_ajeno_responde_404_antes_que_el_403_por_el_dni(entorno, rep):
    """Intentar el DNI de un pasajero ajeno no revela que existe: gana el 404."""
    _, cliente, ids = entorno
    r = cliente.patch(
        f"{RUTA}/{ids['acme']}/pasajeros/{ids['beto']}", json={"dni": "999"}, headers=rep
    )
    assert (r.status_code, r.json()["error"]["codigo"]) == (404, "PASAJERO_NO_ENCONTRADO")


def test_una_empresa_ajena_es_404_aunque_el_pasajero_exista(entorno, rep):
    """Beto es de Beta, pero el representante de Acme no representa a Beta."""
    base, cliente, ids = entorno
    antes = _datos(base, ids["beto"])
    r = cliente.patch(
        f"{RUTA}/{ids['beta']}/pasajeros/{ids['beto']}", json={"nombre": "Hack"}, headers=rep
    )
    assert (r.status_code, r.json()["error"]["codigo"]) == (404, "ORGANIZACION_NO_ENCONTRADA")
    assert _datos(base, ids["beto"]) == antes


def test_un_pasajero_de_dos_empresas_lo_puede_modificar_el_representante_de_cualquiera(
    entorno, rep
):
    """La spec no dice nada de este caso: queda documentado, no resuelto (ver el Issue)."""
    base, cliente, ids = entorno
    _vincular(base, ids["beta"], ids["ana"])
    r = cliente.patch(
        f"{RUTA}/{ids['beta']}/pasajeros/{ids['ana']}",
        json={"nombre": "Anita"},
        headers=_con(ids["rep_dos"], "representante_corporativo"),
    )
    assert r.status_code == 200
    assert _datos(base, ids["ana"])[0] == "Anita"


# --- contrato ------------------------------------------------------------------------------


def test_las_respuestas_coinciden_con_el_contrato(entorno, rep):
    _, cliente, ids = entorno
    esquemas = yaml.safe_load(CONTRATO.read_text(encoding="utf-8"))["components"]["schemas"]
    alta = cliente.post(
        f"{RUTA}/{ids['acme']}/pasajeros",
        json={
            "nombre": "N",
            "apellido": "A",
            "dni": "920",
            "email": "e@x.test",
            "telefono": "1",
            "direccion": "d",
        },
        headers=rep,
    ).json()
    assert set(alta) == set(esquemas["PasajeroOrganizacion"]["properties"])
    lista = cliente.get(f"{RUTA}/{ids['acme']}/pasajeros", headers=rep).json()
    assert set(lista) == set(esquemas["PasajeroOrganizacionLista"]["properties"])
    assert set(lista["items"][0]) <= set(esquemas["PasajeroOrganizacion"]["properties"])
    organizaciones = cliente.get(RUTA, headers=rep).json()
    assert set(organizaciones) == set(esquemas["OrganizacionLista"]["properties"])
    assert set(organizaciones["items"][0]) <= set(
        esquemas["OrganizacionRepresentada"]["properties"]
    )
