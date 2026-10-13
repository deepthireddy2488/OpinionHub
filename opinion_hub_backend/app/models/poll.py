from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, Integer
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database.connection import Base


class Poll(Base):
    __tablename__ = "polls"

    poll_id: Mapped[int] = mapped_column(Integer, primary_key=True)
    question_id: Mapped[int] = mapped_column(
        ForeignKey("questions.question_id", ondelete="CASCADE"),
        nullable=False,
        unique=True,
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

    question = relationship("Question", back_populates="poll")
    options = relationship(
        "PollOption",
        back_populates="poll",
        cascade="all, delete-orphan",
    )
    votes = relationship(
        "PollVote",
        back_populates="poll",
        cascade="all, delete-orphan",
    )