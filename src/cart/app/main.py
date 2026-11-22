from datetime import datetime, timezone
import json
import time
from fastapi import FastAPI, Request
from prometheus_fastapi_instrumentator import Instrumentator
from app.config import settings
from app.router import router

app = FastAPI(title="Cart Service")


@app.middleware("http")
async def json_access_log(request: Request, call_next):
    if request.url.path in ("/health", "/metrics"):
        return await call_next(request)
    start = time.perf_counter()
    response = await call_next(request)
    duration_ms = round((time.perf_counter() - start) * 1000, 2)
    level = "error" if response.status_code >= 500 else "warn" if response.status_code >= 400 else "info"
    print(
        json.dumps(
            {
                "timestamp": datetime.now(timezone.utc).isoformat(),
                "level": level,
                "service": "cart",
                "event": "http_request",
                "method": request.method,
                "path": request.url.path,
                "status": response.status_code,
                "duration_ms": duration_ms,
            }
        ),
        flush=True,
    )
    return response


@app.on_event("startup")
def startup():
    if settings.cart_persistence_provider == "postgres":
        from app.postgres_service import PostgresCartService
        app.state.cart_service = PostgresCartService()
    else:
        from app.service import InMemoryCartService
        app.state.cart_service = InMemoryCartService()


@app.get("/topology")
def topology():
    return {"provider": settings.cart_persistence_provider}


@app.get("/health")
def health():
    return {"status": "UP", "service": "cart", "version": settings.app_version}


app.include_router(router)
Instrumentator().instrument(app).expose(app, endpoint="/metrics")
