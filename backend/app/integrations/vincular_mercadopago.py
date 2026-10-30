"""D2 candidato: alta local explícita; sin endpoint, creación de pagos ni bypass HMAC.

Uso local: python -m app.integrations.vincular_mercadopago --id-pago N --id-operacion ID
Requiere habilitación explícita y DB vf_sandbox_/vf_test_; no aplica migraciones.
"""

import argparse
import asyncio

import httpx
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.core.config import get_settings
from app.core.errors import ApiError
from app.integrations.mercadopago import ClienteMercadoPagoPruebas, ErrorMercadoPago
from app.services.mercadopago_sandbox import exigir_habilitado, vincular_operacion


async def ejecutar(id_pago: int, id_operacion: str) -> str:
    ajustes = get_settings()
    exigir_habilitado(ajustes)
    motor = create_async_engine(ajustes.database_url, echo=False)
    try:
        async with (
            async_sessionmaker(motor, expire_on_commit=False)() as db,
            httpx.AsyncClient(follow_redirects=False) as cliente,
        ):
            return await vincular_operacion(
                db,
                id_operacion=id_operacion,
                id_pago=id_pago,
                proveedor=ClienteMercadoPagoPruebas(cliente, ajustes.mercadopago_access_token),
                ajustes=ajustes,
            )
    finally:
        await motor.dispose()


def main() -> None:
    parser = argparse.ArgumentParser(description="Vínculo explícito sandbox estricto CU-036")
    parser.add_argument("--id-pago", required=True, type=int)
    parser.add_argument("--id-operacion", required=True)
    args = parser.parse_args()
    try:
        resultado = asyncio.run(ejecutar(args.id_pago, args.id_operacion))
    except (ApiError, ErrorMercadoPago):
        parser.exit(
            1, "No se pudo vincular la operación. Sin cambios contables; verificar entorno/datos.\n"
        )
    except Exception:
        parser.exit(
            1, "No se pudo completar el vínculo. No imprimir configuración ni excepciones crudas.\n"
        )
    print(resultado)


if __name__ == "__main__":
    main()
