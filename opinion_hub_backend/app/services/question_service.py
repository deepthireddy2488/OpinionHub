from fastapi import HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.models.group import Group
from app.models.group_member import GroupMember
from app.models.poll import Poll
from app.models.question import Question
from app.models.question_reaction import QuestionReaction
from app.models.user import User


def create_public_question(
    db: Session,
    user_id: int,
    title: str,
) -> Question:
    question = Question(
        user_id=user_id,
        group_id=None,
        title=title.strip(),
    )

    db.add(question)
    db.commit()
    db.refresh(question)

    return question


def create_group_question(
    db: Session,
    user_id: int,
    group_id: int,
    title: str,
) -> Question:
    group = db.scalar(
        select(Group).where(
            Group.group_id == group_id,
            Group.is_active.is_(True),
        )
    )

    if group is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Group not found",
        )

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

    question = Question(
        user_id=user_id,
        group_id=group_id,
        title=title.strip(),
    )

    db.add(question)
    db.commit()
    db.refresh(question)

    return question


def _question_reaction_counts():
    return (
        func.count(QuestionReaction.question_reaction_id)
        .filter(
            QuestionReaction.reaction_type == "like"
        )
        .label("like_count"),
        func.count(QuestionReaction.question_reaction_id)
        .filter(
            QuestionReaction.reaction_type == "interesting"
        )
        .label("interesting_count"),
        func.count(QuestionReaction.question_reaction_id)
        .filter(
            QuestionReaction.reaction_type == "agree"
        )
        .label("agree_count"),
    )


def _question_select():
    like_count, interesting_count, agree_count = (
        _question_reaction_counts()
    )

    return select(
        Question.question_id,
        User.public_code,
        User.profile_picture_url.label("profile_picture_url"),
        Question.title,
        Question.group_id,
        Poll.poll_id,
        like_count,
        interesting_count,
        agree_count,
        Question.created_at,
        Question.updated_at,
    )


def _question_group_by():
    return (
        Question.question_id,
        User.public_code,
        User.profile_picture_url,
        Question.title,
        Question.group_id,
        Poll.poll_id,
        Question.created_at,
        Question.updated_at,
    )


def _question_joins(statement):
    return (
        statement
        .join(User, User.user_id == Question.user_id)
        .outerjoin(
            QuestionReaction,
            QuestionReaction.question_id == Question.question_id,
        )
        .outerjoin(
            Poll,
            Poll.question_id == Question.question_id,
        )
    )


def get_questions(db: Session):
    statement = _question_select()

    statement = _question_joins(statement)

    statement = (
        statement
        .where(
            Question.is_active.is_(True),
            User.is_active.is_(True),
            Question.group_id.is_(None),
        )
        .group_by(*_question_group_by())
        .order_by(Question.created_at.desc())
    )

    return db.execute(statement).all()


def get_question_by_id(
    db: Session,
    question_id: int,
):
    statement = _question_select()

    statement = _question_joins(statement)

    statement = (
        statement
        .where(
            Question.question_id == question_id,
            Question.is_active.is_(True),
            User.is_active.is_(True),
        )
        .group_by(*_question_group_by())
    )

    return db.execute(statement).first()


def get_group_questions(
    db: Session,
    user_id: int,
    group_id: int,
):
    group = db.scalar(
        select(Group).where(
            Group.group_id == group_id,
            Group.is_active.is_(True),
        )
    )

    if group is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Group not found",
        )

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

    statement = _question_select()

    statement = _question_joins(statement)

    statement = (
        statement
        .where(
            Question.group_id == group_id,
            Question.is_active.is_(True),
            User.is_active.is_(True),
        )
        .group_by(*_question_group_by())
        .order_by(Question.created_at.desc())
    )

    return db.execute(statement).all()