from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.api.auth import router as auth_router
from app.api.users import router as users_router
from app.api.questions import router as questions_router
from app.api.answers import router as answers_router
from app.api.replies import router as replies_router
from app.api.question_reactions import router as question_reactions_router
from app.api.answer_reactions import router as answer_reactions_router
from app.api.reports import router as reports_router
from app.api.polls import router as polls_router
from app.api.groups import router as groups_router
from app.api.group_messages import router as group_messages_router
from app.api.voice_notes import router as voice_notes_router
from app.api.community_features import router as community_features_router

from app.database.connection import engine
from app.models import community_features  # Register new SQLAlchemy models.


UPLOADS_DIR = Path(__file__).resolve().parent / "uploads"
UPLOADS_DIR.mkdir(parents=True, exist_ok=True)

app = FastAPI(
    title="OpinionHub API",
    description="Backend API for the OpinionHub community platform",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=(
        r"^https?://("
        r"localhost|127\.0\.0\.1|"
        r"10\.\d{1,3}\.\d{1,3}\.\d{1,3}|"
        r"192\.168\.\d{1,3}\.\d{1,3}|"
        r"172\.(?:1[6-9]|2\d|3[01])\.\d{1,3}\.\d{1,3}"
        r")(:\d+)?$"
    ),
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.mount(
    "/uploads",
    StaticFiles(directory=str(UPLOADS_DIR)),
    name="uploads",
)

app.include_router(auth_router)
app.include_router(users_router)
app.include_router(questions_router)
app.include_router(answers_router)
app.include_router(replies_router)
app.include_router(question_reactions_router)
app.include_router(answer_reactions_router)
app.include_router(reports_router)
app.include_router(polls_router)
app.include_router(groups_router)
app.include_router(group_messages_router)
app.include_router(voice_notes_router)
app.include_router(community_features_router)


@app.get("/")
def root():
    return {
        "message": "OpinionHub API is running",
        "status": "success",
    }


@app.get("/health")
def health_check():
    return {"status": "healthy"}


@app.get("/database-test")
def database_test():
    try:
        with engine.connect():
            return {
                "database": "connected",
                "status": "success",
            }
    except Exception:
        return {
            "database": "connection failed",
            "status": "error",
        }