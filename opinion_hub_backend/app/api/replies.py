from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.dependencies import get_current_user, get_current_user_optional
from app.database.connection import get_db
from app.models.user import User
from app.schemas.reply import ReplyCreate, ReplyResponse
from app.services.reply_service import create_reply, get_replies_by_answer


router = APIRouter(prefix="/replies", tags=["Replies"])


@router.post(
    "",
    response_model=ReplyResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_new_reply(
    request: ReplyCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    try:
        reply = create_reply(
            db=db,
            user_id=current_user.user_id,
            answer_id=request.answer_id,
            reply_text=request.reply_text,
        )
    except ValueError as error:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(error),
        ) from error

    return {
        "reply_id": reply.reply_id,
        "answer_id": reply.answer_id,
        "public_code": current_user.public_code,
        "profile_picture_url": current_user.profile_picture_url,
        "reply_text": reply.reply_text,
        "created_at": reply.created_at,
        "updated_at": reply.updated_at,
    }


@router.get(
    "/answer/{answer_id}",
    response_model=list[ReplyResponse],
)
def list_answer_replies(
    answer_id: int,
    current_user: User | None = Depends(get_current_user_optional),
    db: Session = Depends(get_db),
):
    try:
        replies = get_replies_by_answer(
            db=db,
            answer_id=answer_id,
            user_id=current_user.user_id if current_user else None,
        )
    except ValueError as error:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(error),
        ) from error

    return [
        {
            "reply_id": reply.reply_id,
            "answer_id": reply.answer_id,
            "public_code": reply.public_code,
            "profile_picture_url": reply.profile_picture_url,
            "reply_text": reply.reply_text,
            "created_at": reply.created_at,
            "updated_at": reply.updated_at,
        }
        for reply in replies
    ]