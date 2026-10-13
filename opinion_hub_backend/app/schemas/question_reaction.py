from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class QuestionReactionCreate(BaseModel):
    reaction_type: str = Field(
        min_length=1,
        max_length=30,
    )


class QuestionReactionResponse(BaseModel):
    question_reaction_id: int
    user_id: int
    question_id: int
    reaction_type: str
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)