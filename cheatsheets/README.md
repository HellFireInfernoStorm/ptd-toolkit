# cheatsheets/ — exam-day copy-paste playbooks

Open **`00-KILLCHAIN.md` first** and drive from it. The rest are drill-downs you jump to.
Everything is copy-paste-first with `$RHOST` (target) / `$LHOST` (Kali) placeholders.
Reverse-shell ports are **4444 / 5555 / 6666 only**. Metasploit **once** (foothold). Scan **gently**.

| Sheet | When you reach for it |
|-------|-----------------------|
| `00-SETUP.md` | Fresh-Kali setup + **full guide to every script, alias & function** (recon, web, winrev…). |
| `00-KILLCHAIN.md` | **Start here on a box.** Master chain recon→foothold→privesc, time budget, stuck-nudges. |
| `01-recon-enum.md` | Port scan + per-service enum (SMB, FTP, HTTP, RDP, MSSQL, SNMP, WinRM). |
| `02-foothold.md` | Get the easy flag + first shell — 4 Windows archetypes + web vectors. |
| `03-shells.md` | Listeners + reverse-shell payloads (Win/Linux) + TTY upgrade. |
| `04-win-privesc.md` | ⭐ SeImpersonate→SigmaPotato→SYSTEM, task hijack, writable svc, AIE, xp_cmdshell. |
| `05-lin-privesc.md` | sudo/SUID/caps/writable-cron/MOTD/kernel (if a target is Linux). |
| `06-passwords.md` | Hash-ID → crack (top-250) / gentle online guess; where to use creds. |
| `07-transfer.md` | Move files Kali↔target (certutil, IWR, SMB, http.server 8081); exfil. |
| `08-reporting.md` | **Part 2 report guide** — fill `Report Template.docx`; technique→finding→risk→remediation Library. PDF: `../PTD-Report-Guide.pdf`. |

**Exam-day flow:** set `$RHOST`/`$LHOST` → `01` scan → `02` foothold+easy flag → `03` shell →
`04`/`05` privesc for intermediate+hard → log + screenshot each flag for the report.

> Deeper "why" explanations + worked tutorial examples live in the project's `context/concepts/`
> (not shipped on exam day). These sheets are the self-contained field reference.
