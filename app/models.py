from dataclasses import dataclass, field
from typing import Any


@dataclass
class TurnRequest:
    user_id: str
    text: str


@dataclass
class NLUResult:
    intent: str
    entities: dict[str, Any]
    confidence: float


@dataclass
class ActionResult:
    status: str
    message: str
    details: dict[str, Any] = field(default_factory=dict)
