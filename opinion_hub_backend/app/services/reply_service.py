from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.answer import Answer
from app.models.group_member import GroupMember
from app.models.question import Question
from app.models.reply import Reply
from app.models.user import User
from app.services.community_features_service import create_user_notification


def _check_group_membership(
    db: Session,
    user_id: int,
    group_id: int,
) -> None:
    membership = db.scalar(
        select(GroupMember).where(
            GroupMember.group_id == group_id,
            GroupMember.user_id == user_id,
            GroupMember.is_active.is_(True),
        )
    )

    if membership is None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You are not a member of this group",
        )


def create_reply(
    db: Session,
    user_id: int,
    answer_id: int,
    reply_text: str,
) -> Reply:
    answer = db.scalar(
        select(Answer).where(
            Answer.answer_id == answer_id,
            Answer.is_active.is_(True),
        )
    )

    if answer is None:
        raise ValueError("Answer not found")

    question = db.scalar(
        select(Question).where(
            Question.question_id == answer.question_id,
            Question.is_active.is_(True),
        )
    )

    if question is None:
        raise ValueError("Question not found")

    if question.group_id is not None:
        _check_group_membership(
            db=db,
            user_id=user_id,
            group_id=question.group_id,
        )

    cleaned_text = reply_text.strip()

    if not cleaned_text:
        raise ValueError("Reply cannot be empty")

    reply = Reply(
        answer_id=answer_id,
        user_id=user_id,
        reply_text=cleaned_text,
    )

    db.add(reply)
    db.commit()
    db.refresh(reply)

    create_user_notification(
        db=db,
        recipient_user_id=answer.user_id,
        actor_user_id=user_id,
        notification_type="reply",
        title="New reply to your opinion",
        body="Someone replied to your community opinion.",
        target_type="answer",
        target_id=answer_id,
    )

    return reply


def get_replies_by_answer(
    db: Session,
    answer_id: int,
    user_id: int | None = None,
):
    answer = db.scalar(
        select(Answer).where(
            Answer.answer_id == answer_id,
            Answer.is_active.is_(True),
        )
    )

    if answer is None:
        raise ValueError("Answer not found")

    question = db.scalar(
        select(Question).where(
            Question.question_id == answer.question_id,
            Question.is_active.is_(True),
        )
    )

    if question is None:
        raise ValueError("Question not found")

    if question.group_id is not None:
        if user_id is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Authentication required for group replies",
            )

        _check_group_membership(
            db=db,
            user_id=user_id,
            group_id=question.group_id,
        )

    return db.execute(
        select(
            Reply.reply_id,
            Reply.answer_id,
            User.public_code,
            User.profile_picture_url.label("profile_picture_url"),
            Reply.reply_text,
            Reply.created_at,
            Reply.updated_at,
        )
        .join(
            User,
            User.user_id == Reply.user_id,
        )
        .where(
            Reply.answer_id == answer_id,
            Reply.is_active.is_(True),
            User.is_active.is_(True),
        )
        .order_by(Reply.created_at.asc())
    ).all()