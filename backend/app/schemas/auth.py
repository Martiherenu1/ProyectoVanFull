"""Entrada y salida de /auth. Los nombres son los del contrato (`LoginRequest`, `TokenResponse`)."""

from pydantic import BaseModel, Field


class LoginRequest(BaseModel):
    identificador_acceso: str = Field(min_length=1, max_length=120)
    password: str = Field(min_length=1, repr=False)


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    roles: list[str]
