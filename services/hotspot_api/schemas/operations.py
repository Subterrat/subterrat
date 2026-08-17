from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, ConfigDict


class Health(BaseModel):
    model_config = ConfigDict(extra="forbid")

    status: Literal["alive"] = "alive"
    proof_scope: Literal["process_liveness_only"] = "process_liveness_only"


class Readiness(BaseModel):
    model_config = ConfigDict(extra="forbid")

    status: Literal["ready"] = "ready"
    current_release_id: str
    proof_scope: Literal["public_release_serving_only"] = "public_release_serving_only"
