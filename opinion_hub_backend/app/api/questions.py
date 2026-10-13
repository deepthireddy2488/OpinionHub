from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.dependencies import (
    get_current_user,
    get_current_user_optional,
)
from app.database.connection import get_db
from app.models.group_member import GroupMember
from app.models.user import User
from app.schemas.question import QuestionCreate, QuestionResponse
from app.schemas.question_details import QuestionDetailsResponse
from app.services.question_details_service import get_question_details
from app.services.question_service import (
    create_public_question,
    get_question_by_id,
    get_questions,
)


router = APIRouter(
    prefix="/questions",
    tags=["Questions"],
)


@router.post(
    "/public",
    response_model=QuestionResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_public_question_endpoint(
    request: QuestionCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    question = create_public_question(
        db=db,
        user_id=current_user.user_id,
        title=request.title,
    )

    return {
        "question_id": question.question_id,
        "public_code": current_user.public_code,
        "profile_picture_url": current_user.profile_picture_url,
        "title": question.title,
        "group_id": None,
        "poll_id": None,
        "like_count": 0,
        "interesting_count": 0,
        "agree_count": 0,
        "created_at": question.created_at,
        "updated_at": question.updated_at,
    }


@router.get(
    "",
    response_model=list[QuestionResponse],
)
def list_questions(
    db: Session = Depends(get_db),
):
    questions = get_questions(db)

    return [
        {
            "question_id": question.question_id,
            "public_code": question.public_code,
            "title": question.title,
            "group_id": question.group_id,
            "poll_id": question.poll_id,
            "like_count": question.like_count,
            "interesting_count": question.interesting_count,
            "agree_count": question.agree_count,
            "created_at": question.created_at,
            "updated_at": question.updated_at,
        }
        for question in questions
    ]


@router.get(
    "/{question_id}/details",
    response_model=QuestionDetailsResponse,
)
def get_question_details_endpoint(
    question_id: int,
    current_user: User | None = Depends(
        get_current_user_optional
    ),
    db: Session = Depends(get_db),
):
    question_details = get_question_details(
        db=db,
        question_id=question_id,
        user_id=(
            current_user.user_id
            if current_user is not None
            else None
        ),
    )

    if question_details is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Question not found",
        )

    return question_details


@router.get(
    "/{question_id}",
    response_model=QuestionResponse,
)
def get_single_question(
    question_id: int,
    current_user: User | None = Depends(
        get_current_user_optional
    ),
    db: Session = Depends(get_db),
):
    question = get_question_by_id(
        db=db,
        question_id=question_id,
    )

    if question is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Question not found",
        )

    if question.group_id is not None:

        if current_user is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Authentication required for group questions",
            )

        membership = db.scalar(
            __import__(
                "sqlalchemy",
                fromlist=["select"],
            ).select(GroupMember).where(
                GroupMember.group_id == question.group_id,
                GroupMember.user_id == current_user.user_id,
                GroupMember.is_active.is_(True),
            )
        )

        if membership is None:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You are not a member of this group",
            )

    return {
        "question_id": question.question_id,
        "public_code": question.public_code,
        "profile_picture_url": question.profile_picture_url,
        "title": question.title,
        "group_id": question.group_id,
        "poll_id": question.poll_id,
        "like_count": question.like_count,
        "interesting_count": question.interesting_count,
        "agree_count": question.agree_count,
        "created_at": question.created_at,
        "updated_at": question.updated_at,
    }