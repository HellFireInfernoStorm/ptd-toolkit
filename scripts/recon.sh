#!/usr/bin/env bash
# recon.sh — gentle, scripted recon of a target. Writes to loot/.
# Usage:  bash scripts/recon.sh <RHOST>
# Be gentle by design: -T2, no -A blast, gobuster -t 4. Does NOT brute-force anything.
set -uo pipefail

RHOST="${1:-${RHOST:-}}"
[ -z "$RHOST" ] && { echo "usage: bash scripts/recon.sh <target-ip>"; exit 1; }
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/loot/nmap"; mkdir -p "$OUT"
echo "[*] Recon $RHOST (gentle). Output -> $OUT"

# 1) all TCP ports, slow
echo "[*] Full TCP port sweep (-p- -T2)... this is slow on purpose."
nmap -Pn -n -T2 -p- --open -oN "$OUT/allports.txt" "$RHOST"

# 2) extract open ports
PORTS="$(grep -oE '^[0-9]+/tcp' "$OUT/allports.txt" | cut -d/ -f1 | paste -sd, -)"
echo "[*] Open TCP ports: ${PORTS:-none}"
[ -z "$PORTS" ] && { echo "[-] No open ports found. Re-check connectivity / firewall."; exit 0; }

# 3) service + default scripts on open ports only
echo "[*] Service/version scan on $PORTS ..."
nmap -Pn -n -T2 -sV -sC -p "$PORTS" -oN "$OUT/services.txt" "$RHOST"

# 4) hints
echo
echo "========== HINTS (read services.txt) =========="
grep -Ei '445|139|microsoft-ds|netbios' "$OUT/services.txt" >/dev/null 2>&1 && \
  echo "  [SMB]  smbclient -L //$RHOST -N   ;   nxc smb $RHOST -u '' -p '' --shares"
grep -Ei '(^|[^0-9])21/tcp|ftp' "$OUT/services.txt" >/dev/null 2>&1 && \
  echo "  [FTP]  ftp -n $RHOST  (anonymous/anonymous)"
grep -Ei 'http' "$OUT/services.txt" >/dev/null 2>&1 && \
  echo "  [HTTP] whatweb + gobuster + curl robots.txt/sitemap.xml  (ports: $(grep -Ei 'http' "$OUT/services.txt" | grep -oE '^[0-9]+' | paste -sd, -))"
grep -Ei '3389|ms-wbt' "$OUT/services.txt" >/dev/null 2>&1 && \
  echo "  [RDP]  xfreerdp /u:<u> /p:'<p>' /v:$RHOST /cert:ignore   (need creds)"
grep -Ei '1433|ms-sql' "$OUT/services.txt" >/dev/null 2>&1 && \
  echo "  [MSSQL] sqsh -S $RHOST -U <u> -P '<p>'  -> xp_cmdshell (04 §5)"
grep -Ei '5985|5986|winrm|wsman' "$OUT/services.txt" >/dev/null 2>&1 && \
  echo "  [WinRM] evil-winrm -i $RHOST -u <u> -p '<p>'  (need creds)"
echo "==============================================="
echo "[*] Next: cheatsheets/02-foothold.md"
