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
    # 💛 Góc tâm sự – chỉ số lượt & cảnh báo, KHÔNG có nội dung trò chuyện
    friend_turns: int = 0
    friend_days: int = 0
    friend_alerts: list[str] = Field(default_factory=list)  # self_harm | abuse | danger


class FriendMessage(BaseModel):
    who: Literal["child", "owl"] = "child"
    text: str = Field("", max_length=400)


class TtsRequest(BaseModel):
    text: str = Field(..., min_length=1, max_length=400)
    speed: float = Field(1.0, ge=0.6, le=1.6)
    pitch: float = Field(1.0, ge=0.85, le=1.25)


class FriendRequest(BaseModel):
    device_id: str = Field("", max_length=64)
    child_id: str = Field("", max_length=64)
    nickname: str = Field("bạn", max_length=30)
    grade: int = Field(1, ge=1, le=5)
    mood: str = Field("", max_length=10)
    message: str = Field(..., min_length=1, max_length=400)
    history: list[FriendMessage] = Field(default_factory=list, max_length=12)
    provider: Optional[str] = None
    tier: Optional[str] = None


class FriendResponse(BaseModel):
    say: str
    owl_mood: str = "listening"
    suggest_breathing: bool = False
    crisis: str = ""  # self_harm | abuse | "" – app hiện thẻ "nói với người lớn + gọi 111"
    hotline: str = ""
