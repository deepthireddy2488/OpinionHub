from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.core.dependencies import get_current_user
from app.database.connection import get_db
from app.models.user import User


router = APIRouter(tags=["Group Messages"])


class GroupMessageCreate(BaseModel):
    content: str = Field(min_length=1, max_length=2000)


class GroupMessageResponse(BaseModel):
    message_id: int
    group_id: int
    public_code: str
    nickname: str
    profile_picture_url: str | None = None
    content: str
    created_at: datetime
    is_mine: bool
    voice_note_id: int | None = None
    duration_seconds: float | None = None
    audio_url: str | None = None


class GroupMessageDeleteResponse(BaseModel):
    message_id: int
    message: str


class GroupMessageClearResponse(BaseModel):
    message: str


def _check_group_membership(
    db: Session,
    group_id: int,
    user_id: int,
) -> None:
    membership = db.execute(
        text(
            """
            SELECT 1
            FROM group_members
            WHERE group_id = :group_id
              AND user_id = :user_id
              AND is_active = TRUE
            LIMIT 1
            """
        ),
        {
            "group_id": group_id,
            "user_id": user_id,
        },
    ).first()

    if membership is None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You are not a member of this group",
        )


@router.get(
    "/groups/{group_id}/messages",
    response_model=list[GroupMessageResponse],
)
def get_group_messages(
    group_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    _check_group_membership(
        db=db,
        group_id=group_id,
        user_id=current_user.user_id,
    )

    rows = db.execute(
        text(
            """
            SELECT
                gm.message_id,
                gm.group_id,
                gm.user_id,
                u.public_code,
                u.nickname,
                u.profile_picture_url,
                gm.content,
                gm.created_at,
                vn.voice_note_id,
                vn.duration_seconds
            FROM group_messages gm
            INNER JOIN users u
                ON u.user_id = gm.user_id
            LEFT JOIN group_message_clears gmc
                ON gmc.group_id = gm.group_id
               AND gmc.user_id = :user_id
            LEFT JOIN voice_notes vn
                ON vn.group_message_id = gm.message_id
               AND vn.is_active = TRUE
            WHERE gm.group_id = :group_id
              AND gm.is_active = TRUE
              AND u.is_active = TRUE
              AND (
                    gmc.cleared_at IS NULL
                    OR gm.created_at > gmc.cleared_at
              )
            ORDER BY
                gm.created_at ASC,
                gm.message_id ASC
            LIMIT 100
            """
        ),
        {
            "group_id": group_id,
            "user_id": current_user.user_id,
        },
    ).mappings().all()

    return [
        {
            "message_id": row["message_id"],
            "group_id": row["group_id"],
            "public_code": row["public_code"],
            "nickname": row["nickname"],
            "profile_picture_url": row["profile_picture_url"],
            "content": row["content"],
            "created_at": row["created_at"],
            "is_mine": row["user_id"] == current_user.user_id,
            "voice_note_id": row["voice_note_id"],
            "duration_seconds": (
                float(row["duration_seconds"])
                if row["duration_seconds"] is not None
                else None
            ),
            "audio_url": (
                f"/voice-notes/{row['voice_note_id']}/audio"
                if row["voice_note_id"] is not None
                else None
            ),
        }
        for row in rows
    ]


@router.post(
    "/groups/{group_id}/messages",
    response_model=GroupMessageResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_group_message(
    group_id: int,
    payload: GroupMessageCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    _check_group_membership(
        db=db,
        group_id=group_id,
        user_id=current_user.user_id,
    )

    content = payload.content.strip()

    if not content:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Message cannot be empty",
        )

    row = db.execute(
        text(
            """
            INSERT INTO group_messages (
                group_id,
                user_id,
                content
            )
            VALUES (
                :group_id,
                :user_id,
                :content
            )
            RETURNING
                message_id,
                group_id,
                user_id,
                content,
                created_at
            """
        ),
        {
            "group_id": group_id,
            "user_id": current_user.user_id,
            "content": content,
        },
    ).mappings().one()

    db.commit()

    return {
        "message_id": row["message_id"],
        "group_id": row["group_id"],
        "public_code": current_user.public_code,
        "nickname": current_user.nickname,
        "profile_picture_url": current_user.profile_picture_url,
        "content": row["content"],
        "created_at": row["created_at"],
        "is_mine": True,
        "voice_note_id": None,
        "duration_seconds": None,
        "audio_url": None,
    }


@router.post(
    "/groups/{group_id}/messages/clear",
    response_model=GroupMessageClearResponse,
)
def clear_group_messages(
    group_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    _check_group_membership(
        db=db,
        group_id=group_id,
        user_id=current_user.user_id,
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
            "user_id": current_user.user_id,
        },
    )

    db.commit()

    return {"message": "Chat cleared for your account"}


@router.delete(
    "/groups/{group_id}/messages/{message_id}",
    response_model=GroupMessageDeleteResponse,
)
def delete_group_message(
    group_id: int,
    message_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    _check_group_membership(
        db=db,
        group_id=group_id,
        user_id=current_user.user_id,
    )

    result = db.execute(
        text(
            """
            UPDATE group_messages
            SET is_active = FALSE
            WHERE message_id = :message_id
              AND group_id = :group_id
              AND user_id = :user_id
              AND is_active = TRUE
            RETURNING message_id
            """
        ),
        {
            "message_id": message_id,
            "group_id": group_id,
            "user_id": current_user.user_id,
        },
    ).mappings().first()

    if result is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Message not found",
        )

    db.commit()

    return {
        "message_id": result["message_id"],
        "message": "Message deleted successfully",
    }