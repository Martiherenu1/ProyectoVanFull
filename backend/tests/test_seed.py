"""El seed (`backend/db/seed/`) carga sobre una base migrada y deja cuentas con las que se puede entrar."""

import asyncio
import csv

import pytest

from db.seed import cargar as seed
from tests._bd import base_migrada, base_temporal, cliente_api, consultar, ejecutar_sql, url_de

CUENTAS = {  # identificador_acceso -> roles esperados
    "pasajero1@vanfull.test": ["pasajero"],
    "pasajero2@vanfull.test": ["pasajero"],
    "chofer1@vanfull.test": ["chofer"],
    "admin1@vanfull.test": ["administrador"],
}


def _dsn(base: str) -> str:
    return url_de(base).set(drivername="postgresql").render_as_string(hide_password=False)


def _cargar(base: str, **opciones) -> dict[str, int]:
    return asyncio.run(seed.cargar(_dsn(base), **opciones))


def _uno(base: str, consulta: str, *parametros):
    return asyncio.run(consultar(base, consulta, *parametros))[0][0]


@pytest.fixture
def base():
    with base_migrada() as nombre:
        yield nombre


# --- Los archivos ---------------------------------------------------------------------------


def test_cada_csv_esta_en_el_orden_de_carga_y_viceversa():
    en_carpeta = {p.stem for p in seed.CARPETA.glob("*.csv")} - {"contrasenas-de-prueba"}
    assert en_carpeta == set(seed.ORDEN)


def test_hay_una_contrasena_por_cuenta_sembrada():
    cuentas = {f["identificador_acceso"] for f in seed.leer_csv("cuenta_acceso")}
    assert cuentas == set(CUENTAS)
    assert cuentas <= set(seed.leer_contrasenas(seed.CONTRASENAS))


def test_el_csv_de_cuentas_no_trae_hashes_ni_contrasenas():
    """El hash se calcula al cargar: nada que parezca una credencial en los CSV de datos."""
    with (seed.CARPETA / "cuenta_acceso.csv").open(encoding="utf-8") as archivo:
        assert "hash_contrasena" not in next(csv.reader(archivo))


# --- La carga -------------------------------------------------------------------------------


def test_carga_las_tablas_y_devuelve_la_cantidad(base):
    resumen = _cargar(base)
    assert resumen["persona"] == 4
    assert resumen["cuenta_rol"] == 4
    for tabla, cantidad in resumen.items():
        assert _uno(base, f'SELECT count(*) FROM "{tabla}"') == cantidad


def test_las_cuentas_quedan_con_hash_y_con_su_rol(base):
    _cargar(base)
    contrasenas = seed.leer_contrasenas(seed.CONTRASENAS)
    for identificador, roles in CUENTAS.items():
        hash_guardado = _uno(
            base,
            "SELECT hash_contrasena FROM cuenta_acceso WHERE identificador_acceso = $1",
            identificador,
        )
        assert hash_guardado.startswith("$2")  # bcrypt
        assert hash_guardado != contrasenas[identificador]
        obtenidos = asyncio.run(
            consultar(
                base,
                "SELECT r.rol FROM cuenta_rol cr "
                "JOIN cuenta_acceso c USING (id_cuenta_acceso) "
                "JOIN rol_acceso r USING (id_rol_acceso) "
                "WHERE c.identificador_acceso = $1 ORDER BY r.id_rol_acceso",
                identificador,
            )
        )
        assert [f[0] for f in obtenidos] == roles


def test_se_puede_iniciar_sesion_con_cada_cuenta_sembrada(base):
    """Prueba de punta a punta: el seed, el hash y el login cuentan la misma historia."""
    _cargar(base)
    contrasenas = seed.leer_contrasenas(seed.CONTRASENAS)
    with cliente_api(base) as cliente:
        for identificador, roles in CUENTAS.items():
            respuesta = cliente.post(
                "/api/auth/login",
                json={
                    "identificador_acceso": identificador,
                    "password": contrasenas[identificador],
                },
            )
            assert respuesta.status_code == 200, identificador
            assert respuesta.json()["roles"] == roles


def test_las_secuencias_siguen_despues_de_la_carga(base):
    """Con ids explícitos la secuencia quedaría en 1 y el próximo INSERT chocaría."""
    _cargar(base)
    nuevo = _uno(
        base,
        "INSERT INTO persona (nombre, apellido, dni) VALUES ('Nueva', 'Persona', '90000099') "
        "RETURNING id_persona",
    )
    assert nuevo == 5


def test_la_carga_es_todo_o_nada(base, tmp_path):
    """Si falla a mitad de camino no queda nada: falta la contraseña de una cuenta."""
    incompleto = tmp_path / "contrasenas.csv"
    incompleto.write_text(
        "identificador_acceso,contrasena\npasajero1@vanfull.test,x\n", encoding="utf-8"
    )
    with pytest.raises(seed.ErrorSeed, match="Falta la contraseña"):
        _cargar(base, archivo_contrasenas=incompleto)
    assert _uno(base, "SELECT count(*) FROM persona") == 0


def test_no_carga_dos_veces_sin_pedirlo(base):
    _cargar(base)
    with pytest.raises(seed.ErrorSeed, match="--reiniciar"):
        _cargar(base)
    assert _uno(base, "SELECT count(*) FROM persona") == 4


def test_con_reiniciar_deja_el_mismo_estado(base):
    primero = _cargar(base)
    asyncio.run(ejecutar_sql(base, "UPDATE persona SET nombre = 'Cambiado' WHERE id_persona = 1"))
    segundo = _cargar(base, reiniciar=True)
    assert primero == segundo
    assert _uno(base, "SELECT nombre FROM persona WHERE id_persona = 1") == "Pasajera"


def test_no_corre_si_la_base_no_esta_migrada():
    """Sin migrar no existe rol_acceso: el mensaje dice qué hacer, no es un traceback."""
    with base_temporal() as vacia, pytest.raises(seed.ErrorSeed, match="migraciones"):
        _cargar(vacia)


# --- La protección contra bases remotas -----------------------------------------------------


@pytest.mark.parametrize(
    ("dsn", "esperado"),
    [
        ("postgresql://u:p@localhost:5432/vanfull", True),
        ("postgresql://u:p@db:5432/vanfull", True),
        ("postgresql://u:p@127.0.0.1/vanfull", True),
        ("postgresql://u:p@ep-algo.neon.tech/vanfull", False),
        ("postgresql://u:p@dpg-123.render.com/vanfull", False),
    ],
)
def test_solo_se_considera_local_la_base_de_desarrollo(dsn, esperado):
    assert seed.es_base_local(dsn) is esperado


def test_main_se_niega_a_cargar_en_una_base_remota(monkeypatch, capsys):
    monkeypatch.setattr(seed, "_dsn_de_settings", lambda: "postgresql://u:p@ep-algo.neon.tech/x")
    llamado = []
    monkeypatch.setattr(seed, "cargar", lambda *a, **k: llamado.append(1))
    assert seed.main([]) == 2
    assert not llamado, "no debería ni intentar conectarse"
    assert "no local" in capsys.readouterr().err
