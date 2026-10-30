"""Contrato candidato D3, sin datos del pagador en schemas/salidas."""

from typing import Annotated

from pydantic import BaseModel, ConfigDict, Field, StrictBool, StrictInt, StrictStr


class DatosNotificacionMP(BaseModel):
    model_config = ConfigDict(extra="ignore")
    id: Annotated[StrictStr, Field(pattern=r"^[0-9]{1,64}$")] | Annotated[StrictInt, Field(ge=0)]


class NotificacionMP(BaseModel):
    model_config = ConfigDict(extra="ignore")
    type: str = Field(max_length=32)
    live_mode: StrictBool
    data: DatosNotificacionMP
