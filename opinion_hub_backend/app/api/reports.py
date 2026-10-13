from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.dependencies import get_current_user
from app.database.connection import get_db
from app.models.user import User
from app.schemas.report import ReportCreate, ReportResponse
from app.services.community_features_service import record_report_moderation
from app.services.report_service import (
    create_answer_report,
    create_question_report,
    create_reply_report,
)


router = APIRouter(
    prefix="/reports",
    tags=["Reports"],
)


def _run_moderation_safely(db: Session, report_id: int) -> None:
    try:
        record_report_moderation(db, report_id)
    except Exception:
        # Reports must remain available even if AI or the audit write fails.
        db.rollback()


@router.post(
    "/question/{question_id}",
    response_model=ReportResponse,
    status_code=status.HTTP_201_CREATED,
)
def report_question(
    question_id: int,
    request: ReportCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    try:
        report = create_question_report(
            db=db,
            reporter_user_id=current_user.user_id,
            question_id=question_id,
            reason=request.reason,
            description=request.description,
        )
    except ValueError as error:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(error),
        ) from error

    _run_moderation_safely(db, report.report_id)
    return report


@router.post(
    "/answer/{answer_id}",
    response_model=ReportResponse,
    status_code=status.HTTP_201_CREATED,
)
def report_answer(
    answer_id: int,
    request: ReportCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    try:
        report = create_answer_report(
            db=db,
            reporter_user_id=current_user.user_id,
            answer_id=answer_id,
            reason=request.reason,
            description=request.description,
        )
    except ValueError as error:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(error),
        ) from error

    _run_moderation_safely(db, report.report_id)
    return report


@router.post(
    "/reply/{reply_id}",
    response_model=ReportResponse,
    status_code=status.HTTP_201_CREATED,
)
def report_reply(
    reply_id: int,
    request: ReportCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    try:
        report = create_reply_report(
            db=db,
            reporter_user_id=current_user.user_id,
            reply_id=reply_id,
            reason=request.reason,
            description=request.description,
        )
    except ValueError as error:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(error),
        ) from error

    _run_moderation_safely(db, report.report_id)
    return report