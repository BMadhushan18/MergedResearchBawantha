"""
Smart Construction Management - MongoDB Backend
Structured entrypoint that wires blueprints and core services.
"""

import io
import sys
from flask import Flask
from flask_cors import CORS

from config.settings import DB_NAME, PORT
from database.connection import init_db
from services.auth.routes import auth_bp
from services.boq.routes import boq_bp
from services.health.routes import health_bp
from services.materials.routes import materials_bp
from services.projects.routes import projects_bp
from services.three_d_view.routes import threejs_bp

# Feature blueprints
from services.plan_analysis.computer_vision.contour_routes import contour_bp
from services.plan_analysis.computer_vision.comprehensive_cv_routes import comprehensive_cv_bp
from services.plan_analysis.pipeline.routes import plan_bp, training_bp
from services.pixel_coordinates.routes import pixel_coordinates_bp
from services.three_d_floor_plan.routes import three_d_floor_plan_bp


def create_app() -> Flask:
    app = Flask(__name__)
    CORS(app)

    # Initialize database and seed data
    init_db()

    # External feature modules
    app.register_blueprint(contour_bp)
    app.register_blueprint(comprehensive_cv_bp)
    app.register_blueprint(plan_bp)
    app.register_blueprint(training_bp)
    app.register_blueprint(pixel_coordinates_bp)
    app.register_blueprint(three_d_floor_plan_bp)

    # Core API
    app.register_blueprint(auth_bp)
    app.register_blueprint(projects_bp)
    app.register_blueprint(materials_bp)
    app.register_blueprint(boq_bp)
    app.register_blueprint(threejs_bp)
    app.register_blueprint(health_bp)

    return app


app = create_app()


if __name__ == "__main__":
    if sys.stdout and hasattr(sys.stdout, "buffer"):
        sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
    print("\nSmart Construction MongoDB Backend")
    print(f"   DB  : {DB_NAME}")
    print(f"   URL : http://0.0.0.0:{PORT}")
    print(f"   Health: http://localhost:{PORT}/health\n")
    app.run(host="0.0.0.0", port=PORT, debug=False, use_reloader=False)
