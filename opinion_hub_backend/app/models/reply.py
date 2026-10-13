from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database.connection import Base


class Reply(Base):
    __tablename__ = "replies"

    reply_id: Mapped[int] = mapped_column(
        primary_key=True,
        autoincrement=True,
    )

    answer_id: Mapped[int] = mapped_column(
        ForeignKey("answers.answer_id", ondelete="CASCADE"),
        nullable=False,
    )

    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.user_id", ondelete="CASCADE"),
        nullable=False,
    )

    reply_text: Mapped[str] = mapped_column(
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

    answer = relationship(
        "Answer",
        back_populates="replies",
    )

    user = relationship(
        "User",
        back_populates="replies",
    )

    reports = relationship(
        "Report",
        back_populates="reply",
    )