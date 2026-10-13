from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.answer import Answer
from app.models.group_member import GroupMember
from app.models.question import Question
from app.models.reply import Reply
from app.models.report import Report


def _check_group_membership(
    db: Session,
    user_id: int,
    group_id: int,
):
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


def create_question_report(
    db: Session,
    reporter_user_id: int,
    question_id: int,
    reason: str,
    description: str | None,
) -> Report:

    question = db.scalar(
        select(Question).where(
            Question.question_id == question_id,
            Question.is_active.is_(True),
        )
    )

    if question is None:
        raise ValueError("Question not found")

    if question.group_id is not None:
        _check_group_membership(
            db=db,
            user_id=reporter_user_id,
            group_id=question.group_id,
        )

    report = Report(
        reporter_user_id=reporter_user_id,
        question_id=question_id,
        reason=reason.strip(),
        description=description.strip() if description else None,
    )

    db.add(report)
    db.commit()
    db.refresh(report)

    return report


def create_answer_report(
    db: Session,
    reporter_user_id: int,
    answer_id: int,
    reason: str,
    description: str | None,
) -> Report:

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
            user_id=reporter_user_id,
            group_id=question.group_id,
        )

    report = Report(
        reporter_user_id=reporter_user_id,
        answer_id=answer_id,
        reason=reason.strip(),
        description=description.strip() if description else None,
    )

    db.add(report)
    db.commit()
    db.refresh(report)

    return report


def create_reply_report(
    db: Session,
    reporter_user_id: int,
    reply_id: int,
    reason: str,
    description: str | None,
) -> Report:

    reply = db.scalar(
        select(Reply).where(
            Reply.reply_id == reply_id,
            Reply.is_active.is_(True),
        )
    )

    if reply is None:
        raise ValueError("Reply not found")

    answer = db.scalar(
        select(Answer).where(
            Answer.answer_id == reply.answer_id,
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
            user_id=reporter_user_id,
            group_id=question.group_id,
        )

    report = Report(
        reporter_user_id=reporter_user_id,
        reply_id=reply_id,
        reason=reason.strip(),
        description=description.strip() if description else None,
    )

    db.add(report)
    db.commit()
    db.refresh(report)

    return report