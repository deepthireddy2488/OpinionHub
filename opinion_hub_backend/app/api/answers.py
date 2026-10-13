from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.dependencies import get_current_user, get_current_user_optional
from app.database.connection import get_db
from app.models.user import User
from app.schemas.answer import AnswerCreate, AnswerResponse
from app.services.answer_service import create_answer, get_answers_by_question


router = APIRouter(prefix="/answers", tags=["Answers"])


@router.post(
    "",
    response_model=AnswerResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_new_answer(
    request: AnswerCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    try:
        answer = create_answer(
            db=db,
            user_id=current_user.user_id,
            question_id=request.question_id,
            answer_text=request.answer_text,
        )
    except ValueError as error:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(error),
        ) from error

    return {
        "answer_id": answer.answer_id,
        "question_id": answer.question_id,
        "public_code": current_user.public_code,
        "profile_picture_url": current_user.profile_picture_url,
        "answer_text": answer.answer_text,
        "helpful_count": 0,
        "agree_count": 0,
        "good_answer_count": 0,
        "created_at": answer.created_at,
        "updated_at": answer.updated_at,
    }


@router.get(
    "/question/{question_id}",
    response_model=list[AnswerResponse],
)
def list_question_answers(
    question_id: int,
    current_user: User | None = Depends(get_current_user_optional),
    db: Session = Depends(get_db),
):
    answers = get_answers_by_question(
        db=db,
        question_id=question_id,
        user_id=current_user.user_id if current_user else None,
    )

    return [
        {
            "answer_id": answer.answer_id,
            "question_id": answer.question_id,
            "public_code": answer.public_code,
            "profile_picture_url": answer.profile_picture_url,
            "answer_text": answer.answer_text,
            "helpful_count": answer.helpful_count,
            "agree_count": answer.agree_count,
            "good_answer_count": answer.good_answer_count,
            "created_at": answer.created_at,
            "updated_at": answer.updated_at,
        }
        for answer in answers
    ]