# Pomplin 🚀

Pomplin is an AI-powered productivity assistant and life coach. It helps users define ambitious goals, breaks them down into actionable roadmaps, and maintains a persistent memory of the user's background, skills, and preferences to provide deeply personalized coaching.

## ✨ Key Features

- **🧠 Autonomous Memory System**: The AI automatically records important facts about you (skills, experience, preferences) using dedicated tool calls. This context is persisted in PostgreSQL and injected into every future conversation.
- **🗺️ Dynamic Roadmap Generation**: Proposes structured plans (Linear or Cyclic) tailored to your specific objectives.
- **💬 Interactive Coaching**: A neutral, casual AI assistant that interviews you to gather context before jumping into planning.
- **🔄 Real-time Interaction**: Built with WebSockets for a snappy, real-time chat experience.

## 🛠️ Tech Stack

- **Backend**: [FastAPI](https://fastapi.tiangolo.com/) (Python 3.12)
- **AI Engine**: [Google Gemini 2.5 Flash](https://ai.google.dev/)
- **Database**: [PostgreSQL](https://www.postgresql.org/) with [SQLAlchemy 2.0](https://www.sqlalchemy.org/) (Async)
- **Migrations**: [Alembic](https://alembic.sqlalchemy.org/)
- **Frontend**: Vanilla JavaScript & TailwindCSS (via CDN)
- **Containerization**: [Docker](https://www.docker.com/) & [Docker Compose](https://docs.docker.com/compose/)

## 🚀 Getting Started

### Prerequisites
- Docker and Docker Compose
- A [Google Gemini API Key](https://aistudio.google.com/)

### Installation

1. Clone the repository.
2. Create a `.env` file in the root directory:
   ```env
   DATABASE_URL=postgresql+asyncpg://postgres:postgres@db:5432/pomplin
   GEMINI_API_KEY=your_gemini_api_key_here
   SECRET_KEY=your_jwt_secret_key
   ```
3. Start the application:
   ```bash
   docker compose up --build
   ```
4. Open your browser to `http://localhost:8000/frontend/chat.html`

## 📂 Project Structure

- `backend/app/api`: FastAPI route handlers (Auth, Chat, Goals, Memories, etc.)
- `backend/app/models`: SQLAlchemy database models.
- `backend/app/services/gemini.py`: Core AI logic, prompt engineering, and tool definitions.
- `backend/app/db`: Database session management and migrations.
- `frontend/`: Real-time chat interface and assets.

## 🤖 LLM Implementation Notes

- **Memory**: The system uses a `UserMemory` table. Memories are injected into the system prompt as `User's Permanent Memories (Context)`.
- **Tools**: The AI has access to:
    - `save_memory(content)`: Persists context.
    - `delete_memory(memory_id)`: Removes context.
    - `propose_roadmap(title, description, roadmap)`: Shows a draft plan.
    - `confirm_and_create_goal(...)`: Saves a goal to the DB.
- **Prompts**: Managed in `backend/app/services/gemini.py`. The assistant is currently configured as a "neutral, casual productivity assistant".
