from __future__ import annotations

from pydantic import BaseModel, ConfigDict


class CurrentRelease(BaseModel):
    model_config = ConfigDict(extra="forbid")

    release_id: str
    href: str
