"""
Goals API — Phase 2
- POST /goals         → create goal + AI roadmap generation
- GET  /goals         → list all user goals
- GET  /goals/{id}    → fetch specific goal with roadmap
- PUT  /goals/{id}    → update goal details (regenerate roadmap if desc changes)
- DELETE /goals/{id}  → delete goal + all its tasks
"""
from typing import Any
from fastapi import APIRouter, Depends, HTTPException, status, Response
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.api.deps import get_current_user
from app.db.session import get_db
from app.models.goal import Goal
from app.models.user import User
from app.schemas.goal import GoalCreate, GoalUpdate, Goal as GoalSchema, GoalWithRoadmap
from app.services.gemini import generate_roadmap

router = APIRouter()


@router.post("", response_model=GoalWithRoadmap, status_code=status.HTTP_201_CREATED)
async def create_goal(
    *,
    db: AsyncSession = Depends(get_db),
    goal_in: GoalCreate,
    current_user: User = Depends(get_current_user),
) -> Any:
    """Create a new goal and generate its AI roadmap."""
    # Generate roadmap via Gemini
    roadmap = await generate_roadmap(goal_in.description, goal_in.goal_type.value)

    db_goal = Goal(
        user_id=current_user.id,
        title=goal_in.title,
        description=goal_in.description,
        goal_type=goal_in.goal_type,
        roadmap=roadmap,
    )
    db.add(db_goal)
    await db.commit()
    await db.refresh(db_goal)
    return db_goal


@router.get("", response_model=list[GoalSchema])
async def list_goals(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> Any:
    """List all goals for the current user."""
    result = await db.execute(
        select(Goal).where(Goal.user_id == current_user.id).order_by(Goal.created_at.desc())
    )
    return result.scalars().all()


@router.get("/{goal_id}", response_model=GoalWithRoadmap)
async def get_goal(
    goal_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> Any:
    """Fetch a specific goal with its roadmap."""
    result = await db.execute(
        select(Goal).where(Goal.id == goal_id, Goal.user_id == current_user.id)
    )
    goal = result.scalar_one_or_none()
    if not goal:
        raise HTTPException(status_code=404, detail="Goal not found")
    return goal


@router.put("/{goal_id}", response_model=GoalWithRoadmap)
async def update_goal(
    goal_id: int,
    *,
    db: AsyncSession = Depends(get_db),
    goal_in: GoalUpdate,
    current_user: User = Depends(get_current_user),
) -> Any:
    """
    Update a goal. If description changes, regenerates the roadmap via AI.
    You can also directly patch the roadmap JSON without AI.
    """
    result = await db.execute(
        select(Goal).where(Goal.id == goal_id, Goal.user_id == current_user.id)
    )
    goal = result.scalar_one_or_none()
    if not goal:
        raise HTTPException(status_code=404, detail="Goal not found")

    description_changed = goal_in.description and goal_in.description != goal.description

    # Apply all updates
    if goal_in.title is not None:
        goal.title = goal_in.title
    if goal_in.description is not None:
        goal.description = goal_in.description
    if goal_in.goal_type is not None:
        goal.goal_type = goal_in.goal_type
    if goal_in.roadmap is not None:
        goal.roadmap = goal_in.roadmap

    # If description changed and no manual roadmap supplied, regenerate
    if description_changed and goal_in.roadmap is None:
        goal.roadmap = await generate_roadmap(
            goal.description,
            goal.goal_type.value
        )

    await db.commit()
    await db.refresh(goal)
    return goal


@router.post("/{goal_id}/regenerate-roadmap", response_model=GoalWithRoadmap)
async def regenerate_roadmap(
    goal_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> Any:
    """Force-regenerate the AI roadmap for an existing goal."""
    result = await db.execute(
        select(Goal).where(Goal.id == goal_id, Goal.user_id == current_user.id)
    )
    goal = result.scalar_one_or_none()
    if not goal:
        raise HTTPException(status_code=404, detail="Goal not found")

    goal.roadmap = await generate_roadmap(goal.description, goal.goal_type.value)
    await db.commit()
    await db.refresh(goal)
    return goal


@router.delete("/{goal_id}", status_code=status.HTTP_204_NO_CONTENT, response_class=Response)
async def delete_goal(
    goal_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> None:
    """Delete a goal and all its associated tasks."""
    result = await db.execute(
        select(Goal).where(Goal.id == goal_id, Goal.user_id == current_user.id)
    )
    goal = result.scalar_one_or_none()
    if not goal:
        raise HTTPException(status_code=404, detail="Goal not found")

    await db.delete(goal)
    await db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)
