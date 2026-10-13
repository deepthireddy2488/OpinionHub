from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.dependencies import get_current_user
from app.database.connection import get_db
from app.models.user import User
from app.schemas.question_reaction import (
    QuestionReactionCreate,
    QuestionReactionResponse,
)
from app.services.question_reaction_service import (
    create_question_reaction,
)


router = APIRouter(
    prefix="/questions",
    tags=["Question Reactions"],
)


@router.post(
    "/{question_id}/reactions",
    response_model=QuestionReactionResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_new_question_reaction(
    question_id: int,
    request: QuestionReactionCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    try:
        reaction = create_question_reaction(
            db=db,
            user_id=current_user.user_id,
            question_id=question_id,
            reaction_type=request.reaction_type,
        )

        return reaction

    except ValueError as error:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(error),
        )