from app.models import NLUResult


SENSITIVE_INTENTS = {"agendar_reunion", "enviar_email"}


def evaluate_policy(nlu: NLUResult) -> tuple[bool, str]:
    if nlu.intent == "fallback":
        return False, "No entendí la solicitud. ¿Puedes reformularla?"

    if nlu.intent in SENSITIVE_INTENTS and nlu.confidence < 0.7:
        return False, "Necesito confirmar antes de ejecutar esa acción."

    return True, "ok"
