from datetime import datetime

from pydantic import BaseModel, Field


class PollOptionCreate(BaseModel):
    option_text: str = Field(
        min_length=1,
        max_length=200,
    )


class PollCreate(BaseModel):
    question_id: int
    options: list[PollOptionCreate] = Field(
        min_length=2,
        max_length=6,
    )


class StandalonePollCreate(BaseModel):
    title: str = Field(min_length=5, max_length=200)
    options: list[PollOptionCreate] = Field(min_length=2, max_length=6)


class PollOptionResponse(BaseModel):
    option_id: int
    option_text: str
    option_order: int
    vote_count: int


class PollResponse(BaseModel):
    poll_id: int
    question_id: int
    options: list[PollOptionResponse]
    total_votes: int
    created_at: datetime
    updated_at: datetime
    is_active: bool


class PollVoteCreate(BaseModel):
    option_id: int


class PollVoteResponse(BaseModel):
    poll_id: int
    option_id: int
    total_votes: int
