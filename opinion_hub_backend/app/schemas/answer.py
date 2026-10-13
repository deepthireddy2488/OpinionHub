from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class AnswerCreate(BaseModel):
    question_id: int
    answer_text: str = Field(
        min_length=1,
        max_length=5000,
    )


class AnswerResponse(BaseModel):
    answer_id: int
    question_id: int
    public_code: str
    answer_text: str
    helpful_count: int
    agree_count: int
    good_answer_count: int
    created_at: datetime
    updated_at: datetime
    profile_picture_url: str | None = None

    model_config = ConfigDict(from_attributes=True)