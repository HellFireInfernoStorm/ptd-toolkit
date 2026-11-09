#!/usr/bin/env bash
# fetch-binaries.sh — download the privesc/enum binaries into payloads/.
# RUN THIS AT HOME WITH INTERNET, BEFORE THE EXAM. Commit the binaries so a clone has them.
# These are standard, well-known pentest tools for an AUTHORISED university CTF exam.
# Usage:  bash scripts/fetch-binaries.sh
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../payloads" && pwd)"
cd "$DIR"
echo "[*] Fetching into: $DIR"

dl(){ # dl <url> <outfile> [tries]   — retries on transient GitHub errors (e.g. 504)
  local url="$1" out="$2" tries="${3:-3}" i
  if [ -s "$out" ]; then echo "    [=] $out already present, skip"; return 0; fi
  for i in $(seq 1 "$tries"); do
    echo "    [>] $out (try $i/$tries)"
    if command -v curl >/dev/null; then
      curl -fsSL --retry 3 --retry-delay 2 --connect-timeout 20 "$url" -o "$out" && [ -s "$out" ] && return 0
    else
      wget -q --tries=3 --timeout=20 "$url" -O "$out" && [ -s "$out" ] && return 0
    fi
    rm -f "$out"; sleep 3
  done
  echo "        [-] FAILED after $tries tries: $url"
  return 1
}

# --- Windows privesc: Potato family (SeImpersonate -> SYSTEM) ------------------
# SigmaPotato (maintained NG potato; --revshell / --cmd). Grab latest release asset.
dl "https://github.com/tylerdotrar/SigmaPotato/releases/latest/download/SigmaPotato.exe" "SigmaPotato.exe"
# PrintSpoofer
dl "https://github.com/itm4n/PrintSpoofer/releases/download/v1.0/PrintSpoofer64.exe" "PrintSpoofer64.exe"
dl "https://github.com/itm4n/PrintSpoofer/releases/download/v1.0/PrintSpoofer32.exe" "PrintSpoofer32.exe"
# GodPotato (pick the .NET build that matches the target; grab the common ones)
dl "https://github.com/BeichenDream/GodPotato/releases/download/V1.20/GodPotato-NET4.exe" "GodPotato-NET4.exe"
dl "https://github.com/BeichenDream/GodPotato/releases/download/V1.20/GodPotato-NET35.exe" "GodPotato-NET35.exe"

# --- Windows enum -------------------------------------------------------------
dl "https://github.com/peass-ng/PEASS-ng/releases/latest/download/winPEASx64.exe" "winPEASx64.exe"
dl "https://github.com/peass-ng/PEASS-ng/releases/latest/download/winPEASany.exe"  "winPEASany.exe"
# Seatbelt / SharpUp (optional, C# enum) — add if you use them.

# --- nc.exe (both archs) ------------------------------------------------------
dl "https://github.com/int0x33/nc.exe/raw/master/nc.exe"   "nc.exe"
dl "https://github.com/int0x33/nc.exe/raw/master/nc64.exe" "nc64.exe"
# Fallback: Kali bundles nc.exe (32-bit) under windows-resources — use it if the download failed.
for n in nc.exe nc64.exe; do
  if [ ! -s "$n" ]; then
    for src in "/usr/share/windows-resources/binaries/$n" "/usr/share/windows-binaries/$n"; do
      [ -f "$src" ] && cp "$src" "$n" && echo "    [+] $n copied from $src" && break
    done
  fi
done

# --- Linux privesc / enum -----------------------------------------------------
dl "https://github.com/peass-ng/PEASS-ng/releases/latest/download/linpeas.sh" "linpeas.sh"
dl "https://github.com/DominicBreuker/pspy/releases/download/v1.2.1/pspy64"    "pspy64"
dl "https://github.com/DominicBreuker/pspy/releases/download/v1.2.1/pspy32"    "pspy32"
# LinEnum (classic)
dl "https://raw.githubusercontent.com/rebootuser/LinEnum/master/LinEnum.sh" "LinEnum.sh"

# --- Linux kernel exploits (local-root PoCs, last resort) ---------------------
# PwnKit (CVE-2021-4034) self-contained
dl "https://raw.githubusercontent.com/ly4k/PwnKit/main/PwnKit.c" "PwnKit.c"

chmod +x linpeas.sh LinEnum.sh pspy64 pspy32 2>/dev/null || true

echo
echo "[*] Done. Contents:"
ls -la "$DIR"
echo
echo "[!] Verify each file downloaded (size > 0). Some URLs/tags drift over time — if one fails,"
echo "    grab it manually from the project's GitHub Releases page and drop it in payloads/."
echo "[!] GodPotato: match -NET<ver> to the target's installed .NET. If unsure, try NET4 first."
