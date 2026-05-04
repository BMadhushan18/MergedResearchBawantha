"""MongoDB connection and collections.

Falls back to process-local collections when MongoDB is unreachable at startup.
This keeps the API available for local frontend development.
"""

from copy import deepcopy
from types import SimpleNamespace

from bson import ObjectId
from pymongo import MongoClient

from config.settings import DB_NAME, MONGO_TIMEOUT_MS, MONGO_URI

DB_READY = False
DB_INIT_ERROR = "Database init has not run yet."
USING_LOCAL_STORE = False


class _LocalResult:
    def __init__(self, inserted_id=None, modified_count=0, deleted_count=0):
        self.inserted_id = inserted_id
        self.modified_count = modified_count
        self.deleted_count = deleted_count


class _LocalCursor(list):
    def sort(self, key, direction=1):
        reverse = direction == -1
        return _LocalCursor(sorted(self, key=lambda doc: doc.get(key), reverse=reverse))


class _LocalCollection:
    def __init__(self, name):
        self.name = name
        self._docs = []

    def create_index(self, *args, **kwargs):
        return None

    def _matches(self, doc, query):
        if not query:
            return True
        for key, value in query.items():
            if key == "$or":
                return any(self._matches(doc, item) for item in value)
            if isinstance(value, dict):
                if "$regex" in value:
                    needle = str(value["$regex"]).lower()
                    if needle not in str(doc.get(key, "")).lower():
                        return False
                    continue
                if "$in" in value:
                    if doc.get(key) not in value["$in"]:
                        return False
                    continue
            if doc.get(key) != value:
                return False
        return True

    def _project(self, doc, projection):
        if not projection:
            return deepcopy(doc)
        out = deepcopy(doc)
        for key, enabled in projection.items():
            if enabled == 0 and key in out:
                out.pop(key, None)
        return out

    def find_one(self, query=None, *args, **kwargs):
        matches = self.find(query or {}, projection=kwargs.get("projection"))
        sort = kwargs.get("sort")
        if sort:
            for key, direction in reversed(sort):
                matches = matches.sort(key, direction)
        return matches[0] if matches else None

    def find(self, query=None, *args, **kwargs):
        projection = kwargs.get("projection")
        return _LocalCursor([
            self._project(doc, projection)
            for doc in self._docs
            if self._matches(doc, query or {})
        ])

    def insert_one(self, doc):
        stored = deepcopy(doc)
        stored.setdefault("_id", ObjectId())
        self._docs.append(stored)
        return _LocalResult(inserted_id=stored["_id"])

    def insert_many(self, docs):
        ids = []
        for doc in docs:
            ids.append(self.insert_one(doc).inserted_id)
        return SimpleNamespace(inserted_ids=ids)

    def update_one(self, query, update, *args, **kwargs):
        upsert = kwargs.get("upsert", False)
        for doc in self._docs:
            if self._matches(doc, query):
                if "$set" in update:
                    doc.update(deepcopy(update["$set"]))
                return _LocalResult(modified_count=1)
        if upsert:
            new_doc = deepcopy(query)
            if "$set" in update:
                new_doc.update(deepcopy(update["$set"]))
            return self.insert_one(new_doc)
        return _LocalResult(modified_count=0)

    def delete_one(self, query):
        for index, doc in enumerate(self._docs):
            if self._matches(doc, query):
                del self._docs[index]
                return _LocalResult(deleted_count=1)
        return _LocalResult(deleted_count=0)

    def delete_many(self, query):
        before = len(self._docs)
        self._docs = [doc for doc in self._docs if not self._matches(doc, query)]
        return _LocalResult(deleted_count=before - len(self._docs))

    def count_documents(self, query):
        return len([doc for doc in self._docs if self._matches(doc, query)])


class _LocalDb:
    def __init__(self):
        self._collections = {}

    def __getitem__(self, name):
        if name not in self._collections:
            self._collections[name] = _LocalCollection(name)
        return self._collections[name]


class _LocalClient:
    def __init__(self):
        self.admin = self
        self._db = _LocalDb()

    def command(self, name):
        return {"ok": 1}

    def __getitem__(self, name):
        return self._db


def _bind_collections(db):
    global users_col, projects_col, threejs_col, buildingstructure_col
    global structuralframe_col, walling_col, finishing_col, materials_col, boqReport_col
    global pixelcoordinates_col

    users_col = db["users"]
    projects_col = db["projects"]
    threejs_col = db["threejs"]
    buildingstructure_col = db["buildingstructure"]
    structuralframe_col = db["structuralframe"]
    walling_col = db["walling"]
    finishing_col = db["finishing"]
    materials_col = db["materials"]
    boqReport_col = db["boqReport"]
    pixelcoordinates_col = db["pixelcoordinates"]


def _activate_local_store(reason):
    global client, _db, USING_LOCAL_STORE, DB_INIT_ERROR
    USING_LOCAL_STORE = True
    DB_INIT_ERROR = f"MongoDB unavailable; using local store: {reason}"
    client = _LocalClient()
    _db = client[DB_NAME]
    _bind_collections(_db)


try:
    client = MongoClient(
        MONGO_URI,
        serverSelectionTimeoutMS=MONGO_TIMEOUT_MS,
        connectTimeoutMS=MONGO_TIMEOUT_MS,
        socketTimeoutMS=MONGO_TIMEOUT_MS,
    )
    _db = client[DB_NAME]
except Exception as e:
    _activate_local_store(e)

_bind_collections(_db)

# Seed materials (runs at startup, drops + re-inserts so brand names stay correct)
# Schema: name, category, unit, sizes, brands, boqSections
_MAT_SEED = [
    {"name": "Cement (OPC)", "category": "Concrete & Foundation", "unit": "bag", "unitPrice": 2200,
     "brands": ["INSEE", "Sanstha", "Tokyo Cement", "Holcim", "Lanwa"],
     "sizes": ["25 kg", "50 kg"],
     "boqSections": ["foundation", "structural_frame", "walling", "plastering", "flooring"]},
    {"name": "River Sand", "category": "Concrete & Foundation", "unit": "m3", "unitPrice": 8500,
     "brands": [], "sizes": ["Fine Grade", "Coarse Grade", "Washed"],
     "boqSections": ["foundation", "structural_frame", "walling", "plastering"]},
    {"name": "Coarse Aggregate", "category": "Concrete & Foundation", "unit": "m3", "unitPrice": 12000,
     "brands": [], "sizes": ["10 mm", "20 mm", "40 mm"],
     "boqSections": ["foundation", "structural_frame"]},
    {"name": "Fine Sand", "category": "Concrete & Foundation", "unit": "m3", "unitPrice": 9000,
     "brands": [], "sizes": ["Fine Grade", "Extra Fine Grade"],
     "boqSections": ["plastering", "flooring"]},
    {"name": "Polythene Sheet", "category": "Concrete & Foundation", "unit": "m2", "unitPrice": 85,
     "brands": [], "sizes": ["125 um (500 gauge)", "250 um (1000 gauge)"],
     "boqSections": ["foundation", "walling"]},
    {"name": "Steel Rebar Y10", "category": "Structural Steel", "unit": "kg", "unitPrice": 220,
     "brands": ["Taian", "Aruna Steel", "Lanka Steel"],
     "sizes": ["6 m length", "12 m length"],
     "boqSections": ["foundation", "structural_frame", "walling"]},
    {"name": "Steel Rebar Y12", "category": "Structural Steel", "unit": "kg", "unitPrice": 230,
     "brands": ["Taian", "Aruna Steel", "Lanka Steel"],
     "sizes": ["6 m length", "12 m length"],
     "boqSections": ["foundation", "structural_frame"]},
    {"name": "Steel Rebar Y16", "category": "Structural Steel", "unit": "kg", "unitPrice": 245,
     "brands": ["Taian", "Aruna Steel", "Lanka Steel"],
     "sizes": ["6 m length", "12 m length"],
     "boqSections": ["structural_frame"]},
    {"name": "Steel Rebar Y20", "category": "Structural Steel", "unit": "kg", "unitPrice": 255,
     "brands": ["Taian", "Aruna Steel", "Lanka Steel"],
     "sizes": ["6 m length", "12 m length"],
     "boqSections": ["structural_frame", "foundation"]},
    {"name": "Binding Wire", "category": "Structural Steel", "unit": "kg", "unitPrice": 380,
     "brands": [], "sizes": ["1 kg roll", "5 kg roll"],
     "boqSections": ["foundation", "structural_frame"]},
    {"name": "Mild Steel Nails", "category": "Structural Steel", "unit": "kg", "unitPrice": 420,
     "brands": [], "sizes": ["2\" (50 mm)", "3\" (75 mm)", "4\" (100 mm)"],
     "boqSections": ["structural_frame", "roofing"]},
    {"name": "Hollow Concrete Blocks", "category": "Masonry & Walling", "unit": "No.", "unitPrice": 85,
     "brands": [], "sizes": ["4 in", "6 in", "8 in"],
     "boqSections": ["walling"]},
    {"name": "Cement Blocks", "category": "Masonry & Walling", "unit": "No.", "unitPrice": 75,
     "brands": [], "sizes": ["4 in", "6 in", "8 in"],
     "boqSections": ["walling"]},
    {"name": "Clay Bricks", "category": "Masonry & Walling", "unit": "No.", "unitPrice": 25,
     "brands": [], "sizes": ["Standard"], "boqSections": ["walling"]},
    {"name": "DPC Sheet", "category": "Masonry & Walling", "unit": "m2", "unitPrice": 85,
     "brands": [], "sizes": ["125 um", "250 um"], "boqSections": ["walling"]},
    {"name": "Timber", "category": "Carpentry", "unit": "m", "unitPrice": 650,
     "brands": [], "sizes": ["2x2", "2x3", "2x4", "3x3"], "boqSections": ["roofing", "ceiling"]},
    {"name": "Roofing Sheets", "category": "Roofing", "unit": "m2", "unitPrice": 1200,
     "brands": ["Lanka", "Green", "Lysaght"], "sizes": ["0.35 mm", "0.4 mm", "0.5 mm"],
     "boqSections": ["roofing"]},
    {"name": "Ceiling Sheets", "category": "Ceiling", "unit": "m2", "unitPrice": 950,
     "brands": ["Lanka", "Knauf"], "sizes": ["8 mm", "10 mm"], "boqSections": ["ceiling"]},
    {"name": "Wall Putty", "category": "Finishing", "unit": "kg", "unitPrice": 450,
     "brands": ["Holcim", "Lanka"], "sizes": ["5 kg", "10 kg", "20 kg"],
     "boqSections": ["plastering"]},
    {"name": "Primer", "category": "Finishing", "unit": "L", "unitPrice": 1100,
     "brands": ["Nippon", "Dulux"], "sizes": ["1 L", "4 L", "10 L"],
     "boqSections": ["finishing"]},
    {"name": "Wall Paint", "category": "Finishing", "unit": "L", "unitPrice": 1800,
     "brands": ["Nippon", "Dulux"], "sizes": ["1 L", "4 L", "10 L"],
     "boqSections": ["finishing"]},
    {"name": "Floor Tiles", "category": "Flooring", "unit": "m2", "unitPrice": 2400,
     "brands": ["Lanka", "Royal"], "sizes": ["300x300 mm", "600x600 mm"],
     "boqSections": ["flooring"]},
    {"name": "Tile Adhesive", "category": "Flooring", "unit": "bag", "unitPrice": 1600,
     "brands": ["Lanka", "Laticrete"], "sizes": ["25 kg"], "boqSections": ["flooring"]},
    {"name": "Tile Grout", "category": "Flooring", "unit": "kg", "unitPrice": 600,
     "brands": ["Lanka", "Laticrete"], "sizes": ["1 kg", "5 kg"], "boqSections": ["flooring"]},
    {"name": "Glass", "category": "Doors & Windows", "unit": "m2", "unitPrice": 4200,
     "brands": [], "sizes": ["5 mm", "6 mm", "8 mm"], "boqSections": ["doors_windows"]},
    {"name": "Door Frame (Timber)", "category": "Doors & Windows", "unit": "No.", "unitPrice": 9500,
     "brands": [], "sizes": ["Standard"], "boqSections": ["doors_windows"]},
    {"name": "Door Leaf (Timber)", "category": "Doors & Windows", "unit": "No.", "unitPrice": 8000,
     "brands": [], "sizes": ["Standard"], "boqSections": ["doors_windows"]},
    {"name": "Window Frame (Aluminium)", "category": "Doors & Windows", "unit": "No.", "unitPrice": 28000,
     "brands": [], "sizes": ["Standard"], "boqSections": ["doors_windows"]},
    {"name": "Wash Basin", "category": "Plumbing", "unit": "No.", "unitPrice": 18000,
     "brands": [], "sizes": ["Standard"], "boqSections": ["plumbing"]},
    {"name": "Kitchen Sink (Stainless)", "category": "Plumbing", "unit": "No.", "unitPrice": 28000,
     "brands": [], "sizes": ["Standard"], "boqSections": ["plumbing"]},
]


def _seed_materials() -> None:
    if materials_col.count_documents({}) > 0:
        materials_col.delete_many({})
    docs = []
    for d in _MAT_SEED:
        doc = dict(d)
        doc["name_lower"] = doc["name"].lower()
        doc["createdAt"] = "seed"
        doc["updatedAt"] = "seed"
        docs.append(doc)
    if docs:
        materials_col.insert_many(docs)


def init_db() -> None:
    """Initialize Mongo indexes/seed once at startup with clear diagnostics."""
    global DB_READY, DB_INIT_ERROR
    try:
        client.admin.command("ping")
        users_col.create_index("email", unique=True)
        materials_col.create_index("name_lower")
        boqReport_col.create_index([("projectId", 1)], unique=True)
        _seed_materials()
        DB_READY = True
        if USING_LOCAL_STORE:
            print("[db] MongoDB unavailable; using local in-memory store.")
        else:
            DB_INIT_ERROR = ""
            print("[db] MongoDB connected and initialized.")
    except Exception as e:
        DB_READY = False
        DB_INIT_ERROR = str(e)
        print("[db] MongoDB initialization failed:")
        print(f"[db] {DB_INIT_ERROR}")
        if not USING_LOCAL_STORE:
            _activate_local_store(e)
            _seed_materials()
            DB_READY = True
            print("[db] Switched to local in-memory store.")


def get_db():
    return _db
