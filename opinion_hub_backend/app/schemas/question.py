from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class QuestionCreate(BaseModel):
    title: str = Field(min_length=5, max_length=200)


class QuestionResponse(BaseModel):
    question_id: int
    public_code: str
    profile_picture_url: str | None = None
    title: str
    group_id: int | None
    poll_id: int | None
    like_count: int
    interesting_count: int
    agree_count: int
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)