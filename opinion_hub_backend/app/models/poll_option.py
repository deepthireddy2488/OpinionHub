from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database.connection import Base


class PollOption(Base):
    __tablename__ = "poll_options"

    option_id: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
    )

    poll_id: Mapped[int] = mapped_column(
        ForeignKey("polls.poll_id", ondelete="CASCADE"),
        nullable=False,
    )

    option_text: Mapped[str] = mapped_column(
        String(200),
        nullable=False,
    )

    option_order: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime,
        default=datetime.utcnow,
    )

    poll = relationship(
        "Poll",
        back_populates="options",
    )

    votes = relationship(
        "PollVote",
        back_populates="option",
        cascade="all, delete-orphan",
    )