from pydantic import BaseModel


class VaultResponseSchema(BaseModel):
    id: int
    name: str
    introduction: str
    offlineCapSeconds: float
    offlineEfficiency: float
