from contextlib import asynccontextmanager
import logging

from fastapi import FastAPI

from services import model_service

logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Loading ML models")
    try:
        model_service.load_models()
        if model_service.models_loaded():
            logger.info("Models loaded successfully")
        else:
            logger.warning("One or more model files are missing or failed to load")
    except Exception as exc:
        logger.warning("Model startup check failed: %s", exc)
    yield
    logger.info("Application shutdown")
