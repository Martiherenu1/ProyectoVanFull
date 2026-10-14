"""El contrato OpenAPI es válido y `openapi.json` es el mismo contrato que `openapi.yaml`.

backend/openapi/README.md: el YAML es la fuente y el JSON se genera de él. CONTRIBUTING §1.5: si se
toca el YAML hay que regenerar el JSON y validar ambos. Esta prueba lo hace cumplir.
"""

import json
from pathlib import Path

import pytest
import yaml
from openapi_spec_validator import validate

OPENAPI = Path(__file__).resolve().parents[1] / "openapi"


@pytest.fixture(scope="module")
def desde_yaml() -> dict:
    return yaml.safe_load((OPENAPI / "openapi.yaml").read_text(encoding="utf-8"))


@pytest.fixture(scope="module")
def desde_json() -> dict:
    return json.loads((OPENAPI / "openapi.json").read_text(encoding="utf-8"))


def test_el_yaml_es_un_contrato_valido(desde_yaml):
    validate(desde_yaml)


def test_el_json_es_un_contrato_valido(desde_json):
    validate(desde_json)


def test_el_json_es_equivalente_al_yaml(desde_yaml, desde_json):
    assert desde_json == desde_yaml, (
        "openapi.json no coincide con openapi.yaml: regenerarlo con el comando de "
        "backend/openapi/README.md"
    )
