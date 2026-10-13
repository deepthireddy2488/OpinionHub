from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database.connection import Base


class Answer(Base):
    __tablename__ = "answers"

    answer_id: Mapped[int] = mapped_column(
        primary_key=True,
        autoincrement=True,
    )

    question_id: Mapped[int] = mapped_column(
        ForeignKey("questions.question_id", ondelete="CASCADE"),
        nullable=False,
    )

    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.user_id", ondelete="CASCADE"),
        nullable=False,
    )

    answer_text: Mapped[str] = mapped_column(
        Text,
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
        Boolean,
        default=True,
    )

    question = relationship(
        "Question",
        back_populates="answers",
    )

    user = relationship(
        "User",
        back_populates="answers",
    )

    replies = relationship(
        "Reply",
        back_populates="answer",
    )

    reactions = relationship(
        "AnswerReaction",
        back_populates="answer",
    )

    reports = relationship(
        "Report",
        back_populates="answer",
    )