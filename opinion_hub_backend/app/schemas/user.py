from datetime import datetime

from pydantic import BaseModel, ConfigDict


class UserResponse(BaseModel):
    user_id: int
    nickname: str
    public_code: str
    created_at: datetime
    profile_picture_url: str | None = None
    is_admin: bool = False

    model_config = ConfigDict(from_attributes=True)


class PublicProfileResponse(BaseModel):
    user_id: int
    nickname: str
    public_code: str
    created_at: datetime
    profile_picture_url: str | None = None

    model_config = ConfigDict(from_attributes=True)