"""Error uniforme de la API.

El contrato (`openapi.yaml`, schema `Error`) fija el cuerpo de todo error:

    {"error": {"codigo": "CUPO_NO_DISPONIBLE", "mensaje": "...", "detalles": {...}}}

Los servicios no conocen HTTP: levantan `ApiError` con el estado y un `codigo` estable (el que
usa el cliente para decidir qué mostrar) y estos manejadores lo convierten a la respuesta.
Los errores que genera FastAPI solo (falta de token, ruta inexistente, cuerpo inválido) pasan
por los mismos manejadores, así el cliente recibe siempre la misma forma.
"""

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

# Código estable para los errores HTTP que no levanta un servicio.
_CODIGOS_HTTP = {
    401: "NO_AUTENTICADO",
    403: "SIN_PERMISO",
    404: "NO_ENCONTRADO",
    405: "METODO_NO_PERMITIDO",
}


class ApiError(Exception):
    """Error de negocio o de acceso, con la forma del contrato."""

    def __init__(
        self,
        status_code: int,
        codigo: str,
        mensaje: str,
        detalles: dict | None = None,
        headers: dict[str, str] | None = None,
    ):
        super().__init__(mensaje)
        self.status_code = status_code
        self.codigo = codigo
        self.mensaje = mensaje
        self.detalles = detalles
        self.headers = headers


def _respuesta(status_code: int, codigo: str, mensaje: str, detalles=None, headers=None):
    error: dict = {"codigo": codigo, "mensaje": mensaje}
    if detalles:
        error["detalles"] = detalles
    return JSONResponse(status_code=status_code, content={"error": error}, headers=headers)


async def _manejar_api_error(_: Request, exc: ApiError):
    return _respuesta(exc.status_code, exc.codigo, exc.mensaje, exc.detalles, exc.headers)


async def _manejar_http(_: Request, exc: StarletteHTTPException):
    codigo = _CODIGOS_HTTP.get(exc.status_code, "ERROR_HTTP")
    return _respuesta(exc.status_code, codigo, str(exc.detail), headers=exc.headers)


async def _manejar_validacion(_: Request, exc: RequestValidationError):
    # Solo el campo y el motivo. Nunca el valor recibido: podría ser una contraseña.
    errores = [
        {"campo": ".".join(str(p) for p in e["loc"][1:]) or "cuerpo", "mensaje": e["msg"]}
        for e in exc.errors()
    ]
    # El contrato usa 400 para validación (FastAPI usaría 422 por defecto).
    return _respuesta(400, "VALIDACION", "Los datos enviados no son válidos.", {"errores": errores})


def registrar_manejadores(app: FastAPI) -> None:
    app.add_exception_handler(ApiError, _manejar_api_error)
    app.add_exception_handler(StarletteHTTPException, _manejar_http)
    app.add_exception_handler(RequestValidationError, _manejar_validacion)
