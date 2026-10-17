from fastapi import HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.models.group_member import GroupMember
from app.models.poll import Poll
from app.models.poll_option import PollOption
from app.models.poll_vote import PollVote
from app.models.question import Question


def _check_group_membership(
    db: Session,
    user_id: int,
    group_id: int,
):
    membership = db.scalar(
        select(GroupMember).where(
            GroupMember.group_id == group_id,
            GroupMember.user_id == user_id,
            GroupMember.is_active.is_(True),
        )
    )

    if membership is None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You are not a member of this group",
        )


def create_poll(
    db: Session,
    user_id: int,
    question_id: int,
    options: list[str],
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
            detail="Question not found",
        )

    if question.user_id != user_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You can only create a poll for your own question",
        )

    if question.group_id is not None:
        _check_group_membership(
            db=db,
            user_id=user_id,
            group_id=question.group_id,
        )

    existing_poll = db.scalar(
        select(Poll).where(
            Poll.question_id == question_id,
        )
    )

    if existing_poll is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="This question already has a poll",
        )

    poll = Poll(
        question_id=question_id,
    )

    db.add(poll)
    db.flush()

    for index, option_text in enumerate(options, start=1):
        cleaned_text = option_text.strip()

        if not cleaned_text:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Poll option cannot be empty",
            )

        option = PollOption(
            poll_id=poll.poll_id,
            option_text=cleaned_text,
            option_order=index,
        )

        db.add(option)

    db.commit()
    db.refresh(poll)

    return poll



def create_standalone_poll(
    db: Session,
    user_id: int,
    title: str,
    options: list[str],
):
    """Create the feed item, poll, and options in one database transaction."""
    cleaned_title = title.strip()
    cleaned_options = [option.strip() for option in options]

    if len(cleaned_title) < 5:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Poll question must be at least 5 characters long",
        )

    if not 2 <= len(cleaned_options) <= 6:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="A poll must have between 2 and 6 options",
        )

    if any(not option for option in cleaned_options):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Poll options cannot be empty",
        )

    if any(len(option) > 200 for option in cleaned_options):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Each poll option must be 200 characters or less",
        )

    try:
        # The backing question is an internal feed item: the user creates
        # one poll directly, without having to create a separate question.
        question = Question(
            user_id=user_id,
            group_id=None,
            title=cleaned_title,
        )
        db.add(question)
        db.flush()

        poll = Poll(question_id=question.question_id)
        db.add(poll)
        db.flush()

        for index, option_text in enumerate(cleaned_options, start=1):
            db.add(
                PollOption(
                    poll_id=poll.poll_id,
                    option_text=option_text,
                    option_order=index,
                )
            )

        db.commit()
        db.refresh(poll)
        return poll
    except Exception:
        db.rollback()
        raise

def get_poll(
    db: Session,
    poll_id: int,
    user_id: int | None = None,
):
    poll = db.scalar(
        select(Poll).where(
            Poll.poll_id == poll_id,
            Poll.is_active.is_(True),
        )
    )

    if poll is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Poll not found",
        )

    question = db.scalar(
        select(Question).where(
            Question.question_id == poll.question_id,
            Question.is_active.is_(True),
        )
    )

    if question is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Question not found",
        )

    if question.group_id is not None:

        if user_id is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Authentication required for group polls",
            )

        _check_group_membership(
            db=db,
            user_id=user_id,
            group_id=question.group_id,
        )

    options = db.scalars(
        select(PollOption)
        .where(PollOption.poll_id == poll_id)
        .order_by(PollOption.option_order)
    ).all()

    result_options = []

    total_votes = db.scalar(
        select(func.count(PollVote.vote_id))
        .where(
            PollVote.poll_id == poll_id
        )
    ) or 0

    for option in options:

        vote_count = db.scalar(
            select(func.count(PollVote.vote_id))
            .where(
                PollVote.option_id == option.option_id
            )
        ) or 0

        result_options.append(
            {
                "option_id": option.option_id,
                "option_text": option.option_text,
                "option_order": option.option_order,
                "vote_count": vote_count,
            }
        )

    return {
        "poll_id": poll.poll_id,
        "question_id": poll.question_id,
        "options": result_options,
        "total_votes": total_votes,
        "created_at": poll.created_at,
        "updated_at": poll.updated_at,
        "is_active": poll.is_active,
    }


def vote_on_poll(
    db: Session,
    user_id: int,
    poll_id: int,
    option_id: int,
):
    poll = db.scalar(
        select(Poll).where(
            Poll.poll_id == poll_id,
            Poll.is_active.is_(True),
        )
    )

    if poll is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Poll not found",
        )

    question = db.scalar(
        select(Question).where(
            Question.question_id == poll.question_id,
            Question.is_active.is_(True),
        )
    )

    if question is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Question not found",
        )

    if question.group_id is not None:
        _check_group_membership(
            db=db,
            user_id=user_id,
            group_id=question.group_id,
        )

    option = db.scalar(
        select(PollOption).where(
            PollOption.option_id == option_id,
            PollOption.poll_id == poll_id,
        )
    )

    if option is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid poll option",
        )

    existing_vote = db.scalar(
        select(PollVote).where(
            PollVote.poll_id == poll_id,
            PollVote.user_id == user_id,
        )
    )

    if existing_vote is not None:
        existing_vote.option_id = option_id
    else:
        vote = PollVote(
            poll_id=poll_id,
            option_id=option_id,
            user_id=user_id,
        )

        db.add(vote)

    db.commit()

    total_votes = db.scalar(
        select(func.count(PollVote.vote_id))
        .where(
            PollVote.poll_id == poll_id
        )
    ) or 0

    return {
        "poll_id": poll_id,
        "option_id": option_id,
        "total_votes": total_votes,
    }