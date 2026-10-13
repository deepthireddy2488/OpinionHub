
from datetime import datetime

from sqlalchemy import (
    DateTime,
    ForeignKey,
    Integer,
    UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database.connection import Base


class PollVote(Base):
    __tablename__ = "poll_votes"

    vote_id: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
    )

    poll_id: Mapped[int] = mapped_column(
        ForeignKey("polls.poll_id", ondelete="CASCADE"),
        nullable=False,
    )

    option_id: Mapped[int] = mapped_column(
        ForeignKey("poll_options.option_id", ondelete="CASCADE"),
        nullable=False,
    )

    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.user_id", ondelete="CASCADE"),
        nullable=False,
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime,
        default=datetime.utcnow,
    )

    poll = relationship(
        "Poll",
        back_populates="votes",
    )

    option = relationship(
        "PollOption",
        back_populates="votes",
    )

    __table_args__ = (
        UniqueConstraint(
            "poll_id",
            "user_id",
            name="uq_poll_vote_user_poll",
        ),
    )
