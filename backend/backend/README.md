# Pomplin Backend

This is the backend for **Pomplin**, an app designed to help users manage their goals, schedule tasks, and interact with an AI companion named Pomplin. 

## Tech Stack
- **FastAPI**: Main web framework.
- **SQLAlchemy (Async)**: ORM for database interactions.
- **PostgreSQL**: Database for persisting users, goals, tasks, and chats.
- **Alembic**: Database migrations.
- **WebSockets**: Real-time chat with the AI companion.
- **Google Generative AI (Gemini)**: The AI brain for Pomplin.
- **APScheduler**: Task scheduling (for reminders, task rollovers, etc.).
- **Docker & Docker Compose**: Containerization.
- **Passlib & Bcrypt**: Password hashing.
- **JWT**: Authentication.

## LLM Context / Core Features
For an LLM reading this repository, here is what we have implemented:

1. **Authentication & Users (`app/api/endpoints/auth.py`, `app/models/user.py`)**
   - Standard email/password registration and login via JWT.
   - User profile endpoints.

2. **Goals (`app/api/endpoints/goals.py`, `app/models/goal.py`)**
   - Users can create goals.
   - Goals can be `linear` or `cyclic`.
   - Each goal can have a generated JSON roadmap.

3. **Tasks (`app/api/endpoints/tasks.py`, `app/models/task.py`)**
   - Tasks are linked to goals and users.
   - Tasks have specific dates, and states (`completed`, `skipped`).
   - Tasks can be dynamically rolled over or scheduled.

4. **AI Companion / Chat (`app/api/endpoints/chat.py`, `app/models/chat.py`)**
   - WebSocket endpoint (`/ws/chat`) allowing users to chat directly with Pomplin.
   - Integrates with Gemini via `app/services/gemini.py`.
   - Persists chat sessions and messages. Pomplin uses the user's goals and tasks as context to provide personalized productivity advice.

5. **Scheduler (`app/services/scheduler.py`)**
   - Runs background jobs (like evaluating daily progress, sending reminders).

## Getting Started Locally
1. Configure `.env` with required secrets (DB connection, `GEMINI_API_KEY`, `SECRET_KEY`, etc.).
2. Run `docker compose up --build -d`.
3. Alembic migrations are automatically applied on startup via `start.sh`.

Enjoy building Pomplin!
