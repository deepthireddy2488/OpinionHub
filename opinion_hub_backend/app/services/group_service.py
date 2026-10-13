from datetime import datetime

from fastapi import HTTPException, status
from sqlalchemy import case, select, text
from sqlalchemy.orm import Session, aliased

from app.models.group import Group
from app.models.group_invitation import GroupInvitation
from app.models.group_member import GroupMember
from app.models.user import User


def create_group(
    db: Session,
    user_id: int,
    group_name: str,
):
    cleaned_name = group_name.strip()

    if len(cleaned_name) < 2:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Group name must contain at least 2 characters",
        )

    if len(cleaned_name) > 100:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Group name cannot exceed 100 characters",
        )

    group = Group(
        group_name=cleaned_name,
        created_by_user_id=user_id,
    )

    db.add(group)
    db.flush()

    db.add(
        GroupMember(
            group_id=group.group_id,
            user_id=user_id,
            role="owner",
            is_active=True,
        )
    )

    db.commit()
    db.refresh(group)

    return group


def get_user_groups(
    db: Session,
    user_id: int,
):
    return db.scalars(
        select(Group)
        .join(
            GroupMember,
            GroupMember.group_id == Group.group_id,
        )
        .where(
            GroupMember.user_id == user_id,
            GroupMember.is_active.is_(True),
            Group.is_active.is_(True),
        )
        .distinct()
        .order_by(Group.created_at.desc())
    ).all()


def get_group_members(
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

    members = db.execute(
        select(GroupMember, User)
        .join(
            User,
            User.user_id == GroupMember.user_id,
        )
        .where(
            GroupMember.group_id == group_id,
            GroupMember.is_active.is_(True),
            User.is_active.is_(True),
        )
        .order_by(GroupMember.joined_at)
    ).all()

    return [
        {
            "group_member_id": member.group_member_id,
            "user_id": user.user_id,
            "public_code": user.public_code,
            "nickname": user.nickname,
            "role": member.role,
            "joined_at": member.joined_at,
            "profile_picture_url": user.profile_picture_url,
        }
        for member, user in members
    ]


def invite_user(
    db: Session,
    inviter_user_id: int,
    group_id: int,
    public_code: str,
):
    group = db.scalar(
        select(Group).where(
            Group.group_id == group_id,
            Group.is_active.is_(True),
        )
    )

    if group is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Group not found",
        )

    inviter_membership = db.scalar(
        select(GroupMember).where(
            GroupMember.group_id == group_id,
            GroupMember.user_id == inviter_user_id,
            GroupMember.is_active.is_(True),
            GroupMember.role.in_(["owner", "admin"]),
        )
    )

    if inviter_membership is None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You are not allowed to invite users to this group",
        )

    invited_user = db.scalar(
        select(User).where(
            User.public_code == public_code.strip().upper(),
            User.is_active.is_(True),
        )
    )

    if invited_user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )

    if invited_user.user_id == inviter_user_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You cannot invite yourself",
        )

    existing_member = db.scalar(
        select(GroupMember).where(
            GroupMember.group_id == group_id,
            GroupMember.user_id == invited_user.user_id,
            GroupMember.is_active.is_(True),
        )
    )

    if existing_member is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="User is already a group member",
        )

    existing_invitation = db.scalar(
        select(GroupInvitation).where(
            GroupInvitation.group_id == group_id,
            GroupInvitation.invited_user_id == invited_user.user_id,
        )
    )

    if existing_invitation is not None:
        if existing_invitation.status == "pending":
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Invitation already exists",
            )

        existing_invitation.status = "pending"
        existing_invitation.invited_by_user_id = inviter_user_id
        existing_invitation.created_at = datetime.utcnow()
        existing_invitation.responded_at = None

        db.commit()
        db.refresh(existing_invitation)

        return existing_invitation

    invitation = GroupInvitation(
        group_id=group_id,
        invited_user_id=invited_user.user_id,
        invited_by_user_id=inviter_user_id,
        status="pending",
    )

    db.add(invitation)
    db.commit()
    db.refresh(invitation)

    return invitation


def get_received_invitations(
    db: Session,
    user_id: int,
):
    invited_user = aliased(User)
    inviting_user = aliased(User)

    results = db.execute(
        select(
            GroupInvitation,
            Group,
            invited_user,
            inviting_user,
        )
        .join(
            Group,
            Group.group_id == GroupInvitation.group_id,
        )
        .join(
            invited_user,
            invited_user.user_id == GroupInvitation.invited_user_id,
        )
        .join(
            inviting_user,
            inviting_user.user_id == GroupInvitation.invited_by_user_id,
        )
        .where(
            GroupInvitation.invited_user_id == user_id,
            GroupInvitation.status == "pending",
            Group.is_active.is_(True),
            invited_user.is_active.is_(True),
        )
        .order_by(GroupInvitation.created_at.desc())
    ).all()

    return [
        {
            "invitation_id": invitation.invitation_id,
            "group_id": group.group_id,
            "group_name": group.group_name,
            "invited_user_public_code": invited.public_code,
            "invited_by_user_public_code": inviter.public_code,
            "status": invitation.status,
            "created_at": invitation.created_at,
            "responded_at": invitation.responded_at,
        }
        for invitation, group, invited, inviter in results
    ]


def respond_to_invitation(
    db: Session,
    user_id: int,
    invitation_id: int,
    accept: bool,
):
    invitation = db.scalar(
        select(GroupInvitation).where(
            GroupInvitation.invitation_id == invitation_id,
            GroupInvitation.invited_user_id == user_id,
            GroupInvitation.status == "pending",
        )
    )

    if invitation is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Invitation not found",
        )

    if accept:
        group = db.scalar(
            select(Group).where(
                Group.group_id == invitation.group_id,
                Group.is_active.is_(True),
            )
        )

        if group is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Group not found or inactive",
            )

    invitation.status = "accepted" if accept else "rejected"
    invitation.responded_at = datetime.utcnow()

    if accept:
        existing_member = db.scalar(
            select(GroupMember).where(
                GroupMember.group_id == invitation.group_id,
                GroupMember.user_id == user_id,
            )
        )

        if existing_member is None:
            db.add(
                GroupMember(
                    group_id=invitation.group_id,
                    user_id=user_id,
                    role="member",
                    is_active=True,
                )
            )
        else:
            existing_member.is_active = True
            if not existing_member.role:
                existing_member.role = "member"

    db.commit()
    db.refresh(invitation)

    return invitation


def rename_group(
    db: Session,
    user_id: int,
    group_id: int,
    group_name: str,
):
    group = db.scalar(
        select(Group).where(
            Group.group_id == group_id,
            Group.is_active.is_(True),
        )
    )

    if group is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Group not found",
        )

    membership = db.scalar(
        select(GroupMember).where(
            GroupMember.group_id == group_id,
            GroupMember.user_id == user_id,
            GroupMember.is_active.is_(True),
            GroupMember.role.in_(["owner", "admin"]),
        )
    )

    if membership is None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only the group owner or admin can change the group name",
        )

    cleaned_name = group_name.strip()

    if len(cleaned_name) < 2:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Group name must contain at least 2 characters",
        )

    if len(cleaned_name) > 100:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Group name cannot exceed 100 characters",
        )

    group.group_name = cleaned_name

    db.commit()
    db.refresh(group)

    return group


def leave_group(
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
            status_code=status.HTTP_404_NOT_FOUND,
            detail="You are not a member of this group",
        )

    if membership.role != "owner":
        membership.is_active = False
        db.commit()

        return {"message": "You have left the group"}

    replacement = db.scalar(
        select(GroupMember)
        .where(
            GroupMember.group_id == group_id,
            GroupMember.user_id != user_id,
            GroupMember.is_active.is_(True),
        )
        .order_by(
            case(
                (GroupMember.role == "admin", 0),
                (GroupMember.role == "member", 1),
                else_=2,
            ),
            GroupMember.joined_at,
        )
    )

    if replacement is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=(
                "You are the only active member. "
                "Add another member before leaving the group."
            ),
        )

    replacement.role = "owner"
    membership.is_active = False
    db.commit()

    return {
        "message": (
            "You have left the group and ownership "
            "was transferred to another member"
        )
    }


def remove_group_member(
    db: Session,
    requester_user_id: int,
    group_id: int,
    member_user_id: int,
):
    requester_membership = db.scalar(
        select(GroupMember).where(
            GroupMember.group_id == group_id,
            GroupMember.user_id == requester_user_id,
            GroupMember.is_active.is_(True),
            GroupMember.role.in_(["owner", "admin"]),
        )
    )

    if requester_membership is None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You are not allowed to remove group members",
        )

    member = db.scalar(
        select(GroupMember).where(
            GroupMember.group_id == group_id,
            GroupMember.user_id == member_user_id,
            GroupMember.is_active.is_(True),
        )
    )

    if member is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Group member not found",
        )

    if member.role == "owner":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="The group owner cannot be removed",
        )

    if member.role == "admin" and requester_membership.role != "owner":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only the group owner can remove an admin",
        )

    member.is_active = False
    db.commit()

    return {"message": "Group member removed successfully"}


def clear_group_chat(
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

    db.execute(
        text(
            """
            INSERT INTO group_message_clears (
                group_id,
                user_id,
                cleared_at
            )
            VALUES (
                :group_id,
                :user_id,
                CURRENT_TIMESTAMP
            )
            ON CONFLICT (group_id, user_id)
            DO UPDATE SET
                cleared_at = EXCLUDED.cleared_at
            """
        ),
        {
            "group_id": group_id,
            "user_id": user_id,
        },
    )

    db.commit()

    return {"message": "Chat cleared for your account"}