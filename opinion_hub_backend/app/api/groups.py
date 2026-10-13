from fastapi import APIRouter, Depends, status
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.core.dependencies import get_current_user
from app.database.connection import get_db
from app.models.group import Group
from app.models.user import User
from app.schemas.group import (
    GroupCreate,
    GroupInvitationCreate,
    GroupInvitationResponse,
    GroupMemberResponse,
    GroupResponse,
)
from app.schemas.question import QuestionCreate, QuestionResponse
from app.services.community_features_service import create_user_notification
from app.services.group_service import (
    create_group,
    get_group_members,
    get_received_invitations,
    get_user_groups,
    invite_user,
    leave_group,
    remove_group_member,
    rename_group,
    respond_to_invitation,
)
from app.services.question_service import (
    create_group_question,
    get_group_questions,
)


router = APIRouter(prefix="/groups", tags=["Groups"])


class GroupRenameRequest(BaseModel):
    group_name: str = Field(min_length=2, max_length=100)


def _invitation_response(db: Session, invitation, invited_user_code: str | None = None):
    group = db.get(Group, invitation.group_id)
    invited = db.get(User, invitation.invited_user_id)
    inviter = db.get(User, invitation.invited_by_user_id)

    return {
        "invitation_id": invitation.invitation_id,
        "group_id": invitation.group_id,
        "group_name": group.group_name if group else "Unavailable group",
        "invited_user_public_code": (
            invited_user_code
            or (invited.public_code if invited else "")
        ),
        "invited_by_user_public_code": (
            inviter.public_code if inviter else ""
        ),
        "status": invitation.status,
        "created_at": invitation.created_at,
        "responded_at": invitation.responded_at,
    }


@router.post(
    "",
    response_model=GroupResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_new_group(
    request: GroupCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return create_group(
        db=db,
        user_id=current_user.user_id,
        group_name=request.group_name,
    )


@router.get("", response_model=list[GroupResponse])
def list_my_groups(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return get_user_groups(
        db=db,
        user_id=current_user.user_id,
    )


@router.post(
    "/{group_id}/questions",
    response_model=QuestionResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_new_group_question(
    group_id: int,
    request: QuestionCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    question = create_group_question(
        db=db,
        user_id=current_user.user_id,
        group_id=group_id,
        title=request.title,
    )

    return {
        "question_id": question.question_id,
        "public_code": current_user.public_code,
        "profile_picture_url": current_user.profile_picture_url,
        "title": question.title,
        "group_id": question.group_id,
        "poll_id": getattr(question, "poll_id", None),
        "like_count": 0,
        "interesting_count": 0,
        "agree_count": 0,
        "created_at": question.created_at,
        "updated_at": question.updated_at,
    }


@router.get(
    "/{group_id}/questions",
    response_model=list[QuestionResponse],
)
def list_group_questions(
    group_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    questions = get_group_questions(
        db=db,
        user_id=current_user.user_id,
        group_id=group_id,
    )

    return [
        {
            "question_id": question.question_id,
            "public_code": question.public_code,
            "profile_picture_url": getattr(
                question, "profile_picture_url", None
            ),
            "title": question.title,
            "group_id": question.group_id,
            "poll_id": getattr(question, "poll_id", None),
            "like_count": question.like_count,
            "interesting_count": question.interesting_count,
            "agree_count": question.agree_count,
            "created_at": question.created_at,
            "updated_at": question.updated_at,
        }
        for question in questions
    ]


@router.post("/{group_id}/rename", response_model=GroupResponse)
def rename_group_endpoint(
    group_id: int,
    request: GroupRenameRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return rename_group(
        db=db,
        user_id=current_user.user_id,
        group_id=group_id,
        group_name=request.group_name,
    )


@router.get(
    "/{group_id}/members",
    response_model=list[GroupMemberResponse],
)
def list_group_members(
    group_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return get_group_members(
        db=db,
        user_id=current_user.user_id,
        group_id=group_id,
    )


@router.post(
    "/{group_id}/invitations",
    response_model=GroupInvitationResponse,
    status_code=status.HTTP_201_CREATED,
)
def send_group_invitation(
    group_id: int,
    request: GroupInvitationCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    invitation = invite_user(
        db=db,
        inviter_user_id=current_user.user_id,
        group_id=group_id,
        public_code=request.public_code,
    )

    invited_user = db.get(User, invitation.invited_user_id)
    group = db.get(Group, invitation.group_id)

    if invited_user is not None and group is not None:
        create_user_notification(
            db=db,
            recipient_user_id=invited_user.user_id,
            actor_user_id=current_user.user_id,
            notification_type="group_invitation",
            title="New group invitation",
            body=f"You were invited to join {group.group_name}.",
            target_type="group",
            target_id=group.group_id,
        )

    return _invitation_response(db, invitation)


@router.get(
    "/invitations/received",
    response_model=list[GroupInvitationResponse],
)
def list_received_invitations(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return get_received_invitations(
        db=db,
        user_id=current_user.user_id,
    )


@router.post(
    "/invitations/{invitation_id}/accept",
    response_model=GroupInvitationResponse,
)
def accept_group_invitation(
    invitation_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    invitation = respond_to_invitation(
        db=db,
        user_id=current_user.user_id,
        invitation_id=invitation_id,
        accept=True,
    )

    return _invitation_response(
        db,
        invitation,
        invited_user_code=current_user.public_code,
    )


@router.post(
    "/invitations/{invitation_id}/reject",
    response_model=GroupInvitationResponse,
)
def reject_group_invitation(
    invitation_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    invitation = respond_to_invitation(
        db=db,
        user_id=current_user.user_id,
        invitation_id=invitation_id,
        accept=False,
    )

    return _invitation_response(
        db,
        invitation,
        invited_user_code=current_user.public_code,
    )


@router.post("/{group_id}/leave")
def leave_group_endpoint(
    group_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return leave_group(
        db=db,
        user_id=current_user.user_id,
        group_id=group_id,
    )


@router.delete("/{group_id}/members/{member_user_id}")
def remove_member(
    group_id: int,
    member_user_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return remove_group_member(
        db=db,
        requester_user_id=current_user.user_id,
        group_id=group_id,
        member_user_id=member_user_id,
    )