from datetime import datetime

from pydantic import BaseModel


class AnswerDetailsResponse(BaseModel):
    answer_id: int
    public_code: str
    answer_text: str
    helpful_count: int
    agree_count: int
    good_answer_count: int
    created_at: datetime
    updated_at: datetime


class QuestionDetailsResponse(BaseModel):
    question_id: int
    public_code: str
    title: str
    group_id: int | None
    like_count: int
    interesting_count: int
    agree_count: int
    created_at: datetime
    updated_at: datetime
    answers: list[AnswerDetailsResponse]