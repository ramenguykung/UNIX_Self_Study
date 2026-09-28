"""Small API that generates predictable HTTP statuses for log analysis."""

import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlsplit


class Handler(BaseHTTPRequestHandler):
    def send_json(self, status: int, payload: dict) -> None:
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:
        path = urlsplit(self.path).path
        if path == "/":
            self.send_json(200, {"message": "Web Log Analyzer demo API"})
        elif path == "/health":
            self.send_json(200, {"status": "ok"})
        elif path == "/error":
            self.send_json(500, {"error": "Simulated server error"})
        else:
            self.send_json(404, {"error": "Not found"})

    def do_POST(self) -> None:
        if urlsplit(self.path).path == "/login":
            self.send_json(401, {"error": "Simulated failed login"})
        else:
            self.send_json(404, {"error": "Not found"})


if __name__ == "__main__":
    ThreadingHTTPServer(("0.0.0.0", 8000), Handler).serve_forever()
