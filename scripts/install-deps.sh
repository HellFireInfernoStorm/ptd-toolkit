#!/usr/bin/env bash
# install-deps.sh — install the Kali packages the toolkit needs. Idempotent; uses sudo.
# Tuned for the exam base image. Safe to re-run: skips tools already present, skips any
# apt name not in the repo (so a renamed/absent package can never abort the whole install).
# Called automatically by setup.sh (set SKIP_APT=1 to skip there), or run on its own:
#   bash scripts/install-deps.sh
set -uo pipefail

# Command names we expect on PATH (detect what's missing) --------------------
NEED=(nmap smbclient enum4linux-ng nxc gobuster hydra medusa hashcat john hashid \
      searchsploit msfvenom msfconsole nc rlwrap evil-winrm sqsh impacket-mssqlclient \
      impacket-smbserver snmpwalk whatweb curl wget python3)

missing=(); for t in "${NEED[@]}"; do command -v "$t" >/dev/null 2>&1 || missing+=("$t"); done
rdp_ok=0; { command -v xfreerdp >/dev/null 2>&1 || command -v xfreerdp3 >/dev/null 2>&1; } && rdp_ok=1

if [ "${#missing[@]}" -eq 0 ] && [ "$rdp_ok" -eq 1 ]; then
  echo "[+] All required tools already present — nothing to apt-install."
else
  [ "${#missing[@]}" -gt 0 ] && echo "[*] Missing commands: ${missing[*]}"
  [ "$rdp_ok" -eq 0 ]        && echo "[*] Missing: RDP client (xfreerdp/xfreerdp3)"

  # apt package names (superset; apt no-ops the ones already installed) -------
  PKGS=(nmap smbclient enum4linux-ng netexec gobuster hydra medusa hashcat john hashid \
        exploitdb metasploit-framework netcat-traditional rlwrap evil-winrm freerdp3-x11 \
        sqsh python3-impacket impacket-scripts snmp whatweb curl wget python3 seclists wordlists)

  echo "[*] apt-get update ..."
  sudo apt-get update -y || echo "    [-] apt update failed (offline?) — continuing anyway"

  # keep only packages that actually exist in the repo on this image ----------
  avail=()
  for p in "${PKGS[@]}"; do
    if apt-cache show "$p" >/dev/null 2>&1; then avail+=("$p"); else echo "    [-] not in apt, skipping: $p"; fi
  done
  echo "[*] Installing: ${avail[*]}"
  sudo apt-get install -y "${avail[@]}" || echo "    [-] some packages failed — re-run or install by hand"
fi

# FreeRDP 3 ships the binary as `xfreerdp3`; the cheat sheets call `xfreerdp`.
# Symlink once so every `xfreerdp ...` command works unchanged.
if ! command -v xfreerdp >/dev/null 2>&1 && command -v xfreerdp3 >/dev/null 2>&1; then
  sudo ln -sf "$(command -v xfreerdp3)" /usr/local/bin/xfreerdp && echo "[+] symlinked xfreerdp -> xfreerdp3"
fi

echo "[*] install-deps done."
