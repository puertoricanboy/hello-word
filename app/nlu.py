import re
from datetime import datetime
from app.models import NLUResult


STOPWORDS = {"mañana", "hoy", "min", "minutos", "por", "la", "tarde", "noche", "mañana"}


def _extract_participants(lowered: str) -> list[str]:
    match = re.search(r"con\s+([a-záéíóúñ\s,]+)", lowered)
    if not match:
        return []

    raw = match.group(1)
    raw = re.sub(r"\b\d{1,3}\s*(min|minutos)\b", "", raw)
    tokens = [t.strip() for t in re.split(r",| y ", raw) if t.strip()]

    participants = []
    for t in tokens:
        words = [w for w in t.split() if w not in STOPWORDS]
        cleaned = " ".join(words).strip()
        if cleaned:
            participants.append(cleaned)
    return participants


def parse_text(text: str) -> NLUResult:
    lowered = text.lower().strip()

    if any(word in lowered for word in ["agenda", "agendar", "reunión", "reunion"]):
        duration_match = re.search(r"(\d{1,3})\s*(min|minutos)", lowered)
        duration = int(duration_match.group(1)) if duration_match else 30

        participants = _extract_participants(lowered)
        date_hint = "mañana" if "mañana" in lowered else "no_especificada"

        return NLUResult(
            intent="agendar_reunion",
            entities={
                "duracion": duration,
                "participantes": participants,
                "fecha": date_hint,
                "timestamp": datetime.utcnow().isoformat(),
            },
            confidence=0.84,
        )

    if any(word in lowered for word in ["email", "correo", "responde", "responder"]):
        return NLUResult(
            intent="enviar_email",
            entities={"prioridad": "media", "timestamp": datetime.utcnow().isoformat()},
            confidence=0.78,
        )

    if any(word in lowered for word in ["tarea", "recordatorio", "recuerdame", "recuérdame"]):
        return NLUResult(
            intent="crear_tarea",
            entities={"timestamp": datetime.utcnow().isoformat()},
            confidence=0.8,
        )

    return NLUResult(intent="fallback", entities={}, confidence=0.4)
