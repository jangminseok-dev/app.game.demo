from pydantic import BaseModel


class AlmanacResponseSchema(BaseModel):
    id: int
    name: str
    introduction: str
    balanceVersion: int
