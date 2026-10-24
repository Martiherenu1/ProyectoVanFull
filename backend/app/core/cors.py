"""Qué orígenes pueden llamar a la API desde un navegador (Flutter Web)."""

from app.core.config import Settings

# `flutter run -d chrome` sirve la app en un puerto distinto cada vez.
LOCALHOST_CUALQUIER_PUERTO = r"https?://(localhost|127\.0\.0\.1)(:\d+)?"


def opciones_cors(ajustes: Settings) -> dict:
    """Argumentos de origen para `CORSMiddleware`.

    Con `CORS_ORIGINS` se permiten exactamente esos orígenes. Sin la variable, en desarrollo se
    permite localhost; fuera de desarrollo la API no arranca, igual que sin `JWT_SECRET`.
    """
    origenes = [o.strip().rstrip("/") for o in ajustes.cors_origins.split(",") if o.strip()]
    if "*" in origenes:
        raise RuntimeError("CORS_ORIGINS no admite '*': listar los orígenes, separados por comas.")
    if origenes:
        return {"allow_origins": origenes}
    if ajustes.env == "development":
        return {"allow_origin_regex": LOCALHOST_CUALQUIER_PUERTO}
    raise RuntimeError(
        "Falta CORS_ORIGINS: el origen de Flutter Web (por ejemplo https://martiherenu1.github.io)."
    )
