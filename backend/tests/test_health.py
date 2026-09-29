"""Test básico de humo: la raíz responde y las tools de AG-01 están bien definidas."""
from fastapi.testclient import TestClient

from app.agent.tools import TOOLS
from app.main import app

client = TestClient(app)

# Canario de deriva: si se agrega o saca una tool, este número tiene que moverse
# junto con la documentación (07-IA-y-Agentes-Consolidado.md y el documento del MVC).
CANTIDAD_TOOLS_ESPERADA = 13


def test_root_ok():
    resp = client.get("/")
    assert resp.status_code == 200
    assert resp.json()["service"] == "vanfull-api"


def test_ag01_tiene_las_tools_esperadas():
    assert len(TOOLS) == CANTIDAD_TOOLS_ESPERADA
    nombres = {t["function"]["name"] for t in TOOLS}
    assert len(nombres) == CANTIDAD_TOOLS_ESPERADA, "hay tools con el nombre repetido"
    assert "crear_reserva" in nombres
    assert "derivar_humano" in nombres
