from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class AnswerReactionCreate(BaseModel):
    reaction_type: str = Field(
        min_length=1,
        max_length=30,
    )


class AnswerReactionResponse(BaseModel):
    answer_reaction_id: int
    user_id: int
    answer_id: int
    reaction_type: str
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)