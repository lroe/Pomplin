# Import all the models, so that Base has them before being
# imported by Alembic
from app.db.base_class import Base  # noqa
from app.models.user import User  # noqa
from app.models.goal import Goal  # noqa
from app.models.task import Task  # noqa
from app.models.chat import ChatSession, ChatMessage  # noqa
from app.models.memory import UserMemory  # noqa
