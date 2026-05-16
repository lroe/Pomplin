from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
import os

from app.api.api import api_router
from app.api.endpoints.chat import router as chat_ws_router
from app.core.config import settings
from app.services.scheduler import start_scheduler, stop_scheduler


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    start_scheduler()
    yield
    # Shutdown
    stop_scheduler()


app = FastAPI(
    title=settings.PROJECT_NAME,
    description="Pomplin — Your AI goblin life coach. Powered by Gemini.",
    version="1.0.0",
    openapi_url="/openapi.json",
    lifespan=lifespan,
)

# CORS — allow all origins for development (tighten in production)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# REST routes
app.include_router(api_router)

# WebSocket route (registered at root so path is /ws/chat)
app.include_router(chat_ws_router)

# Serve the frontend static files
frontend_path = "/frontend" if os.path.isdir("/frontend") else "../frontend"
if os.path.isdir(frontend_path):
    app.mount("/frontend", StaticFiles(directory=frontend_path), name="frontend")


@app.get("/", tags=["health"])
async def root():
    return {"message": "Pomplin API is alive! 🔥", "version": "1.0.0"}


@app.get("/health", tags=["health"])
async def health():
    return {"status": "ok"}
