from datetime import datetime

from pydantic import BaseModel, Field


class ReportCreate(BaseModel):
    reason: str = Field(min_length=2, max_length=50)
    description: str | None = Field(
        default=None,
        max_length=1000,
    )


class ReportResponse(BaseModel):
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