from fastapi import HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.models.answer import Answer
from app.models.answer_reaction import AnswerReaction
from app.models.group_member import GroupMember
from app.models.question import Question
from app.models.question_reaction import QuestionReaction
from app.models.user import User


def get_question_details(
    db: Session,
    question_id: int,
    user_id: int | None = None,
):

    question = db.execute(
        select(
            Question.question_id,
            Question.group_id,
            User.public_code,
            Question.title,
            Question.created_at,
            Question.updated_at,
        )
        .join(
            User,
            User.user_id == Question.user_id,
        )
        .where(
            Question.question_id == question_id,
            Question.is_active.is_(True),
            User.is_active.is_(True),
        )
    ).first()

    if question is None:
        return None

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

    question_reactions = db.execute(
        select(
            QuestionReaction.reaction_type,
            func.count(
                QuestionReaction.question_reaction_id
            ),
        )
        .where(
            QuestionReaction.question_id == question_id,
        )
        .group_by(
            QuestionReaction.reaction_type,
        )
    ).all()

    question_counts = {
        "like": 0,
        "interesting": 0,
        "agree": 0,
    }

    for reaction_type, count in question_reactions:
        question_counts[reaction_type] = count

    answers = db.execute(
        select(
            Answer.answer_id,
            User.public_code,
            Answer.answer_text,
            Answer.created_at,
            Answer.updated_at,
        )
        .join(
            User,
            User.user_id == Answer.user_id,
        )
        .where(
            Answer.question_id == question_id,
            Answer.is_active.is_(True),
            User.is_active.is_(True),
        )
        .order_by(
            Answer.created_at.asc(),
        )
    ).all()

    answer_details = []

    for answer in answers:

        answer_reactions = db.execute(
            select(
                AnswerReaction.reaction_type,
                func.count(
                    AnswerReaction.answer_reaction_id
                ),
            )
            .where(
                AnswerReaction.answer_id == answer.answer_id,
            )
            .group_by(
                AnswerReaction.reaction_type,
            )
        ).all()

        answer_counts = {
            "helpful": 0,
            "agree": 0,
            "good_answer": 0,
        }

        for reaction_type, count in answer_reactions:
            answer_counts[reaction_type] = count

        answer_details.append(
            {
                "answer_id": answer.answer_id,
                "public_code": answer.public_code,
                "answer_text": answer.answer_text,
                "helpful_count": answer_counts["helpful"],
                "agree_count": answer_counts["agree"],
                "good_answer_count": answer_counts["good_answer"],
                "created_at": answer.created_at,
                "updated_at": answer.updated_at,
            }
        )

    return {
        "question_id": question.question_id,
        "public_code": question.public_code,
        "title": question.title,
        "group_id": question.group_id,
        "like_count": question_counts["like"],
        "interesting_count": question_counts["interesting"],
        "agree_count": question_counts["agree"],
        "created_at": question.created_at,
        "updated_at": question.updated_at,
        "answers": answer_details,
    }