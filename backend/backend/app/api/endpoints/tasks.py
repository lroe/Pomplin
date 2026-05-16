"""
Tasks API — Phase 3
- GET  /tasks/today          → today's tasks for the user
- GET  /tasks/momentum       → 7-day completion stats
- GET  /tasks/goal/{goal_id} → all tasks for a specific goal
- PATCH /tasks/{id}          → mark completed or skipped
- POST  /tasks/generate-today → manually trigger today's task generation
"""
from typing import Any
from datetime import date, timedelta
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func

from app.api.deps import get_current_user
from app.db.session import get_db
from app.models.task import Task
from app.models.goal import Goal
from app.models.user import User
from app.schemas.task import Task as TaskSchema, TaskUpdate, MomentumStats
from app.services.scheduler import _extract_todays_tasks

router = APIRouter()


@router.get("/today", response_model=list[TaskSchema])
async def get_todays_tasks(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> Any:
    """Get all tasks for today for the current user."""
    today = date.today()
    result = await db.execute(
        select(Task).where(
            Task.user_id == current_user.id,
            Task.date == today,
        ).order_by(Task.created_at)
    )
    return result.scalars().all()


@router.get("/momentum", response_model=MomentumStats)
async def get_momentum(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> Any:
    """Get 7-day momentum/completion stats."""
    today = date.today()
    week_ago = today - timedelta(days=7)

    result = await db.execute(
        select(Task).where(
            Task.user_id == current_user.id,
            Task.date >= week_ago,
            Task.date <= today,
        )
    )
    tasks = result.scalars().all()

    total = len(tasks)
    completed = sum(1 for t in tasks if t.completed)
    rate = round(completed / total, 2) if total > 0 else 0.0

    # Calculate streak: consecutive days with at least one completed task
    streak = 0
    for i in range(7):
        check_date = today - timedelta(days=i)
        day_tasks = [t for t in tasks if t.date == check_date]
        if any(t.completed for t in day_tasks):
            streak += 1
        else:
            break

    return MomentumStats(
        total_tasks_last_7_days=total,
        completed_tasks_last_7_days=completed,
        completion_rate=rate,
        current_streak=streak,
    )


@router.get("/goal/{goal_id}", response_model=list[TaskSchema])
async def get_tasks_by_goal(
    goal_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> Any:
    """Get all tasks for a specific goal."""
    result = await db.execute(
        select(Task).where(
            Task.goal_id == goal_id,
            Task.user_id == current_user.id,
        ).order_by(Task.date.desc())
    )
    return result.scalars().all()


@router.patch("/{task_id}", response_model=TaskSchema)
async def update_task(
    task_id: int,
    *,
    db: AsyncSession = Depends(get_db),
    task_in: TaskUpdate,
    current_user: User = Depends(get_current_user),
) -> Any:
    """Mark a task as completed or skipped."""
    result = await db.execute(
        select(Task).where(Task.id == task_id, Task.user_id == current_user.id)
    )
    task = result.scalar_one_or_none()
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")

    if task_in.completed is not None:
        task.completed = task_in.completed
        if task_in.completed:
            task.skipped = False  # Can't be both
    if task_in.skipped is not None:
        task.skipped = task_in.skipped
        if task_in.skipped:
            task.completed = False

    await db.commit()
    await db.refresh(task)
    return task


@router.post("/generate-today", response_model=list[TaskSchema])
async def generate_today_manually(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> Any:
    """
    Manually trigger today's task generation for the current user.
    Useful for testing or if the scheduler missed the user.
    """
    today = date.today()

    # Check if already generated
    existing_result = await db.execute(
        select(Task).where(
            Task.user_id == current_user.id,
            Task.date == today,
        )
    )
    existing = existing_result.scalars().all()
    if existing:
        return existing  # Already done

    # Fetch all user goals with roadmaps
    goals_result = await db.execute(
        select(Goal).where(
            Goal.user_id == current_user.id,
            Goal.roadmap.isnot(None),
        )
    )
    goals = goals_result.scalars().all()

    new_tasks = []
    for goal in goals:
        task_data_list = _extract_todays_tasks(goal, today)
        for task_data in task_data_list:
            task = Task(
                goal_id=goal.id,
                user_id=current_user.id,
                title=task_data["title"],
                description=task_data.get("description", ""),
                date=today,
                completed=False,
                skipped=False,
            )
            db.add(task)
            new_tasks.append(task)

    await db.commit()
    for t in new_tasks:
        await db.refresh(t)

    return new_tasks
