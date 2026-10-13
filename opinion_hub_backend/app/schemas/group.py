from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class GroupCreate(BaseModel):
    group_name: str = Field(min_length=2, max_length=100)


class GroupResponse(BaseModel):
    group_id: int
    group_name: str
    created_by_user_id: int
    created_at: datetime
    updated_at: datetime
    is_active: bool

    model_config = ConfigDict(from_attributes=True)


class GroupInvitationCreate(BaseModel):
    public_code: str = Field(min_length=3, max_length=20)


class GroupInvitationResponse(BaseModel):
    invitation_id: int
    group_id: int
    group_name: str
    invited_user_public_code: str
    invited_by_user_public_code: str
    status: str
    created_at: datetime
    responded_at: datetime | None = None


class GroupMemberResponse(BaseModel):
    group_member_id: int
    user_id: int
    public_code: str
    nickname: str
    profile_picture_url: str | None = None
    role: str
    joined_at: datetime

    model_config = ConfigDict(from_attributes=True)