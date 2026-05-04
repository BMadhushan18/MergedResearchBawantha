import joblib
import pandas as pd


# Foundation phase
class FoundationDurationService:

    def __init__(self, model_path):
        self.model = joblib.load(model_path)

        self.required_fields = [
            "foundation_type",
            "soil_condition",
            "total_volume_m3",
            "labor_count",
        ]

    # Validate the input payload for required fields and correct values
    def validate(self, payload):
        missing = [k for k in self.required_fields if k not in payload]
        if missing:
            raise ValueError(f"Missing fields: {missing}")

        try:
            vol = float(payload["total_volume_m3"])
            lab = int(payload["labor_count"])
        except Exception:
            raise ValueError("Invalid types: total_volume_m3 must be number, labor_count must be integer")

        if vol <= 0:
            raise ValueError("total_volume_m3 must be greater than 0")
        if lab < 1:
            raise ValueError("labor_count must be at least 1")


    # Predict the duration in days based on the input payload
    def predict(self, payload):
        self.validate(payload)
        df = pd.DataFrame([payload])
        pred = self.model.predict(df)

        days = int(round(pred[0]))
        return max(days, 1)


# Structural and Wall
class WallDurationService:

    def __init__(self, model_path):
        self.model = joblib.load(model_path)

        self.required_fields = [
            "wall_type",
            "floor_area_m2",
            "total_wall_area_m2",
            "working_hours_per_day",
            "labor_count",
        ]

    def validate(self, payload):
        missing = [k for k in self.required_fields if k not in payload]
        if missing:
            raise ValueError(f"Missing fields: {missing}")

        try:
            floor_area = float(payload["floor_area_m2"])
            wall_area = float(payload["total_wall_area_m2"])
            working_hours = float(payload["working_hours_per_day"])
            labor_count = int(payload["labor_count"])
        except Exception:
            raise ValueError(
                "Invalid types: floor_area_m2/total_wall_area_m2/working_hours_per_day must be numbers, labor_count must be integer"
            )

        if floor_area <= 0:
            raise ValueError("floor_area_m2 must be greater than 0")
        if wall_area <= 0:
            raise ValueError("total_wall_area_m2 must be greater than 0")
        if working_hours <= 0:
            raise ValueError("working_hours_per_day must be greater than 0")
        if labor_count < 1:
            raise ValueError("labor_count must be at least 1")

    def predict(self, payload):
        self.validate(payload)
        df = pd.DataFrame([payload])
        pred = self.model.predict(df)

        days = int(round(pred[0]))
        return max(days, 1)


# Roofing
class RoofingDurationService:
    def __init__(self, model_path):
        self.model = joblib.load(model_path)

        self.required_fields = [
            "roof_area_m2",
            "roof_height_m",
            "roof_type",
            "roof_covering",
            "labor_count",
        ]

    def validate(self, payload):
        missing = [k for k in self.required_fields if k not in payload]
        if missing:
            raise ValueError(f"Missing fields: {missing}")

        try:
            roof_area = float(payload["roof_area_m2"])
            roof_height = float(payload["roof_height_m"])
            labor_count = int(payload["labor_count"])
        except Exception:
            raise ValueError(
                "Invalid types: roof_area_m2/roof_height_m must be numbers, labor_count must be integer"
            )

        if roof_area <= 0:
            raise ValueError("roof_area_m2 must be greater than 0")
        if roof_height <= 0:
            raise ValueError("roof_height_m must be greater than 0")
        if labor_count < 1:
            raise ValueError("labor_count must be at least 1")

    def predict(self, payload):
        self.validate(payload)
        df = pd.DataFrame([payload])
        pred = self.model.predict(df)

        days = int(round(pred[0]))
        return max(days, 1)


# Door/Window Installation
class DoorWindowDurationService:
    def __init__(self, model_path):
        self.model = joblib.load(model_path)

        self.required_fields = [
            "door_count",
            "door_material",
            "window_count",
            "window_material",
            "labor_count",
        ]

    def validate(self, payload):
        missing = [k for k in self.required_fields if k not in payload]
        if missing:
            raise ValueError(f"Missing fields: {missing}")

        try:
            door_count = int(payload["door_count"])
            window_count = int(payload["window_count"])
            labor_count = int(payload["labor_count"])
        except Exception:
            raise ValueError(
                "Invalid types: door_count/window_count/labor_count must be integers"
            )

        if door_count < 1:
            raise ValueError("door_count must be at least 1")
        if window_count < 1:
            raise ValueError("window_count must be at least 1")
        if labor_count < 1:
            raise ValueError("labor_count must be at least 1")

    def predict(self, payload):
        self.validate(payload)
        df = pd.DataFrame([payload])
        pred = self.model.predict(df)

        days = int(round(pred[0]))
        return max(days, 1)


# Plastering
class PlasteringDurationService:
    def __init__(self, model_path):
        self.model = joblib.load(model_path)

        self.required_fields = [
            "wall_area_m2",
            "material",
            "location",
            "floors",
            "labor_count",
        ]

    def validate(self, payload):
        missing = [k for k in self.required_fields if k not in payload]
        if missing:
            raise ValueError(f"Missing fields: {missing}")

        try:
            wall_area = float(payload["wall_area_m2"])
            floors = int(payload["floors"])
            labor_count = int(payload["labor_count"])
        except Exception:
            raise ValueError(
                "Invalid types: wall_area_m2 must be number, floors/labor_count must be integers"
            )

        if wall_area <= 0:
            raise ValueError("wall_area_m2 must be greater than 0")
        if floors < 1:
            raise ValueError("floors must be at least 1")
        if labor_count < 1:
            raise ValueError("labor_count must be at least 1")

    def predict(self, payload):
        self.validate(payload)
        df = pd.DataFrame([payload])
        pred = self.model.predict(df)

        days = int(round(pred[0]))
        return max(days, 1)


# Flooring
class FlooringDurationService:
    def __init__(self, model_path):
        self.model = joblib.load(model_path)

        self.required_fields = [
            "floor_area_m2",
            "material_type",
            "location",
            "floors",
            "labor_count",
        ]

    def validate(self, payload):
        missing = [k for k in self.required_fields if k not in payload]
        if missing:
            raise ValueError(f"Missing fields: {missing}")

        try:
            floor_area = float(payload["floor_area_m2"])
            floors = int(payload["floors"])
            labor_count = int(payload["labor_count"])
        except Exception:
            raise ValueError(
                "Invalid types: floor_area_m2 must be number, floors/labor_count must be integers"
            )

        if floor_area <= 0:
            raise ValueError("floor_area_m2 must be greater than 0")
        if floors < 1:
            raise ValueError("floors must be at least 1")
        if labor_count < 1:
            raise ValueError("labor_count must be at least 1")

    def predict(self, payload):
        self.validate(payload)
        df = pd.DataFrame([payload])
        pred = self.model.predict(df)

        days = int(round(pred[0]))
        return max(days, 1)


# Painting
class PaintingDurationService:
    def __init__(self, model_path):
        self.model = joblib.load(model_path)

        self.required_fields = [
            "paint_area_m2",
            "painting_location",
            "number_of_coats",
            "floors",
            "labor_count",
        ]

    def validate(self, payload):
        missing = [k for k in self.required_fields if k not in payload]
        if missing:
            raise ValueError(f"Missing fields: {missing}")

        try:
            paint_area = float(payload["paint_area_m2"])
            coats = int(payload["number_of_coats"])
            floors = int(payload["floors"])
            labor_count = int(payload["labor_count"])
        except Exception:
            raise ValueError(
                "Invalid types: paint_area_m2 must be number, number_of_coats/floors/labor_count must be integers"
            )

        if paint_area <= 0:
            raise ValueError("paint_area_m2 must be greater than 0")
        if coats < 1:
            raise ValueError("number_of_coats must be at least 1")
        if floors < 1:
            raise ValueError("floors must be at least 1")
        if labor_count < 1:
            raise ValueError("labor_count must be at least 1")

    def predict(self, payload):
        self.validate(payload)
        df = pd.DataFrame([payload])
        pred = self.model.predict(df)

        days = int(round(pred[0]))
        return max(days, 1)