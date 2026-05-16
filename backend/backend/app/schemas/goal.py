from pydantic import BaseModel, ConfigDict
from typing import Optional, Any
from datetime import datetime
from app.models.goal import GoalType


class GoalBase(BaseModel):
    title: str
    description: str
    goal_type: GoalType = GoalType.linear


class GoalCreate(GoalBase):
    pass


class GoalUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    goal_type: Optional[GoalType] = None
    roadmap: Optional[Any] = None


class GoalInDB(GoalBase):
    id: int
    user_id: int
    roadmap: Optional[Any] = None
    created_at: datetime
    updated_at: Optional[datetime] = None
    model_config = ConfigDict(from_attributes=True)


class Goal(GoalInDB):
    pass


class GoalWithRoadmap(GoalInDB):
    roadmap: Optional[Any] = None
