from typing import List, Optional, Literal
from datetime import datetime, timezone
import json
import os

import firebase_admin
from firebase_admin import credentials, auth as firebase_auth
from pathlib import Path
import glob
import os

# Initialize Firebase Admin SDK using service account JSON if available.
# Prefer the standard environment variable GOOGLE_APPLICATION_CREDENTIALS (or
# FIREBASE_CREDENTIALS). If not present, try to find any '*-firebase-adminsdk-*.json'
# file in the repository root and use it. If none found, skip initialization.
cred_path = os.environ.get('GOOGLE_APPLICATION_CREDENTIALS') or os.environ.get('FIREBASE_CREDENTIALS')
if not cred_path:
    # try to find a service-account JSON in repo root (same dir as this file)
    root = Path(__file__).resolve().parent
    matches = list(root.glob('*-firebase-adminsdk-*.json'))
    if matches:
        cred_path = str(matches[0])

if cred_path:
    try:
        if not firebase_admin._apps:
            cred = credentials.Certificate(cred_path)
            firebase_admin.initialize_app(cred)
    except Exception as e:
        # If credentials are missing or invalid, log and proceed — get_uid will fail to verify tokens.
        print(f"Firebase admin init error: {e}")
else:
    print("No Firebase service account found (set GOOGLE_APPLICATION_CREDENTIALS). Skipping admin init.")

from fastapi import FastAPI, HTTPException, Depends, Header
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from sqlalchemy import (
    create_engine, Column, String, Integer, Text, DateTime, and_
)
from sqlalchemy.orm import declarative_base, sessionmaker, Session

DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./swipeat.db")

engine = create_engine(DATABASE_URL, connect_args={"check_same_thread": False})
SessionLocal = sessionmaker(bind=engine, autocommit=False, autoflush=False)
Base = declarative_base()

# --- ORM models ---
class ProfileORM(Base):
    __tablename__ = "profiles"
    uid = Column(String, primary_key=True, index=True)  # stable uid for user (Firebase uid expected)
    name = Column(String(128), nullable=False)
    age = Column(Integer, nullable=True)
    bio = Column(Text, nullable=True)
    photos_json = Column(Text, nullable=True)   # JSON list of URLs
    interests_json = Column(Text, nullable=True) # JSON list of strings
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    updated_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))

class SwipeORM(Base):
    __tablename__ = "swipes"
    id = Column(String, primary_key=True, index=True)
    from_uid = Column(String, index=True, nullable=False)
    to_uid = Column(String, index=True, nullable=False)
    direction = Column(String(8), nullable=False)  # "like" or "dislike"
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))

Base.metadata.create_all(bind=engine)

# --- Pydantic schemas ---
class ProfileCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=128)
    age: Optional[int]
    bio: Optional[str] = Field(None, max_length=1000)
    photos: Optional[List[str]] = []
    interests: Optional[List[str]] = []

class ProfileOut(ProfileCreate):
    uid: str
    created_at: datetime
    updated_at: datetime

class SwipeRequest(BaseModel):
    direction: Literal["like", "dislike"]

class SwipeResult(BaseModel):
    ok: bool
    already_swiped: bool = False

# --- App & middleware ---
app = FastAPI(title="Swipeat - Swipe API", version="0.1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- Dependencies ---
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

def get_uid(authorization: Optional[str] = Header(None)) -> str:
    """
    Verify Authorization: Bearer <idToken> using Firebase Admin SDK and return stable uid.
    Raises 401 on missing/invalid token.
    """
    if not authorization:
        raise HTTPException(status_code=401, detail="Authorization header missing")
    parts = authorization.split()
    if len(parts) != 2 or parts[0].lower() != "bearer" or not parts[1]:
        raise HTTPException(status_code=401, detail="Invalid Authorization header")

    id_token = parts[1]
    try:
        decoded = firebase_auth.verify_id_token(id_token)
    except Exception as e:
        raise HTTPException(status_code=401, detail=f"Token verification failed: {e}")

    uid = decoded.get('uid') or decoded.get('sub')
    if not uid:
        raise HTTPException(status_code=401, detail="Invalid token: uid missing")
    return uid

# --- Utilities ---
def profile_to_out(p: ProfileORM) -> ProfileOut:
    return ProfileOut(
        uid=p.uid,
        name=p.name,
        age=p.age,
        bio=p.bio,
        photos=json.loads(p.photos_json) if p.photos_json else [],
        interests=json.loads(p.interests_json) if p.interests_json else [],
        created_at=p.created_at,
        updated_at=p.updated_at,
    )

import uuid
def gen_id() -> str:
    return uuid.uuid4().hex

# --- API endpoints ---

@app.post("/api/profiles", response_model=ProfileOut, status_code=201)
def create_or_update_profile(payload: ProfileCreate, uid: str = Depends(get_uid), db: Session = Depends(get_db)):
    """
    Create or update the authenticated user's profile.
    """
    p = db.get(ProfileORM, uid)
    now = datetime.now(timezone.utc)
    if p is None:
        p = ProfileORM(
            uid=uid,
            name=payload.name,
            age=payload.age,
            bio=payload.bio,
            photos_json=json.dumps(payload.photos or []),
            interests_json=json.dumps(payload.interests or []),
            created_at=now,
            updated_at=now,
        )
        db.add(p)
    else:
        p.name = payload.name
        p.age = payload.age
        p.bio = payload.bio
        p.photos_json = json.dumps(payload.photos or [])
        p.interests_json = json.dumps(payload.interests or [])
        p.updated_at = now
        db.add(p)
    db.commit()
    db.refresh(p)
    return profile_to_out(p)

@app.get("/api/me", response_model=ProfileOut)
def get_my_profile(uid: str = Depends(get_uid), db: Session = Depends(get_db)):
    p = db.get(ProfileORM, uid)
    if p:
        return profile_to_out(p)

    # If no profile exists in DB, attempt to return a sensible default using Firebase
    # user record (display name / email). This avoids 404s in development when
    # the frontend queries /api/me before creating a profile.
    try:
        user = firebase_auth.get_user(uid)
        display_name = user.display_name or (user.email.split('@')[0] if user.email else f'user-{uid[:6]}')
    except Exception:
        display_name = f'user-{uid[:6]}'

    now = datetime.now(timezone.utc)
    return ProfileOut(
        uid=uid,
        name=display_name,
        age=None,
        bio=None,
        photos=[],
        interests=[],
        created_at=now,
        updated_at=now,
    )

@app.get("/api/profiles/{target_uid}", response_model=ProfileOut)
def get_profile(target_uid: str, db: Session = Depends(get_db)):
    p = db.get(ProfileORM, target_uid)
    if not p:
        raise HTTPException(status_code=404, detail="Profile not found")
    return profile_to_out(p)

@app.get("/api/profiles/next", response_model=List[ProfileOut])
@app.get("/api/profiles/next/", response_model=List[ProfileOut])
def get_next_candidates(limit: int = 20, uid: str = Depends(get_uid), db: Session = Depends(get_db)):
    """
    Return a list of candidate profiles for the current user to swipe on.
    Excludes:
     - the current user
     - profiles the user already swiped on
    Order: newest first
    """
    try:
        # get uids already swiped by user
        swiped = db.execute(
            db.query(SwipeORM.to_uid).filter(SwipeORM.from_uid == uid)
        ).scalars().all()
        q = db.query(ProfileORM).filter(ProfileORM.uid != uid)
        if swiped:
            q = q.filter(~ProfileORM.uid.in_(swiped))
        q = q.order_by(ProfileORM.created_at.desc()).limit(limit)
        candidates = q.all()
        print(f"get_next_candidates: uid={uid} -> {len(candidates)} candidates")
        return [profile_to_out(c) for c in candidates]
    except Exception as e:
        # In case of unexpected errors (or missing DB objects), log and return empty list
        print(f"get_next_candidates error for uid={uid}: {e}")
        return []

@app.post("/api/profiles/{to_uid}/swipe", response_model=SwipeResult)
def swipe_profile(to_uid: str, payload: SwipeRequest, uid: str = Depends(get_uid), db: Session = Depends(get_db)):
    """
    Record a swipe from the authenticated user to target user.
    direction: 'like' or 'dislike'
    """
    if uid == to_uid:
        raise HTTPException(status_code=400, detail="Cannot swipe on yourself")
    # ensure target exists; in dev we may receive placeholder UIDs from the client
    # (e.g. dummy candidates). Create a lightweight placeholder profile if missing
    # so swipes do not fail with 404 during local development.
    target = db.get(ProfileORM, to_uid)
    if not target:
        placeholder_name = f'Candidate-{to_uid[:6]}'
        now = datetime.now(timezone.utc)
        target = ProfileORM(
            uid=to_uid,
            name=placeholder_name,
            age=None,
            bio=None,
            photos_json=json.dumps([]),
            interests_json=json.dumps([]),
            created_at=now,
            updated_at=now,
        )
        db.add(target)
        db.commit()
        db.refresh(target)

    # check existing swipe
    existing = db.query(SwipeORM).filter(and_(SwipeORM.from_uid == uid, SwipeORM.to_uid == to_uid)).first()
    if existing:
        return SwipeResult(ok=True, already_swiped=True)

    s = SwipeORM(
        id=gen_id(),
        from_uid=uid,
        to_uid=to_uid,
        direction=payload.direction,
        created_at=datetime.now(timezone.utc),
    )
    db.add(s)
    db.commit()
    # Note: matching logic (mutual like) will be added later
    return SwipeResult(ok=True, already_swiped=False)

# Health endpoint
@app.get("/api/status")
def status():
    return {"status": "ok", "app": "swipeat", "timestamp": datetime.now(timezone.utc).isoformat()}

# Run with: uvicorn main:app --reload
if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="127.0.0.1", port=8000, reload=True)