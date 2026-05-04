import os

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

TIME_MODELS_DIR = os.path.join(BASE_DIR, "time_models")


# Foundation phase model
FOUNDATION_MODEL_PATH = os.path.join(
    TIME_MODELS_DIR,
    "foundation_pipeline.pkl"
)


# Structural wall phase model
WALL_MODEL_PATH = os.path.join(
    TIME_MODELS_DIR,
    "wall_pipeline.pkl"
)


# Roofing phase model
ROOFING_MODEL_PATH = os.path.join(
    TIME_MODELS_DIR,
    "roofing_pipeline.pkl"
)


# Doors and windows phase model
DOOR_WINDOW_MODEL_PATH = os.path.join(
    TIME_MODELS_DIR,
    "door_window_pipeline.pkl"
)


# Plastering phase model
PLASTERING_MODEL_PATH = os.path.join(
    TIME_MODELS_DIR,
    "plastering_pipeline.pkl"
)


# Flooring phase model
FLOORING_MODEL_PATH = os.path.join(
    TIME_MODELS_DIR,
    "flooring_pipeline.pkl"
)


# Painting and finishing phase model
PAINTING_MODEL_PATH = os.path.join(
    TIME_MODELS_DIR,
    "painting_pipeline.pkl"
)