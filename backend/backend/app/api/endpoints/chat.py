"""
Chat API — Phase 4
- WS   /ws/chat              → Real-time Pomplin goblin chat (JWT via query param)
- POST /chat/session         → Create or resume a chat session
- GET  /chat/sessions        → List user's chat sessions
- GET  /chat/sessions/{id}   → Get session with message history
- DELETE /chat/sessions/{id} → Delete a chat session
"""
import json
import logging
from typing import Any, Optional

from fastapi import APIRouter, Depends, HTTPException, WebSocket, WebSocketDisconnect, Query, status, Response
from jose import jwt, JWTError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, delete

from app.api.deps import get_current_user
from app.core.config import settings
from app.db.session import get_db, SessionLocal
from app.models.chat import ChatSession, ChatMessage
from app.models.goal import Goal
from app.models.user import User
from app.models.memory import UserMemory
from app.schemas.chat import (
    ChatSessionSchema, ChatSessionWithMessages, ChatMessageSchema, WSOutgoingMessage
)
from app.services.gemini import pomplin_chat
from app.services.connection_manager import manager

router = APIRouter()
logger = logging.getLogger(__name__)


# ──────────────────────────────────────────────
#  WebSocket Authentication helper
# ──────────────────────────────────────────────

async def get_user_from_token(token: str, db: AsyncSession) -> Optional[User]:
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        user_id = int(payload.get("sub"))
    except (JWTError, TypeError, ValueError):
        return None
    result = await db.execute(select(User).where(User.id == user_id))
    return result.scalar_one_or_none()


# ──────────────────────────────────────────────
#  WebSocket Endpoint
# ──────────────────────────────────────────────

@router.websocket("/ws/chat")
async def websocket_chat(
    websocket: WebSocket,
    token: str = Query(..., description="JWT access token"),
    goal_id: Optional[int] = Query(None, description="Optional goal context"),
    session_id: Optional[int] = Query(None, description="Resume existing session"),
):
    """
    WebSocket endpoint for real-time Pomplin goblin chat.
    Connect with: ws://host/ws/chat?token=<JWT>[&goal_id=<id>][&session_id=<id>]
    
    Send JSON: {"content": "your message"}
    Receive JSON: {"role": "model", "content": "Pomplin's reply", "session_id": 123}
    """
    async with SessionLocal() as db:
        # Authenticate
        user = await get_user_from_token(token, db)
        if not user:
            await websocket.close(code=4001, reason="Invalid or expired token")
            return

        await manager.connect(websocket, user.id)

        # Get or create chat session
        if session_id:
            sess_result = await db.execute(
                select(ChatSession).where(
                    ChatSession.id == session_id,
                    ChatSession.user_id == user.id
                )
            )
            session = sess_result.scalar_one_or_none()
        else:
            session = None

        if not session:
            session = ChatSession(user_id=user.id, goal_id=goal_id)
            db.add(session)
            await db.commit()
            await db.refresh(session)

        # Load message history for context
        hist_result = await db.execute(
            select(ChatMessage)
            .where(ChatMessage.session_id == session.id)
            .order_by(ChatMessage.created_at)
        )
        history_rows = hist_result.scalars().all()

        # Build Gemini-compatible history
        gemini_history = [
            {"role": msg.role, "parts": [{"text": msg.content}]}
            for msg in history_rows
        ]

        # Build goal context string if applicable
        goal_context = None
        if goal_id:
            goal_result = await db.execute(
                select(Goal).where(Goal.id == goal_id, Goal.user_id == user.id)
            )
            goal = goal_result.scalar_one_or_none()
            if goal:
                goal_context = (
                    f"Goal: {goal.title}\n"
                    f"Description: {goal.description}\n"
                    f"Type: {goal.goal_type.value}\n"
                    f"Roadmap summary: {json.dumps(goal.roadmap)[:500] if goal.roadmap else 'Not generated yet'}"
                )

        # Check if user has any goals
        goals_check = await db.execute(select(Goal).where(Goal.user_id == user.id))
        has_goals = goals_check.scalar_one_or_none() is not None

        # Send greeting on new session
        if not history_rows:
            if not has_goals:
                greeting = (
                    "Hey there! I'm your productivity assistant. It looks like you don't have any active goals yet.\n"
                    "What would you like to achieve? Let's figure out a plan together."
                )
            else:
                greeting = (
                    "Welcome back! Are we focusing on one of your current goals today, or are we planning something new?"
                )
            
            greeting_msg = ChatMessage(
                session_id=session.id,
                role="model",
                content=greeting,
            )
            db.add(greeting_msg)
            await db.commit()
            gemini_history.append({"role": "model", "parts": [{"text": greeting}]})

            await manager.send_message(
                {"role": "model", "content": greeting, "session_id": session.id},
                websocket,
            )

        # Main message loop
        try:
            while True:
                raw = await websocket.receive_text()

                try:
                    data = json.loads(raw)
                    user_content = data.get("content", "").strip()
                except (json.JSONDecodeError, AttributeError):
                    continue

                if not user_content:
                    continue

                # Save user message
                user_msg = ChatMessage(session_id=session.id, role="user", content=user_content)
                db.add(user_msg)
                await db.commit()

                # Update history
                gemini_history.append({"role": "user", "parts": [{"text": user_content}]})

                # Fetch User Memories
                mem_result = await db.execute(select(UserMemory).where(UserMemory.user_id == user.id))
                memories_list = mem_result.scalars().all()
                memories_str = "\n".join([f"[{m.id}] {m.content}" for m in memories_list]) if memories_list else "No memories recorded yet."

                # Get Assistant's reply and potential tool call
                reply, tool_call = await pomplin_chat(
                    user_message=user_content,
                    history=gemini_history[:-1],
                    goal_context=goal_context,
                    memories=memories_str,
                    has_goals=has_goals
                )

                # Execute Tool Call if requested
                tool_data = None
                if tool_call:
                    name = tool_call["name"]
                    args = tool_call["args"]

                    if name == "confirm_and_create_goal":
                        new_goal = Goal(
                            user_id=user.id,
                            title=args["title"],
                            description=args["description"],
                            goal_type=args["goal_type"],
                            roadmap=args["roadmap"]
                        )
                        db.add(new_goal)
                        await db.commit()
                        await db.refresh(new_goal)
                        tool_data = {"status": "success", "goal_id": new_goal.id}
                        has_goals = True # Now they have a goal!
                    
                    elif name == "modify_goal":
                        target_goal_id = args.get("goal_id") or goal_id
                        if target_goal_id:
                            g_res = await db.execute(select(Goal).where(Goal.id == target_goal_id, Goal.user_id == user.id))
                            g = g_res.scalar_one_or_none()
                            if g:
                                g.roadmap = args["new_roadmap"]
                                await db.commit()
                                tool_data = {"status": "success"}
                        
                    elif name == "propose_roadmap":
                        # Just send the draft roadmap as a special event to the client
                        tool_data = {"status": "preview", "roadmap": args["roadmap"]}
                    
                    elif name == "save_memory":
                        new_mem = UserMemory(user_id=user.id, content=args["content"])
                        db.add(new_mem)
                        await db.commit()
                        await db.refresh(new_mem)
                        tool_data = {"status": "saved", "memory_id": new_mem.id}
                    
                    elif name == "delete_memory":
                        mem_id = args["memory_id"]
                        await db.execute(delete(UserMemory).where(UserMemory.id == mem_id, UserMemory.user_id == user.id))
                        await db.commit()
                        tool_data = {"status": "deleted"}

                # Save model reply
                model_msg = ChatMessage(session_id=session.id, role="model", content=reply)
                db.add(model_msg)
                await db.commit()

                gemini_history.append({"role": "model", "parts": [{"text": reply}]})

                # Send reply + any tool data to client
                response_payload = {
                    "role": "model", 
                    "content": reply, 
                    "session_id": session.id
                }
                if tool_data:
                    response_payload["tool_result"] = tool_data
                    response_payload["tool_name"] = tool_call["name"]

                await manager.send_message(response_payload, websocket)

        except WebSocketDisconnect:
            manager.disconnect(websocket, user.id)
            logger.info(f"User {user.id} disconnected from chat session {session.id}")


# ──────────────────────────────────────────────
#  REST endpoints for session management
# ──────────────────────────────────────────────

@router.post("/session", response_model=ChatSessionSchema)
async def create_session(
    goal_id: Optional[int] = None,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> Any:
    """Create a new chat session (optionally linked to a goal)."""
    session = ChatSession(user_id=current_user.id, goal_id=goal_id)
    db.add(session)
    await db.commit()
    await db.refresh(session)
    return session


@router.get("/sessions", response_model=list[ChatSessionSchema])
async def list_sessions(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> Any:
    """List all chat sessions for the current user."""
    result = await db.execute(
        select(ChatSession)
        .where(ChatSession.user_id == current_user.id)
        .order_by(ChatSession.created_at.desc())
    )
    return result.scalars().all()


@router.get("/sessions/{session_id}", response_model=ChatSessionWithMessages)
async def get_session(
    session_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> Any:
    """Get a chat session with all its messages."""
    result = await db.execute(
        select(ChatSession).where(
            ChatSession.id == session_id,
            ChatSession.user_id == current_user.id,
        )
    )
    session = result.scalar_one_or_none()
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")

    msgs_result = await db.execute(
        select(ChatMessage)
        .where(ChatMessage.session_id == session_id)
        .order_by(ChatMessage.created_at)
    )
    messages = msgs_result.scalars().all()

    return {
        "id": session.id,
        "user_id": session.user_id,
        "goal_id": session.goal_id,
        "created_at": session.created_at,
        "messages": messages,
    }


@router.delete("/sessions/{session_id}", status_code=status.HTTP_204_NO_CONTENT, response_class=Response)
async def delete_session(
    session_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> None:
    """Delete a chat session and all its messages."""
    result = await db.execute(
        select(ChatSession).where(
            ChatSession.id == session_id,
            ChatSession.user_id == current_user.id,
        )
    )
    session = result.scalar_one_or_none()
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
    await db.delete(session)
    await db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)
