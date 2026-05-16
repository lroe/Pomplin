from typing import Any, List
from fastapi import APIRouter, Depends, HTTPException, status, Response
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.api.deps import get_current_user
from app.db.session import get_db
from app.models.user import User
from app.models.memory import UserMemory
from app.schemas.memory import UserMemory as UserMemorySchema, UserMemoryCreate

router = APIRouter()

@router.get("/", response_model=List[UserMemorySchema])
async def read_memories(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> Any:
    """Retrieve all memories for the current user."""
    result = await db.execute(select(UserMemory).where(UserMemory.user_id == current_user.id))
    return result.scalars().all()

@router.post("/", response_model=UserMemorySchema)
async def create_memory(
    *,
    db: AsyncSession = Depends(get_db),
    memory_in: UserMemoryCreate,
    current_user: User = Depends(get_current_user),
) -> Any:
    """Create a new memory manually."""
    memory = UserMemory(content=memory_in.content, user_id=current_user.id)
    db.add(memory)
    await db.commit()
    await db.refresh(memory)
    return memory

@router.delete("/{id}", status_code=status.HTTP_204_NO_CONTENT, response_class=Response)
async def delete_memory(
    *,
    db: AsyncSession = Depends(get_db),
    id: int,
    current_user: User = Depends(get_current_user),
):
    """Delete a memory."""
    result = await db.execute(select(UserMemory).where(UserMemory.id == id, UserMemory.user_id == current_user.id))
    memory = result.scalar_one_or_none()
    if not memory:
        raise HTTPException(status_code=404, detail="Memory not found")
    await db.delete(memory)
    await db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)
