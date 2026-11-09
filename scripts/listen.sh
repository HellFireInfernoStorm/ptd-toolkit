#!/usr/bin/env bash
# listen.sh — start a reverse-shell listener on an exam-legal port.
# Usage:  bash scripts/listen.sh [4444|5555|6666]   (default 4444)
# Uses rlwrap for history/arrow keys if available.
set -uo pipefail

PORT="${1:-4444}"
case "$PORT" in
  4444|5555|6666) ;;
  *) echo "[-] Port must be 4444, 5555, or 6666 (exam rule). Got: $PORT"; exit 1;;
esac

echo "[*] Listening on 0.0.0.0:$PORT  (Ctrl-C to stop)"
echo "    4444=foothold  5555=privesc/SYSTEM  6666=spare/exfil"
if command -v rlwrap >/dev/null 2>&1; then
  exec rlwrap nc -lvnp "$PORT"
else
  echo "[!] rlwrap not found (no history). Install: sudo apt install rlwrap"
  exec nc -lvnp "$PORT"
fi
