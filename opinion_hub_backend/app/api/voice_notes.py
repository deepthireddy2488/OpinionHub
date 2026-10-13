import os
import uuid
from pathlib import Path
from datetime import datetime

from fastapi import (
    APIRouter,
    Depends,
    File,
    Form,
    HTTPException,
    UploadFile,
    status,
)
from fastapi.responses import FileResponse
from pydantic import BaseModel
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.core.dependencies import get_current_user
from app.database.connection import get_db
from app.models.user import User


router = APIRouter(tags=["Voice Notes"])

BASE_DIR = Path(__file__).resolve().parents[2]

STORAGE_DIR = Path(
    os.getenv(
        "VOICE_NOTES_STORAGE_DIR",
        str(BASE_DIR / "uploads" / "voice_notes"),
    )
)

MAX_FILE_SIZE = 10 * 1024 * 1024
MAX_DURATION_SECONDS = 300.0
CHUNK_SIZE = 1024 * 1024


MIME_TO_EXTENSION = {
    "audio/mp4": ".m4a",
    "audio/m4a": ".m4a",
    "audio/x-m4a": ".m4a",
    "audio/aac": ".aac",
    "audio/wav": ".wav",
    "audio/x-wav": ".wav",
    "audio/webm": ".webm",
    "audio/ogg": ".ogg",
    "audio/opus": ".opus",
    "audio/mpeg": ".mp3",
    "audio/3gpp": ".3gp",
}

EXTENSION_TO_MIME = {
    ".m4a": "audio/mp4",
    ".aac": "audio/aac",
    ".wav": "audio/wav",
    ".webm": "audio/webm",
    ".ogg": "audio/ogg",
    ".opus": "audio/opus",
    ".mp3": "audio/mpeg",
    ".3gp": "audio/3gpp",
}


TARGET_LOOKUPS = {
    "question": """
        SELECT
            q.question_id AS target_id,
            q.user_id AS owner_id,
            q.group_id,
            q.is_active AS item_active,
            TRUE AS parent_active
        FROM questions q
        WHERE q.question_id = :target_id
    """,

    "answer": """
        SELECT
            a.answer_id AS target_id,
            a.user_id AS owner_id,
            q.group_id,
            a.is_active AS item_active,
            q.is_active AS parent_active
        FROM answers a
        JOIN questions q
            ON q.question_id = a.question_id
        WHERE a.answer_id = :target_id
    """,

    "reply": """
        SELECT
            r.reply_id AS target_id,
            r.user_id AS owner_id,
            q.group_id,
            r.is_active AS item_active,
            (q.is_active AND a.is_active) AS parent_active
        FROM replies r
        JOIN answers a
            ON a.answer_id = r.answer_id
        JOIN questions q
            ON q.question_id = a.question_id
        WHERE r.reply_id = :target_id
    """,

    "group_message": """
        SELECT
            gm.message_id AS target_id,
            gm.user_id AS owner_id,
            gm.group_id,
            gm.is_active AS item_active,
            TRUE AS parent_active
        FROM group_messages gm
        WHERE gm.message_id = :target_id
    """,
}


TARGET_COLUMNS = {
    "question": "question_id",
    "answer": "answer_id",
    "reply": "reply_id",
    "group_message": "group_message_id",
}


class VoiceNoteResponse(BaseModel):
    voice_note_id: int
    target_type: str
    target_id: int
    public_code: str
    nickname: str
    duration_seconds: float
    mime_type: str
    file_size_bytes: int
    transcript: str | None = None
    moderation_status: str
    created_at: datetime
    audio_url: str
    is_mine: bool


class VoiceNoteDeleteResponse(BaseModel):
    voice_note_id: int
    message: str


def _check_group_membership(
    db: Session,
    group_id: int,
    user_id: int,
) -> None:
    membership = db.execute(
        text("""
            SELECT 1
            FROM group_members
            WHERE group_id = :group_id
              AND user_id = :user_id
              AND is_active = TRUE
            LIMIT 1
        """),
        {
            "group_id": group_id,
            "user_id": user_id,
        },
    ).first()

    if membership is None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You are not an active member of this group",
        )


def _load_target(
    db: Session,
    target_type: str,
    target_id: int,
    user_id: int,
):
    query = TARGET_LOOKUPS.get(target_type)

    if query is None:
        raise HTTPException(
            status_code=422,
            detail="Invalid target_type",
        )

    target = db.execute(
        text(query),
        {"target_id": target_id},
    ).mappings().first()

    if (
        target is None
        or not target["item_active"]
        or not target["parent_active"]
    ):
        raise HTTPException(
            status_code=404,
            detail="Target content was not found or is inactive",
        )

    if target["group_id"] is not None:
        _check_group_membership(
            db,
            target["group_id"],
            user_id,
        )

    return target


async def _save_upload(file: UploadFile):
    supplied_mime = (
        (file.content_type or "")
        .split(";")[0]
        .strip()
        .lower()
    )

    extension = Path(file.filename or "").suffix.lower()
    mime_type = supplied_mime

    if mime_type not in MIME_TO_EXTENSION:
        if (
            mime_type in ("", "application/octet-stream")
            and extension in EXTENSION_TO_MIME
        ):
            mime_type = EXTENSION_TO_MIME[extension]
        else:
            await file.close()
            raise HTTPException(
                status_code=415,
                detail="Unsupported audio format",
            )

    extension = MIME_TO_EXTENSION[mime_type]

    STORAGE_DIR.mkdir(
        parents=True,
        exist_ok=True,
    )

    temporary_path = (
        STORAGE_DIR / f"{uuid.uuid4().hex}.upload"
    )

    file_size = 0

    try:
        with temporary_path.open("wb") as output:
            while True:
                chunk = await file.read(CHUNK_SIZE)

                if not chunk:
                    break

                file_size += len(chunk)

                if file_size > MAX_FILE_SIZE:
                    raise HTTPException(
                        status_code=413,
                        detail="Voice note exceeds the 10 MB limit",
                    )

                output.write(chunk)

        if file_size == 0:
            raise HTTPException(
                status_code=400,
                detail="Uploaded audio file is empty",
            )

        storage_key = (
            f"{uuid.uuid4().hex}{extension}"
        )

        os.replace(
            temporary_path,
            STORAGE_DIR / storage_key,
        )

        return storage_key, mime_type, file_size

    except Exception:
        temporary_path.unlink(missing_ok=True)
        raise

    finally:
        await file.close()


def _delete_stored_file(storage_key: str) -> None:
    try:
        (
            STORAGE_DIR / Path(storage_key).name
        ).unlink(missing_ok=True)
    except OSError:
        pass


def _fetch_note(
    db: Session,
    voice_note_id: int,
):
    return db.execute(
        text("""
            SELECT
                vn.voice_note_id,
                vn.user_id,
                vn.question_id,
                vn.answer_id,
                vn.reply_id,
                vn.group_message_id,
                vn.storage_key,
                vn.mime_type,
                vn.file_size_bytes,
                vn.duration_seconds,
                vn.transcript,
                vn.moderation_status,
                vn.created_at,
                vn.is_active,
                u.public_code,
                u.nickname
            FROM voice_notes vn
            JOIN users u
                ON u.user_id = vn.user_id
            WHERE vn.voice_note_id = :voice_note_id
        """),
        {"voice_note_id": voice_note_id},
    ).mappings().first()


def _format_note(
    row,
    current_user: User,
) -> dict:
    for target_type, column in TARGET_COLUMNS.items():
        if row[column] is not None:
            return {
                "voice_note_id": row["voice_note_id"],
                "target_type": target_type,
                "target_id": row[column],
                "public_code": row["public_code"],
                "nickname": row["nickname"],
                "duration_seconds": float(
                    row["duration_seconds"]
                ),
                "mime_type": row["mime_type"],
                "file_size_bytes": row["file_size_bytes"],
                "transcript": row["transcript"],
                "moderation_status": row["moderation_status"],
                "created_at": row["created_at"],
                "audio_url": (
                    f"/voice-notes/"
                    f"{row['voice_note_id']}/audio"
                ),
                "is_mine": (
                    row["user_id"]
                    == current_user.user_id
                ),
            }

    raise HTTPException(
        status_code=404,
        detail="Voice-note target not found",
    )


@router.post(
    "/voice-notes",
    response_model=VoiceNoteResponse,
    status_code=201,
)
async def upload_voice_note(
    target_type: str = Form(...),
    target_id: int = Form(...),
    duration_seconds: float = Form(
        ...,
        gt=0,
        le=MAX_DURATION_SECONDS,
    ),
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if target_type not in (
        "question",
        "answer",
        "reply",
    ):
        raise HTTPException(
            status_code=422,
            detail=(
                "Use question, answer, or reply "
                "for this endpoint"
            ),
        )

    target = _load_target(
        db,
        target_type,
        target_id,
        current_user.user_id,
    )

    if target["owner_id"] != current_user.user_id:
        raise HTTPException(
            status_code=403,
            detail=(
                "You can attach a recording only "
                "to your own content"
            ),
        )

    storage_key, mime_type, file_size = (
        await _save_upload(file)
    )

    try:
        column = TARGET_COLUMNS[target_type]

        inserted = db.execute(
            text(f"""
                INSERT INTO voice_notes (
                    user_id,
                    {column},
                    storage_key,
                    mime_type,
                    file_size_bytes,
                    duration_seconds
                )
                VALUES (
                    :user_id,
                    :target_id,
                    :storage_key,
                    :mime_type,
                    :file_size_bytes,
                    :duration_seconds
                )
                RETURNING voice_note_id
            """),
            {
                "user_id": current_user.user_id,
                "target_id": target_id,
                "storage_key": storage_key,
                "mime_type": mime_type,
                "file_size_bytes": file_size,
                "duration_seconds": duration_seconds,
            },
        ).mappings().one()

        row = _fetch_note(
            db,
            inserted["voice_note_id"],
        )

        db.commit()

        return _format_note(row, current_user)

    except Exception:
        db.rollback()
        _delete_stored_file(storage_key)
        raise


@router.post(
    "/groups/{group_id}/voice-notes",
    response_model=VoiceNoteResponse,
    status_code=201,
)
async def upload_group_voice_note(
    group_id: int,
    duration_seconds: float = Form(
        ...,
        gt=0,
        le=MAX_DURATION_SECONDS,
    ),
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    _check_group_membership(
        db,
        group_id,
        current_user.user_id,
    )

    storage_key, mime_type, file_size = (
        await _save_upload(file)
    )

    try:
        message = db.execute(
            text("""
                INSERT INTO group_messages (
                    group_id,
                    user_id,
                    content
                )
                VALUES (
                    :group_id,
                    :user_id,
                    '🎙️ Voice note'
                )
                RETURNING message_id
            """),
            {
                "group_id": group_id,
                "user_id": current_user.user_id,
            },
        ).mappings().one()

        inserted = db.execute(
            text("""
                INSERT INTO voice_notes (
                    user_id,
                    group_message_id,
                    storage_key,
                    mime_type,
                    file_size_bytes,
                    duration_seconds
                )
                VALUES (
                    :user_id,
                    :message_id,
                    :storage_key,
                    :mime_type,
                    :file_size_bytes,
                    :duration_seconds
                )
                RETURNING voice_note_id
            """),
            {
                "user_id": current_user.user_id,
                "message_id": message["message_id"],
                "storage_key": storage_key,
                "mime_type": mime_type,
                "file_size_bytes": file_size,
                "duration_seconds": duration_seconds,
            },
        ).mappings().one()

        row = _fetch_note(
            db,
            inserted["voice_note_id"],
        )

        db.commit()

        return _format_note(row, current_user)

    except Exception:
        db.rollback()
        _delete_stored_file(storage_key)
        raise


@router.get(
    "/voice-notes/target/{target_type}/{target_id}",
    response_model=list[VoiceNoteResponse],
)
def list_voice_notes(
    target_type: str,
    target_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if target_type not in TARGET_COLUMNS:
        raise HTTPException(
            status_code=422,
            detail="Invalid target_type",
        )

    _load_target(
        db,
        target_type,
        target_id,
        current_user.user_id,
    )

    column = TARGET_COLUMNS[target_type]

    ids = db.execute(
        text(f"""
            SELECT voice_note_id
            FROM voice_notes
            WHERE {column} = :target_id
              AND is_active = TRUE
            ORDER BY created_at ASC, voice_note_id ASC
        """),
        {"target_id": target_id},
    ).mappings().all()

    results = []

    for item in ids:
        row = _fetch_note(
            db,
            item["voice_note_id"],
        )

        if row is not None and row["is_active"]:
            results.append(
                _format_note(row, current_user)
            )

    return results


@router.get(
    "/voice-notes/{voice_note_id}/audio"
)
def play_voice_note(
    voice_note_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    row = _fetch_note(db, voice_note_id)

    if row is None or not row["is_active"]:
        raise HTTPException(
            status_code=404,
            detail="Voice note not found",
        )

    target_type = next(
        (
            kind
            for kind, column in TARGET_COLUMNS.items()
            if row[column] is not None
        ),
        None,
    )

    if target_type is None:
        raise HTTPException(
            status_code=404,
            detail="Voice-note target not found",
        )

    _load_target(
        db,
        target_type,
        row[TARGET_COLUMNS[target_type]],
        current_user.user_id,
    )

    path = (
        STORAGE_DIR / Path(row["storage_key"]).name
    )

    if not path.is_file():
        raise HTTPException(
            status_code=404,
            detail="Audio file is missing from storage",
        )

    return FileResponse(
        path=path,
        media_type=row["mime_type"],
        headers={
            "Content-Disposition": "inline",
        },
    )


@router.delete(
    "/voice-notes/{voice_note_id}",
    response_model=VoiceNoteDeleteResponse,
)
def delete_voice_note(
    voice_note_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    row = db.execute(
        text("""
            SELECT
                voice_note_id,
                user_id,
                storage_key,
                is_active
            FROM voice_notes
            WHERE voice_note_id = :voice_note_id
        """),
        {"voice_note_id": voice_note_id},
    ).mappings().first()

    if row is None or not row["is_active"]:
        raise HTTPException(
            status_code=404,
            detail="Voice note not found",
        )

    if row["user_id"] != current_user.user_id:
        raise HTTPException(
            status_code=403,
            detail="You can delete only your own voice note",
        )

    db.execute(
        text("""
            UPDATE voice_notes
            SET is_active = FALSE
            WHERE voice_note_id = :voice_note_id
        """),
        {"voice_note_id": voice_note_id},
    )

    db.commit()

    _delete_stored_file(row["storage_key"])

    return {
        "voice_note_id": voice_note_id,
        "message": "Voice note deleted",
    }