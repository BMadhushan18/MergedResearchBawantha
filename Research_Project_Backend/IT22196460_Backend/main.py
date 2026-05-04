import logging
import os
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from utils.lifecycle import lifespan
from routers import prediction, auth, admin

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)

app = FastAPI(
    title="Smart Logistics Optimization API",
    description="BOQ-based resource prediction for vehicles, labor, and machinery",
    version="1.0.0",
    lifespan=lifespan,
)

cors_origins = [o.strip() for o in os.getenv("CORS_ALLOW_ORIGINS", "*").split(",") if o.strip()]
allow_all_origins = "*" in cors_origins

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"] if allow_all_origins else cors_origins,
    # Browsers reject wildcard origin when credentials are enabled.
    allow_credentials=not allow_all_origins,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(prediction.router, prefix="/api/v1", tags=["Prediction"])
app.include_router(auth.router, prefix="/api/v1", tags=["Authentication"])
app.include_router(admin.router, prefix="/api/v1")


@app.get("/")
def root():
    return {"status": "ok", "message": "Smart Logistics Optimization API is running"}


@app.get("/health")
def health():
    return {"status": "healthy"}


if __name__ == "__main__":
    import uvicorn
    print("\nIT22196460 Backend (Smart Logistics)")
    print("   URL : http://0.0.0.0:8001")
    print("   Health: http://localhost:8001/\n")
    uvicorn.run("main:app", host="0.0.0.0", port=8001, reload=False)
