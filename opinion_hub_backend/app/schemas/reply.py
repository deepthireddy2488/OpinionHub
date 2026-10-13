from datetime import datetime

from pydantic import BaseModel, Field


class ReplyCreate(BaseModel):
    answer_id: int
    reply_text: str = Field(
        min_length=1,
        max_length=2000,
    )


class ReplyResponse(BaseModel):
    reply_id: int
    answer_id: int
    public_code: str
    reply_text: str
    created_at: datetime
    updated_at: datetime
    profile_picture_url: str | None = None