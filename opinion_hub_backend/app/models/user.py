from datetime import datetime

from sqlalchemy import Boolean, DateTime, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database.connection import Base


class User(Base):
    __tablename__ = "users"

    user_id: Mapped[int] = mapped_column(
        primary_key=True,
        autoincrement=True,
    )

    email: Mapped[str] = mapped_column(
        String(255),
        unique=True,
        nullable=False,
    )

    password_hash: Mapped[str] = mapped_column(
        nullable=False,
    )

    nickname: Mapped[str] = mapped_column(
        String(50),
        nullable=False,
    )

    public_code: Mapped[str] = mapped_column(
        String(20),
        unique=True,
        nullable=False,
    )

    profile_picture_url: Mapped[str | None] = mapped_column(
        String(500),
        nullable=True,
        default=None,
    )

    is_admin: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime,
        default=datetime.utcnow,
    )

    is_active: Mapped[bool] = mapped_column(
        Boolean,
        default=True,
    )

    questions = relationship("Question", back_populates="user")
    answers = relationship("Answer", back_populates="user")
    replies = relationship("Reply", back_populates="user")

    question_reactions = relationship(
        "QuestionReaction",
        back_populates="user",
    )

    answer_reactions = relationship(
        "AnswerReaction",
        back_populates="user",
    )

    reports = relationship(
        "Report",
        back_populates="reporter",
    )

    groups_created = relationship(
        "Group",
        foreign_keys="Group.created_by_user_id",
    )

    group_memberships = relationship(
        "GroupMember",
        foreign_keys="GroupMember.user_id",
        back_populates="user",
    )

    sent_group_invitations = relationship(
        "GroupInvitation",
        foreign_keys="GroupInvitation.invited_by_user_id",
    )

    received_group_invitations = relationship(
        "GroupInvitation",
        foreign_keys="GroupInvitation.invited_user_id",
    )