from pydantic import BaseModel, ConfigDict
from typing import Optional
from datetime import datetime


class ChatMessageSchema(BaseModel):
    role: str
    content: str
    created_at: Optional[datetime] = None
    model_config = ConfigDict(from_attributes=True)


class ChatSessionSchema(BaseModel):
    id: int
    user_id: int
    goal_id: Optional[int] = None
    created_at: datetime
    model_config = ConfigDict(from_attributes=True)


class ChatSessionWithMessages(ChatSessionSchema):
    messages: list[ChatMessageSchema] = []


class WSIncomingMessage(BaseModel):
    content: str
    goal_id: Optional[int] = None


class WSOutgoingMessage(BaseModel):
    role: str
    content: str
    session_id: int
