from pydantic import BaseModel


class RegistrarResponseSchema(BaseModel):
    id: int
    name: str
    introduction: str
    accessTokenTtlSeconds: int
