from fastapi import HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.models.answer import Answer
from app.models.answer_reaction import AnswerReaction
from app.models.group_member import GroupMember
from app.models.question import Question
from app.models.question_reaction import QuestionReaction
from app.models.user import User
from app.services.community_features_service import create_user_notification


def create_answer(
    db: Session,
    user_id: int,
    question_id: int,
    answer_text: str,
) -> Answer:
    question = db.scalar(
        select(Question).where(
            Question.question_id == question_id,
            Question.is_active.is_(True),
        )
    )

    if question is None:
        raise ValueError("Question not found")

    if question.group_id is not None:
        membership = db.scalar(
            select(GroupMember).where(
                GroupMember.group_id == question.group_id,
                GroupMember.user_id == user_id,
                GroupMember.is_active.is_(True),
            )
        )

        if membership is None:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You are not a member of this group",
            )

    cleaned_text = answer_text.strip()

    if not cleaned_text:
        raise ValueError("Opinion cannot be empty")

    answer = Answer(
        question_id=question_id,
        user_id=user_id,
        answer_text=cleaned_text,
    )

    db.add(answer)
    db.commit()
    db.refresh(answer)

    create_user_notification(
        db=db,
        recipient_user_id=question.user_id,
        actor_user_id=user_id,
        notification_type="answer",
        title="New community opinion",
        body="Someone shared an opinion on your question.",
        target_type="question",
        target_id=question_id,
    )

    return answer


def get_answers_by_question(
    db: Session,
    question_id: int,
    user_id: int | None = None,
):
    question = db.scalar(
        select(Question).where(
            Question.question_id == question_id,
            Question.is_active.is_(True),
        )
    )

    if question is None:
        raise ValueError("Question not found")

    if question.group_id is not None:
        if user_id is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Authentication required for group questions",
            )

        membership = db.scalar(
            select(GroupMember).where(
                GroupMember.group_id == question.group_id,
                GroupMember.user_id == user_id,
                GroupMember.is_active.is_(True),
            )
        )

        if membership is None:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You are not a member of this group",
            )

    helpful_count = func.count(
        AnswerReaction.answer_reaction_id
    ).filter(
        AnswerReaction.reaction_type == "helpful"
    )

    agree_count = func.count(
        AnswerReaction.answer_reaction_id
    ).filter(
        AnswerReaction.reaction_type == "agree"
    )

    good_answer_count = func.count(
        AnswerReaction.answer_reaction_id
    ).filter(
        AnswerReaction.reaction_type == "good_answer"
    )

    return db.execute(
        select(
            Answer.answer_id,
            Answer.question_id,
            User.public_code,
            User.profile_picture_url.label("profile_picture_url"),
            Answer.answer_text,
            helpful_count.label("helpful_count"),
            agree_count.label("agree_count"),
            good_answer_count.label("good_answer_count"),
            Answer.created_at,
            Answer.updated_at,
        )
        .join(
            User,
            User.user_id == Answer.user_id,
        )
        .outerjoin(
            AnswerReaction,
            AnswerReaction.answer_id == Answer.answer_id,
        )
        .where(
            Answer.question_id == question_id,
            Answer.is_active.is_(True),
            User.is_active.is_(True),
        )
        .group_by(
            Answer.answer_id,
            Answer.question_id,
            User.public_code,
            User.profile_picture_url,
            Answer.answer_text,
            Answer.created_at,
            Answer.updated_at,
        )
        .order_by(Answer.created_at.asc())
    ).all()


def get_answer_by_id(
    db: Session,
    answer_id: int,
) -> Answer | None:
    return db.scalar(
        select(Answer).where(
            Answer.answer_id == answer_id,
            Answer.is_active.is_(True),
        )
    )