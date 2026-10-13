from datetime import datetime

from sqlalchemy import (
    CheckConstraint,
    DateTime,
    ForeignKey,
    String,
    Text,
)
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.database.connection import Base


class Report(Base):
    __tablename__ = "reports"

    report_id: Mapped[int] = mapped_column(
        primary_key=True,
        autoincrement=True,
    )

    reporter_user_id: Mapped[int] = mapped_column(
        ForeignKey("users.user_id", ondelete="CASCADE"),
        nullable=False,
    )

    question_id: Mapped[int | None] = mapped_column(
        ForeignKey("questions.question_id", ondelete="CASCADE"),
        nullable=True,
    )

    answer_id: Mapped[int | None] = mapped_column(
        ForeignKey("answers.answer_id", ondelete="CASCADE"),
        nullable=True,
    )

    reply_id: Mapped[int | None] = mapped_column(
        ForeignKey("replies.reply_id", ondelete="CASCADE"),
        nullable=True,
    )

    reason: Mapped[str] = mapped_column(
        String(50),
        nullable=False,
    )

    description: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
    )

    status: Mapped[str] = mapped_column(
        String(20),
        default="pending",
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime,
        default=datetime.utcnow,
    )

    reviewed_at: Mapped[datetime | None] = mapped_column(
        DateTime,
        nullable=True,
    )

    __table_args__ = (
        CheckConstraint(
            """
            (question_id IS NOT NULL)::integer +
            (answer_id IS NOT NULL)::integer +
            (reply_id IS NOT NULL)::integer = 1
            """,
            name="chk_report_target",
        ),
        CheckConstraint(
            "status IN ('pending', 'reviewed', 'resolved', 'rejected')",
            name="chk_report_status",
        ),
    )

    reporter = relationship("User", back_populates="reports")
    question = relationship("Question", back_populates="reports")
    answer = relationship("Answer", back_populates="reports")
    reply = relationship("Reply", back_populates="reports")