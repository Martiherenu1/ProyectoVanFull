"""El seed (`backend/db/seed/`) carga sobre una base migrada y deja cuentas con las que se puede entrar."""

import asyncio
import csv

import pytest

from app.core.config import Settings
from db.seed import cargar as seed
from db.seed import generar_contrasenas
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


def test_carga_los_tres_escenarios_administrativos_del_30_de_octubre(base):
    _cargar(base)
    filas = asyncio.run(
        consultar(
            base,
            "SELECT v.id_viaje, v.horario::text, v.id_chofer, v.id_vehiculo, v.estado, "
            "v.capacidad_planificada, ve.capacidad "
            "FROM viaje v LEFT JOIN vehiculo ve USING (id_vehiculo) "
            "WHERE v.fecha = DATE '2026-10-30' ORDER BY v.id_viaje",
        )
    )
    assert filas == [
        (1, "07:30:00", 3, 1, "programado", 18, 20),
        (2, "12:30:00", None, 1, "programado", 18, 20),
        (3, "18:00:00", 3, None, "programado", 18, None),
    ]


def test_el_seed_es_compatible_con_cu018_y_cu029(base):
    _cargar(base)
    contrasenas = seed.leer_contrasenas(seed.CONTRASENAS)
    with cliente_api(base) as cliente:
        sesion_chofer = cliente.post(
            "/api/auth/login",
            json={
                "identificador_acceso": "chofer1@vanfull.test",
                "password": contrasenas["chofer1@vanfull.test"],
            },
        )
        viajes = cliente.get(
            "/api/choferes/me/viajes",
            params={"fecha": "2026-10-30"},
            headers={"Authorization": f"Bearer {sesion_chofer.json()['access_token']}"},
        )
        assert viajes.status_code == 200
        assert [viaje["id_viaje"] for viaje in viajes.json()] == [1, 3]

        sesion_admin = cliente.post(
            "/api/auth/login",
            json={
                "identificador_acceso": "admin1@vanfull.test",
                "password": contrasenas["admin1@vanfull.test"],
            },
        )
        creado = cliente.post(
            "/api/viajes",
            json={
                "id_servicio": 1,
                "id_recorrido": 1,
                "fecha": "2026-10-31",
                "sentido": "IDA",
            },
            headers={"Authorization": f"Bearer {sesion_admin.json()['access_token']}"},
        )
        assert creado.status_code == 201
        assert creado.json()["id_viaje"] == 4


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


NEON = "postgresql://u:p@ep-algo.neon.tech/x"


def _cargar_falso(llamado: list):
    async def falso(*args, **kwargs):
        llamado.append(kwargs)
        return {}

    return falso


def test_con_la_bandera_y_las_contrasenas_del_repo_tampoco_carga(monkeypatch, capsys):
    """`--permitir-base-remota` sin `--contrasenas` sembraría las contraseñas públicas."""
    monkeypatch.setattr(seed, "_dsn_de_settings", lambda: NEON)
    llamado = []
    monkeypatch.setattr(seed, "cargar", _cargar_falso(llamado))
    assert seed.main(["--permitir-base-remota"]) == 2
    archivo_del_repo = str(seed.CARPETA / "otras.csv")
    assert seed.main(["--permitir-base-remota", "--contrasenas", archivo_del_repo]) == 2
    assert not llamado
    assert "fuera del repositorio" in capsys.readouterr().err


def test_con_la_bandera_y_un_archivo_propio_carga_en_la_base_remota(monkeypatch, tmp_path):
    propio = tmp_path / "contrasenas-demo.csv"
    monkeypatch.setattr(seed, "_dsn_de_settings", lambda: NEON)
    llamado = []
    monkeypatch.setattr(seed, "cargar", _cargar_falso(llamado))
    assert seed.main(["--permitir-base-remota", "--contrasenas", str(propio)]) == 0
    assert llamado == [{"reiniciar": False, "archivo_contrasenas": propio}]


def test_la_dsn_del_seed_traduce_ssl_a_sslmode(monkeypatch):
    """La configuración deja `ssl` (SQLAlchemy); la DSN de asyncpg necesita `sslmode`."""
    ajustes = Settings(
        _env_file=None, database_url=f"{NEON}?sslmode=require&channel_binding=require"
    )
    monkeypatch.setattr(seed, "get_settings", lambda: ajustes)
    assert seed._dsn_de_settings() == f"{NEON}?sslmode=require"


# --- Contraseñas para la base de la demo ---------------------------------------------------


def test_genera_una_contrasena_nueva_por_cuenta(tmp_path, capsys):
    destino = tmp_path / "demo.csv"
    assert generar_contrasenas.main([str(destino)]) == 0
    generadas = seed.leer_contrasenas(destino)
    publicas = seed.leer_contrasenas(seed.CONTRASENAS)
    assert set(generadas) == set(CUENTAS)
    assert len(set(generadas.values())) == len(generadas)
    assert not set(generadas.values()) & set(publicas.values())
    salida = capsys.readouterr().out
    assert not any(c in salida for c in generadas.values()), "no debe imprimir las contraseñas"


def test_las_contrasenas_generadas_sirven_para_el_cargador(tmp_path):
    destino = tmp_path / "demo.csv"
    generar_contrasenas.generar(destino)
    assert seed._filas_a_cargar(destino)["cuenta_acceso"][0]["hash_contrasena"].startswith("$2")


def test_no_genera_dentro_del_repo_ni_pisa_un_archivo(tmp_path):
    with pytest.raises(ValueError, match="fuera del repositorio"):
        generar_contrasenas.generar(seed.CARPETA / "demo.csv")
    assert not (seed.CARPETA / "demo.csv").exists()
    existente = tmp_path / "demo.csv"
    existente.write_text("no tocar", encoding="utf-8")
    with pytest.raises(ValueError, match="ya existe"):
        generar_contrasenas.generar(existente)
    assert existente.read_text(encoding="utf-8") == "no tocar"
