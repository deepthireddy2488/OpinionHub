from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.dependencies import get_current_user
from app.database.connection import get_db
from app.models.user import User
from app.schemas.answer_reaction import (
    AnswerReactionCreate,
    AnswerReactionResponse,
)
from app.services.answer_reaction_service import (
    create_answer_reaction,
)


router = APIRouter(
    prefix="/answers",
    tags=["Answer Reactions"],
)


@router.post(
    "/{answer_id}/reactions",
    response_model=AnswerReactionResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_new_answer_reaction(
    answer_id: int,
    request: AnswerReactionCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    try:
        reaction = create_answer_reaction(
            db=db,
            user_id=current_user.user_id,
            answer_id=answer_id,
            reaction_type=request.reaction_type,
        )

        return reaction

    except ValueError as error:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(error),
        )