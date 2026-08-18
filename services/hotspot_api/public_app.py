from __future__ import annotations

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from services.hotspot_api.config import get_settings
from services.hotspot_api.errors import register_exception_handlers
from services.hotspot_api.routers import (
    capabilities,
    cells,
    lab_v03,
    map as map_router,
    network_redistribution,
    operations,
    releases,
)


def create_app() -> FastAPI:
    settings = get_settings()
    app = FastAPI(title="SubTerrat Hotspot API", version="0.1.0")
    if settings.cors_allow_origins:
        app.add_middleware(
            CORSMiddleware,
            allow_origins=list(settings.cors_allow_origins),
            allow_methods=["GET"],
            allow_headers=["*"],
        )
    register_exception_handlers(app)
    app.include_router(operations.router)
    app.include_router(capabilities.router)
    app.include_router(map_router.router)
    app.include_router(releases.router)
    app.include_router(cells.router)
    app.include_router(lab_v03.router)
    app.include_router(network_redistribution.router)
    return app


app = create_app()
