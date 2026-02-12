from app.models import ActionResult, NLUResult


class InMemoryStore:
    def __init__(self) -> None:
        self.events: list[dict] = []
        self.tasks: list[dict] = []
        self.emails: list[dict] = []


store = InMemoryStore()


def run_action(user_id: str, nlu: NLUResult) -> ActionResult:
    if nlu.intent == "agendar_reunion":
        event = {
            "user_id": user_id,
            "tipo": "reunion",
            "duracion": nlu.entities.get("duracion", 30),
            "participantes": nlu.entities.get("participantes", []),
            "fecha": nlu.entities.get("fecha", "no_especificada"),
        }
        store.events.append(event)
        return ActionResult(
            status="success",
            message="Reunión agendada correctamente.",
            details=event,
        )

    if nlu.intent == "enviar_email":
        email = {"user_id": user_id, "estado": "borrador_creado"}
        store.emails.append(email)
        return ActionResult(
            status="needs_confirmation",
            message="Preparé un borrador. ¿Deseas enviarlo ahora?",
            details=email,
        )

    if nlu.intent == "crear_tarea":
        task = {"user_id": user_id, "estado": "pendiente"}
        store.tasks.append(task)
        return ActionResult(status="success", message="Tarea creada.", details=task)

    return ActionResult(
        status="blocked",
        message="No puedo ejecutar esta acción todavía.",
        details={},
    )
