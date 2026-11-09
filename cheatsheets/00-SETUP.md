# 0 · Setup & Toolkit Guide

Everything to stand up Kali from scratch, then a full reference for **every script, alias, and
function** in the toolkit. Read this page first; the rest of the PDF is the per-phase playbook.

---

## A. Fresh Kali from scratch — ONE command

Public repo, no login. On a bare Kali box, this installs deps, clones the repo, builds wordlists +
aliases, and fetches the privesc binaries:
```bash
curl -fsSL https://raw.githubusercontent.com/HellFireInfernoStorm/ptd-toolkit/main/bootstrap.sh | bash
```
Then load the helpers into your **current** shell (new terminals load them automatically):
```bash
source ~/ptd-toolkit/aliases.sh
```
**Toggles:** `SKIP_APT=1` (skip apt), `SKIP_FETCH=1` (skip binary download), `DEST=/path` (clone elsewhere).

### If you'd rather do it by hand (what bootstrap does for you)
```bash
git clone https://github.com/HellFireInfernoStorm/ptd-toolkit.git && cd ptd-toolkit
bash setup.sh            # apt deps (sudo) + wordlists + aliases + tool check
source aliases.sh        # load sett/recon/web/l4/winrev...
bash scripts/fetch-binaries.sh    # pull SigmaPotato, winPEAS, nc.exe, linpeas... (gitignored, not in repo)
ls -la payloads/         # verify each file size > 0
```

### Verify the box is ready
```bash
type sett recon winrev venexe        # helpers present (they're FUNCTIONS, so `alias` won't list them)
which nmap gobuster evil-winrm xfreerdp3 impacket-mssqlclient searchsploit
sett 10.10.10.10 ; vars              # RHOST set + LHOST auto-detected (both must show)
```
If `git pull` ever complains about file modes: `git config core.fileMode false && git pull`.

### Per-box workflow (the whole exam in 6 lines)
```bash
sett <target-ip>          # set RHOST + auto LHOST (route to target)
recon                     # thorough, port-agnostic recon → read the HINTS/SUMMARY
#   pick a foothold from the hints (web/SMB/FTP/exploit) — cheatsheet 02
l4                        # listener on 4444, THEN trigger your payload (winrev 4444)
#   whoami /priv on the shell → cheatsheet 04 (SeImpersonate → potato → SYSTEM)
#   type the flags; screenshot each step (recon.log + loot/ have the evidence)
```

---

## B. Scripts reference

| Script | Usage | What it does |
|--------|-------|--------------|
| `bootstrap.sh` | `curl …/bootstrap.sh \| bash` | One-shot fresh-Kali: install git → clone/update → `setup.sh` → `fetch-binaries.sh` → wire aliases into your shell rc. Toggles: `DEST=`, `SKIP_APT=1`, `SKIP_FETCH=1`. |
| `setup.sh` | `bash setup.sh` | apt deps (via `install-deps.sh`), builds trimmed wordlists, **generates `aliases.sh`**, checks tools. `SKIP_APT=1 bash setup.sh` to skip apt. Re-run it any time you pull new aliases. |
| `scripts/install-deps.sh` | `bash scripts/install-deps.sh` | apt-installs everything the toolkit needs (nmap, gobuster, evil-winrm, freerdp3, impacket, seclists…) and symlinks `xfreerdp → xfreerdp3`. |
| `scripts/recon.sh` | `recon [ip]` or `bash scripts/recon.sh <ip>` | **The workhorse** — see §C below. |
| `scripts/fetch-binaries.sh` | `bash scripts/fetch-binaries.sh` | Downloads the privesc/enum binaries (SigmaPotato, PrintSpoofer, GodPotato, winPEAS, nc.exe, linpeas, pspy…). Retries on GitHub 504s; skips files already present. |
| `scripts/serve.sh` | `serve` or `bash scripts/serve.sh [port]` | Serves `payloads/` over HTTP (default **:8081**) and prints the `certutil`/`wget` pull commands with your LHOST filled in. |
| `scripts/listen.sh` | `l4`/`l5`/`l6` or `bash scripts/listen.sh [port]` | `rlwrap nc` listener; refuses any port that isn't 4444/5555/6666 (exam rule). |

### Evidence: every script prints each command + its output to the terminal AND saves it
`recon.sh` writes a full transcript to `loot/recon-<ip>/recon.log` and per-service nmap files; `serve.sh`
and `listen.sh` echo the exact command they run. **Screenshot straight from the terminal** — you never
need to re-run anything, and the files in `loot/` are your backup copy.

---

## C. `recon.sh` — thorough, port-agnostic recon

```bash
recon                     # uses $RHOST (set by sett)
recon 10.10.10.10         # or pass an IP
MODE=gentle recon         # quieter: no UDP, no vuln scripts
sudo recon                # needed for the UDP phase + OS detection
```
**What it does, in order** (all at gentle `-T3`):
1. **Full TCP sweep** (`-p-`) → finds every open port.
2. **Version + default-script scan** (`-sV -sC`, +`-O` if root) on those ports.
3. **UDP top-100** (thorough/balanced) → SNMP/TFTP/DNS that hide on odd ports.
4. **Per-service enumeration** — for EACH service nmap identifies (by banner, **not** by port number):
   targeted NSE scripts, `nmap vuln` scripts (thorough), an offline **searchsploit** on the version,
   and an **auto quick `gobuster`** on any web port. Then prints **HINTS** with the exact next command.
5. **SUMMARY** — a port→service→version table and all the hints, also saved to `loot/recon-<ip>/summary.txt`.

**Modes / toggles:** `MODE=gentle|balanced|thorough` (default **thorough**). Override individually:
`UDP=1/0`, `VULN=1/0`, `DIRB=1/0` (auto web dir scan). Example: `MODE=thorough UDP=0 recon`.

> **Why port-agnostic matters:** if the lecturer puts the web server on 8531 or SMB on 1445, recon
> still identifies the *service* and runs the right enumeration against **that** port — and the HINTS
> hand you commands with the real port already filled in. No more losing time guessing the port.

---

## D. Targeting — set these once per box

| Command | Does |
|---------|------|
| `sett <ip>` | export **RHOST** (target) **and auto-detect LHOST** (your IP on the route to the target) |
| `seti <iface>` | override LHOST from an interface, e.g. `seti tun0` (or just `export LHOST=…`) |
| `vars` | show current `RHOST` / `LHOST` — check both are set before anything else |

Every helper below reads `$RHOST`/`$LHOST`, so set them first.

## E. Service helpers — **all take the REAL port** (odd ports welcome)

| Command | Usage | Does |
|---------|-------|------|
| `recon [ip]` | `recon` | full port-agnostic recon (§C) |
| `nmapfast` | `nmapfast $RHOST` | quick full-port sweep (`-T3 -p-`) |
| `nmapsvc <ports> [ip]` | `nmapsvc 80,445` | version+script scan of specific ports |
| `smbnull [port]` | `smbnull` / `smbnull 1445` | list SMB shares via null session |
| `smap [port]` | `smap` / `smap 1445` | smbmap — shares + READ/WRITE level |
| `web <port> [path]` | `web 8080` | whatweb + headers + quick gobuster on that port |
| `gob <port> [wordlist]` | `gob 8080` | deeper gobuster (medium list) on that port |
| `fuzz <url> [wordlist]` | `fuzz 'http://$RHOST:8080/p?FUZZ=x'` | ffuf param/content fuzz (auto-calibrated) |
| `rdp <user> <pass> [port]` | `rdp maris 'Summer2026!'` | xfreerdp3 session (default 3389) |
| `winrm <user> <pass> [port]` | `winrm maris 'Summer2026!'` | evil-winrm PowerShell shell (default 5985) |
| `ssql <user> <pass> [port]` | `ssql sa 'P@ss'` | impacket-mssqlclient (default 1433) → `xp_cmdshell` |

## F. Shells, serving & payloads — **your fixed infra ports**

| Command | Does |
|---------|------|
| `l4` / `l5` / `l6` | `rlwrap nc` listener on 4444 / 5555 / 6666 (4444=foothold, 5555=privesc, 6666=spare) |
| `serve` | `python3 -m http.server 8081` over `payloads/` (prints the certutil/wget pull lines) |
| `smbserve` | `impacket-smbserver share $(pwd) -smb2support` — SMB delivery when HTTP is filtered |
| `winrev [port]` | print a ready-to-paste **Windows PowerShell reverse shell** with your LHOST baked in (arg = PORT; ip-tolerant) |
| `venexe [port]` | `msfvenom` a `windows/x64` reverse-shell **exe** into `payloads/` (does NOT burn the one MSF use) |

## G. Evidence helper

| Command | Does |
|---------|------|
| `ev <command…>` | run any manual command, printing `+ <command>` then its output, and tee it to `loot/manual-<ip>.log`. Use it so ad-hoc commands are screenshot-ready too. e.g. `ev smbclient //$RHOST/Share -N` |

---

## H. Port-swap resistance — the whole system assumes nothing about ports

- **`recon`** classifies by the service nmap detects, not by port, and auto-runs web dir scans on
  whatever port the web server is really on.
- **Every service helper takes the port as an argument** (`web 8531`, `smbnull 1445`,
  `winrm u p 9985`) — so when recon says "http on 8531", you run `web 8531` and move on.
- The only fixed ports are **yours**: listeners 4444/5555/6666 and the `serve` port 8081. Those are
  exam rules / your choice, not the target's.

**Reminder of the exam rules baked into the toolkit:** reverse-shell ports **4444/5555/6666 only** ·
**Metasploit once** (save it for a foothold) · **be gentle** (`-T3`, never `-T5`, no rockyou sprays) ·
passwords in rockyou **top ~250** or uncrackable · serve on **:8081** · flags in user/Admin **Desktop** dirs.
