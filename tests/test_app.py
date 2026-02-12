from app.main import handle_turn
from app.models import TurnRequest


def test_agendar_reunion():
    req = TurnRequest(user_id="u1", text="Agenda una reunión con Ana mañana 30 minutos")
    body = handle_turn(req)
    assert body['nlu']['intent'] == 'agendar_reunion'
    assert body['status'] == 'success'
    assert body['details']['participantes'] == ['ana']


def test_fallback():
    req = TurnRequest(user_id="u1", text="blablabla")
    body = handle_turn(req)
    assert body['status'] == 'blocked'
