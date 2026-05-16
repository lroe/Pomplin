from typing import Optional
from pydantic import BaseModel
from datetime import datetime

class UserMemoryBase(BaseModel):
    content: str

class UserMemoryCreate(UserMemoryBase):
    pass

class UserMemory(UserMemoryBase):
    id: int
    user_id: int
    created_at: datetime

    class Config:
        from_attributes = True
