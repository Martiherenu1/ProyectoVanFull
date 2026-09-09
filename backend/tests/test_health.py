"""Test básico de humo: la raíz responde y las 11 tools de AG-01 están definidas."""
from fastapi.testclient import TestClient

from app.agent.tools import TOOLS
from app.main import app

client = TestClient(app)


def test_root_ok():
    resp = client.get("/")
    assert resp.status_code == 200
    assert resp.json()["service"] == "vanfull-api"


def test_ag01_tiene_11_tools():
    assert len(TOOLS) == 11
    nombres = {t["function"]["name"] for t in TOOLS}
    assert "crear_reserva" in nombres
    assert "derivar_humano" in nombres
