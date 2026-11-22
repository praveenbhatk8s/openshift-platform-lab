#!/usr/bin/env python3
"""Tiny demo service for the OpenShift lab. Standard library only.

- HTTP on 8080 always.
- HTTPS on 8443 when a certificate is mounted at /etc/tls (tls.crt and tls.key),
  for example the service serving certificate in module 02.
- GET /        returns who and where it runs, including the UID OpenShift assigned
- GET /healthz returns 200 for probes
"""
import json
import os
import socket
import ssl
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

CERT = os.environ.get("TLS_CERT", "/etc/tls/tls.crt")
KEY = os.environ.get("TLS_KEY", "/etc/tls/tls.key")
HTTP_PORT = int(os.environ.get("HTTP_PORT", "8080"))
HTTPS_PORT = int(os.environ.get("HTTPS_PORT", "8443"))


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/healthz":
            self._send(200, {"status": "ok"})
            return
        if self.path == "/":
            self._send(200, {
                "service": "rack-demo",
                "pod": socket.gethostname(),
                "uid": os.getuid(),
                "gid": os.getgid(),
                "groups": os.getgroups(),
                "tls": self.server.server_port == HTTPS_PORT,
            })
            return
        self._send(404, {"error": "not found"})

    def _send(self, code, body):
        data = json.dumps(body, indent=2).encode() + b"\n"
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, fmt, *args):
        print(f"{self.address_string()} {fmt % args}", flush=True)


def serve_https():
    ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    ctx.minimum_version = ssl.TLSVersion.TLSv1_2
    ctx.load_cert_chain(CERT, KEY)
    httpd = ThreadingHTTPServer(("0.0.0.0", HTTPS_PORT), Handler)
    httpd.socket = ctx.wrap_socket(httpd.socket, server_side=True)
    print(f"https listening on {HTTPS_PORT}", flush=True)
    httpd.serve_forever()


if __name__ == "__main__":
    print(f"starting as uid={os.getuid()} gid={os.getgid()} groups={os.getgroups()}", flush=True)
    if os.path.exists(CERT) and os.path.exists(KEY):
        threading.Thread(target=serve_https, daemon=True).start()
    else:
        print("no certificate mounted, https disabled", flush=True)
    httpd = ThreadingHTTPServer(("0.0.0.0", HTTP_PORT), Handler)
    print(f"http listening on {HTTP_PORT}", flush=True)
    httpd.serve_forever()
