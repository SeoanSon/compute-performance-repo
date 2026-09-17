#!/usr/bin/env bash
set -euo pipefail

apt-get update -y
apt-get install -y python3

cat >/opt/order-api.py <<'PY'
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import hashlib
import os
import time

PORT = int(os.environ.get("PORT", "80"))

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path in ("/healthz", "/readyz"):
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b"ok\n")
            return
        if self.path.startswith("/api/orders"):
            digest = hashlib.sha256((self.path * 200).encode()).hexdigest()
            body = ('{"status":"ok","digest":"' + digest + '"}\n').encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        if self.path.startswith("/api/report"):
            with open("/tmp/order-api-report", "a+", encoding="utf-8") as report:
                report.write("report\n")
                report.flush()
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b"report\n")
            return
        self.send_response(404)
        self.end_headers()

    def log_message(self, format, *args):
        print("%s %s" % (self.path, self.log_date_time_string()), flush=True)

ThreadingHTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
PY

cat >/etc/systemd/system/order-api.service <<'UNIT'
[Unit]
Description=Workshop Order API
After=network-online.target

[Service]
ExecStart=/usr/bin/python3 /opt/order-api.py
Restart=always
RestartSec=2
User=root

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
if systemctl list-unit-files nginx.service >/dev/null 2>&1; then
  systemctl disable --now nginx || true
fi
pkill -x nginx 2>/dev/null || true
systemctl enable order-api
systemctl restart order-api
test -f /etc/systemd/system/order-api.service
systemctl is-active --quiet order-api
