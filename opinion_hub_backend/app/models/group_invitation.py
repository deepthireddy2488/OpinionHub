from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database.connection import Base


class GroupInvitation(Base):
    __tablename__ = "group_invitations"

    invitation_id: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
    )

    group_id: Mapped[int] = mapped_column(
        ForeignKey("groups.group_id", ondelete="CASCADE"),
        nullable=False,
    )

    invited_user_id: Mapped[int] = mapped_column(
        ForeignKey("users.user_id", ondelete="CASCADE"),
        nullable=False,
    )

    invited_by_user_id: Mapped[int] = mapped_column(
        ForeignKey("users.user_id", ondelete="CASCADE"),
        nullable=False,
    )

    status: Mapped[str] = mapped_column(
        String(20),
        default="pending",
        nullable=False,
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime,
        default=datetime.utcnow,
    )

    responded_at: Mapped[datetime | None] = mapped_column(
        DateTime,
        nullable=True,
    )

    group = relationship(
        "Group",
        back_populates="invitations",
    )

    invited_user = relationship(
        "User",
        foreign_keys=[invited_user_id],
    )

    invited_by_user = relationship(
        "User",
        foreign_keys=[invited_by_user_id],
    )