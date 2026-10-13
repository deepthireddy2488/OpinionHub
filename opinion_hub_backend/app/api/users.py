from pathlib import Path
from uuid import uuid4

from fastapi import (
    APIRouter,
    Depends,
    File,
    HTTPException,
    UploadFile,
    status,
)
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.dependencies import get_current_user
from app.database.connection import get_db
from app.models.user import User
from app.schemas.user import UserResponse, PublicProfileResponse


router = APIRouter(
    prefix="/users",
    tags=["Users"],
)

UPLOADS_DIR = Path(__file__).resolve().parents[1] / "uploads"
PROFILE_PICTURES_DIR = UPLOADS_DIR / "profile_pictures"
MAX_PROFILE_PICTURE_BYTES = 5 * 1024 * 1024

PROFILE_URL_PREFIX = "/uploads/profile_pictures/"


def _detect_image_extension(content: bytes) -> str | None:
    """Check file signatures instead of trusting the filename."""

    if content.startswith(b"\xff\xd8\xff"):
        return ".jpg"

    if content.startswith(b"\x89PNG\r\n\x1a\n"):
        return ".png"

    if (
        len(content) >= 12
        and content.startswith(b"RIFF")
        and content[8:12] == b"WEBP"
    ):
        return ".webp"

    return None


def _delete_managed_picture(picture_url: str | None) -> None:
    """Delete only files within the profile-picture directory."""

    if not picture_url or not picture_url.startswith(PROFILE_URL_PREFIX):
        return

    filename = picture_url.removeprefix(PROFILE_URL_PREFIX)

    # Prevent path traversal or attempts to delete unrelated files.
    if not filename or Path(filename).name != filename:
        return

    file_path = PROFILE_PICTURES_DIR / filename

    try:
        file_path.resolve().relative_to(PROFILE_PICTURES_DIR.resolve())
    except ValueError:
        return

    try:
        file_path.unlink(missing_ok=True)
    except OSError:
        # A cleanup failure should not undo a successfully saved profile.
        pass


@router.get(
    "/me",
    response_model=UserResponse,
)
def get_my_profile(
    current_user: User = Depends(get_current_user),
):
    return current_user


@router.post(
    "/me/profile-picture",
    response_model=UserResponse,
)
async def upload_profile_picture(
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    content = await file.read(MAX_PROFILE_PICTURE_BYTES + 1)
    await file.close()

    if not content:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="The uploaded image is empty.",
        )

    if len(content) > MAX_PROFILE_PICTURE_BYTES:
        raise HTTPException(
            status_code=status.HTTP_413_CONTENT_TOO_LARGE,
            detail="Profile pictures must be 5 MB or smaller.",
        )

    extension = _detect_image_extension(content)

    if extension is None:
        raise HTTPException(
            status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
            detail="Upload a valid JPEG, PNG, or WebP image.",
        )

    PROFILE_PICTURES_DIR.mkdir(
        parents=True,
        exist_ok=True,
    )

    filename = f"{current_user.user_id}_{uuid4().hex}{extension}"
    destination = PROFILE_PICTURES_DIR / filename
    old_picture_url = current_user.profile_picture_url

    try:
        destination.write_bytes(content)

        current_user.profile_picture_url = (
            f"{PROFILE_URL_PREFIX}{filename}"
        )

        db.commit()
        db.refresh(current_user)

    except Exception:
        db.rollback()

        try:
            destination.unlink(missing_ok=True)
        except OSError:
            pass

        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Unable to save the profile picture.",
        )

    _delete_managed_picture(old_picture_url)

    return current_user


@router.delete(
    "/me/profile-picture",
    response_model=UserResponse,
)
def remove_profile_picture(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    old_picture_url = current_user.profile_picture_url

    try:
        current_user.profile_picture_url = None
        db.commit()
        db.refresh(current_user)

    except Exception:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Unable to remove the profile picture.",
        )

    _delete_managed_picture(old_picture_url)

    return current_user


@router.get(
    "/{public_code}",
    response_model=PublicProfileResponse,
)
def get_public_profile(
    public_code: str,
    db: Session = Depends(get_db),
):
    user = db.scalar(
        select(User).where(
            User.public_code == public_code,
            User.is_active.is_(True),
        )
    )

    if user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )

    return user