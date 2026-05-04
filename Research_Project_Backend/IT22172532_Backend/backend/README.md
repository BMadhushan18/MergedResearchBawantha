# Smart Construction Backend

Backend source is organized by responsibility:

- `app.py`: Flask app factory and blueprint registration
- `database/`: MongoDB connection, collection handles, seed data
- `services/`: feature folders; each feature keeps its `routes.py` beside related logic
- `core/`: shared helpers for auth, errors, and serialization
- `config/`: environment-backed settings
- `scripts/`: maintenance scripts
- `tests/`: backend tests and fixtures

The plan-analysis feature lives under `services/plan_analysis/`:

- `computer_vision/`: contour and comprehensive CV endpoints/helpers
- `pipeline/`: sheet upload, subplan detection, AI extraction, fusion, and dataset export

Run locally:

```bash
python app.py
```
