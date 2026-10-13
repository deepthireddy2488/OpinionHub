from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.dependencies import get_current_user
from app.database.connection import get_db
from app.models.answer import Answer
from app.models.community_features import QuestionBookmark
from app.models.question import Question
from app.models.user import User
from app.schemas.community_features import (
    AISummaryResponse,
    AdminReportResponse,
    BadgeResponse,
    BookmarkResponse,
    NotificationResponse,
    PublicProfileResponse,
    QuestionPreview,
    ReportDecisionRequest,
)
from app.services.ai_service import summarize_perspectives
from app.services.community_features_service import (
    add_question_bookmark,
    decide_report,
    get_public_profile,
    get_question_bookmarks,
    get_user_notifications,
    list_admin_reports,
    mark_all_notifications_read,
    mark_notification_read,
)
from app.services.answer_service import get_answers_by_question


router = APIRouter(
    prefix="/community",
    tags=["Community features"],
)


def _require_admin(user: User) -> None:
    if not user.is_admin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Administrator access is required.",
        )


@router.get(
    "/search",
    response_model=PublicProfileResponse,
)
def search_profile(
    public_code: str = Query(min_length=1, max_length=20),
    db: Session = Depends(get_db),
):
    return get_public_profile(db, public_code)


@router.get(
    "/profiles/{public_code}",
    response_model=PublicProfileResponse,
)
def read_public_profile(
    public_code: str,
    db: Session = Depends(get_db),
):
    return get_public_profile(db, public_code)


@router.get(
    "/profiles/{public_code}/reputation",
    response_model=PublicProfileResponse,
)
def read_reputation(
    public_code: str,
    db: Session = Depends(get_db),
):
    # Reputation and badges are calculated from public content.
    return get_public_profile(db, public_code)


@router.post(
    "/bookmarks/questions/{question_id}",
    response_model=BookmarkResponse,
    status_code=status.HTTP_201_CREATED,
)
def bookmark_question(
    question_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    bookmark = add_question_bookmark(
        db=db,
        user_id=current_user.user_id,
        question_id=question_id,
    )

    question_data = db.execute(
        select(Question.question_id)
        .where(Question.question_id == question_id)
    ).first()

    if question_data is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Question not found.",
        )

    from app.services.question_service import get_question_by_id

    question = get_question_by_id(db=db, question_id=question_id)

    return {
        "bookmark_id": bookmark.bookmark_id,
        "bookmarked_at": bookmark.created_at,
        "question": dict(question._mapping),
    }


@router.get(
    "/bookmarks/questions",
    response_model=list[BookmarkResponse],
)
def list_bookmarked_questions(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return get_question_bookmarks(
        db=db,
        user_id=current_user.user_id,
    )


@router.delete(
    "/bookmarks/questions/{question_id}",
)
def unbookmark_question(
    question_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    from app.services.community_features_service import (
        remove_question_bookmark,
    )

    remove_question_bookmark(
        db=db,
        user_id=current_user.user_id,
        question_id=question_id,
    )

    return {"message": "Question removed from saved items."}


@router.get(
    "/notifications",
    response_model=list[NotificationResponse],
)
def list_notifications(
    unread_only: bool = False,
    limit: int = Query(default=50, ge=1, le=100),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return get_user_notifications(
        db=db,
        user_id=current_user.user_id,
        unread_only=unread_only,
        limit=limit,
    )


@router.post("/notifications/read-all")
def read_all_notifications(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    count = mark_all_notifications_read(
        db=db,
        user_id=current_user.user_id,
    )

    return {
        "message": "Notifications marked as read.",
        "updated_count": count,
    }


@router.post("/notifications/{notification_id}/read")
def read_notification(
    notification_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    success = mark_notification_read(
        db=db,
        user_id=current_user.user_id,
        notification_id=notification_id,
    )

    if not success:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Notification not found.",
        )

    return {"message": "Notification marked as read."}


@router.post(
    "/questions/{question_id}/ai-summary",
    response_model=AISummaryResponse,
)
def create_ai_summary(
    question_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
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

    # This service enforces group membership for group questions.
    answers = get_answers_by_question(
        db=db,
        question_id=question_id,
        user_id=current_user.user_id,
    )

    opinions = [answer.answer_text for answer in answers]

    summary = summarize_perspectives(
        question_title=question.title,
        answers=opinions,
    )

    return {
        "question_id": question.question_id,
        "question_title": question.title,
        **summary,
        "ai_generated": True,
        "generated_at": datetime.utcnow(),
    }


@router.get(
    "/admin/reports",
    response_model=list[AdminReportResponse],
)
def admin_report_queue(
    report_status: str = Query(default="pending", max_length=20),
    limit: int = Query(default=50, ge=1, le=100),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    _require_admin(current_user)

    allowed_statuses = {
        "pending",
        "reviewed",
        "resolved",
        "rejected",
        "all",
    }

    if report_status not in allowed_statuses:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Invalid report status filter.",
        )

    return list_admin_reports(
        db=db,
        report_status=report_status,
        limit=limit,
    )


@router.post(
    "/admin/reports/{report_id}/decision",
    response_model=AdminReportResponse,
)
def review_report(
    report_id: int,
    request: ReportDecisionRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    _require_admin(current_user)

    report = decide_report(
        db=db,
        report_id=report_id,
        action=request.action,
    )

    rows = list_admin_reports(
        db=db,
        report_status="all",
        limit=100,
    )

    for row in rows:
        if row["report_id"] == report.report_id:
            return row

    raise HTTPException(
        status_code=status.HTTP_404_NOT_FOUND,
        detail="Reviewed report not found.",
    )