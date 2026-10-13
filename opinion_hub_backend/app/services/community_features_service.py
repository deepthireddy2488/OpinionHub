from datetime import datetime

from fastapi import HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.orm import Session, aliased

from app.models.answer import Answer
from app.models.answer_reaction import AnswerReaction
from app.models.community_features import (
    ModerationAudit,
    QuestionBookmark,
    UserNotification,
)
from app.models.group_member import GroupMember
from app.models.question import Question
from app.models.question_reaction import QuestionReaction
from app.models.reply import Reply
from app.models.report import Report
from app.models.user import User
from app.services.ai_service import moderate_text
from app.services.question_service import get_question_by_id


def create_user_notification(
    db: Session,
    recipient_user_id: int,
    actor_user_id: int | None,
    notification_type: str,
    title: str,
    body: str,
    target_type: str | None = None,
    target_id: int | None = None,
) -> None:
    if actor_user_id == recipient_user_id:
        return

    db.add(
        UserNotification(
            recipient_user_id=recipient_user_id,
            actor_user_id=actor_user_id,
            notification_type=notification_type,
            title=title[:120],
            body=body[:500],
            target_type=target_type,
            target_id=target_id,
            is_read=False,
        )
    )
    db.commit()


def search_public_profile(
    db: Session,
    public_code: str,
) -> User:
    code = public_code.strip().upper()

    if not code:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Enter a public code.",
        )

    user = db.scalar(
        select(User).where(
            User.public_code == code,
            User.is_active.is_(True),
        )
    )

    if user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No active user was found for that public code.",
        )

    return user


def _count(db: Session, statement) -> int:
    return int(db.scalar(statement) or 0)


def get_public_profile(
    db: Session,
    public_code: str,
) -> dict:
    user = search_public_profile(db, public_code)

    question_count = _count(
        db,
        select(func.count(Question.question_id)).where(
            Question.user_id == user.user_id,
            Question.group_id.is_(None),
            Question.is_active.is_(True),
        ),
    )

    answer_count = _count(
        db,
        select(func.count(Answer.answer_id))
        .join(Question, Question.question_id == Answer.question_id)
        .where(
            Answer.user_id == user.user_id,
            Answer.is_active.is_(True),
            Question.is_active.is_(True),
            Question.group_id.is_(None),
        ),
    )

    question_reactions = _count(
        db,
        select(func.count(QuestionReaction.question_reaction_id))
        .join(
            Question,
            Question.question_id == QuestionReaction.question_id,
        )
        .where(
            Question.user_id == user.user_id,
            Question.group_id.is_(None),
            Question.is_active.is_(True),
        ),
    )

    answer_reactions = _count(
        db,
        select(func.count(AnswerReaction.answer_reaction_id))
        .join(Answer, Answer.answer_id == AnswerReaction.answer_id)
        .join(Question, Question.question_id == Answer.question_id)
        .where(
            Answer.user_id == user.user_id,
            Answer.is_active.is_(True),
            Question.is_active.is_(True),
            Question.group_id.is_(None),
        ),
    )

    received_reactions = question_reactions + answer_reactions

    # Transparent MVP scoring: these are reputation points, not a rating
    # of whether a person's opinions are factually correct.
    points = (
        question_count * 2
        + answer_count * 3
        + received_reactions * 2
    )

    badges = []

    if question_count >= 1:
        badges.append({
            "code": "first_question",
            "title": "Curious Mind",
            "description": "Shared a public question.",
        })

    if answer_count >= 1:
        badges.append({
            "code": "first_opinion",
            "title": "Voice Heard",
            "description": "Shared a public opinion.",
        })

    if answer_count >= 10:
        badges.append({
            "code": "contributor",
            "title": "Community Contributor",
            "description": "Shared at least 10 public opinions.",
        })

    if received_reactions >= 10:
        badges.append({
            "code": "recognized",
            "title": "Recognized Voice",
            "description": "Received at least 10 reactions on public content.",
        })

    if points >= 100:
        badges.append({
            "code": "active_member",
            "title": "Active Member",
            "description": "Reached 100 reputation points.",
        })

    recent_rows = db.execute(
        select(Question.question_id)
        .where(
            Question.user_id == user.user_id,
            Question.group_id.is_(None),
            Question.is_active.is_(True),
        )
        .order_by(Question.created_at.desc())
        .limit(5)
    ).all()

    recent_questions = []

    for row in recent_rows:
        question = get_question_by_id(
            db=db,
            question_id=row[0],
        )

        if question is not None:
            recent_questions.append(dict(question._mapping))

    return {
        "user_id": user.user_id,
        "nickname": user.nickname,
        "public_code": user.public_code,
        "profile_picture_url": user.profile_picture_url,
        "created_at": user.created_at,
        "question_count": question_count,
        "answer_count": answer_count,
        "received_reactions": received_reactions,
        "reputation_points": points,
        "badges": badges,
        "recent_questions": recent_questions,
    }


def _check_question_access(
    db: Session,
    question: Question,
    user_id: int,
) -> None:
    if question.group_id is None:
        return

    membership = db.scalar(
        select(GroupMember).where(
            GroupMember.group_id == question.group_id,
            GroupMember.user_id == user_id,
            GroupMember.is_active.is_(True),
        )
    )

    if membership is None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You are not a member of this group.",
        )


def add_question_bookmark(
    db: Session,
    user_id: int,
    question_id: int,
) -> QuestionBookmark:
    question = db.scalar(
        select(Question).where(
            Question.question_id == question_id,
            Question.is_active.is_(True),
        )
    )

    if question is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Question not found.",
        )

    _check_question_access(db, question, user_id)

    existing = db.scalar(
        select(QuestionBookmark).where(
            QuestionBookmark.user_id == user_id,
            QuestionBookmark.question_id == question_id,
        )
    )

    if existing is not None:
        return existing

    bookmark = QuestionBookmark(
        user_id=user_id,
        question_id=question_id,
    )

    db.add(bookmark)
    db.commit()
    db.refresh(bookmark)

    return bookmark


def remove_question_bookmark(
    db: Session,
    user_id: int,
    question_id: int,
) -> None:
    bookmark = db.scalar(
        select(QuestionBookmark).where(
            QuestionBookmark.user_id == user_id,
            QuestionBookmark.question_id == question_id,
        )
    )

    if bookmark is not None:
        db.delete(bookmark)
        db.commit()


def get_question_bookmarks(
    db: Session,
    user_id: int,
) -> list[dict]:
    bookmarks = db.scalars(
        select(QuestionBookmark)
        .where(QuestionBookmark.user_id == user_id)
        .order_by(QuestionBookmark.created_at.desc())
    ).all()

    results = []

    for bookmark in bookmarks:
        question = db.scalar(
            select(Question).where(
                Question.question_id == bookmark.question_id,
                Question.is_active.is_(True),
            )
        )

        if question is None:
            continue

        try:
            _check_question_access(db, question, user_id)
        except HTTPException:
            continue

        question_data = get_question_by_id(
            db=db,
            question_id=question.question_id,
        )

        if question_data is None:
            continue

        results.append({
            "bookmark_id": bookmark.bookmark_id,
            "bookmarked_at": bookmark.created_at,
            "question": dict(question_data._mapping),
        })

    return results


def get_user_notifications(
    db: Session,
    user_id: int,
    unread_only: bool = False,
    limit: int = 50,
) -> list[dict]:
    actor = aliased(User)

    statement = (
        select(UserNotification, actor)
        .outerjoin(
            actor,
            actor.user_id == UserNotification.actor_user_id,
        )
        .where(UserNotification.recipient_user_id == user_id)
        .order_by(UserNotification.created_at.desc())
        .limit(max(1, min(limit, 100)))
    )

    if unread_only:
        statement = statement.where(
            UserNotification.is_read.is_(False)
        )

    rows = db.execute(statement).all()

    return [
        {
            "notification_id": notification.notification_id,
            "notification_type": notification.notification_type,
            "title": notification.title,
            "body": notification.body,
            "target_type": notification.target_type,
            "target_id": notification.target_id,
            "is_read": notification.is_read,
            "created_at": notification.created_at,
            "actor_nickname": user.nickname if user else None,
            "actor_public_code": user.public_code if user else None,
            "actor_profile_picture_url": (
                user.profile_picture_url if user else None
            ),
        }
        for notification, user in rows
    ]


def mark_notification_read(
    db: Session,
    user_id: int,
    notification_id: int,
) -> bool:
    notification = db.scalar(
        select(UserNotification).where(
            UserNotification.notification_id == notification_id,
            UserNotification.recipient_user_id == user_id,
        )
    )

    if notification is None:
        return False

    notification.is_read = True
    db.commit()

    return True


def mark_all_notifications_read(
    db: Session,
    user_id: int,
) -> int:
    notifications = db.scalars(
        select(UserNotification).where(
            UserNotification.recipient_user_id == user_id,
            UserNotification.is_read.is_(False),
        )
    ).all()

    for notification in notifications:
        notification.is_read = True

    db.commit()

    return len(notifications)


def record_report_moderation(
    db: Session,
    report_id: int,
) -> ModerationAudit | None:
    report = db.get(Report, report_id)

    if report is None:
        return None

    content_type = ""
    content_id = 0
    content_text = ""

    if report.question_id is not None:
        content_type = "question"
        content_id = report.question_id
        content = db.get(Question, report.question_id)

        if content is not None:
            content_text = content.title

    elif report.answer_id is not None:
        content_type = "answer"
        content_id = report.answer_id
        content = db.get(Answer, report.answer_id)

        if content is not None:
            content_text = content.answer_text

    elif report.reply_id is not None:
        content_type = "reply"
        content_id = report.reply_id
        content = db.get(Reply, report.reply_id)

        if content is not None:
            content_text = content.reply_text

    result = moderate_text(content_text)

    audit = ModerationAudit(
        report_id=report.report_id,
        content_type=content_type or "unknown",
        content_id=content_id,
        ai_status=result["ai_status"],
        flagged=result["flagged"],
        categories=result["categories"],
        explanation=result["explanation"],
    )

    db.add(audit)
    db.commit()
    db.refresh(audit)

    return audit


def list_admin_reports(
    db: Session,
    report_status: str = "pending",
    limit: int = 50,
) -> list[dict]:
    statement = (
        select(Report)
        .order_by(Report.created_at.desc())
        .limit(max(1, min(limit, 100)))
    )

    if report_status != "all":
        statement = statement.where(Report.status == report_status)

    reports = db.scalars(statement).all()
    results = []

    for report in reports:
        audit = db.scalar(
            select(ModerationAudit)
            .where(ModerationAudit.report_id == report.report_id)
            .order_by(ModerationAudit.created_at.desc())
        )

        results.append({
            "report_id": report.report_id,
            "reporter_user_id": report.reporter_user_id,
            "question_id": report.question_id,
            "answer_id": report.answer_id,
            "reply_id": report.reply_id,
            "reason": report.reason,
            "description": report.description,
            "status": report.status,
            "created_at": report.created_at,
            "reviewed_at": report.reviewed_at,
            "ai_status": audit.ai_status if audit else None,
            "ai_flagged": audit.flagged if audit else None,
            "ai_categories": audit.categories if audit else None,
        })

    return results


def decide_report(
    db: Session,
    report_id: int,
    action: str,
) -> Report:
    report = db.get(Report, report_id)

    if report is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Report not found.",
        )

    if action == "hide":
        if report.question_id is not None:
            content = db.get(Question, report.question_id)
        elif report.answer_id is not None:
            content = db.get(Answer, report.answer_id)
        elif report.reply_id is not None:
            content = db.get(Reply, report.reply_id)
        else:
            content = None

        if content is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Reported content was not found.",
            )

        content.is_active = False
        report.status = "resolved"
    else:
        report.status = action

    report.reviewed_at = datetime.utcnow()
    db.commit()
    db.refresh(report)

    return report