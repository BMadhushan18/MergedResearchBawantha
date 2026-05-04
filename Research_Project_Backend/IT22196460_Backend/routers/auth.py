import logging
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from services import mongo_service
from passlib.context import CryptContext

logger = logging.getLogger(__name__)
router = APIRouter()

# Password hashing configuration
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

class LoginRequest(BaseModel):
    email: str
    password: str

class RegisterRequest(BaseModel):
    email: str
    password: str
    displayName: str
    role: str = "user"

@router.post("/login")
async def login(request: LoginRequest):
    logger.info(f"Login attempt for: {request.email}")
    user = mongo_service.get_user_by_email(request.email)
    
    if not user:
        logger.warning(f"User not found: {request.email}")
        raise HTTPException(status_code=401, detail="Invalid email or password")
    
    # Check password hash
    hashed_password = user.get("passwordHash") or user.get("password")
    
    if not hashed_password:
        logger.error(f"No password found for user: {request.email}")
        raise HTTPException(status_code=401, detail="Invalid email or password")

    # Verify hashed password
    try:
        # Debugging password mismatch
        clean_password = request.password
        logger.info(f"Verifying password for {request.email} (length: {len(clean_password)})")
        
        is_valid = pwd_context.verify(clean_password, hashed_password)
    except Exception as e:
        logger.error(f"Password verification error for {request.email}: {e}")
        # Fallback for plain text passwords if hash check fails
        is_valid = (hashed_password == request.password)

    if is_valid:
        logger.info(f"Login successful for: {request.email}")
        return {
            "status": "success",
            "message": "Login successful",
            "user": {
                "email": user.get("email"),
                "displayName": user.get("displayName") or "User",
                "role": user.get("role") or "user"
            }
        }
    
    logger.warning(f"Password mismatch for: {request.email} (Input length: {len(request.password)})")
    raise HTTPException(status_code=401, detail="Invalid email or password")

@router.post("/register")
async def register(request: RegisterRequest):
    # Check if user already exists
    existing = mongo_service.get_user_by_email(request.email)
    if existing:
        raise HTTPException(status_code=400, detail="User already exists")
    
    # Hash the password before saving
    hashed_password = pwd_context.hash(request.password)
    
    user_data = {
        "email": request.email,
        "passwordHash": hashed_password,
        "displayName": request.displayName,
        "role": request.role
    }
    
    success = mongo_service.create_user(user_data)
    if success:
        return {"status": "success", "message": "User created successfully"}
    
    raise HTTPException(status_code=500, detail="Failed to create user")
