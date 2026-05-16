from pydantic import BaseModel, ConfigDict
from typing import Optional
from datetime import datetime, date


class TaskBase(BaseModel):
    title: str
    description: Optional[str] = None
    date: date


class TaskCreate(TaskBase):
    goal_id: int
    user_id: int


class TaskUpdate(BaseModel):
    completed: Optional[bool] = None
    skipped: Optional[bool] = None


class TaskInDB(TaskBase):
    id: int
    goal_id: int
    user_id: int
    completed: bool
    skipped: bool
    created_at: datetime
    model_config = ConfigDict(from_attributes=True)


class Task(TaskInDB):
    pass


class MomentumStats(BaseModel):
    total_tasks_last_7_days: int
    completed_tasks_last_7_days: int
    completion_rate: float
    current_streak: int
