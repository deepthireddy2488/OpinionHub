from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database.connection import Base


class QuestionReaction(Base):
    __tablename__ = "question_reactions"

    question_reaction_id: Mapped[int] = mapped_column(
        primary_key=True,
        autoincrement=True,
    )

    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.user_id", ondelete="CASCADE"),
        nullable=False,
    )

    question_id: Mapped[int] = mapped_column(
        ForeignKey("questions.question_id", ondelete="CASCADE"),
        nullable=False,
    )

    reaction_type: Mapped[str] = mapped_column(
        String(30),
        nullable=False,
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime,
        default=datetime.utcnow,
    )

    user = relationship(
        "User",
        back_populates="question_reactions",
    )

    question = relationship(
        "Question",
        back_populates="reactions",
    )

    __table_args__ = (
        UniqueConstraint(
            "user_id",
            "question_id",
            name="uq_question_reaction_user_question",
        ),
    )