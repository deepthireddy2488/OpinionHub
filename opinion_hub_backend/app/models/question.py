from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database.connection import Base


class Question(Base):
    __tablename__ = "questions"

    question_id: Mapped[int] = mapped_column(
        primary_key=True,
        autoincrement=True,
    )

    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.user_id", ondelete="CASCADE"),
        nullable=False,
    )

    group_id: Mapped[int | None] = mapped_column(
        ForeignKey("groups.group_id", ondelete="CASCADE"),
        nullable=True,
    )

    title: Mapped[str] = mapped_column(
        String(200),
        nullable=False,
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime,
        default=datetime.utcnow,
    )

    updated_at: Mapped[datetime] = mapped_column(
        DateTime,
        default=datetime.utcnow,
        onupdate=datetime.utcnow,
    )

    is_active: Mapped[bool] = mapped_column(
        default=True,
    )

    user = relationship(
        "User",
        back_populates="questions",
    )

    group = relationship(
        "Group",
        back_populates="questions",
    )

    answers = relationship(
        "Answer",
        back_populates="question",
    )

    reactions = relationship(
        "QuestionReaction",
        back_populates="question",
    )

    reports = relationship(
        "Report",
        back_populates="question",
    )

    poll = relationship(
        "Poll",
        back_populates="question",
        uselist=False,
        cascade="all, delete-orphan",
    )