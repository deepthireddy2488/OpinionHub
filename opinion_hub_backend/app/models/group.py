from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database.connection import Base


class Group(Base):
    __tablename__ = "groups"

    group_id: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
    )

    group_name: Mapped[str] = mapped_column(
        String(100),
        nullable=False,
    )

    created_by_user_id: Mapped[int] = mapped_column(
        ForeignKey("users.user_id", ondelete="CASCADE"),
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

    creator = relationship(
        "User",
        foreign_keys=[created_by_user_id],
    )

    members = relationship(
        "GroupMember",
        back_populates="group",
        cascade="all, delete-orphan",
    )

    invitations = relationship(
        "GroupInvitation",
        back_populates="group",
        cascade="all, delete-orphan",
    )

    questions = relationship(
        "Question",
        back_populates="group",
    )