"""
Simple API gateway for the four backends.
Each service is exposed under a distinct prefix and requests are
forwarded to the appropriate local port.

Usage:
    uvicorn gateway:app --host 0.0.0.0 --port 8000

Then:
  /it22196460/...  -> http://localhost:8001/...   (IT22196460_Backend – Smart Logistics)
  /dineth/...      -> http://localhost:8002/...   (Dineth backend)
  /it22574718/...  -> http://localhost:8003/...   (IT22574718_Backend – Time Estimation)
  /it22172532/...  -> http://localhost:8004/...   (IT22172532_Backend – BOQ / 3D / Projects)


Backward compatibility:
  /api/v1/...      -> http://localhost:8001/api/v1/...
"""

from fastapi import FastAPI, Request, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import Response
import httpx

app = FastAPI(title="Project Gateway")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Mapping from prefix -> base url of backend service.
SERVICE_MAP = {
    "it22196460": "http://localhost:8001",   # IT22196460_Backend – Smart Logistics
    "dineth":     "http://localhost:8002",   # Dineth backend
    "it22574718": "http://localhost:8003",   # IT22574718_Backend – Time Estimation
    "it22172532": "http://localhost:8004",   # IT22172532_Backend – BOQ / 3D / Projects
    "bawantha":   "http://localhost:8004",   # alias kept for backward compatibility
}


async def forward_request(base_url: str, path: str, request: Request):
    target = f"{base_url}/{path}"

    # Copy headers except host so each backend sees its own host.
    headers = dict(request.headers)
    headers.pop("host", None)

    try:
        async with httpx.AsyncClient(follow_redirects=False) as client:
            resp = await client.request(
                request.method,
                target,
                headers=headers,
                params=request.query_params,
                content=await request.body(),
                timeout=60.0,
            )
    except (httpx.ConnectError, httpx.ConnectTimeout, httpx.ReadTimeout):
        raise HTTPException(
            status_code=503,
            detail=f"Backend service at {base_url} is not reachable. Please ensure all backend services are running.",
        )

    return Response(
        content=resp.content,
        status_code=resp.status_code,
        headers=dict(resp.headers),
    )


# Backward-compatible route for frontend calls like /api/v1/login.
@app.api_route("/api/{path:path}", methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS", "HEAD"])
async def default_api_proxy(path: str, request: Request):
    return await forward_request(SERVICE_MAP["it22196460"], f"api/{path}", request)


# Generic prefixed proxy route, e.g. /it22574718/...
# Unknown prefixes (e.g. /auth/..., /projects/...) fall back to IT22172532 backend (port 8004).
@app.api_route("/{service}/{path:path}", methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS", "HEAD"])
async def proxy(service: str, path: str, request: Request):
    if service in SERVICE_MAP:
        return await forward_request(SERVICE_MAP[service], path, request)
    # Fall back: forward the full original path to IT22172532 (auth/projects/boq/etc.)
    full_path = f"{service}/{path}".rstrip("/")
    return await forward_request(SERVICE_MAP["it22172532"], full_path, request)


# Optionally provide a root health endpoint.
@app.get("/")
async def health():
    return {"status": "gateway running", "routes": list(SERVICE_MAP.keys())}