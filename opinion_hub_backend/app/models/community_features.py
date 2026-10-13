from datetime import datetime

from sqlalchemy import (
    Boolean,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    JSON,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.database.connection import Base


class QuestionBookmark(Base):
    __tablename__ = "question_bookmarks"

    bookmark_id: Mapped[int] = mapped_column(
        Integer,
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

    created_at: Mapped[datetime] = mapped_column(
        DateTime,
        default=datetime.utcnow,
        nullable=False,
    )

    __table_args__ = (
        UniqueConstraint(
            "user_id",
            "question_id",
            name="uq_question_bookmark_user_question",
        ),
        Index("ix_question_bookmarks_user_created", "user_id", "created_at"),
    )


class UserNotification(Base):
    __tablename__ = "user_notifications"

    notification_id: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
        autoincrement=True,
    )

    recipient_user_id: Mapped[int] = mapped_column(
        ForeignKey("users.user_id", ondelete="CASCADE"),
        nullable=False,
    )

    actor_user_id: Mapped[int | None] = mapped_column(
        ForeignKey("users.user_id", ondelete="SET NULL"),
        nullable=True,
    )

    notification_type: Mapped[str] = mapped_column(
        String(40),
        nullable=False,
    )

    title: Mapped[str] = mapped_column(
        String(120),
        nullable=False,
    )

    body: Mapped[str] = mapped_column(
        String(500),
        nullable=False,
    )

    target_type: Mapped[str | None] = mapped_column(
        String(30),
        nullable=True,
    )

    target_id: Mapped[int | None] = mapped_column(
        Integer,
        nullable=True,
    )

    is_read: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        nullable=False,
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime,
        default=datetime.utcnow,
        nullable=False,
    )

    __table_args__ = (
        Index(
            "ix_user_notifications_recipient_created",
            "recipient_user_id",
            "created_at",
        ),
    )


class ModerationAudit(Base):
    __tablename__ = "moderation_audits"

    moderation_audit_id: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
        autoincrement=True,
    )

    report_id: Mapped[int] = mapped_column(
        ForeignKey("reports.report_id", ondelete="CASCADE"),
        nullable=False,
    )

    content_type: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
    )

    content_id: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
    )

    ai_status: Mapped[str] = mapped_column(
        String(20),
        default="not_configured",
        nullable=False,
    )

    flagged: Mapped[bool | None] = mapped_column(
        Boolean,
        nullable=True,
    )

    categories: Mapped[dict | None] = mapped_column(
        JSON,
        nullable=True,
    )

    explanation: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime,
        default=datetime.utcnow,
        nullable=False,
    )