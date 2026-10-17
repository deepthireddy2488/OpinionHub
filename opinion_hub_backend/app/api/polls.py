from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.core.dependencies import get_current_user
from app.database.connection import get_db
from app.models.user import User
from app.schemas.poll import (
    PollCreate,
    PollResponse,
    StandalonePollCreate,
    PollVoteCreate,
    PollVoteResponse,
)
from app.services.poll_service import (
    create_poll,
    create_standalone_poll,
    get_poll,
    vote_on_poll,
)

router = APIRouter(
    prefix="/polls",
    tags=["Polls"],
)


@router.post(
    "",
    response_model=PollResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_new_poll(
    request: PollCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    poll = create_poll(
        db=db,
        user_id=current_user.user_id,
        question_id=request.question_id,
        options=[
            option.option_text
            for option in request.options
        ],
    )

    return get_poll(
        db=db,
        poll_id=poll.poll_id,
        user_id=current_user.user_id,
    )


@router.post(
    "/standalone",
    response_model=PollResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_standalone_poll_endpoint(
    request: StandalonePollCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    poll = create_standalone_poll(
        db=db,
        user_id=current_user.user_id,
        title=request.title,
        options=[option.option_text for option in request.options],
    )

    return get_poll(
        db=db,
        poll_id=poll.poll_id,
        user_id=current_user.user_id,
    )


@router.get(
    "/{poll_id}",
    response_model=PollResponse,
)
def get_poll_details(
    poll_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return get_poll(
        db=db,
        poll_id=poll_id,
        user_id=current_user.user_id,
    )


@router.post(
    "/{poll_id}/vote",
    response_model=PollVoteResponse,
)
def vote(
    poll_id: int,
    request: PollVoteCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return vote_on_poll(
        db=db,
        user_id=current_user.user_id,
        poll_id=poll_id,
        option_id=request.option_id,
    )