from pydantic import BaseModel


class CuratorResponseSchema(BaseModel):
    id: int
    name: str
    introduction: str
    monsterCount: int
    maxStars: int
