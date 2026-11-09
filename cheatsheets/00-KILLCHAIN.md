# 00 — EXAM-DAY KILL CHAIN (start here)

**Target = Windows. 3 flags. Goal = SPEED.** This is the driver sheet. Set your two variables once,
then follow the chain. Every other sheet (`01`–`07`) is a drill-down you jump to as needed.

```bash
# Run this FIRST in every terminal (or use setup.sh aliases):
export RHOST=10.x.x.x        # target IP
export LHOST=10.x.x.x        # your Kali IP (ip a | grep <iface>)
```

## ⛔ Rules burned into every command here
- Reverse-shell / payload ports: **4444, 5555, 6666 ONLY** (4444 main · 5555 privesc · 6666 spare).
- **Metasploit = ONE use all exam.** Spend it on a foothold exploit, never on privesc (privesc is manual
  → bonus marks). `msfvenom` and `nc` listeners do NOT count as the one use.
- **Be gentle.** No `-T5`, no full-rockyou sprays. Loud = IP blacklisted = exam over.
- Passwords = **top ~250 of rockyou** or uncrackable. >2–3 min cracking/guessing ⇒ STOP, pivot.
- **"The answer is often obvious."** Read every note/readme/share/comment. Don't overthink.
- Screenshot + log EVERY command as you go (for the report). `script loot/session-$(date +%H%M).log`.

## ⏱️ Time budget (90-ish min feel — adjust)
`easy ≈ 20 min · intermediate ≈ 30 min · hard ≈ 40 min`. If a flag stalls 15 min past budget, bank what
you have, write it up, move on. Easy = Pass, easy+inter = up to Distinction, all 3 = up to HD.

---
## THE CHAIN

### ① RECON  → `01-recon-enum.md`
```bash
# gentle full-port, then service scan on what's open
nmap -Pn -n -T3 -p- --open -oN loot/nmap-allports.txt $RHOST
nmap -Pn -n -T3 -sV -sC -p <csv_open_ports> -oN loot/nmap-services.txt $RHOST
```
→ Note every open port + service/version. **Web apps often sit on a high random port** (e.g. 28553).

### ② FOOTHOLD (get the easy flag + a shell)  → `02-foothold.md`
Match what's open to one of the **4 Windows archetypes**:
| See this | Do this | Sheet |
|----------|---------|-------|
| SMB (445) | `smbclient -L //$RHOST -N` → anon share → read flag / loot creds | 02 |
| FTP (21) | anon login → download flag/notes; writable? → drop payload | 02 |
| HTTP (80/high) | view-source, gobuster, `sitemap.xml`, robots → RCE / login | 02 |
| Service port w/ version | `searchsploit <product ver>` → public exploit (**MSF one-use here**) | 02 |
→ Easy flag usually readable right here (share / web artefact / home dir).

### ③ REVERSE SHELL (turn RCE/creds into an interactive shell)  → `03-shells.md`
```bash
# Kali listener FIRST:
nc -lvnp 4444
# then fire the matching payload (web RCE, scheduled pull, service, etc.) back to $LHOST:4444
```
→ Upgrade to a usable shell, then enumerate for privesc.

### ④ PRIVESC (intermediate + hard usually live here)
- **Windows** → `04-win-privesc.md` — **FIRST: `whoami /priv`**.
  ⭐ **SeImpersonate → upload SigmaPotato → SYSTEM** is THE path (service accts almost always have it).
  Else: scheduled-task/service token hijack · writable service .exe · AlwaysInstallElevated MSI.
- **Linux** (if a box is Linux) → `05-lin-privesc.md` — **FIRST: `sudo -l` + SUID + `getcap` + cron**.
  ⭐ writable root-cron script · sudo-NOPASSWD GTFOBins · cap_setuid.
→ As SYSTEM/root: `type C:\Users\Administrator\Desktop\*flag*` / `cat /root/*flag*`.

### ⑤ REPORT  → `07-transfer.md` for exfil, `Report Template.docx` for write-up
Each flag: screenshot the flag value + the command that got it + a one-line method note.

---
## Supporting drills
- Move files Kali ↔ target: **`07-transfer.md`** (`certutil`, `Invoke-WebRequest`, `python3 -m http.server 8081`).
- Crack/guess a password: **`06-passwords.md`** (hash-ID → hashcat/john; hydra/medusa top-250, slow).

## If you're stuck (decision nudges)
```
No foothold?      -> re-enum: every port, gobuster -x php,txt,json, sitemap.xml, robots, view-source,
                     SMB/RPC null session, SNMP (161/udp), anon FTP. The box left a breadcrumb.
Shell but no priv?-> Windows: whoami /priv (SeImpersonate?), schtasks, sc qc, icacls writable paths,
                     read every readme/.ps1/.bak near the last flag, PowerShell history.
                     Linux: sudo -l, find / -perm -4000, getcap -r /, cat /etc/crontab, pspy.
Password wall?    -> top-250 only, one user, 2 min max. Else it's NOT the path — find another vector.
Everything slow?  -> you're probably overthinking. The intended path is simpler than it looks.
```
Reverse-shell ports **4444/5555/6666**. MSF **once**. Gentle scans. Log everything.
