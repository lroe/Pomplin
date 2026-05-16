# Pomplin: AI-Powered Life Coach App

Pomplin is a full-stack mobile application designed to help users achieve their goals through an agentic AI coach.

## 🚀 Overview

- **Frontend**: Flutter (Dart) with a modern, high-end dark aesthetic.
- **Backend**: FastAPI (Python) with SQLAlchemy (PostgreSQL) and Alembic for migrations.
- **AI Engine**: Google Gemini 2.5 Flash for agentic chat and structured roadmap generation.

## 🧠 LLM / Developer Documentation

### Backend Architecture

The backend follows a modular FastAPI structure:
- `app/api/endpoints/`: Contains REST and WebSocket controllers.
- `app/models/`: SQLAlchemy models (User, Goal, Task, ChatSession, ChatMessage, UserMemory).
- `app/services/gemini.py`: Core AI logic. Uses **Function Calling** to manage user memory and propose roadmaps.
- `app/services/connection_manager.py`: Manages WebSocket sessions.

#### Function Calling Tools:
- `save_memory`: Records user context (skills, background) into permanent storage.
- `propose_roadmap`: Generates a structured JSON roadmap for a goal.
- `confirm_and_create_goal`: Saves a reviewed roadmap to the database.

### Frontend Architecture

- `lib/services/api_service.dart`: Centralized API client using `http` and `web_socket_channel`.
- `lib/chat.dart`: Real-time chat interface with WebSocket support. Renders "Roadmap Preview" cards from AI tool calls.
- `lib/roadmap.dart`: Visualizes the structured JSON roadmap. Supports "Preview Mode" for unconfirmed plans.
- `lib/homepage.dart`: Dashboard showing active goals and daily missions.

### Key Integration Points

1.  **Authentication**: Uses JWT tokens stored in `shared_preferences`.
2.  **Stitching**: The Chat screen is the "Command Center". When the AI proposes a roadmap, it sends a `tool_result` via WebSocket. The frontend renders a preview card. Tapping it opens the `RoadmapScreen` in preview mode.
3.  **Real-time**: WebSockets are used for the chat to allow for low-latency interactions and multi-part tool results.

## 🛠️ Setup Instructions

### Backend
1. Create a virtual environment: `python -m venv venv`
2. Install requirements: `pip install -r backend/requirements.txt`
3. Configure `.env` in `backend/backend/`:
   ```env
   DATABASE_URL=postgresql+asyncpg://postgres:postgres@localhost:5432/pomplin
   GEMINI_API_KEY=your_key_here
   ```
4. Run migrations: `alembic upgrade head`
5. Start server: `uvicorn app.main:app --reload --port 8001`

### Frontend
1. Install dependencies: `flutter pub get`
2. Run app: `flutter run`

---
*Pomplin — Clarity through discipline.*
