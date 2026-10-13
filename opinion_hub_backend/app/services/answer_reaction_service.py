from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.answer import Answer
from app.models.answer_reaction import AnswerReaction
from app.models.group_member import GroupMember
from app.models.question import Question
from app.services.community_features_service import create_user_notification


ANSWER_REACTIONS = {
    "helpful",
    "agree",
    "good_answer",
}


def create_answer_reaction(
    db: Session,
    user_id: int,
    answer_id: int,
    reaction_type: str,
) -> AnswerReaction:
    if reaction_type not in ANSWER_REACTIONS:
        raise ValueError("Invalid reaction type for an answer")

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

    existing = db.scalar(
        select(AnswerReaction).where(
            AnswerReaction.user_id == user_id,
            AnswerReaction.answer_id == answer_id,
        )
    )

    is_new_reaction = existing is None

    if existing is not None:
        existing.reaction_type = reaction_type
        db.commit()
        db.refresh(existing)
        reaction = existing
    else:
        reaction = AnswerReaction(
            user_id=user_id,
            answer_id=answer_id,
            reaction_type=reaction_type,
        )
        db.add(reaction)
        db.commit()
        db.refresh(reaction)

    if is_new_reaction:
        create_user_notification(
            db=db,
            recipient_user_id=answer.user_id,
            actor_user_id=user_id,
            notification_type="answer_reaction",
            title="Someone reacted to your opinion",
            body=f"Your opinion received a {reaction_type} reaction.",
            target_type="answer",
            target_id=answer_id,
        )

    return reaction