"""
APScheduler service — Phase 3
Runs a daily job to generate today's tasks for all users from their active goals.
"""
from datetime import date, timedelta
from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.cron import CronTrigger
import asyncio
import logging

logger = logging.getLogger(__name__)

scheduler = AsyncIOScheduler()


async def generate_daily_tasks_job():
    """
    Called every day at midnight. For each user+goal combo,
    generate tasks for today based on the roadmap.
    """
    from app.db.session import SessionLocal
    from app.models.goal import Goal, GoalType
    from app.models.task import Task
    from sqlalchemy import select

    logger.info("Running daily task generation job...")

    async with SessionLocal() as db:
        try:
            today = date.today()

            # Fetch all goals that have a roadmap
            result = await db.execute(
                select(Goal).where(Goal.roadmap.isnot(None))
            )
            goals = result.scalars().all()

            tasks_created = 0
            for goal in goals:
                # Check if tasks already exist for this goal today
                existing = await db.execute(
                    select(Task).where(
                        Task.goal_id == goal.id,
                        Task.date == today
                    )
                )
                if existing.scalar_one_or_none():
                    continue  # Already generated for today

                new_tasks = _extract_todays_tasks(goal, today)
                for task_data in new_tasks:
                    task = Task(
                        goal_id=goal.id,
                        user_id=goal.user_id,
                        title=task_data["title"],
                        description=task_data.get("description", ""),
                        date=today,
                        completed=False,
                        skipped=False,
                    )
                    db.add(task)
                    tasks_created += 1

            await db.commit()
            logger.info(f"Daily task generation complete: {tasks_created} tasks created.")

        except Exception as e:
            logger.error(f"Daily task generation error: {e}")
            await db.rollback()


def _extract_todays_tasks(goal, today: date) -> list[dict]:
    """
    Extract tasks from the roadmap that should run today.
    """
    roadmap = goal.roadmap
    if not roadmap:
        return []

    tasks = []

    if goal.goal_type.value == "linear":
        # Find the active phase based on start date (use goal created_at)
        goal_start = goal.created_at.date()
        days_elapsed = (today - goal_start).days

        # Determine which phase we're in
        weeks_elapsed = days_elapsed // 7
        weeks_used = 0

        for phase in roadmap.get("phases", []):
            phase_duration = phase.get("duration_weeks", 1)
            if weeks_elapsed < weeks_used + phase_duration:
                # We're in this phase
                for task in phase.get("tasks", []):
                    freq = task.get("frequency", "daily")
                    if freq == "daily":
                        tasks.append(task)
                    elif freq == "weekly" and today.weekday() == 0:  # Monday
                        tasks.append(task)
                    elif freq == "once" and days_elapsed == weeks_used * 7:
                        tasks.append(task)
                break
            weeks_used += phase_duration

    elif goal.goal_type.value == "cyclic":
        cycle_days = roadmap.get("cycle_duration_days", 7)
        goal_start = goal.created_at.date()
        day_in_cycle = ((today - goal_start).days % cycle_days) + 1

        for node in roadmap.get("nodes", []):
            freq = node.get("frequency", "daily")
            node_day = node.get("day_of_cycle", 1)

            if freq == "daily":
                tasks.append(node)
            elif freq == "weekly" and day_in_cycle == node_day:
                tasks.append(node)
            elif freq == "every_2_days" and (today - goal_start).days % 2 == 0:
                tasks.append(node)

    return tasks


def start_scheduler():
    """Start the APScheduler with the daily task generation job."""
    scheduler.add_job(
        generate_daily_tasks_job,
        CronTrigger(hour=0, minute=0),  # Midnight every day
        id="daily_task_generation",
        replace_existing=True,
    )
    scheduler.start()
    logger.info("APScheduler started — daily task generation active.")


def stop_scheduler():
    """Gracefully stop the scheduler."""
    if scheduler.running:
        scheduler.shutdown()
        logger.info("APScheduler stopped.")
