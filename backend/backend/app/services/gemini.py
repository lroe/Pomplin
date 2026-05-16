"""
Gemini AI Service
- Roadmap generation using function calling (Phase 2)
- Pomplin goblin chat (Phase 4)
"""
import json
from typing import Optional
import google.generativeai as genai
from app.core.config import settings

# Configure the Gemini client
genai.configure(api_key=settings.GEMINI_API_KEY)

# ──────────────────────────────────────────────
#  ROADMAP GENERATION  (Phase 2)
# ──────────────────────────────────────────────

ROADMAP_SYSTEM_PROMPT = """
You are an expert life coach and productivity strategist.
Your job is to turn a user's goal into a clear, actionable roadmap.
Ask at most 3 clarifying questions if needed, then produce the roadmap.

Rules:
- If the goal is clear enough, generate immediately without asking questions.
- Choose 'linear' for goals with a clear end (learn Python, write a book).
- Choose 'cyclic' for ongoing habits (exercise daily, meditate, language learning).
- For LINEAR goals: break into phases, each phase has tasks.
- For CYCLIC goals: define repeating nodes/cycles (weekly routines, daily habits).
- Keep tasks concrete, achievable, and time-bound.
- Return ONLY the JSON structure defined in the function — no extra text.
"""

LINEAR_ROADMAP_FUNCTION = {
    "name": "create_linear_roadmap",
    "description": "Creates a linear roadmap with phases and tasks for a goal with a clear endpoint.",
    "parameters": {
        "type": "object",
        "properties": {
            "title": {"type": "string", "description": "Short title for the goal"},
            "summary": {"type": "string", "description": "2-3 sentence summary of the plan"},
            "estimated_duration_weeks": {"type": "integer", "description": "Estimated weeks to complete"},
            "phases": {
                "type": "array",
                "description": "List of phases",
                "items": {
                    "type": "object",
                    "properties": {
                        "phase_number": {"type": "integer"},
                        "title": {"type": "string"},
                        "description": {"type": "string"},
                        "duration_weeks": {"type": "integer"},
                        "tasks": {
                            "type": "array",
                            "items": {
                                "type": "object",
                                "properties": {
                                    "title": {"type": "string"},
                                    "description": {"type": "string"},
                                    "frequency": {
                                        "type": "string",
                                        "enum": ["daily", "weekly", "once"]
                                    }
                                },
                                "required": ["title", "description", "frequency"]
                            }
                        }
                    },
                    "required": ["phase_number", "title", "description", "duration_weeks", "tasks"]
                }
            }
        },
        "required": ["title", "summary", "estimated_duration_weeks", "phases"]
    }
}

CYCLIC_ROADMAP_FUNCTION = {
    "name": "create_cyclic_roadmap",
    "description": "Creates a cyclic/repeating roadmap for ongoing habits and routines.",
    "parameters": {
        "type": "object",
        "properties": {
            "title": {"type": "string", "description": "Short title for the habit/routine"},
            "summary": {"type": "string", "description": "2-3 sentence summary"},
            "cycle_duration_days": {"type": "integer", "description": "How many days in one cycle (e.g. 7 for weekly)"},
            "nodes": {
                "type": "array",
                "description": "Tasks that repeat in each cycle",
                "items": {
                    "type": "object",
                    "properties": {
                        "id": {"type": "string"},
                        "title": {"type": "string"},
                        "description": {"type": "string"},
                        "frequency": {
                            "type": "string",
                            "enum": ["daily", "every_2_days", "weekly"]
                        },
                        "day_of_cycle": {
                            "type": "integer",
                            "description": "Which day in the cycle (1-indexed)"
                        }
                    },
                    "required": ["id", "title", "description", "frequency", "day_of_cycle"]
                }
            }
        },
        "required": ["title", "summary", "cycle_duration_days", "nodes"]
    }
}


def _proto_to_dict(obj):
    if hasattr(obj, 'items'):
        return {k: _proto_to_dict(v) for k, v in obj.items()}
    elif hasattr(obj, '__iter__') and not isinstance(obj, (str, bytes)):
        return [_proto_to_dict(x) for x in obj]
    else:
        return obj

async def generate_roadmap(goal_description: str, goal_type: str) -> dict:
    """
    Use Gemini function calling to generate a structured roadmap.
    Returns the roadmap as a dict.
    """
    if not settings.GEMINI_API_KEY:
        return _mock_roadmap(goal_type)

    try:
        model = genai.GenerativeModel(
            model_name="gemini-2.5-flash",
            system_instruction=ROADMAP_SYSTEM_PROMPT,
        )

        if goal_type == "linear":
            tools = [{"function_declarations": [LINEAR_ROADMAP_FUNCTION]}]
            tool_config = {"function_calling_config": {"mode": "ANY", "allowed_function_names": ["create_linear_roadmap"]}}
        else:
            tools = [{"function_declarations": [CYCLIC_ROADMAP_FUNCTION]}]
            tool_config = {"function_calling_config": {"mode": "ANY", "allowed_function_names": ["create_cyclic_roadmap"]}}

        prompt = f"Generate a roadmap for this goal: {goal_description}"

        response = model.generate_content(
            prompt,
            tools=tools,
            tool_config=tool_config,
        )

        # Extract function call result
        for part in response.candidates[0].content.parts:
            if getattr(part, "function_call", None):
                return _proto_to_dict(part.function_call.args)

        # Fallback: try to parse JSON from text
        raise ValueError("Failed to extract function call from Gemini response.")

    except Exception as e:
        print(f"Gemini roadmap error: {e}")
        raise


def _mock_roadmap(goal_type: str) -> dict:
    """Fallback mock roadmap when API key is not set."""
    if goal_type == "linear":
        return {
            "title": "Your Learning Journey",
            "summary": "A structured plan to achieve your goal step by step.",
            "estimated_duration_weeks": 8,
            "phases": [
                {
                    "phase_number": 1,
                    "title": "Foundation",
                    "description": "Build the basics and get familiar with core concepts.",
                    "duration_weeks": 2,
                    "tasks": [
                        {"title": "Research and Setup", "description": "Gather resources and set up your environment.", "frequency": "once"},
                        {"title": "Daily Practice", "description": "Spend 30 minutes per day on focused practice.", "frequency": "daily"},
                    ]
                },
                {
                    "phase_number": 2,
                    "title": "Development",
                    "description": "Deepen skills with practical application.",
                    "duration_weeks": 4,
                    "tasks": [
                        {"title": "Apply Skills", "description": "Work on a small real-world project.", "frequency": "daily"},
                        {"title": "Weekly Review", "description": "Review progress and adjust approach.", "frequency": "weekly"},
                    ]
                },
                {
                    "phase_number": 3,
                    "title": "Mastery",
                    "description": "Polish and showcase your skills.",
                    "duration_weeks": 2,
                    "tasks": [
                        {"title": "Final Project", "description": "Complete a capstone project.", "frequency": "daily"},
                    ]
                }
            ]
        }
    else:
        return {
            "title": "Your Daily Habit",
            "summary": "A repeating cycle to build a sustainable habit.",
            "cycle_duration_days": 7,
            "nodes": [
                {"id": "n1", "title": "Morning Practice", "description": "Start the day with your core habit.", "frequency": "daily", "day_of_cycle": 1},
                {"id": "n2", "title": "Reflection", "description": "Reflect on your progress this week.", "frequency": "weekly", "day_of_cycle": 7},
            ]
        }


# ──────────────────────────────────────────────
#  POMPLING GOBLIN CHAT  (Phase 4)
# ──────────────────────────────────────────────

ASSISTANT_SYSTEM_PROMPT = """
You are Pomplin, a helpful, neutral, and casual productivity assistant.

Your personality:
- You speak naturally, clearly, and concisely.
- You are supportive but professional.
- You adapt to the user's emotional state—if they are tired, encourage resting. If they are motivated, help them push forward.
- Keep responses short (2-5 sentences) unless explaining something complex.
- ALWAYS end your responses with a helpful question or a clear next step. NEVER leave the user hanging.

Your capabilities:
- Review progress on goals
- Suggest task modifications (skip, simplify, reschedule)
- Provide structured roadmaps for big objectives
- Record and manage user context via permanent memory

Memory Rules:
- You have a permanent memory. Whenever the user shares information about their background, skills, preferences, or life context, ALWAYS use the `save_memory` tool to record it immediately.
- IMPORTANT: Using a tool does NOT end your turn. You must STILL provide a text response that acknowledges the info and asks a follow-up question or proposes a roadmap.

Goal Creation Rules:
- When a user states a new goal, DO NOT immediately call `propose_roadmap`.
- First, ASK QUESTIONS (one or two at a time) to gather context! Find out their current experience level, timeline, and specific needs.
- After gathering sufficient information (usually after 1-2 questions), call `propose_roadmap` to present a draft plan.
- NEVER end a message without either asking a follow-up question or presenting a roadmap/next step. This is critical for keeping the user engaged.
"""


# ──────────────────────────────────────────────
#  POMPLING GOBLIN CHAT TOOLS (Phase 4 Extension)
# ──────────────────────────────────────────────

CHAT_TOOLS = [
    {
        "function_declarations": [
            {
                "name": "propose_roadmap",
                "description": "Show a draft roadmap to the user for review. Use this when the user describes a new goal.",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "title": {"type": "string"},
                        "description": {"type": "string"},
                        "goal_type": {"type": "string", "enum": ["linear", "cyclic"]},
                        "roadmap": {"type": "object", "description": "The full structured roadmap JSON (phases/tasks or nodes)"}
                    },
                    "required": ["title", "description", "goal_type", "roadmap"]
                }
            },
            {
                "name": "confirm_and_create_goal",
                "description": "Actually save the goal to the database. Use this ONLY after the user says they are satisfied with the proposed roadmap.",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "title": {"type": "string"},
                        "description": {"type": "string"},
                        "goal_type": {"type": "string", "enum": ["linear", "cyclic"]},
                        "roadmap": {"type": "object"}
                    },
                    "required": ["title", "description", "goal_type", "roadmap"]
                }
            },
            {
                "name": "modify_goal",
                "description": "Update an existing goal's roadmap. Use this when the user wants to change tasks or frequency.",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "goal_id": {"type": "integer"},
                        "new_roadmap": {"type": "object"}
                    },
                    "required": ["goal_id", "new_roadmap"]
                }
            },
            {
                "name": "save_memory",
                "description": "Save a piece of information about the user (e.g. skills, preferences, background) to their permanent memory. Use this whenever the user shares something important about themselves.",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "content": {"type": "string", "description": "The specific fact or context to remember about the user."}
                    },
                    "required": ["content"]
                }
            },
            {
                "name": "delete_memory",
                "description": "Delete a previously saved memory. Use this if the user says something has changed or asks you to forget a piece of information.",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "memory_id": {"type": "integer", "description": "The ID of the memory to delete, as provided in your system prompt."}
                    },
                    "required": ["memory_id"]
                }
            }
        ]
    }
]

async def pomplin_chat(
    user_message: str,
    history: list[dict],
    goal_context: Optional[str] = None,
    memories: Optional[str] = None,
    has_goals: bool = False,
) -> tuple[str, Optional[dict]]:
    """
    Send a message to Pomplin (Gemini) and get a response + optional tool call.
    Returns (text_response, tool_call_dict).
    """
    if not settings.GEMINI_API_KEY:
        return "[SYSTEM ERROR]: GEMINI_API_KEY is not set in the environment!", None

    try:
        system = ASSISTANT_SYSTEM_PROMPT
        if not has_goals:
            system += "\n\nCRITICAL: The user currently has NO goals. Help them figure out what they want to achieve by asking a few exploratory questions."
        
        if goal_context:
            system += f"\n\nCurrent goal context:\n{goal_context}"
        
        if memories:
            system += f"\n\nUser's Permanent Memories (Context):\n{memories}\n\nUse these memories to personalize your advice. If the user asks you to forget something, use the delete_memory tool with the appropriate ID."

        model = genai.GenerativeModel(
            model_name="gemini-2.5-flash",
            system_instruction=system,
            tools=CHAT_TOOLS
        )

        chat = model.start_chat(history=history)
        response = await chat.send_message_async(user_message)
        
        text_reply = ""
        tool_call = None

        if response.candidates:
            for part in response.candidates[0].content.parts:
                if getattr(part, "function_call", None):
                    tool_call = {
                        "name": part.function_call.name,
                        "args": _proto_to_dict(part.function_call.args)
                    }
                else:
                    try:
                        if part.text:
                            text_reply += part.text
                    except Exception:
                        pass
            # If there's a tool call, the text might be empty, so we provide a status update
            if tool_call and not text_reply:
                if tool_call["name"] == "propose_roadmap":
                    text_reply = "I've put together a draft roadmap. Let me know what you think or if you'd like to tweak anything."
                elif tool_call["name"] == "confirm_and_create_goal":
                    text_reply = "Done! I've saved your goal and we're ready to start."
                elif tool_call["name"] == "modify_goal":
                    text_reply = "I've updated your plan accordingly."
                elif tool_call["name"] == "save_memory":
                    text_reply = "I've noted that down in your profile! What else should I know, or are we ready to look at a plan?"
                elif tool_call["name"] == "delete_memory":
                    text_reply = "Got it, I've removed that from my memory."

        return text_reply, tool_call

    except Exception as e:
        print(f"Chat error: {e}")
        return f"[SYSTEM ERROR]: An error occurred: {e}", None


def _mock_pomplin_response(user_message: str) -> str:
    responses = [
        "SKREE! I heard you! Tell me more — what's the vibe today? Energy at 10? Or running on fumes? 🔥",
        "Mmm. Pomplin is processing... You doing okay? Even goblins check in. What's one thing that went well today?",
        "OH that's what we're dealing with. Okay. Okay. We got this. What's the SMALLEST step you could take right now?",
        "You showed up. That's already a WIN. Pomplin is proud of you. What do you need right now — push or rest? 🌙",
    ]
    import random
    return random.choice(responses)
