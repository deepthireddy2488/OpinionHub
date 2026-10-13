from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field


class QuestionPreview(BaseModel):
    question_id: int
    public_code: str
    profile_picture_url: str | None = None
    title: str
    group_id: int | None = None
    poll_id: int | None = None
    like_count: int = 0
    interesting_count: int = 0
    agree_count: int = 0
    created_at: datetime


class BadgeResponse(BaseModel):
    code: str
    title: str
    description: str


class PublicProfileResponse(BaseModel):
    user_id: int
    nickname: str
    public_code: str
    profile_picture_url: str | None = None
    created_at: datetime
    question_count: int
    answer_count: int
    received_reactions: int
    reputation_points: int
    badges: list[BadgeResponse]
    recent_questions: list[QuestionPreview]


class BookmarkResponse(BaseModel):
    bookmark_id: int
    bookmarked_at: datetime
    question: QuestionPreview


class NotificationResponse(BaseModel):
    notification_id: int
    notification_type: str
    title: str
    body: str
    target_type: str | None = None
    target_id: int | None = None
    is_read: bool
    created_at: datetime
    actor_nickname: str | None = None
    actor_public_code: str | None = None
    actor_profile_picture_url: str | None = None


class AISummaryResponse(BaseModel):
    question_id: int
    question_title: str
    summary: str
    common_ground: list[str]
    different_viewpoints: list[str]
    questions_to_consider: list[str]
    ai_generated: bool = True
    generated_at: datetime


class ReportDecisionRequest(BaseModel):
    action: Literal["reviewed", "resolved", "rejected", "hide"]


class AdminReportResponse(BaseModel):
    report_id: int
    reporter_user_id: int
    question_id: int | None
    answer_id: int | None
    reply_id: int | None
    reason: str
    description: str | None
    status: str
    created_at: datetime
    reviewed_at: datetime | None
    ai_status: str | None = None
    ai_flagged: bool | None = None
    ai_categories: dict | None = None


class ReportCreateInternal(BaseModel):
    reason: str = Field(min_length=2, max_length=50)
    description: str | None = Field(default=None, max_length=1000)