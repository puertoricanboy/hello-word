import json
from dataclasses import asdict
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

from app.executor import run_action, store
from app.models import TurnRequest
from app.nlu import parse_text
from app.policy import evaluate_policy


ROOT = Path(__file__).resolve().parent.parent


def handle_turn(req: TurnRequest) -> dict:
    nlu = parse_text(req.text)
    allowed, reason = evaluate_policy(nlu)

    if not allowed:
        return {
            "status": "blocked",
            "assistant": reason,
            "nlu": asdict(nlu),
        }

    action = run_action(req.user_id, nlu)
    return {
        "status": action.status,
        "assistant": action.message,
        "nlu": asdict(nlu),
        "details": action.details,
    }


class AppHandler(BaseHTTPRequestHandler):
    def _send_json(self, body: dict, status: int = 200) -> None:
        raw = json.dumps(body).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    def do_GET(self):
        if self.path == "/":
            html = (ROOT / "static" / "index.html").read_bytes()
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(html)))
            self.end_headers()
            self.wfile.write(html)
            return

        if self.path == "/api/state":
            self._send_json({"events": store.events, "tasks": store.tasks, "emails": store.emails})
            return

        self._send_json({"error": "not found"}, status=404)

    def do_POST(self):
        if self.path != "/api/turn":
            self._send_json({"error": "not found"}, status=404)
            return

        length = int(self.headers.get("Content-Length", "0"))
        payload = json.loads(self.rfile.read(length) or b"{}")

        user_id = str(payload.get("user_id", "")).strip()
        text = str(payload.get("text", "")).strip()

        if not user_id or not text:
            self._send_json({"error": "user_id y text son requeridos"}, status=400)
            return

        response = handle_turn(TurnRequest(user_id=user_id, text=text))
        self._send_json(response)


def run(port: int = 8000):
    server = HTTPServer(("0.0.0.0", port), AppHandler)
    print(f"Secretaria Virtual MVP running on http://0.0.0.0:{port}")
    server.serve_forever()


if __name__ == "__main__":
    run()
