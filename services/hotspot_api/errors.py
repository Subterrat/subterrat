from __future__ import annotations

import uuid

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

from services.hotspot_api.schemas.common import ErrorCode, Problem

_TITLES: dict[ErrorCode, str] = {
    "NO_PUBLISHED_RELEASE": "No published release",
    "RELEASE_NOT_FOUND": "Release not found",
    "CELL_NOT_FOUND": "Cell not found",
    "PREDICTION_RUN_NOT_FOUND": "Prediction run not found",
    "INVALID_BBOX": "Invalid bounding box",
    "INVALID_TIME_WINDOW": "Invalid time window",
    "CAPABILITY_NOT_AVAILABLE": "Capability not available",
    "DATA_GATE_FAILED": "Data gate failed",
    "STATE_CONFLICT": "State conflict",
    "IDEMPOTENCY_CONFLICT": "Idempotency key conflict",
    "FORBIDDEN_DATA_SCOPE": "Forbidden data scope",
    "INTERNAL_ERROR": "Internal error",
}


class ApiError(Exception):
    def __init__(self, status_code: int, code: ErrorCode, detail: str) -> None:
        super().__init__(detail)
        self.status_code = status_code
        self.code = code
        self.detail = detail


def _request_id(request: Request) -> str:
    return request.headers.get("x-request-id", str(uuid.uuid4()))


def _problem_response(
    status_code: int, code: ErrorCode, detail: str, request_id: str
) -> JSONResponse:
    problem = Problem(
        type="about:blank",
        title=_TITLES[code],
        status=status_code,
        code=code,
        detail=detail,
        request_id=request_id,
    )
    return JSONResponse(
        status_code=status_code,
        content=problem.model_dump(),
        media_type="application/problem+json",
    )


def register_exception_handlers(app: FastAPI) -> None:
    @app.exception_handler(ApiError)
    async def handle_api_error(request: Request, exc: ApiError) -> JSONResponse:
        return _problem_response(exc.status_code, exc.code, exc.detail, _request_id(request))

    @app.exception_handler(RequestValidationError)
    async def handle_validation_error(
        request: Request, exc: RequestValidationError
    ) -> JSONResponse:
        return _problem_response(
            422, "INVALID_TIME_WINDOW", str(exc), _request_id(request)
        )

    @app.exception_handler(StarletteHTTPException)
    async def handle_http_exception(
        request: Request, exc: StarletteHTTPException
    ) -> JSONResponse:
        return _problem_response(
            exc.status_code, "INTERNAL_ERROR", str(exc.detail), _request_id(request)
        )
