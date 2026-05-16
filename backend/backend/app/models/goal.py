from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, JSON, Enum as PgEnum
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
import enum
from app.db.base_class import Base

class GoalType(str, enum.Enum):
    linear = "linear"
    cyclic = "cyclic"

class Goal(Base):
    __tablename__ = "goals"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    title = Column(String, nullable=False)
    description = Column(String, nullable=False)
    goal_type = Column(PgEnum(GoalType, name="goaltype"), nullable=False, default=GoalType.linear)
    roadmap = Column(JSON, nullable=True)  # Structured roadmap from Gemini
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    # Relationships
    user = relationship("User", back_populates="goals")
    tasks = relationship("Task", back_populates="goal", cascade="all, delete-orphan")
