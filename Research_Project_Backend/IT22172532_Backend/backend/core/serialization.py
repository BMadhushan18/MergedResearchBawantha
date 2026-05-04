"""Serialization helpers for MongoDB documents."""


def bson_to_dict(doc) -> dict:
    if doc is None:
        return {}
    return _clean(doc)


def _clean(obj):
    from bson import ObjectId

    if isinstance(obj, dict):
        return {k: (_clean(v) if k != "_id" else str(v)) for k, v in obj.items()}
    if isinstance(obj, list):
        return [_clean(i) for i in obj]
    if isinstance(obj, ObjectId):
        return str(obj)
    return obj
