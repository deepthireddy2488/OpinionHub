import secrets

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.user import User
from app.core.security import hash_password, verify_password


def generate_public_code(db: Session) -> str:
    while True:
        public_code = f"OP-{secrets.randbelow(900000) + 100000}"

        existing_user = db.scalar(
            select(User).where(User.public_code == public_code)
        )

        if existing_user is None:
            return public_code


def register_user(
    db: Session,
    email: str,
    password: str,
    nickname: str,
) -> User:

    existing_user = db.scalar(
        select(User).where(User.email == email.lower())
    )

    if existing_user:
        raise ValueError("Email is already registered")

    user = User(
        email=email.lower(),
        password_hash=hash_password(password),
        nickname=nickname.strip(),
        public_code=generate_public_code(db),
    )

    db.add(user)
    db.commit()
    db.refresh(user)

    return user


def authenticate_user(
    db: Session,
    email: str,
    password: str,
) -> User | None:

    user = db.scalar(
        select(User).where(User.email == email.lower())
    )

    if user is None:
        return None

    if not verify_password(password, user.password_hash):
        return None

    if not user.is_active:
        return None

    return user