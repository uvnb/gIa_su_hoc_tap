"""Schema request/response giữa App ↔ Backend (mục 9.3).

Response model liệt kê TƯỜNG MINH từng trường → không có cách nào vô tình gửi `answer`/`steps` xuống app.
"""
from __future__ import annotations

from typing import Any, Literal, Optional

from pydantic import BaseModel, ConfigDict, Field

Mood = Literal["idle", "listening", "thinking", "asking", "encouraging", "celebrating", "sleepy"]
State = Literal["selecting", "confirming", "tutoring", "solved", "explaining", "parked", "break_suggested", "unreadable"]


class Owl(BaseModel):
    say: str
    mood: Mood = "asking"


class ProblemBrief(BaseModel):
    """Chỉ có đề bài – KHÔNG có đáp án."""
    id: int
    text: str


class StartResponse(BaseModel):
    model_config = ConfigDict(extra="forbid")
    session_id: Optional[str] = None
    readable: bool
    problem_display: str = ""
    problems_found: int = 0
    problems: list[ProblemBrief] = []
    needs_selection: bool = False
    subject: str = "math"
    mode: str = "exercise"
    owl: Owl
    hint_level: int = 0
    state: State = "confirming"
    ui_actions: list[dict[str, Any]] = []


class TurnRequest(BaseModel):
    session_id: str
    child_input: str = ""
    input_mode: Literal["voice", "keypad", "text", "choice", "too_hard"] = "voice"


class SelectRequest(BaseModel):
    session_id: str
    problem_id: int


class SessionRef(BaseModel):
    session_id: str


class TurnResponse(BaseModel):
    model_config = ConfigDict(extra="forbid")
    owl: Owl
    hint_level: int
    state: State
    stars_earned: int = 0
    ui_actions: list[dict[str, Any]] = []
    fun_question: str = ""
    problem_display: str = ""


class DeviceRegistration(BaseModel):
    device_id: str
    parent_token: str


class MysteryBox(BaseModel):
    question: str
    subject: str
    kind: str
    date: str


class ParentAnswer(BaseModel):
    problem: str
    answer: str
    steps: list[str]
    mode: str


class ReportItem(BaseModel):
    session_id: str
    started_at: float
    subject: str
    problem_type: str
    problem_text: str
    turns: int
    max_hint: int
    outcome: str
    stars: int


class ParentReport(BaseModel):
    period: str
    minutes: int
    problems_total: int
    solved_self: int
    parked: int
    stars: int
    hard_types: list[dict[str, Any]] = Field(default_factory=list)
    parked_items: list[ReportItem] = Field(default_factory=list)
    recent: list[ReportItem] = Field(default_factory=list)
    safety_alerts: int = 0
    by_day: list[dict[str, Any]] = Field(default_factory=list)
