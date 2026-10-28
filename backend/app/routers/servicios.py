"""Consulta pública de servicios, disponibilidad y paradas (CU-002).

El contrato las declara sin autenticación (`security: []`): la disponibilidad se consulta antes de
tener una cuenta. Por eso acá no hay `requiere_rol`.
"""

from datetime import date
from typing import Literal

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.schemas.servicios import Disponibilidad, Parada, Servicio
from app.services import disponibilidad as disponibilidad_servicio
from app.services import servicios as servicio

router = APIRouter(tags=["servicios"])

# exclude_none: lo que no se puede determinar no aparece, en vez de ir como null (el contrato declara
# estos campos sin `nullable`).


@router.get("/servicios", response_model=list[Servicio])
async def listar_servicios(db: AsyncSession = Depends(get_db)):
    return await servicio.listar_servicios(db)


@router.get(
    "/servicios/disponibilidad",
    response_model=list[Disponibilidad],
    response_model_exclude_none=True,
)
async def consultar_disponibilidad(
    fecha: date,
    sentido: Literal["IDA", "VUELTA"],
    destino: str | None = Query(default=None),
    id_recorrido: int | None = Query(default=None),
    id_parada_destino: int | None = Query(default=None),
    db: AsyncSession = Depends(get_db),
):
    return await disponibilidad_servicio.consultar_disponibilidad(
        db,
        fecha=fecha,
        sentido=sentido,
        id_recorrido=id_recorrido,
        destino=destino,
        id_parada_destino=id_parada_destino,
    )


@router.get(
    "/recorridos/{id_recorrido}/paradas",
    response_model=list[Parada],
    response_model_exclude_none=True,
)
async def paradas_de_recorrido(id_recorrido: int, db: AsyncSession = Depends(get_db)):
    return await servicio.paradas_de_recorrido(db, id_recorrido)
