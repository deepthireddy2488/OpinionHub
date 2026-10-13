from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.group_member import GroupMember
from app.models.question import Question
from app.models.question_reaction import QuestionReaction
from app.services.community_features_service import create_user_notification


QUESTION_REACTIONS = {
    "like",
    "interesting",
    "agree",
}


def create_question_reaction(
    db: Session,
    user_id: int,
    question_id: int,
    reaction_type: str,
) -> QuestionReaction:
    if reaction_type not in QUESTION_REACTIONS:
        raise ValueError("Invalid reaction type for a question")

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

    existing = db.scalar(
        select(QuestionReaction).where(
            QuestionReaction.user_id == user_id,
            QuestionReaction.question_id == question_id,
        )
    )

    is_new_reaction = existing is None

    if existing is not None:
        existing.reaction_type = reaction_type
        db.commit()
        db.refresh(existing)
        reaction = existing
    else:
        reaction = QuestionReaction(
            user_id=user_id,
            question_id=question_id,
            reaction_type=reaction_type,
        )
        db.add(reaction)
        db.commit()
        db.refresh(reaction)

    # Notify only when a new reaction record is added, not whenever
    # the same user changes their existing reaction.
    if is_new_reaction:
        create_user_notification(
            db=db,
            recipient_user_id=question.user_id,
            actor_user_id=user_id,
            notification_type="question_reaction",
            title="Someone reacted to your question",
            body=f"Your question received a {reaction_type} reaction.",
            target_type="question",
            target_id=question_id,
        )

    return reaction