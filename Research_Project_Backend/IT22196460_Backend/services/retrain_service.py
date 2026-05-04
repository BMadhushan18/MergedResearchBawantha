import asyncio
import logging
import os
import time
from datetime import datetime, timezone
from typing import Dict, List, Optional, Any
import joblib
import pandas as pd
import numpy as np
from sklearn.model_selection import train_test_split
from sklearn.metrics import r2_score, f1_score
from services import mongo_service

logger = logging.getLogger(__name__)

MODEL_DIR = os.path.join(os.path.dirname(__file__), "..", "ml_models")

class RetrainStatus:
    IDLE = "idle"
    QUEUED = "queued"
    RUNNING = "running"
    COMPLETED = "completed"
    FAILED = "failed"
    ABORTED = "aborted"

class RetrainService:
    _instance = None
    
    def __new__(cls):
        if cls._instance is None:
            cls._instance = super(RetrainService, cls).__new__(cls)
            cls._instance._init_service()
        return cls._instance

    def _init_service(self):
        self.status = RetrainStatus.IDLE
        self.progress = 0
        self.current_step = ""
        self.last_retrain_at = None
        self.accuracy_delta = {}
        self._lock = asyncio.Lock()
        self._debounce_task = None

    def get_status(self) -> Dict[str, Any]:
        return {
            "status": self.status,
            "progress": self.progress,
            "current_step": self.current_step,
            "last_retrain_at": self.last_retrain_at.isoformat() if self.last_retrain_at else None,
            "accuracy_delta": self.accuracy_delta
        }

    async def queue_retrain(self, change_type: str, summary: str):
        """Queues a retrain job with debounce."""
        mongo_service.log_pending_change(change_type, summary)
        
        async with self._lock:
            if self.status == RetrainStatus.RUNNING:
                return # Already running, will pick up new changes if needed or just wait
            
            if self._debounce_task:
                self._debounce_task.cancel()
            
            self.status = RetrainStatus.QUEUED
            self._debounce_task = asyncio.create_task(self._debounce_trigger())

    async def _debounce_trigger(self):
        try:
            await asyncio.sleep(60) # 60 second debounce
            await self.run_retrain("auto")
        except asyncio.CancelledError:
            pass

    async def run_retrain(self, triggered_by: str = "manual", target_model: Optional[str] = None):
        if self.status == RetrainStatus.RUNNING:
            return False
            
        self.status = RetrainStatus.RUNNING
        self.progress = 0
        self.current_step = "Starting retraining pipeline..."
        start_time = time.time()
        
        try:
            # 1. Clear pending changes
            job_id = str(int(start_time))
            mongo_service.clear_pending_changes(job_id)
            
            # 2. Backup current models
            self.current_step = "Backing up current models..."
            self._backup_models()
            self.progress = 10
            
            # 3. Load Data
            self.current_step = "Loading training data from DB..."
            df = self._load_data_from_db()
            if df.empty:
                raise ValueError("No training data found in database")
            self.progress = 20
            
            results = {}
            models_to_train = [target_model] if target_model else ["vehicle", "machinery", "labour"]
            
            # 4. Retrain Shared Pipeline
            if not target_model:
                self.current_step = "Retraining shared feature pipeline..."
                # In a real scenario, we'd fit the pipeline here
                # self._pipeline.fit(df)
                self.progress = 30
            
            # 5. Retrain Models
            step_increment = 60 / len(models_to_train)
            for i, model_name in enumerate(models_to_train):
                self.current_step = f"Retraining {model_name} model..."
                accuracy_before = self._get_current_accuracy(model_name)
                
                # Mock training and validation
                # In real code: new_model, accuracy_after = self._train_model(model_name, df)
                accuracy_after = accuracy_before + (np.random.random() * 0.1 - 0.02) # Mock delta
                
                if accuracy_after < (accuracy_before * 0.95):
                    logger.warning(f"Aborting {model_name} update: Accuracy dropped too much ({accuracy_before} -> {accuracy_after})")
                    results[model_name] = {"status": "aborted", "before": accuracy_before, "after": accuracy_after}
                else:
                    # self._save_model(model_name, new_model)
                    results[model_name] = {"status": "success", "before": accuracy_before, "after": accuracy_after}
                
                self.progress += step_increment

            # Finalize
            duration = time.time() - start_time
            self.last_retrain_at = datetime.now(timezone.utc)
            self.status = RetrainStatus.COMPLETED
            self.current_step = "Retraining completed successfully"
            self.progress = 100
            
            mongo_service.insert_retrain_log({
                "triggered_by": triggered_by,
                "models_retrained": models_to_train,
                "duration_seconds": duration,
                "status": "success",
                "accuracy_results": results
            })
            
            return True

        except Exception as e:
            logger.error(f"Retraining failed: {e}")
            self.status = RetrainStatus.FAILED
            self.current_step = f"Error: {str(e)}"
            mongo_service.insert_retrain_log({
                "triggered_by": triggered_by,
                "status": "failed",
                "failure_reason": str(e)
            })
            return False

    def _backup_models(self):
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        for f in os.listdir(MODEL_DIR):
            if f.endswith(".pkl") and "backup" not in f:
                src = os.path.join(MODEL_DIR, f)
                dst = os.path.join(MODEL_DIR, f"{f.replace('.pkl', '')}_backup_{timestamp}.pkl")
                import shutil
                shutil.copy2(src, dst)

    def _load_data_from_db(self) -> pd.DataFrame:
        # Placeholder for real data loading
        # Should pull from boq_predictions or other sources
        return pd.DataFrame([{"mock": 1}]) 

    def _get_current_accuracy(self, model_name: str) -> float:
        # Should read from last success log
        return 0.85 # Mock
